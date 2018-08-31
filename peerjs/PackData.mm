//
//  PackData.m
//  l2e_player
//
//  Created by mac on 2018/8/2.
//  Copyright © 2018年 gen. All rights reserved.
//

#import "PackData.h"
#include <vector>

@interface PDDataStream : NSObject

@property (nonatomic, readonly) NSData *data;

- (id)initWithData:(NSData *)data;

- (size_t)read:(void*)buffer length:(size_t)len;

@end

@implementation PDDataStream {
    size_t _offset;
}

- (id)initWithData:(NSData *)data {
    self = [super init];
    if (self) {
        _data = data;
        _offset = 0;
    }
    return self;
}

- (size_t)read:(void *)buffer length:(size_t)len {
    size_t size = MIN(len, _data.length - _offset);
    const char *bytes = (const char *)_data.bytes;
    memcpy(buffer, bytes + _offset, size);
    _offset += size;
    return size;
}

- (const void*)buffer {
    const char *bytes = (const char *)_data.bytes;
    return (const void *)(bytes + _offset);
}

- (void)addOffset:(size_t)off {
    _offset += off;
}

@end


namespace pd {
    class Reader {
        PDDataStream *_stream;
        
    public:
        Reader(PDDataStream *stream) {
            _stream = stream;
        }
        
        template<typename T>
        T read() const {
            T ret = 0;
            const size_t s = sizeof(T);
            char buf[s];
            char *res_buf = (char *)&ret;
            [_stream read:buf length:s];
            for (int i = 0; i < s; ++i) {
                res_buf[i] = buf[s - i - 1];
            }
            return ret;
        }
        const void* read(size_t size) const {
            const void *buf = [_stream buffer];
            [_stream addOffset:size];
            return buf;
        }
    };
    
    struct Writer {
        
        std::vector<char> buffer;
        
        void write(const void *b, size_t s) {
            size_t off = buffer.size();
            buffer.resize(off + s);
            memcpy(buffer.data() + off, b, s);
        }
        
        void writeBE(const void *b, size_t s) {
            size_t off = buffer.size();
            buffer.resize(off + s);
            const char *chs = (const char *)b;
            for (int i = 0; i < s; ++i) {
                buffer.data()[off+i] = chs[s-i-1];
            }
        }
        
        template <typename T>
        Writer &operator<< (const T &n) {
            writeBE(&n, sizeof(T));
            return *this;
        }
    };
}

using namespace pd;

@implementation PackData {
    id _data;
}

- (id)initWithData:(NSData *)data {
    PDDataStream *s = [[PDDataStream alloc] initWithData:data];
    Reader reader(s);
    self = [self initWithReader:reader];
    return self;
}

- (id)initWithReader:(const Reader &)reader {
    self = [super init];
    if (self) {
        uint8_t type = reader.read<uint8_t>();
        if (type < 0x80) {
            _data = [NSNumber numberWithChar:type];
            _type = PackDataByte;
        }else if ((type ^ 0xe0) < 0x20) {
            char negative_fixnum = (char)((type ^ 0xe0) - 0x20);
            _data = [NSNumber numberWithChar:negative_fixnum];
            _type = PackDataByte;
        }else {
            int size;
            if ((size = type ^ 0xa0) <= 0x0f) {
                const void *buf = reader.read(size);
                _data = [NSData dataWithBytes:buf length:size];
                _type = PackDataBuffer;
            }else if ((size = type ^ 0xb0) <= 0x0f) {
                const char *buf = (const char *)reader.read(size);
                _data = [[NSString alloc] initWithBytes:buf
                                                 length:size
                                               encoding:NSUTF8StringEncoding];
                _type = PackDataString;
            }else if ((size = type ^ 0x90) <= 0x0f) {
                NSMutableArray *arr = [NSMutableArray arrayWithCapacity:size];
                for (NSInteger i = 0; i < size; ++i) {
                    [arr addObject:[[PackData alloc] initWithReader:reader]];
                }
                _data = arr;
                _type = PackDataArray;
            }else if ((size = type ^ 0x80) <= 0x0f) {
                NSMutableDictionary *map = [NSMutableDictionary dictionaryWithCapacity:size];
                for (NSInteger i = 0; i < size; ++i) {
                    PackData *key = [[PackData alloc] initWithReader:reader];
                    PackData *value = [[PackData alloc] initWithReader:reader];
                    [map setObject:value forKey:[key stringValue]];
                }
                _data = map;
                _type = PackDataMap;
            }else {
                switch (type) {
                    case 0xc0:
                        _data = nil;
                        _type = PackDataNil;
                        break;
                    case 0xc1:
                        _data = nil;
                        _type = PackDataNone;
                        break;
                    case 0xc2:
                        _data = @NO;
                        _type = PackDataBool;
                        break;
                    case 0xc3:
                        _data = @YES;
                        _type = PackDataBool;
                        break;
                    case 0xca:
                        _data = [NSNumber numberWithFloat:reader.read<float>()];
                        _type = PackDataFloat;
                        break;
                    case 0xcb:
                        _data = [NSNumber numberWithDouble:reader.read<double>()];
                        _type = PackDataDouble;
                        break;
                    case 0xcc:
                        _data = [NSNumber numberWithChar:reader.read<char>()];
                        _type = PackDataByte;
                        break;
                    case 0xcd:
                        _data = [NSNumber numberWithShort:reader.read<short>()];
                        _type = PackDataShort;
                        break;
                    case 0xce:
                        _data = [NSNumber numberWithInt:reader.read<int>()];
                        _type = PackDataInteger;
                        break;
                    case 0xcf:
                        _data = [NSNumber numberWithLong:reader.read<long>()];
                        _type = PackDataLong;
                        break;
                    case 0xd0:
                        _data = [NSNumber numberWithChar:reader.read<char>()];
                        _type = PackDataByte;
                        break;
                    case 0xd1:
                        _data = [NSNumber numberWithShort:reader.read<short>()];
                        _type = PackDataShort;
                        break;
                    case 0xd2:
                        _data = [NSNumber numberWithInt:reader.read<int>()];
                        _type = PackDataInteger;
                        break;
                    case 0xd3:
                        _data = [NSNumber numberWithLong:reader.read<long>()];
                        _type = PackDataLong;
                        break;
                    case 0xd4:
                        _data = nil;
                        _type = PackDataNone;
                        break;
                    case 0xd5:
                        _data = nil;
                        _type = PackDataNone;
                        break;
                    case 0xd6:
                        _data = nil;
                        _type = PackDataNone;
                        break;
                    case 0xd7:
                        _data = nil;
                        _type = PackDataNone;
                        break;
                    case 0xd8: {
                        size = reader.read<uint16_t>();
                        const char *chs = (const char *)reader.read(size);
                        _data = [[NSString alloc] initWithBytes:chs
                                                         length:size
                                                       encoding:NSUTF8StringEncoding];
                        _type = PackDataString;
                        break;
                    }
                    case 0xd9: {
                        size = reader.read<uint32_t>();
                        const char *chs = (const char *)reader.read(size);
                        _data = [[NSString alloc] initWithBytes:chs
                                                         length:size
                                                       encoding:NSUTF8StringEncoding];
                        _type = PackDataString;
                        break;
                    }
                    case 0xda: {
                        size = reader.read<uint16_t>();
                        const void *buf = reader.read(size);
                        _data = [NSData dataWithBytes:buf length:size];
                        _type = PackDataBuffer;
                        break;
                    }
                    case 0xdb: {
                        size = reader.read<uint32_t>();
                        const void *buf = reader.read(size);
                        _data = [NSData dataWithBytes:buf length:size];
                        _type = PackDataBuffer;
                        break;
                    }
                    case 0xdc: {
                        size = reader.read<uint16_t>();
                        NSMutableArray *arr = [NSMutableArray arrayWithCapacity:size];
                        for (NSInteger i = 0; i < size; ++i) {
                            [arr addObject:[[PackData alloc] initWithReader:reader]];
                        }
                        _data = arr;
                        _type = PackDataArray;
                        break;
                    }
                    case 0xdd: {
                        size = reader.read<uint32_t>();
                        NSMutableArray *arr = [NSMutableArray arrayWithCapacity:size];
                        for (NSInteger i = 0; i < size; ++i) {
                            [arr addObject:[[PackData alloc] initWithReader:reader]];
                        }
                        _data = arr;
                        _type = PackDataArray;
                        break;
                    }
                    case 0xde: {
                        size = reader.read<uint16_t>();
                        NSMutableDictionary *map = [NSMutableDictionary dictionaryWithCapacity:size];
                        for (NSInteger i = 0; i < size; ++i) {
                            PackData *key = [[PackData alloc] initWithReader:reader];
                            PackData *value = [[PackData alloc] initWithReader:reader];
                            [map setObject:value forKey:[key stringValue]];
                        }
                        _data = map;
                        _type = PackDataMap;
                        break;
                    }
                    case 0xdf: {
                        size = reader.read<uint32_t>();
                        NSMutableDictionary *map = [NSMutableDictionary dictionaryWithCapacity:size];
                        for (NSInteger i = 0; i < size; ++i) {
                            PackData *key = [[PackData alloc] initWithReader:reader];
                            PackData *value = [[PackData alloc] initWithReader:reader];
                            [map setObject:value forKey:[key stringValue]];
                        }
                        _data = map;
                        _type = PackDataMap;
                        break;
                    }
                }
            }
        }
    }
    return self;
}
- (_Nonnull id)initWithChar:(char)c {
    self = [super init];
    if (self) {
        _type = PackDataByte;
        _data = [NSNumber numberWithChar:c];
    }
    return self;
}
- (_Nonnull id)initWithShort:(short)s {
    self = [super init];
    if (self) {
        _type = PackDataShort;
        _data = [NSNumber numberWithShort:s];
    }
    return self;
}
- (_Nonnull id)initWithLong:(long)l {
    self = [super init];
    if (self) {
        _type = PackDataLong;
        _data = [NSNumber numberWithLong:l];
    }
    return self;
}
- (_Nonnull id)initWithBool:(BOOL)b {
    self = [super init];
    if (self) {
        _type = PackDataBool;
        _data = [NSNumber numberWithBool:b];
    }
    return self;
}
- (_Nonnull id)initWithFloat:(float)f {
    self = [super init];
    if (self) {
        _type = PackDataFloat;
        _data = [NSNumber numberWithFloat:f];
    }
    return self;
}
- (_Nonnull id)initWithDouble:(double)d {
    self = [super init];
    if (self) {
        _type = PackDataDouble;
        _data = [NSNumber numberWithDouble:d];
    }
    return self;
}

- (id)initWithInt:(int)i {
    self = [super init];
    if (self) {
        _data = [NSNumber numberWithInt:i];
        _type = PackDataInteger;
    }
    return self;
}

- (id)initWithString:(NSString *)str {
    self = [super init];
    if (self) {
        _type = PackDataString;
        _data = str;
    }
    return self;
}

- (id)initWithBuffer:(NSData *)data {
    self = [super init];
    if (self) {
        _type = PackDataBuffer;
        _data = data;
    }
    return self;
}

- (NSString *)stringValue {
    if (_type == PackDataString) {
        return _data;
    }else if (_data) {
        return [_data stringValue];
    }else {
        return @"NULL";
    }
}

- (NSData *)pack {
    Writer writer;
    [self pack:writer];
    
    return [NSData dataWithBytes:writer.buffer.data()
                          length:writer.buffer.size()];
}

- (void)pack:(Writer &)writer {
#define _(v) ((char)v)
    switch (_type) {
        case PackDataString:
            [self pack:writer string:_data];
            break;
        case PackDataByte:
            writer << _(0xd0);
            writer << [_data charValue];
            break;
        case PackDataShort:
            writer << _(0xd1);
            writer << [_data shortValue];
            break;
        case PackDataInteger:
            writer << _(0xd2);
            writer << [_data intValue];
            break;
        case PackDataLong:
            writer << _(0xd3);
            writer << [_data longValue];
            break;
        case PackDataFloat:
            writer << _(0xca);
            writer << [_data floatValue];
            break;
        case PackDataDouble:
            writer << _(0xcb);
            writer << [_data doubleValue];
            break;
        case PackDataBool:
            if ([_data boolValue]) {
                writer << _(0xc3);
            }else {
                writer << _(0xc2);
            }
            break;
        case PackDataNone:
            writer << _(0xc0);
            break;
        case PackDataNil:
            writer << _(0xc0);
            break;
        case PackDataArray: {
            NSArray *arr = _data;
            NSInteger len = arr.count;
            if (len <= 0x0f) {
                writer << (char)(0x90 + len);
            }else if (len <= 0xffff) {
                writer << (char)0xdc;
                writer << (uint16_t)len;
            }else {
                writer << (char)0xdd;
                writer << (uint32_t)len;
            }
            for (NSInteger i = 0; i < len; ++i) {
                [[arr objectAtIndex:i] pack:writer];
            }
        }
            break;
        case PackDataBuffer: {
            NSData *d = _data;
            NSInteger len = d.length;
            if (len <= 0x0f) {
                writer << (char)(0xa0 + len);
            }else if (len <= 0xffff) {
                writer << (char)0xda;
                writer << (uint16_t)len;
            }else {
                writer << (char)0xdb;
                writer << (uint32_t)len;
            }
            writer.write(d.bytes, len);
        }
            break;
        case PackDataMap: {
            NSDictionary *d = _data;
            NSInteger len = d.count;
            if (len <= 0x0f) {
                writer << (char)(0x80 + len);
            }else if (len <= 0xffff) {
                writer << (char)0xde;
                writer << (uint16_t)len;
            }else {
                writer << (char)0xdf;
                writer << (uint32_t)len;
            }
            [d enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                [self pack:writer string:key];
                [obj pack:writer];
            }];
        }
            break;
            
        default:
            break;
    }
}

- (void)pack:(Writer &)writer string:(NSString *)string {
    NSInteger len = string.length;
    if (len <= 0x0f) {
        writer << (char)(0xb0 + len);
    }else if (len <= 0xffff) {
        writer << (char)0xd8;
        writer << (uint16_t)len;
    }else {
        writer << (char)0xd9;
        writer << (uint32_t)len;
    }
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    writer.write(data.bytes, data.length);
}

- (void)setObject:(id)obj forKey:(id<NSCopying>)key {
    if (_type == PackDataNone ||
        _type == PackDataNil) {
        _type = PackDataMap;
        _data = [NSMutableDictionary dictionary];
        [_data setObject:[self packData:obj] forKey:key];
    }else if (_type == PackDataMap) {
        [_data setObject:[self packData:obj] forKey:key];
    }
}

#include <objc/runtime.h>

- (PackData *)packData:(id)obj {
    if (obj) {
        if ([obj isKindOfClass:PackData.class]) {
            return obj;
        }else {
            if ([obj isKindOfClass:NSString.class]) {
                return [[PackData alloc] initWithString:obj];
            }else if ([obj isKindOfClass:NSNumber.class]) {
                NSNumber *num = obj;
                char type = num.objCType[0];
                switch (type) {
                    case _C_CHR:
                    case _C_UCHR:
                        return [[PackData alloc] initWithChar:num.charValue];
                        
                    case _C_SHT:
                    case _C_USHT:
                        return [[PackData alloc] initWithShort:num.shortValue];
                        
                    case _C_INT:
                    case _C_UINT:
                        return [[PackData alloc] initWithInt:num.intValue];
                        
                    case _C_LNG:
                    case _C_ULNG:
                    case _C_LNG_LNG:
                    case _C_ULNG_LNG:
                        return [[PackData alloc] initWithLong:num.longValue];
                        
                    case _C_BOOL:
                        return [[PackData alloc] initWithBool:num.boolValue];
                        
                    case _C_FLT:
                        return [[PackData alloc] initWithFloat:num.floatValue];
                        
                    case _C_DBL:
                        return [[PackData alloc] initWithDouble:num.doubleValue];
                        
                    default:
                        break;
                }
            }else if ([obj isKindOfClass:NSData.class]) {
                return [[PackData alloc] initWithBuffer:obj];
            }
        }
    }
    return [[PackData alloc] init];
}

- (void)setValue:(id)value forKey:(NSString *)key {
    [self setObject:value forKey:key];
}

- (id)objectForKey:(id)key {
    if (_type == PackDataMap) {
        return [_data objectForKey:key];
    }
    return nil;
}

- (id)valueForKey:(NSString *)key {
    return [self objectForKey:key];
}

+ (nonnull PackData *)unpack:(nonnull NSData *)data {
    return [[PackData alloc] initWithData:data];
}

- (char)charValue {
    if ([_data isKindOfClass:NSNumber.class]) {
        return [_data charValue];
    }
    return 0;
}
- (short)shortValue {
    if ([_data isKindOfClass:NSNumber.class]) {
        return [_data shortValue];
    }
    return 0;
}
- (int)intValue {
    if ([_data isKindOfClass:NSNumber.class]) {
        return [_data intValue];
    }
    return 0;
}
- (long)longValue {
    if ([_data isKindOfClass:NSNumber.class]) {
        return [_data longValue];
    }
    return 0;
}
- (float)floatValue {
    if ([_data isKindOfClass:NSNumber.class]) {
        return [_data floatValue];
    }
    return 0;
}
- (double)doubleValue {
    if ([_data isKindOfClass:NSNumber.class]) {
        return [_data doubleValue];
    }
    return 0;
}
- (NSData *)bufferValue {
    if (_type == PackDataBuffer) {
        return _data;
    }
    return nil;
}

@end
