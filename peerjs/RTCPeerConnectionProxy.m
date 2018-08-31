//
//  RTCPeerConnectionProxy.m
//  l2e_player
//
//  Created by mac on 2018/8/26.
//  Copyright © 2018年 gen. All rights reserved.
//

#import "RTCPeerConnectionProxy.h"
#import <libjingle_peerconnection/RTCSessionDescriptionDelegate.h>

@class RTCSDPProxy;

@protocol RTCSDPProxyDelegate

- (void)sdpProxyCalled:(RTCSDPProxy *)proxy;

@end

@interface RTCSDPProxy : NSObject <RTCSessionDescriptionDelegate>

@property (nonatomic, copy) RTCPeerConnectionSDPBlock       sdpBlock;
@property (nonatomic, copy) RTCPeerConnectionResultBlock    resultBlock;
@property (nonatomic, weak) id<RTCSDPProxyDelegate>         delegate;

@end

@implementation RTCSDPProxy

- (void)peerConnection:(RTCPeerConnection *)peerConnection
didCreateSessionDescription:(RTCSessionDescription *)sdp
                 error:(NSError *)error {
    if (self.sdpBlock) {
        self.sdpBlock(sdp, error);
    }
    [self.delegate sdpProxyCalled:self];
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
didSetSessionDescriptionWithError:(NSError *)error {
    if (self.resultBlock) {
        self.resultBlock(error);
    }
    [self.delegate sdpProxyCalled:self];
}

@end

@interface RTCPeerConnectionProxy() <RTCSDPProxyDelegate>
@end

@implementation RTCPeerConnectionProxy {
    NSMutableArray <RTCSDPProxy *> *_proxies;
}

- (id)initWithConnection:(RTCPeerConnection *)peerConnection {
    self = [super init];
    if (self) {
        _peerConnection = peerConnection;
        _proxies = [NSMutableArray array];
    }
    return self;
}

- (void)createOfferWithConstraints:(RTCMediaConstraints *)constraints block:(RTCPeerConnectionSDPBlock)block {
    RTCSDPProxy *proxy = [[RTCSDPProxy alloc] init];
    proxy.sdpBlock = block;
    proxy.delegate = self;
    [_proxies addObject:proxy];
    [_peerConnection createOfferWithDelegate:proxy
                                 constraints:constraints];
}

- (void)createAnswerWithConstraints:(RTCMediaConstraints *)constraints block:(RTCPeerConnectionSDPBlock)block {
    RTCSDPProxy *proxy = [[RTCSDPProxy alloc] init];
    proxy.sdpBlock = block;
    proxy.delegate = self;
    [_proxies addObject:proxy];
    [_peerConnection createAnswerWithDelegate:proxy
                                  constraints:constraints];
}

- (void)setLocalDescriptionWithSessionDescription:(RTCSessionDescription *)sdp block:(RTCPeerConnectionResultBlock)block {
    RTCSDPProxy *proxy = [[RTCSDPProxy alloc] init];
    proxy.resultBlock = block;
    proxy.delegate = self;
    [_proxies addObject:proxy];
    [_peerConnection setLocalDescriptionWithDelegate:proxy
                                  sessionDescription:sdp];
}

- (void)setRemoteDescriptionWithSessionDescription:(RTCSessionDescription *)sdp block:(RTCPeerConnectionResultBlock)block {
    RTCSDPProxy *proxy = [[RTCSDPProxy alloc] init];
    proxy.resultBlock = block;
    proxy.delegate = self;
    [_proxies addObject:proxy];
    [_peerConnection setRemoteDescriptionWithDelegate:proxy
                                   sessionDescription:sdp];
}

- (void)sdpProxyCalled:(RTCSDPProxy *)proxy {
    [_proxies removeObject:proxy];
}

@end
