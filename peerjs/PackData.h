//
//  PackData.h
//  l2e_player
//
//  Created by mac on 2018/8/2.
//  Copyright © 2018年 gen. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    PackDataNone,
    PackDataNil,
    PackDataByte,
    PackDataShort,
    PackDataInteger,
    PackDataLong,
    PackDataBuffer,
    PackDataString,
    PackDataArray,
    PackDataMap,
    PackDataBool,
    PackDataFloat,
    PackDataDouble
} PackDataType;

@interface PackData : NSObject

@property (nonatomic, readonly) PackDataType type;

- (_Nonnull id)initWithData:(nonnull NSData *)data;
- (_Nonnull id)initWithChar:(char)c;
- (_Nonnull id)initWithShort:(short)s;
- (_Nonnull id)initWithLong:(long)l;
- (_Nonnull id)initWithBool:(BOOL)b;
- (_Nonnull id)initWithFloat:(float)f;
- (_Nonnull id)initWithDouble:(double)d;
- (_Nonnull id)initWithInt:(int)i;
- (_Nonnull id)initWithString:(nonnull NSString *)str;
- (_Nonnull id)initWithBuffer:(nonnull NSData *)data;

- (nonnull NSData *)pack;

- (nonnull NSString *)stringValue;

- (void)setObject:(nonnull id)obj forKey:(nonnull id<NSCopying>)key;
- (_Nullable id)objectForKey:(_Nonnull id)key;

+ (nonnull PackData *)unpack:(nonnull NSData *)data;

- (char)charValue;
- (short)shortValue;
- (int)intValue;
- (long)longValue;
- (float)floatValue;
- (double)doubleValue;
- (NSData *)bufferValue;

@end
