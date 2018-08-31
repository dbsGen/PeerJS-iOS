//
//  L2EDelegate.h
//  l2e_player
//
//  Created by mac on 2018/8/17.
//  Copyright © 2018年 gen. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PCDelegate : NSObject

- (id)initWithProtocol:(Protocol*)protocol;

- (void)addTarget:(id)target;
- (void)removeTarget:(id)target;

@end
