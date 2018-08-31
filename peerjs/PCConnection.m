//
//  PCConnection.m
//  l2e_player
//
//  Created by mac on 2018/8/1.
//  Copyright © 2018年 gen. All rights reserved.
//

#import "PCConnection.h"
#import "PeerController.h"
#import "BandwidthLimiter.h"
//#import <WebRTC/WebRTC.h>
#import "libjingle_peerconnection/RTCPeerConnection.h"
#import "libjingle_peerconnection/RTCPeerConnectionFactory.h"
#import "libjingle_peerconnection/RTCPeerConnectionInterface.h"
#import "libjingle_peerconnection/RTCDataChannel.h"
#import "libjingle_peerconnection/RTCICEServer.h"
#import "libjingle_peerconnection/RTCMediaConstraints.h"
#import "libjingle_peerconnection/RTCSessionDescription.h"
#import "libjingle_peerconnection/RTCICECandidate.h"
#import "RTCPeerConnectionProxy.h"

#define ChunkedMTU 16300

static RTCPeerConnectionFactory *_PCPeerConnectionFactory = NULL;
static NSInteger PCPeerConnectionDataCount = 0;

typedef enum : NSUInteger {
    PCConnectionBinary,
    PCConnectionBinaryUTF8,
    PCConnectionJSON,
} PCConnectionSerialization;

@interface DataSet : NSObject

@property (nonatomic, readonly) int count;
@property (nonatomic, readonly) NSArray * datas;

- (id)initWithTotal:(int)total;

- (void)setObject:(PackData *)obj atIndex:(NSUInteger)idx;
- (NSData *)pack;

@end

@implementation DataSet {
    NSMutableArray *_datas;
}

- (id)initWithTotal:(int)total {
    self = [super init];
    if (self) {
        _datas = [[NSMutableArray alloc] initWithCapacity:total];
    }
    return self;
}

- (NSArray *) datas {
    return _datas;
}

- (void)setObject:(PackData *)obj atIndex:(NSUInteger)idx {
    PackData *pd = [obj objectForKey:@"data"];
    NSData *bf = pd.bufferValue;
    if (idx > _datas.count) {
        for (NSInteger i = _datas.count, t = idx; i < t; ++i) {
            [_datas addObject:[NSNull null]];
        }
    }
    if (idx == _datas.count) {
        [_datas addObject:bf];
        _count ++;
    }else {
        id old = [_datas objectAtIndex:idx];
        if (old == [NSNull null]) {
            _count++;
        }
        [_datas replaceObjectAtIndex:idx withObject:bf];
    }
}

- (NSData *)pack {
    NSMutableData *pdata = [NSMutableData data];
    for (id data in _datas) {
        if ([data isKindOfClass:NSData.class])
            [pdata appendData:data];
    }
    return pdata;
}

@end

@interface PCConnection() <RTCPeerConnectionDelegate, RTCDataChannelDelegate>

@property (nonatomic, weak) PeerController *controller;

@end

@implementation PCConnection {
    PCConnectionSerialization _serialization;
    RTCPeerConnectionProxy  *_peerConnection;
    RTCDataChannel      *_dataChannel;
    NSMutableArray<NSData *> *_needToSend;
    BOOL    _sendChunk;
    NSMutableDictionary<NSNumber*, DataSet *> * _chunkedDatas;
}


- (NSString*)randomToken {
    long l = (long)(random());
    long t = (long)([NSDate date].timeIntervalSince1970 * 1000) % 1000000;
    return [[NSString stringWithFormat:@"%lx", (l + t)] substringFromIndex:2];
}

- (id)initWithPeer:(NSString *)peer controller:(PeerController*)ctrl {
    self = [super init];
    if (self) {
        self.controller = ctrl;
        _peer = peer;
        
        static NSString *PREFIX = @"dc_";
        _clientId = [PREFIX stringByAppendingString:[self randomToken]];
        
        _serialization = PCConnectionBinary;
        
        if (!_PCPeerConnectionFactory) {
            _PCPeerConnectionFactory = [[RTCPeerConnectionFactory alloc] init];
        }
        _needToSend = [NSMutableArray array];
        _chunkedDatas = [NSMutableDictionary dictionary];
        _messageDelegate = [[PCDelegate<PCConnectionMessageDelegate> alloc] initWithProtocol:@protocol(PCConnectionMessageDelegate)];
    }
    return self;
    
}
- (id)initWithPeer:(NSString *)peer controller:(PeerController*)ctrl payload:(NSDictionary *)payload {
    self = [super init];
    if (self) {
        _peer = peer;
        _clientId = [payload objectForKey:@"connectionId"];
        NSString *ser = [payload objectForKey:@"serialization"];
        if ([ser isEqualToString:@"binary"]) {
            _serialization = PCConnectionBinary;
        }else if ([ser isEqualToString:@"binary-utf8"]) {
            _serialization = PCConnectionBinaryUTF8;
        }else if ([ser isEqualToString:@"json"]) {
            _serialization = PCConnectionJSON;
        }
        
        self.controller = ctrl;
        
        if (!_PCPeerConnectionFactory) {
            _PCPeerConnectionFactory = [[RTCPeerConnectionFactory alloc] init];
        }
        _needToSend = [NSMutableArray array];
        _chunkedDatas = [NSMutableDictionary dictionary];
        _messageDelegate = [[PCDelegate<PCConnectionMessageDelegate> alloc] init];
    }
    return self;
}

- (void)dealloc {
}

- (void)makeConnection {
    NSString *uri = @"stun:stun.xten.com";
    
    RTCConfiguration *configuration = [[RTCConfiguration alloc] init];
    
    configuration.iceServers = @[[[RTCICEServer alloc] initWithURI:[NSURL URLWithString:uri]
                                                          username:@""
                                                          password:@""]];
    
    
    RTCPeerConnection *pc = [_PCPeerConnectionFactory peerConnectionWithConfiguration:configuration
                                                                    constraints:[[RTCMediaConstraints alloc] init]
                                                                       delegate:self];
    _peerConnection = [[RTCPeerConnectionProxy alloc] initWithConnection:pc];
}

- (NSDictionary *)makeJson:(RTCSessionDescription *)sdp {
    if (sdp) {
        NSString *type = sdp.type;
        
//        switch (sdp.type) {
//            case RTCSdpTypeOffer:
//                type = @"offer";
//                break;
//            case RTCSdpTypeAnswer:
//                type = @"answer";
//                break;
//            case RTCSdpTypePrAnswer:
//                type = @"pranswer";
//                break;
//
//            default:
//                break;
//        }
        return @{
                 @"type": type,
                 @"sdp": sdp.description
                 };
    }
    return @{};
}

- (NSDictionary *)makeJsonWithICE:(RTCICECandidate *)ice {
    return @{
             @"candidate": ice.sdp,
             @"sdpMid": ice.sdpMid,
             @"sdpMLineIndex": [NSNumber numberWithInteger:ice.sdpMLineIndex]
             };
}

- (void)connect {
    if (!_peerConnection) {
        [self makeConnection];
    }
    
    RTCDataChannelInit *init = [[RTCDataChannelInit alloc] init];
    init.isOrdered = YES;
    init.protocol = @"";
    _dataChannel = [_peerConnection.peerConnection createDataChannelWithLabel:self.clientId
                                                                       config:init];
    _dataChannel.delegate = self;
    __weak PCConnection *_self = self;
    [_peerConnection createOfferWithConstraints:[[RTCMediaConstraints alloc]  initWithMandatoryConstraints:nil
                                                                                optionalConstraints:nil]
                       block:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
                           if (error) return;
                           [_peerConnection setLocalDescriptionWithSessionDescription:sdp
                                                                                block:^(NSError * _Nullable error) {
                                                                                    if (error) return;
                                                                                    if (!_self.peer) return;
                                                                                    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
                                                                                    [dic setObject:@"OFFER" forKey:@"type"];
                                                                                    [dic setObject:_self.peer forKey:@"dst"];
                                                                                    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
                                                                                    [payload setObject:[_self makeJson:sdp] forKey:@"sdp"];
                                                                                    [payload setObject:@"data" forKey:@"type"];
                                                                                    [payload setObject:_self.clientId forKey:@"connectionId"];
                                                                                    [payload setObject:@YES forKey:@"reliable"];
                                                                                    [payload setObject:@"binary" forKey:@"serialization"];
                                                                                    [payload setObject:@"Chrome" forKey:@"browser"];
                                                                                    [dic setObject:payload forKey:@"payload"];
                                                                                    
                                                                                    [_self.controller send:dic];
                                                                                }];
                       }];
}

- (void)close {
    [_peerConnection.peerConnection close];
}

- (void)onMessage:(NSDictionary *)json {
    NSString *type = [json objectForKey:@"type"];
    if ([type isEqualToString:@"CANDIDATE"]) {
        [self onCandidate:[json objectForKey:@"payload"]];
    }else if ([type isEqualToString:@"ANSWER"]) {
        [self onAnswer:[json objectForKey:@"payload"]];
    }
}
- (void)onOffer:(NSDictionary *)payload {
    if (!_peerConnection) {
        [self makeConnection];
    }
    
    NSString *sdp = [[payload objectForKey:@"sdp"] objectForKey:@"sdp"];
    if (!sdp) return;
    [_peerConnection setRemoteDescriptionWithSessionDescription:[[RTCSessionDescription alloc] initWithType:@"offer"
                                                                                  sdp:sdp] block:^(NSError * _Nullable error) {
        if (error) return;
        [_peerConnection createAnswerWithConstraints:[[RTCMediaConstraints alloc] initWithMandatoryConstraints:nil
                                                                                           optionalConstraints:nil]
                                               block:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
                                                   
                                                   if (error) return;
                                                   [_peerConnection setLocalDescriptionWithSessionDescription:sdp
                                                                                                        block:^(NSError * _Nullable error) {
                                                                                                            if (error) return;
                                                                                                            if (!self.peer) return;
                                                                                                            NSMutableDictionary *dic = [NSMutableDictionary dictionary];
                                                                                                            [dic setObject:@"ANSWER" forKey:@"type"];
                                                                                                            [dic setObject:self.peer forKey:@"dst"];
                                                                                                            NSMutableDictionary *payload = [NSMutableDictionary dictionary];
                                                                                                            [payload setObject:[self makeJson:sdp] forKey:@"sdp"];
                                                                                                            [payload setObject:@"data" forKey:@"type"];
                                                                                                            [payload setObject:self.clientId forKey:@"connectionId"];
                                                                                                            [payload setObject:@YES forKey:@"reliable"];
                                                                                                            [payload setObject:@"binary" forKey:@"serialization"];
                                                                                                            [payload setObject:@"Chrome" forKey:@"browser"];
                                                                                                            [dic setObject:payload forKey:@"payload"];
                                                                                                            
                                                                                                            [self.controller send:dic];
                                                                                                        }];
                                                   
                                               }];
    }];
}

- (void)onCandidate:(NSDictionary *)payload {
    NSDictionary *candidate = [payload objectForKey:@"candidate"];
    if (candidate) {
        [_peerConnection.peerConnection addICECandidate:[[RTCICECandidate alloc] initWithMid:[candidate objectForKey:@"sdpMid"]
                                                                                       index:[[candidate objectForKey:@"sdpMLineIndex"] intValue] sdp:[candidate objectForKey:@"candidate"]]];
    }
}

- (void)onAnswer:(NSDictionary *)payload {
    if (!_peerConnection) return;
    
    _sendChunk = YES;
    NSDictionary *sdpObject = [payload objectForKey:@"sdp"];
    
    NSString *sdp = [sdpObject objectForKey:@"sdp"];
    [_peerConnection setRemoteDescriptionWithSessionDescription:[[RTCSessionDescription alloc] initWithType:@"answer"
                                                                                                        sdp:sdp]
                                                          block:^(NSError * _Nullable error) {
                                                              
                                                          }];
}

- (NSArray *)makeChunks:(NSData *)buffer {
    NSInteger size = buffer.length;
    NSInteger total = ceil(size / (double)ChunkedMTU);
    
    NSMutableArray *chunks = [[NSMutableArray alloc] initWithCapacity:total];
    NSInteger start = 0, index = 0;
    while (start < size) {
        NSInteger end = MIN(size, start + ChunkedMTU);
        
        const char *bytes = (const char *)buffer.bytes;
        NSData *bf = [NSData dataWithBytes:(bytes+start) length:end - start];
        
        PackData *pd = [[PackData alloc] init];
        [pd setObject:[[PackData alloc] initWithInt:(int)PCPeerConnectionDataCount] forKey:@"__peerData"];
        [pd setObject:[[PackData alloc] initWithInt:(int)index] forKey:@"n"];
        [pd setObject:[[PackData alloc] initWithBuffer:bf] forKey:@"data"];
        [pd setObject:[[PackData alloc] initWithInt:(int)total] forKey:@"total"];
        
        [chunks addObject:[pd pack]];
        ++index;
        start = end;
    }
    ++PCPeerConnectionDataCount;
    return chunks;
}

- (void)send:(PackData *)data {
    if (_dataChannel) {
        [self sendRaw:data.pack];
    }
}

- (void)sendRaw:(NSData *)data {
    NSInteger len = data.length;
    if (len > ChunkedMTU) {
        NSArray *arr = [self makeChunks:data];
        for (NSInteger i = 0, t = arr.count; i < t; ++i) {
            [self _send:[arr objectAtIndex:i]];
        }
    }else {
        [self _send:data];
    }
}

- (void)_send:(NSData *)data {
    if ([self canSend]) {
        if ([_dataChannel sendData:[[RTCDataBuffer alloc] initWithData:data
                                                              isBinary:YES]]) {
            // Bind width
            [[BandwidthLimiter getInstance] sendData:data.length];
        }
    }else {
        [_needToSend addObject:data];
    }
}

- (BOOL)canSend {
    return _dataChannel.state == kRTCDataChannelStateOpen && [[BandwidthLimiter getInstance] canSend];
}

- (void)peerConnection:(nonnull RTCPeerConnection *)peerConnection didAddStream:(nonnull RTCMediaStream *)stream {
    
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection iceConnectionChanged:(RTCICEConnectionState)newState {
    
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection iceGatheringChanged:(RTCICEGatheringState)newState {
    
}

- (void)peerConnection:(nonnull RTCPeerConnection *)peerConnection didChangeSignalingState:(RTCSignalingState)stateChanged {
    
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection gotICECandidate:(RTCICECandidate *)candidate {
    
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    [dic setObject:@"CANDIDATE" forKey:@"type"];
    [dic setObject:self.peer forKey:@"dst"];
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    [payload setObject:[self makeJsonWithICE:candidate] forKey:@"candidate"];
    [payload setObject:@"data" forKey:@"type"];
    [payload setObject:self.clientId forKey:@"connectionId"];
    [dic setObject:payload forKey:@"payload"];
    
    [self.controller send:dic];
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didOpenDataChannel:(RTCDataChannel *)dataChannel {
    if (_dataChannel) {
        _dataChannel = nil;
    }
    _dataChannel = dataChannel;
    _dataChannel.delegate = self;
}
- (void)peerConnection:(RTCPeerConnection *)peerConnection
 signalingStateChanged:(RTCSignalingState)stateChanged {
    
}

// Triggered when media is received on a new stream from remote peer.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
           addedStream:(RTCMediaStream *)stream {
    
}

// Triggered when a remote peer close a stream.
- (void)peerConnection:(RTCPeerConnection *)peerConnection
         removedStream:(RTCMediaStream *)stream {
    
}

// Triggered when renegotiation is needed, for example the ICE has restarted.
- (void)peerConnectionOnRenegotiationNeeded:(RTCPeerConnection *)peerConnection {
    
}

- (void)channelDidChangeState:(RTCDataChannel*)channel {
    switch (_dataChannel.state) {
        case kRTCDataChannelStateOpen: {
            if (_needToSend.count > 0) {
                NSArray *arr = [_needToSend copy];
                [_needToSend removeAllObjects];
                for (NSInteger i = 0, t = arr.count; i < t; ++i) {
                    [self _send:[arr objectAtIndex:i]];
                }
            }
            
            [self onOpen];
        }
            break;
        case kRTCDataChannelStateClosed: {
            [self onClose];
        }
            break;
            
        default:
            break;
    }
}
- (void)channel:(RTCDataChannel*)channel
didReceiveMessageWithBuffer:(RTCDataBuffer*)buffer {
    
    PackData *data = [PackData unpack:buffer.data];
    PackData *objectId = [data objectForKey:@"__peerData"];
    if (objectId) {
        NSNumber *key = [NSNumber numberWithInt:[objectId intValue]];
        int total = [[data objectForKey:@"total"] intValue];
        if (total > 0) {
            DataSet * sets = [_chunkedDatas objectForKey:key];
            
            if (!sets) {
                sets = [[DataSet alloc] initWithTotal:total];
                [_chunkedDatas setObject:sets forKey:key];
            }
            
            [sets setObject:data atIndex:[[data objectForKey:@"n"] intValue]];
            
            if (total == sets.count) {
                NSData *buffer = sets.pack;
                PackData *ndata = [PackData unpack:buffer];
                [_chunkedDatas removeObjectForKey:key];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.messageDelegate onMessage:self content:ndata];
                });
            }
        }
    }else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.messageDelegate onMessage:self content:data];
        });
    }
}

- (void)onOpen {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.connectDelegate respondsToSelector:@selector(onOpen:)])
            [self.connectDelegate onOpen:self];
        if ([self.managerDelegate respondsToSelector:@selector(onOpen:)])
            [self.managerDelegate onOpen:self];
    });
}

- (void)onClose {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.connectDelegate respondsToSelector:@selector(onClose:)])
            [self.connectDelegate onClose:self];
        if ([self.managerDelegate respondsToSelector:@selector(onClose:)])
            [self.managerDelegate onClose:self];
    });
}

@end
