//
//  BandwidthLimiter.h
//  l2e_player
//
//  Created by mac on 2018/8/2.
//  Copyright © 2018年 gen. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol BandwidthLimiterOnFree

- (void)onBandwidthFree;

@end

@protocol BandwidthLimiterDelegate

- (void)onBandwidthSpeed:(float)speed;

@end

@interface BandwidthLimiter : NSObject

@property (nonatomic, assign) float limitSpeed;
@property (nonatomic, readonly) float currentSpeed;

+ (BandwidthLimiter*)getInstance;

- (void)addFreeListener:(id<BandwidthLimiterOnFree>)free;
- (void)removeFreeListener:(id<BandwidthLimiterOnFree>)free;

- (void)sendData:(size_t)size;

- (BOOL)canSend;

@end
