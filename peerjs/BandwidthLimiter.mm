//
//  BandwidthLimiter.m
//  l2e_player
//
//  Created by mac on 2018/8/2.
//  Copyright © 2018年 gen. All rights reserved.
//

#import "BandwidthLimiter.h"
#include <list>

static BandwidthLimiter *__Limiter_Instace = NULL;

@implementation BandwidthLimiter {
    std::list<id<BandwidthLimiterOnFree> > _onFrees;
    float _displaySpeed;
    NSTimer *_timer;
    size_t _totalSend;
    BOOL _currentSecSend;
    NSInteger _during;
}

+ (BandwidthLimiter*)getInstance {
    @synchronized([BandwidthLimiter class]) {
        if (!__Limiter_Instace) {
            __Limiter_Instace = [[BandwidthLimiter alloc] init];
        }
    }
    return __Limiter_Instace;
}

- (id)init {
    self = [super init];
    if (self) {
        _timer = [NSTimer scheduledTimerWithTimeInterval:1
                                                  target:self
                                                selector:@selector(onTimer)
                                                userInfo:nil
                                                 repeats:YES];
    }
    return self;
}

- (void)dealloc {
    [_timer invalidate];
    [super dealloc];
}

- (void)addFreeListener:(id<BandwidthLimiterOnFree>)free {
    _onFrees.push_back(free);
}

- (void)removeFreeListener:(id<BandwidthLimiterOnFree>)free {
    _onFrees.remove(free);
}

- (void)sendData:(size_t)size {
    _totalSend += size;
    _currentSecSend = YES;
    _currentSpeed = _totalSend / _during;
}

- (void)onTimer {
    if (_currentSecSend || _currentSpeed > _limitSpeed / 2) {
        _currentSecSend = NO;
        _during ++;
        _currentSpeed = _totalSend / _during;
        for (auto it = _onFrees.begin(), _e = _onFrees.end(); it != _e; ++it) {
            if (_currentSpeed < _limitSpeed) {
                [*it onBandwidthFree];
            }
        }
    }else {
        _currentSpeed = 0;
        _during = 1;
    }
}

- (BOOL)canSend {
    return _currentSpeed <= _limitSpeed;
}

@end
