//
//  PeerController.m
//  l2e_player
//
//  Created by mac on 2018/7/31.
//  Copyright © 2018年 gen. All rights reserved.
//

#import "PeerController.h"
//#import "AFNetworking.h"
#import "PCConnection.h"
#import <SocketRocket/SocketRocket.h>

static PeerController *_peerController = nil;

@interface PeerController() <SRWebSocketDelegate, PCConnectionConnectDelegate>
@end

@implementation PeerController {
    NSURLSession *_session;
    NSURLSessionDataTask *_dataTask;
    SRWebSocket *_client;
    NSMutableArray<NSDictionary *> *_messageQueue;
    NSMutableDictionary<NSString *, NSMutableArray *> *_connections;
}

+ (PeerController*)defaultController {
    @synchronized([PeerController class]) {
        if (!_peerController) {
            _peerController = [[PeerController alloc] init];
        }
    }
    return _peerController;
}

- (id)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 10;
        _session = [NSURLSession sessionWithConfiguration:config];
        _messageQueue = [NSMutableArray array];
        
        _connections = [NSMutableDictionary dictionary];
        _delegate = [[PCDelegate<PeerControllerDelegate> alloc] initWithProtocol:@protocol(PeerControllerDelegate)];
    }
    return  self;
}

- (void)dealloc {
    [_session invalidateAndCancel];
}

- (void)setStatus:(PeerControllerStatus)status {
    if (_status != status) {
        [self.delegate peerController:self
                        statusChanged:status];
        _status = status;
    }
}

- (void)setPeerId:(NSString *)peerId {
    _peerId = peerId;
}

- (void)start {
    if (_status != PeerControllerNone) {
        return;
    }
    [self setStatus:PeerControllerConnecting];
    [self loadId];
}

- (void)stop {
    [self setStatus:PeerControllerNone];
    if (_client.readyState != SR_CLOSED) {
        [_client close];
        _client = nil;
    }
}

- (void)loadId {
    NSString *url = [self.hostURL stringByAppendingString:@"/peerjs/peerjs/id"];
    __weak PeerController *this = self;
    _dataTask = [_session dataTaskWithURL:[NSURL URLWithString:url]
                        completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                            NSHTTPURLResponse *httpRes = (NSHTTPURLResponse*)response;
                            if (httpRes.statusCode != 200) {
                                [this setStatus:PeerControllerNone];
                            }else {
                                char chs[17];
                                memcpy(chs, data.bytes, data.length);
                                chs[16] = 0;
                                [this setPeerId:[NSString stringWithFormat:@"%s", chs]];
                                
                                [this gotId];
                            }
                        }];
    [_dataTask resume];
}

- (PCConnection *)getConnection:(NSString*)peer clientId:(NSString *)clientId {
    NSMutableArray *arr = [_connections objectForKey:peer];
    if (arr) {
        for (NSInteger i = 0, t = arr.count; i < t; ++i) {
            PCConnection *conn = [arr objectAtIndex:i];
            if ([conn.clientId isEqualToString:clientId]) {
                return conn;
            }
        }
    }
    return nil;
}

- (void)addConnection:(PCConnection *)conn {
    NSMutableArray *arr = [_connections objectForKey:conn.peer];
    if (!arr) {
        arr = [NSMutableArray array];
        [_connections setObject:arr forKey:conn.peer];
    }
    [arr addObject:conn];
}

- (void)removeConnection:(PCConnection *)conn {
    NSMutableArray *arr = [_connections objectForKey:conn.peer];
    if (arr) {
        [arr removeObject:conn];
    }
}

- (PCConnection *)connect:(NSString *)peer {
    PCConnection *conn = [[PCConnection alloc] initWithPeer:peer
                                                 controller:self];
    [self addConnection:conn];
    [conn connect];
    
    return conn;
}

- (void)gotId {
    NSString *url;
    if ([self.hostURL hasPrefix:@"https://"]) {
        url = [self.hostURL stringByReplacingOccurrencesOfString:@"https://"
                                                      withString:@"wss://"];
    }else {
        url = [self.hostURL stringByReplacingOccurrencesOfString:@"http://"
                                                      withString:@"ws://"];
    }
    url = [url stringByAppendingFormat:@"/peerjs/peerjs?key=peerjs&id=%@&token=%ld", _peerId, random()];
    
    [self setStatus:PeerControllerConnecting];
    
    _client = [[SRWebSocket alloc] initWithURL:[NSURL URLWithString:url]];
    _client.delegate = self;
    [_client open];
}

- (void)send:(NSDictionary *)dic {
    if (_status == PeerControllerConnected) {
        NSError *error;
        if (!dic)return;
        NSData *data = [NSJSONSerialization dataWithJSONObject:dic
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
        if (!error) {
            [_client send:[[NSString alloc] initWithData:data
                                                encoding:NSUTF8StringEncoding]];
        }else {
            NSLog(@"error: %@", error);
        }
    }else {
        [_messageQueue addObject:[dic copy]];
        if (_status == PeerControllerNone) {
            [self start];
        }
    }
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
    
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    NSLog(@"L2E Output: close with %@", reason);
    [self setStatus:PeerControllerNone];
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessageWithString:(NSString *)string {
    NSError *error;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:[string dataUsingEncoding:NSUTF8StringEncoding]
                                                         options:NSJSONReadingMutableLeaves
                                                           error:&error];
    NSString *type = [json objectForKey:@"type"];
    NSDictionary *payload = [json objectForKey:@"payload"];
    NSString *fromPeer = [json objectForKey:@"src"];
    if ([type isEqualToString:@"OPEN"]) {
        [self setStatus:PeerControllerConnected];
        [_messageQueue enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [self send:obj];
        }];
        [_messageQueue removeAllObjects];
    }else if ([type isEqualToString:@"ERROR"] || [type isEqualToString:@"ID-TAKEN"] || [type isEqualToString:@"INVALID-KEY"]) {
        [self setStatus:PeerControllerNone];
        if (_client.readyState != SR_CLOSED) {
            [_client close];
        }
        _client = nil;
    }else if ([type isEqualToString:@"OFFER"]) {
        NSString *connectionId = [payload objectForKey:@"connectionId"];
        PCConnection *conn = [self getConnection:fromPeer clientId:connectionId];
        if (!conn) {
            conn = [[PCConnection alloc] initWithPeer:fromPeer controller:self payload:payload];
            [self addConnection:conn];
            
            NSString *payloadType = [payload objectForKey:@"type"];
            if ([payloadType isEqualToString:@"data"]) {
                [conn onOffer:payload];
            }else {
                
            }
            conn.managerDelegate = self;
            
            [self addConnection:conn];
            [self.delegate peerController:self onConnection:conn];
        }
    }else if ([type isEqualToString:@"LEAVE"]){
        
    }else if ([type isEqualToString:@"EXPIRE"]) {
        
    }else if ([type isEqualToString:@"BEAT"]) {
        [_client send:@"{\"type\": \"ECHO\"}"];
    } else {
        if (payload) {
            NSString *clientId = [payload objectForKey:@"connectionId"];
            if (clientId) {
                PCConnection *conn = [self getConnection:fromPeer clientId:clientId];
                [conn onMessage:json];
            }
        }
    }
    NSLog(@"message : %@", string);
}

- (void)onClose:(PCConnection *)conn {
    [self removeConnection:conn];
}

- (void)onOpen:(PCConnection *)conn {
    
}


@end
