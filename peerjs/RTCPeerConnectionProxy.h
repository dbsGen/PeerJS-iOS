//
//  RTCPeerConnectionProxy.h
//  l2e_player
//
//  Created by mac on 2018/8/26.
//  Copyright © 2018年 gen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "libjingle_peerconnection/RTCPeerConnection.h"

typedef void(^RTCPeerConnectionSDPBlock)(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error);
typedef void(^RTCPeerConnectionResultBlock)(NSError * _Nullable error);

@interface RTCPeerConnectionProxy : NSObject

@property (nonatomic, readonly) RTCPeerConnection *peerConnection;

- (id)initWithConnection:(RTCPeerConnection *)peerConnection;

- (void)createOfferWithConstraints:(RTCMediaConstraints *)constraints block:(RTCPeerConnectionSDPBlock)block;
- (void)createAnswerWithConstraints:(RTCMediaConstraints *)constraints block:(RTCPeerConnectionSDPBlock)block;

- (void)setLocalDescriptionWithSessionDescription:(RTCSessionDescription *)sdp block:(RTCPeerConnectionResultBlock)block;
- (void)setRemoteDescriptionWithSessionDescription:(RTCSessionDescription *)sdp block:(RTCPeerConnectionResultBlock)block;

@end
