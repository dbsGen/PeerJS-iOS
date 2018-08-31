//
//  PeerController.h
//  l2e_player
//
//  Created by mac on 2018/7/31.
//  Copyright © 2018年 gen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PCConnection.h"
#import "PCDelegate.h"

@class PeerController;


typedef enum : NSUInteger {
    PeerControllerNone,
    PeerControllerConnecting,
    PeerControllerConnected,
} PeerControllerStatus;

@protocol PeerControllerDelegate<NSObject>

@optional
- (void)peerController:(PeerController*)peerController statusChanged:(PeerControllerStatus)status;
- (void)peerController:(PeerController*)peerController onConnection:(PCConnection *)conn;

@end

@interface PeerController : NSObject

@property (nonatomic, strong) NSString *hostURL;
@property (nonatomic, readonly) PCDelegate<PeerControllerDelegate> * delegate;
@property (nonatomic, readonly) NSString *peerId;
@property (nonatomic, readonly) PeerControllerStatus status;

+ (PeerController*)defaultController;

- (void)start;
- (void)stop;

- (void)send:(NSDictionary *)dic;

- (PCConnection *)connect:(NSString *)peerId;

@end
