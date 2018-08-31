//
//  L2EDelegate.m
//  l2e_player
//
//  Created by mac on 2018/8/17.
//  Copyright © 2018年 gen. All rights reserved.
//

#import "PCDelegate.h"
#include <objc/runtime.h>
#include <list>

@implementation PCDelegate {
    std::list<id>   _targets;
    Protocol*       _protocol;
}

- (id)initWithProtocol:(Protocol*)protocol {
    self = [super init];
    if (self) {
        _protocol = protocol;
    }
    return self;
}


- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    struct objc_method_description md = protocol_getMethodDescription(_protocol, aSelector, YES, YES);
    if (!md.types) {
        md = protocol_getMethodDescription(_protocol, aSelector, NO, YES);
    }
    if (md.types) {
        return [NSMethodSignature signatureWithObjCTypes:md.types];
    }else {
        return [super methodSignatureForSelector:aSelector];
    }
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    struct objc_method_description md = protocol_getMethodDescription(_protocol, anInvocation.selector, YES, YES);
    if (!md.types) {
        md = protocol_getMethodDescription(_protocol, anInvocation.selector, NO, YES);
    }
    if (md.types) {
        std::list<id> clist = _targets;
        for (auto it = clist.begin(), _e = clist.end(); it != _e; ++it) {
            id tar = (*it);
            if ([tar respondsToSelector:anInvocation.selector]) {
                [anInvocation invokeWithTarget:tar];
            }
        }
    }else {
        [super forwardInvocation:anInvocation];
    }
}

- (void)addTarget:(id)target {
    _targets.push_back(target);
}

- (void)removeTarget:(id)target {
    _targets.remove(target);
}

@end
