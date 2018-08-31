//
//  PCConnection.h
//  l2e_player
//
//  Created by mac on 2018/8/1.
//  Copyright © 2018年 gen. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "PackData.h"
#import "PCDelegate.h"

@class PeerController;
@class PCConnection;
@class RTCDataBuffer;

@protocol PCConnectionConnectDelegate<NSObject>

- (void)onOpen:(PCConnection *)conn;
- (void)onClose:(PCConnection *)conn;

@end

@protocol PCConnectionMessageDelegate

- (void)onMessage:(PCConnection *)conn content:(PackData *)data;

@end

@interface PCConnection : NSObject

- (id)initWithPeer:(NSString *)peer controller:(PeerController*)ctrl;
- (id)initWithPeer:(NSString *)peer controller:(PeerController*)ctrl payload:(NSDictionary *)payload;

@property (nonatomic, readonly) NSString *clientId;
@property (nonatomic, readonly) NSString *peer;

@property (nonatomic, weak) id<PCConnectionConnectDelegate> connectDelegate;
@property (nonatomic, weak) id<PCConnectionConnectDelegate> managerDelegate;
@property (nonatomic, readonly) PCDelegate<PCConnectionMessageDelegate> * messageDelegate;

- (void)connect;
- (void)close;

- (void)onMessage:(NSDictionary *)json;
- (void)onOffer:(NSDictionary *)payload;

- (void)send:(PackData *)data;
- (void)sendRaw:(NSData *)buffer;

@end
