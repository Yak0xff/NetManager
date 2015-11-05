

#import "NSObject+Evo.h"
#import "EvoRuntime.h"
#import <libkern/OSAtomic.h>
#import <objc/message.h>

#define force_inline __inline__ __attribute__((always_inline))

/// Foundation Class Type
typedef NS_ENUM (NSUInteger, EvoCodingNSType) {
    EvoCodingTypeNSUnknown = 0,
    EvoCodingTypeNSString,
    EvoCodingTypeNSMutableString,
    EvoCodingTypeNSValue,
    EvoCodingTypeNSNumber,
    EvoCodingTypeNSDecimalNumber,
    EvoCodingTypeNSData,
    EvoCodingTypeNSMutableData,
    EvoCodingTypeNSDate,
    EvoCodingTypeNSURL,
    EvoCodingTypeNSArray,
    EvoCodingTypeNSMutableArray,
    EvoCodingTypeNSDictionary,
    EvoCodingTypeNSMutableDictionary,
    EvoCodingTypeNSSet,
    EvoCodingTypeNSMutableSet,
};

/// Get the Foundation class type from property info.
static force_inline EvoCodingNSType EvoClassGetNSType(Class cls) {
    if (!cls) return EvoCodingTypeNSUnknown;
    if ([cls isSubclassOfClass:[NSMutableString class]]) return EvoCodingTypeNSMutableString;
    if ([cls isSubclassOfClass:[NSString class]]) return EvoCodingTypeNSString;
    if ([cls isSubclassOfClass:[NSDecimalNumber class]]) return EvoCodingTypeNSDecimalNumber;
    if ([cls isSubclassOfClass:[NSNumber class]]) return EvoCodingTypeNSNumber;
    if ([cls isSubclassOfClass:[NSValue class]]) return EvoCodingTypeNSValue;
    if ([cls isSubclassOfClass:[NSMutableData class]]) return EvoCodingTypeNSMutableData;
    if ([cls isSubclassOfClass:[NSData class]]) return EvoCodingTypeNSData;
    if ([cls isSubclassOfClass:[NSDate class]]) return EvoCodingTypeNSDate;
    if ([cls isSubclassOfClass:[NSURL class]]) return EvoCodingTypeNSURL;
    if ([cls isSubclassOfClass:[NSMutableArray class]]) return EvoCodingTypeNSMutableArray;
    if ([cls isSubclassOfClass:[NSArray class]]) return EvoCodingTypeNSArray;
    if ([cls isSubclassOfClass:[NSMutableDictionary class]]) return EvoCodingTypeNSMutableDictionary;
    if ([cls isSubclassOfClass:[NSDictionary class]]) return EvoCodingTypeNSDictionary;
    if ([cls isSubclassOfClass:[NSMutableSet class]]) return EvoCodingTypeNSMutableSet;
    if ([cls isSubclassOfClass:[NSSet class]]) return EvoCodingTypeNSSet;
    return EvoCodingTypeNSUnknown;
}

/// Whether the type is c number.
static force_inline BOOL EvoCodingTypeIsCNumber(EvoCodingType type) {
    switch (type & EvoCodingTypeMask) {
        case EvoCodingTypeBool:
        case EvoCodingTypeInt8:
        case EvoCodingTypeUInt8:
        case EvoCodingTypeInt16:
        case EvoCodingTypeUInt16:
        case EvoCodingTypeInt32:
        case EvoCodingTypeUInt32:
        case EvoCodingTypeInt64:
        case EvoCodingTypeUInt64:
        case EvoCodingTypeFloat:
        case EvoCodingTypeDouble:
        case EvoCodingTypeLongDouble: return YES;
        default: return NO;
    }
}

/// Parse a number value from 'id'.
static force_inline NSNumber *EvoNSNumberCreateFromID(__unsafe_unretained id value) {
    static NSCharacterSet *dot;
    static NSDictionary *dic;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dot = [NSCharacterSet characterSetWithRange:NSMakeRange('.', 1)];
        dic = @{@"TRUE" :   @(YES),
                @"True" :   @(YES),
                @"true" :   @(YES),
                @"FALSE" :  @(NO),
                @"False" :  @(NO),
                @"false" :  @(NO),
                @"YES" :    @(YES),
                @"Yes" :    @(YES),
                @"yes" :    @(YES),
                @"NO" :     @(NO),
                @"No" :     @(NO),
                @"no" :     @(NO),
                @"NIL" :    (id)kCFNull,
                @"Nil" :    (id)kCFNull,
                @"nil" :    (id)kCFNull,
                @"NULL" :   (id)kCFNull,
                @"Null" :   (id)kCFNull,
                @"null" :   (id)kCFNull,
                @"(NULL)" : (id)kCFNull,
                @"(Null)" : (id)kCFNull,
                @"(null)" : (id)kCFNull,
                @"<NULL>" : (id)kCFNull,
                @"<Null>" : (id)kCFNull,
                @"<null>" : (id)kCFNull};
    });
    
    if (!value || value == (id)kCFNull) return nil;
    if ([value isKindOfClass:[NSNumber class]]) return value;
    if ([value isKindOfClass:[NSString class]]) {
        NSNumber *num = dic[value];
        if (num) {
            if (num == (id)kCFNull) return nil;
            return num;
        }
        if ([(NSString *)value rangeOfCharacterFromSet:dot].location != NSNotFound) {
            const char *cstring = ((NSString *)value).UTF8String;
            if (!cstring) return nil;
            double num = atof(cstring);
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        } else {
            const char *cstring = ((NSString *)value).UTF8String;
            if (!cstring) return nil;
            return @(atoll(cstring));
        }
    }
    return nil;
}

/// Parse string to date.
static NSDate *EvoNSDateFromString(__unsafe_unretained NSString *string) {
    typedef NSDate* (^EvoNSDateParseBlock)(NSString *string);
#define kParserNum 32
    static EvoNSDateParseBlock blocks[kParserNum + 1] = {0};
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        {
            /*
             2014-01-20  // Google
             */
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            formatter.dateFormat = @"yyyy-MM-dd";
            blocks[10] = ^(NSString *string) { return [formatter dateFromString:string]; };
        }
        
        {
            /*
             2014-01-20 12:24:48
             2014-01-20T12:24:48   // Google
             */
            NSDateFormatter *formatter1 = [[NSDateFormatter alloc] init];
            formatter1.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter1.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            formatter1.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss";
            
            NSDateFormatter *formatter2 = [[NSDateFormatter alloc] init];
            formatter2.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter2.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            formatter2.dateFormat = @"yyyy-MM-dd HH:mm:ss";
            
            blocks[19] = ^(NSString *string) {
                if ([string characterAtIndex:10] == 'T') {
                    return [formatter1 dateFromString:string];
                } else {
                    time_t t = 0;
                    struct tm tm = {0};
                    strptime([string cStringUsingEncoding:NSUTF8StringEncoding], "%Y-%m-%d %H:%M:%S", &tm);
                    tm.tm_isdst = -1;
                    t = mktime(&tm);
                    if (t >= 0) {
                        NSDate *date = [NSDate dateWithTimeIntervalSince1970:t + [[NSTimeZone localTimeZone] secondsFromGMT]];
                        if (date) return date;
                    }
                    return [formatter2 dateFromString:string];
                }
            };
        }
        
        {
            /*
             2014-01-20T12:24:48Z        // Github, Apple
             2014-01-20T12:24:48+0800    // Facebook
             2014-01-20T12:24:48+12:00   // Google
             */
            NSDateFormatter *formatter = [NSDateFormatter new];
            formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
            blocks[20] = ^(NSString *string) {
                time_t t = 0;
                struct tm tm = {0};
                strptime([string cStringUsingEncoding:NSUTF8StringEncoding], "%Y-%m-%dT%H:%M:%S%z", &tm);
                tm.tm_isdst = -1;
                t = mktime(&tm);
                if (t >= 0) {
                    NSDate *date = [NSDate dateWithTimeIntervalSince1970:t + [[NSTimeZone localTimeZone] secondsFromGMT]];
                    if (date) return date;
                }
                return [formatter dateFromString:string];
            };
            blocks[24] = ^(NSString *string) { return [formatter dateFromString:string]; };
            blocks[25] = ^(NSString *string) { return [formatter dateFromString:string]; };
        }
        
        {
            /*
             Fri Sep 04 00:12:21 +0800 2015 // Weibo, Twitter
             */
            NSDateFormatter *formatter = [NSDateFormatter new];
            formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
            formatter.dateFormat = @"EEE MMM dd HH:mm:ss Z yyyy";
            blocks[30] = ^(NSString *string) { return [formatter dateFromString:string]; };
        }
    });
    if (!string) return nil;
    if (string.length > kParserNum) return nil;
    EvoNSDateParseBlock parser = blocks[string.length];
    if (!parser) return nil;
    return parser(string);
#undef kParserNum
}


/// Get the 'NSBlock' class.
static force_inline Class EvoNSBlockClass() {
    static Class cls;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void (^block)(void) = ^{};
        cls = ((NSObject *)block).class;
        while (class_getSuperclass(cls) != [NSObject class]) {
            cls = class_getSuperclass(cls);
        }
    });
    return cls; // current is "NSBlock"
}



/**
 Get the ISO date formatter.
 
 ISO8601 format example:
 2010-07-09T16:13:30+12:00
 2011-01-11T11:11:11+0000
 2011-01-26T19:06:43Z
 
 length: 20/24/25
 */
static force_inline NSDateFormatter *EvoISODateFormatter() {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
    });
    return formatter;
}

/// Get the value with key paths from dictionary
/// The dic should be NSDictionary, and the keyPath should not be nil.
static force_inline id EvoValueForKeyPath(__unsafe_unretained NSDictionary *dic, __unsafe_unretained NSArray *keyPaths) {
    id value = nil;
    for (NSUInteger i = 0, max = keyPaths.count; i < max; i++) {
        value = dic[keyPaths[i]];
        if (i + 1 < max) {
            if ([value isKindOfClass:[NSDictionary class]]) {
                dic = value;
            } else {
                return nil;
            }
        }
    }
    return value;
}

/// A property info in object model.
@interface _EvoModelPropertyMeta : NSObject {
@public
    NSString *_name;             ///< property's name
    EvoCodingType _type;        ///< property's type
    EvoCodingNSType _nsType;    ///< property's Foundation type
    BOOL _isCNumber;             ///< is c number type
    Class _cls;                  ///< property's class, or nil
    Class _genericCls;           ///< container's generic class, or nil if threr's no generic class
    SEL _getter;                 ///< getter, or nil if the instances cannot respond
    SEL _setter;                 ///< setter, or nil if the instances cannot respond
    
    NSString *_mappedToKey;      ///< the key mapped to
    NSArray *_mappedToKeyPath;   ///< the key path mapped to (nil if the name is not key path)
    _EvoModelPropertyMeta *_next; ///< next meta if there are multiple properties mapped to the same key.
}
@end

@implementation _EvoModelPropertyMeta
+ (instancetype)metaWithClassInfo:(EvoRuntime *)classInfo propertyInfo:(EvoPropertyInfo *)propertyInfo generic:(Class)generic {
    _EvoModelPropertyMeta *meta = [self new];
    meta->_name = propertyInfo.name;
    meta->_type = propertyInfo.type;
    meta->_genericCls = generic;
    if ((meta->_type & EvoCodingTypeMask) == EvoCodingTypeObject) {
        meta->_nsType = EvoClassGetNSType(propertyInfo.cls);
    } else {
        meta->_isCNumber = EvoCodingTypeIsCNumber(meta->_type);
    }
    meta->_cls = propertyInfo.cls;
    if (propertyInfo.getter) {
        SEL sel = NSSelectorFromString(propertyInfo.getter);
        if ([classInfo.cls instancesRespondToSelector:sel]) {
            meta->_getter = sel;
        }
    }
    if (propertyInfo.setter) {
        SEL sel = NSSelectorFromString(propertyInfo.setter);
        if ([classInfo.cls instancesRespondToSelector:sel]) {
            meta->_setter = sel;
        }
    }
    return meta;
}
@end


/// A class info in object model.
@interface _EvoModelMeta : NSObject {
@public
    /// Key:mapped key and key path, Value:_YYModelPropertyInfo.
    NSDictionary *_mapper;
    /// Array<_YYModelPropertyInfo>, all property meta of this model.
    NSArray *_allPropertyMetas;
    /// Array<_YYModelPropertyInfo>, property meta which is mapped to a key path.
    NSArray *_keyPathPropertyMetas;
    /// The number of mapped key (and key path), same to _mapper.count.
    NSUInteger _keyMappedCount;
    /// Model class type.
    EvoCodingNSType _nsType;
    
    BOOL _hasCustomTransformFromDictonary;
    BOOL _hasCustomTransformToDictionary;
}
@end

@implementation _EvoModelMeta
- (instancetype)initWithClass:(Class)cls {
    EvoRuntime *classInfo = [EvoRuntime runtimeInfoFromClass:cls];
    if (!classInfo) return nil;
    self = [super init];
    
    // Get black list
    NSSet *blacklist = nil;
    if ([cls respondsToSelector:@selector(modelPropertyBlacklist)]) {
        NSArray *properties = [(id<Evo>)cls modelPropertyBlacklist];
        if (properties) {
            blacklist = [NSSet setWithArray:properties];
        }
    }
    
    // Get white list
    NSSet *whitelist = nil;
    if ([cls respondsToSelector:@selector(modelPropertyWhitelist)]) {
        NSArray *properties = [(id<Evo>)cls modelPropertyWhitelist];
        if (properties) {
            whitelist = [NSSet setWithArray:properties];
        }
    }
    
    // Get container property's generic class
    NSDictionary *genericMapper = nil;
    if ([cls respondsToSelector:@selector(modelContainerPropertyGenericClass)]) {
        genericMapper = [(id<Evo>)cls modelContainerPropertyGenericClass];
        if (genericMapper) {
            NSMutableDictionary *tmp = genericMapper.mutableCopy;
            [genericMapper enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                if (![key isKindOfClass:[NSString class]]) return;
                Class meta = object_getClass(obj);
                if (!meta) return;
                if (class_isMetaClass(meta)) {
                    tmp[key] = obj;
                } else if ([obj isKindOfClass:[NSString class]]) {
                    Class cls = NSClassFromString(obj);
                    if (cls) {
                        tmp[key] = cls;
                    }
                }
            }];
            genericMapper = tmp;
        }
    }
    
    // Create all property metas.
    NSMutableDictionary *allPropertyMetas = [NSMutableDictionary new];
    EvoRuntime *curClassInfo = classInfo;
    while (curClassInfo && curClassInfo.superCls != nil) { // recursive parse super class, but ignore root class (NSObject/NSProxy)
        for (EvoPropertyInfo *propertyInfo in curClassInfo.propertyInfos.allValues) {
            if (!propertyInfo.name) continue;
            if (blacklist && [blacklist containsObject:propertyInfo.name]) continue;
            if (whitelist && ![whitelist containsObject:propertyInfo.name]) continue;
            _EvoModelPropertyMeta *meta = [_EvoModelPropertyMeta metaWithClassInfo:classInfo
                                                                    propertyInfo:propertyInfo
                                                                         generic:genericMapper[propertyInfo.name]];
            if (!meta || !meta->_name) continue;
            if (!meta->_getter && !meta->_setter) continue;
            if (allPropertyMetas[meta->_name]) continue;
            allPropertyMetas[meta->_name] = meta;
        }
        curClassInfo = curClassInfo.superRuntime;
    }
    if (allPropertyMetas.count) _allPropertyMetas = allPropertyMetas.allValues.copy;
    
    // create mapper
    NSMutableDictionary *mapper = [NSMutableDictionary new];
    NSMutableArray *keyPathPropertyMetas = [NSMutableArray new];
    if ([cls respondsToSelector:@selector(modelPropertyMapper)]) {
        NSDictionary *customMapper = [(id <Evo>)cls modelPropertyMapper];
        [customMapper enumerateKeysAndObjectsUsingBlock:^(NSString *propertyName, NSString *mappedToKey, BOOL *stop) {
            _EvoModelPropertyMeta *propertyMeta = allPropertyMetas[propertyName];
            if (propertyMeta) {
                NSArray *keyPath = [mappedToKey componentsSeparatedByString:@"."];
                propertyMeta->_mappedToKey = mappedToKey;
                if (keyPath.count > 1) {
                    propertyMeta->_mappedToKeyPath = keyPath;
                    [keyPathPropertyMetas addObject:propertyMeta];
                }
                [allPropertyMetas removeObjectForKey:propertyName];
                if (mapper[mappedToKey]) {
                    ((_EvoModelPropertyMeta *)mapper[mappedToKey])->_next = propertyMeta;
                } else {
                    mapper[mappedToKey] = propertyMeta;
                }
            }
        }];
    }
    [allPropertyMetas enumerateKeysAndObjectsUsingBlock:^(NSString *name, _EvoModelPropertyMeta *propertyMeta, BOOL *stop) {
        propertyMeta->_mappedToKey = name;
        if (mapper[name]) {
            ((_EvoModelPropertyMeta *)mapper[name])->_next = propertyMeta;
        } else {
            mapper[name] = propertyMeta;
        }
    }];
    
    if (mapper.count) _mapper = mapper;
    if(keyPathPropertyMetas) _keyPathPropertyMetas = keyPathPropertyMetas;
    _keyMappedCount = _allPropertyMetas.count;
    _nsType = EvoClassGetNSType(cls);
    _hasCustomTransformFromDictonary = ([cls instancesRespondToSelector:@selector(modelTransformFromDictionary:)]);
    _hasCustomTransformToDictionary = ([cls instancesRespondToSelector:@selector(modelTransformToDictionary:)]);
    
    return self;
}

/// Returns the cached model class meta
+ (instancetype)metaWithClass:(Class)cls {
    if (!cls) return nil;
    static CFMutableDictionaryRef cache;
    static dispatch_once_t onceToken;
    static OSSpinLock lock;
    dispatch_once(&onceToken, ^{
        cache = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        lock = OS_SPINLOCK_INIT;
    });
    OSSpinLockLock(&lock);
    _EvoModelMeta *meta = CFDictionaryGetValue(cache, (__bridge const void *)(cls));
    OSSpinLockUnlock(&lock);
    if (!meta) {
        meta = [[_EvoModelMeta alloc] initWithClass:cls];
        if (meta) {
            OSSpinLockLock(&lock);
            CFDictionarySetValue(cache, (__bridge const void *)(cls), (__bridge const void *)(meta));
            OSSpinLockUnlock(&lock);
        }
    }
    return meta;
}

@end


/**
 Get number from property.
 @discussion Caller should hold strong reference to the parameters before this function returns.
 @param model Should not be nil.
 @param meta  Should not be nil, meta.isCNumber should be YES, meta.getter should not be nil.
 @return A number object, or nil if failed.
 */
static force_inline NSNumber *ModelCreateNumberFromProperty(__unsafe_unretained id model,
                                                            __unsafe_unretained _EvoModelPropertyMeta *meta) {
    switch (meta->_type & EvoCodingTypeMask) {
        case EvoCodingTypeBool: {
            return @(((bool (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        } break;
        case EvoCodingTypeInt8: {
            return @(((int8_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        } break;
        case EvoCodingTypeUInt8: {
            return @(((uint8_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        } break;
        case EvoCodingTypeInt16: {
            return @(((int16_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        } break;
        case EvoCodingTypeUInt16: {
            return @(((uint16_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        } break;
        case EvoCodingTypeInt32: {
            return @(((int32_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        } break;
        case EvoCodingTypeUInt32: {
            return @(((uint32_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        } break;
        case EvoCodingTypeInt64: {
            return @(((int64_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        } break;
        case EvoCodingTypeUInt64: {
            return @(((uint64_t (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter));
        } break;
        case EvoCodingTypeFloat: {
            float num = ((float (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter);
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        } break;
        case EvoCodingTypeDouble: {
            double num = ((double (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter);
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        } break;
        case EvoCodingTypeLongDouble: {
            double num = ((long double (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter);
            if (isnan(num) || isinf(num)) return nil;
            return @(num);
        } break;
        default: return nil;
    }
}

/**
 Set number to property.
 @discussion Caller should hold strong reference to the parameters before this function returns.
 @param model Should not be nil.
 @param num   Can be nil.
 @param meta  Should not be nil, meta.isCNumber should be YES, meta.setter should not be nil.
 */
static force_inline void ModelSetNumberToProperty(__unsafe_unretained id model,
                                                  __unsafe_unretained NSNumber *num,
                                                  __unsafe_unretained _EvoModelPropertyMeta *meta) {
    switch (meta->_type & EvoCodingTypeMask) {
        case EvoCodingTypeBool: {
            ((void (*)(id, SEL, bool))(void *) objc_msgSend)((id)model, meta->_setter, num.boolValue);
        } break;
        case EvoCodingTypeInt8: {
            ((void (*)(id, SEL, int8_t))(void *) objc_msgSend)((id)model, meta->_setter, (int8_t)num.charValue);
        } break;
        case EvoCodingTypeUInt8: {
            ((void (*)(id, SEL, uint8_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint8_t)num.unsignedCharValue);
        } break;
        case EvoCodingTypeInt16: {
            ((void (*)(id, SEL, int16_t))(void *) objc_msgSend)((id)model, meta->_setter, (int16_t)num.shortValue);
        } break;
        case EvoCodingTypeUInt16: {
            ((void (*)(id, SEL, uint16_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint16_t)num.unsignedShortValue);
        } break;
        case EvoCodingTypeInt32: {
            ((void (*)(id, SEL, int32_t))(void *) objc_msgSend)((id)model, meta->_setter, (int32_t)num.intValue);
        }
        case EvoCodingTypeUInt32: {
            ((void (*)(id, SEL, uint32_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint32_t)num.unsignedIntValue);
        } break;
        case EvoCodingTypeInt64: {
            ((void (*)(id, SEL, int64_t))(void *) objc_msgSend)((id)model, meta->_setter, (int64_t)num.longLongValue);
        }
        case EvoCodingTypeUInt64: {
            ((void (*)(id, SEL, uint64_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint64_t)num.unsignedLongLongValue);
        } break;
        case EvoCodingTypeFloat: {
            float f = num.floatValue;
            if (isnan(f) || isinf(f)) f = 0;
            ((void (*)(id, SEL, float))(void *) objc_msgSend)((id)model, meta->_setter, f);
        } break;
        case EvoCodingTypeDouble: {
            double d = num.floatValue;
            if (isnan(d) || isinf(d)) d = 0;
            ((void (*)(id, SEL, double))(void *) objc_msgSend)((id)model, meta->_setter, d);
        } break;
        case EvoCodingTypeLongDouble: {
            double d = num.floatValue;
            if (isnan(d) || isinf(d)) d = 0;
            ((void (*)(id, SEL, long double))(void *) objc_msgSend)((id)model, meta->_setter, (long double)d);
        } break;
        default: break;
    }
}

/**
 Set value to model with a property meta.
 
 @discussion Caller should hold strong reference to the parameters before this function returns.
 
 @param model Should not be nil.
 @param value Should not be nil, but can be NSNull.
 @param meta  Should not be nil, and meta->_setter should not be nil.
 */
static void ModelSetValueForProperty(__unsafe_unretained id model,
                                     __unsafe_unretained id value,
                                     __unsafe_unretained _EvoModelPropertyMeta *meta) {
    if (meta->_isCNumber) {
        NSNumber *num = EvoNSNumberCreateFromID(value);
        ModelSetNumberToProperty(model, num, meta);
        if (num) [num class]; // hold the number
    } else if (meta->_nsType) {
        if (value == (id)kCFNull) {
            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, (id)nil);
        } else {
            switch (meta->_nsType) {
                case EvoCodingTypeNSString:
                case EvoCodingTypeNSMutableString: {
                    if ([value isKindOfClass:[NSString class]]) {
                        if (meta->_nsType == EvoCodingTypeNSString) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                        } else {
                            if ([value isKindOfClass:[NSMutableString class]]) {
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                            } else {
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, ((NSString *)value).mutableCopy);
                            }
                        }
                    } else if ([value isKindOfClass:[NSNumber class]]) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                       meta->_setter,
                                                                       (meta->_nsType == EvoCodingTypeNSString) ?
                                                                       ((NSNumber *)value).stringValue :
                                                                       ((NSNumber *)value).stringValue.mutableCopy);
                    } else if ([value isKindOfClass:[NSData class]]) {
                        NSMutableString *string = [[NSMutableString alloc] initWithData:value encoding:NSUTF8StringEncoding];
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, string);
                    } else if ([value isKindOfClass:[NSURL class]]) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                       meta->_setter,
                                                                       (meta->_nsType == EvoCodingTypeNSString) ?
                                                                       ((NSURL *)value).absoluteString :
                                                                       ((NSURL *)value).absoluteString.mutableCopy);
                    } else if ([value isKindOfClass:[NSAttributedString class]]) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                       meta->_setter,
                                                                       (meta->_nsType == EvoCodingTypeNSString) ?
                                                                       ((NSAttributedString *)value).string :
                                                                       ((NSAttributedString *)value).string.mutableCopy);
                    }
                } break;
                    
                case EvoCodingTypeNSValue:
                case EvoCodingTypeNSNumber:
                case EvoCodingTypeNSDecimalNumber: {
                    if (meta->_nsType == EvoCodingTypeNSNumber) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, EvoNSNumberCreateFromID(value));
                    } else if (meta->_nsType == EvoCodingTypeNSDecimalNumber) {
                        if ([value isKindOfClass:[NSDecimalNumber class]]) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                        } else if ([value isKindOfClass:[NSNumber class]]) {
                            NSDecimalNumber *decNum = [NSDecimalNumber decimalNumberWithDecimal:[((NSNumber *)value) decimalValue]];
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, decNum);
                        } else if ([value isKindOfClass:[NSString class]]) {
                            NSDecimalNumber *decNum = [NSDecimalNumber decimalNumberWithString:value];
                            NSDecimal dec = decNum.decimalValue;
                            if (dec._length == 0 && dec._isNegative) {
                                decNum = nil; // NaN
                            }
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, decNum);
                        }
                    } else { // EvoCodingTypeNSValue
                        if ([value isKindOfClass:[NSValue class]]) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                        }
                    }
                } break;
                    
                case EvoCodingTypeNSData:
                case EvoCodingTypeNSMutableData: {
                    if ([value isKindOfClass:[NSData class]]) {
                        if (meta->_nsType == EvoCodingTypeNSData) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                        } else {
                            NSMutableData *data = [value isKindOfClass:[NSMutableData class]] ? value : ((NSData *)value).mutableCopy;
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, data);
                        }
                    } else if ([value isKindOfClass:[NSString class]]) {
                        NSData *data = [(NSString *)value dataUsingEncoding:NSUTF8StringEncoding];
                        if (meta->_nsType == EvoCodingTypeNSMutableData) {
                            data = ((NSData *)data).mutableCopy;
                        }
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, data);
                    }
                } break;
                    
                case EvoCodingTypeNSDate: {
                    if ([value isKindOfClass:[NSDate class]]) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                    } else if ([value isKindOfClass:[NSString class]]) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, EvoNSDateFromString(value));
                    }
                } break;
                    
                case EvoCodingTypeNSURL: {
                    if ([value isKindOfClass:[NSURL class]]) {
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                    } else if ([value isKindOfClass:[NSString class]]) {
                        NSCharacterSet *set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
                        NSString *str = [value stringByTrimmingCharactersInSet:set];
                        if (str.length == 0) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, nil);
                        } else {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, [[NSURL alloc] initWithString:str]);
                        }
                    }
                } break;
                    
                case EvoCodingTypeNSArray:
                case EvoCodingTypeNSMutableArray: {
                    if (meta->_genericCls) {
                        NSArray *valueArr = nil;
                        if ([value isKindOfClass:[NSArray class]]) valueArr = value;
                        else if ([value isKindOfClass:[NSSet class]]) valueArr = ((NSSet *)value).allObjects;
                        if (valueArr) {
                            NSMutableArray *objectArr = [NSMutableArray new];
                            for (id one in valueArr) {
                                if ([one isKindOfClass:meta->_genericCls]) {
                                    [objectArr addObject:one];
                                } else if ([one isKindOfClass:[NSDictionary class]]) {
                                    NSObject *newOne = [meta->_genericCls new];
                                    [newOne modelSetWithDictionary:one];
                                    if (newOne) [objectArr addObject:newOne];
                                }
                            }
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, objectArr);
                        }
                    } else {
                        if ([value isKindOfClass:[NSArray class]]) {
                            if (meta->_nsType == EvoCodingTypeNSArray) {
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                            } else {
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                               meta->_setter,
                                                                               [value isKindOfClass:[NSMutableArray class]] ?
                                                                               value :
                                                                               ((NSArray *)value).mutableCopy);
                            }
                        } else if ([value isKindOfClass:[NSSet class]]) {
                            if (meta->_nsType == EvoCodingTypeNSArray) {
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, ((NSSet *)value).allObjects);
                            } else {
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                               meta->_setter,
                                                                               [value isKindOfClass:[NSMutableArray class]] ?
                                                                               ((NSSet *)value).allObjects :
                                                                               ((NSSet *)value).allObjects.mutableCopy);
                            }
                        }
                    }
                } break;
                    
                case EvoCodingTypeNSDictionary:
                case EvoCodingTypeNSMutableDictionary: {
                    if ([value isKindOfClass:[NSDictionary class]]) {
                        if (meta->_genericCls) {
                            NSMutableDictionary *dic = [NSMutableDictionary new];
                            [((NSDictionary *)value) enumerateKeysAndObjectsUsingBlock:^(NSString *oneKey, NSObject *oneValue, BOOL *stop) {
                                if ([oneValue isKindOfClass:[NSDictionary class]]) {
                                    NSObject *o = [meta->_genericCls new];
                                    [o modelSetWithDictionary:(id)oneValue];
                                    if (o) dic[oneKey] = o;
                                }
                            }];
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, dic);
                        } else {
                            if (meta->_nsType == EvoCodingTypeNSDictionary) {
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, value);
                            } else {
                                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                               meta->_setter,
                                                                               [value isKindOfClass:[NSMutableDictionary class]] ?
                                                                               value :
                                                                               ((NSDictionary *)value).mutableCopy);
                            }
                        }
                    }
                } break;
                    
                case EvoCodingTypeNSSet:
                case EvoCodingTypeNSMutableSet: {
                    NSSet *valueSet = nil;
                    if ([value isKindOfClass:[NSArray class]]) valueSet = [NSMutableSet setWithArray:value];
                    else if ([value isKindOfClass:[NSSet class]]) valueSet = ((NSSet *)value);
                    
                    if (meta->_genericCls) {
                        NSMutableSet *set = [NSMutableSet new];
                        for (id one in valueSet) {
                            if ([one isKindOfClass:meta->_genericCls]) {
                                [set addObject:one];
                            } else if ([one isKindOfClass:[NSDictionary class]]) {
                                NSObject *newOne = [meta->_genericCls new];
                                [newOne modelSetWithDictionary:one];
                                if (newOne) [set addObject:newOne];
                            }
                        }
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, valueSet);
                    } else {
                        if (meta->_nsType == EvoCodingTypeNSSet) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, valueSet);
                        } else {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model,
                                                                           meta->_setter,
                                                                           [valueSet isKindOfClass:[NSMutableSet class]] ?
                                                                           valueSet :
                                                                           ((NSSet *)valueSet).mutableCopy);
                        }
                    }
                } break;
                    
                default: break;
            }
        }
    } else {
        BOOL isNull = (value == (id)kCFNull);
        switch (meta->_type & EvoCodingTypeMask) {
            case EvoCodingTypeObject: {
                if (isNull) {
                    ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, (id)nil);
                } else if ([value isKindOfClass:meta->_cls]) {
                    ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, (id)value);
                } else if ([value isKindOfClass:[NSDictionary class]]) {
                    NSObject *one = nil;
                    if (meta->_getter) {
                        one = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, meta->_getter);
                    }
                    if (one) {
                        [one modelSetWithDictionary:value];
                    } else {
                        one = [meta->_cls new];
                        [one modelSetWithDictionary:value];
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, (id)one);
                    }
                }
            } break;
                
            case EvoCodingTypeClass: {
                if (isNull) {
                    ((void (*)(id, SEL, Class))(void *) objc_msgSend)((id)model, meta->_setter, (Class)NULL);
                } else {
                    Class cls = ((NSObject *)value).class;
                    if (cls && class_isMetaClass(cls)) {
                        ((void (*)(id, SEL, Class))(void *) objc_msgSend)((id)model, meta->_setter, (Class)value);
                    }
                }
            } break;
                
            case  EvoCodingTypeSEL: {
                if (isNull) {
                    ((void (*)(id, SEL, SEL))(void *) objc_msgSend)((id)model, meta->_setter, (SEL)NULL);
                } else if ([value isKindOfClass:[NSString class]]) {
                    SEL sel = NSSelectorFromString(value);
                    if (sel) ((void (*)(id, SEL, SEL))(void *) objc_msgSend)((id)model, meta->_setter, (SEL)sel);
                }
            } break;
                
            case EvoCodingTypeBlock: {
                if (isNull) {
                    ((void (*)(id, SEL, void (^)()))(void *) objc_msgSend)((id)model, meta->_setter, (void (^)())NULL);
                } else if ([value isKindOfClass:EvoNSBlockClass()]) {
                    ((void (*)(id, SEL, void (^)()))(void *) objc_msgSend)((id)model, meta->_setter, (void (^)())value);
                }
            } break;
                
            case EvoCodingTypeStruct:
            case EvoCodingTypeUnion:
            case EvoCodingTypeCArray: {
                if ([value isKindOfClass:[NSValue class]]) {
                    [model setValue:value forKey:meta->_name];
                }
            } break;
                
            case EvoCodingTypePointer:
            case EvoCodingTypeCString: {
                if (isNull) {
                    ((void (*)(id, SEL, void *))(void *) objc_msgSend)((id)model, meta->_setter, (void *)NULL);
                } else if ([value isKindOfClass:[NSValue class]]) {
                    void *pointer = ((NSValue *)value).pointerValue;
                    ((void (*)(id, SEL, void *))(void *) objc_msgSend)((id)model, meta->_setter, (void *)pointer);
                }
            } break;
                
            default: break;
        }
    }
}


typedef struct {
    void *modelMeta;  ///< _YYModelMeta
    void *model;      ///< id (self)
    void *dictionary; ///< NSDictionary (json)
} ModelSetContext;

/**
 Apply function for dictionary, to set the key-value pair to model.
 
 @param _key     should not be nil, NSString.
 @param _value   should not be nil.
 @param _context _context.modelMeta and _context.model should not be nil.
 */
static void ModelSetWithDictionaryFunction(const void *_key, const void *_value, void *_context) {
    ModelSetContext *context = _context;
    __unsafe_unretained _EvoModelMeta *meta = (__bridge _EvoModelMeta *)(context->modelMeta);
    __unsafe_unretained _EvoModelPropertyMeta *propertyMeta = [meta->_mapper objectForKey:(__bridge id)(_key)];
    __unsafe_unretained id model = (__bridge id)(context->model);
    while (propertyMeta) {
        if (propertyMeta->_setter) {
            ModelSetValueForProperty(model, (__bridge __unsafe_unretained id)_value, propertyMeta);
        }
        propertyMeta = propertyMeta->_next;
    };
}

/**
 Apply function for model property meta, to set dictionary to model.
 
 @param _propertyMeta should not be nil, _YYModelPropertyMeta.
 @param _context      _context.model and _context.dictionary should not be nil.
 */
static void ModelSetWithPropertyMetaArrayFunction(const void *_propertyMeta, void *_context) {
    ModelSetContext *context = _context;
    __unsafe_unretained NSDictionary *dictionary = (__bridge NSDictionary *)(context->dictionary);
    __unsafe_unretained _EvoModelPropertyMeta *propertyMeta = (__bridge _EvoModelPropertyMeta *)(_propertyMeta);
    if (!propertyMeta->_setter) return;
    id value = nil;
    if (propertyMeta->_mappedToKeyPath) {
        value = (EvoValueForKeyPath(dictionary, propertyMeta->_mappedToKeyPath));
    } else {
        value = [dictionary objectForKey:propertyMeta->_mappedToKey];
    }
    if (value) {
        __unsafe_unretained id model = (__bridge id)(context->model);
        ModelSetValueForProperty(model, value, propertyMeta);
    }
}

/**
 Returns a valid JSON object (NSArray/NSDictionary/NSString/NSNumber/NSNull),
 or nil if an error occurs.
 
 @param model Model, can be nil.
 @return JSON object, nil if an error occurs.
 */
static id ModelToJSONObjectRecursive(NSObject *model) {
    if (!model || model == (id)kCFNull) return model;
    if ([model isKindOfClass:[NSString class]]) return model;
    if ([model isKindOfClass:[NSNumber class]]) return model;
    if ([model isKindOfClass:[NSDictionary class]]) {
        if ([NSJSONSerialization isValidJSONObject:model]) return model;
        NSMutableDictionary *newDic = [NSMutableDictionary new];
        [((NSDictionary *)model) enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
            NSString *stringKey = [key isKindOfClass:[NSString class]] ? key : key.description;
            if (!stringKey) return;
            id jsonObj = ModelToJSONObjectRecursive(obj);
            if (!jsonObj) jsonObj = (id)kCFNull;
            newDic[stringKey] = jsonObj;
        }];
        return newDic;
    }
    if ([model isKindOfClass:[NSSet class]]) {
        NSArray *array = ((NSSet *)model).allObjects;
        if ([NSJSONSerialization isValidJSONObject:array]) return array;
        NSMutableArray *newArray = [NSMutableArray new];
        for (id obj in array) {
            if ([obj isKindOfClass:[NSString class]] || [obj isKindOfClass:[NSNumber class]]) {
                [newArray addObject:obj];
            } else {
                id jsonObj = ModelToJSONObjectRecursive(obj);
                if (jsonObj && jsonObj != (id)kCFNull) [newArray addObject:jsonObj];
            }
        }
        return newArray;
    }
    if ([model isKindOfClass:[NSArray class]]) {
        if ([NSJSONSerialization isValidJSONObject:model]) return model;
        NSMutableArray *newArray = [NSMutableArray new];
        for (id obj in (NSArray *)model) {
            if ([obj isKindOfClass:[NSString class]] || [obj isKindOfClass:[NSNumber class]]) {
                [newArray addObject:obj];
            } else {
                id jsonObj = ModelToJSONObjectRecursive(obj);
                if (jsonObj && jsonObj != (id)kCFNull) [newArray addObject:jsonObj];
            }
        }
        return newArray;
    }
    if ([model isKindOfClass:[NSURL class]]) return ((NSURL *)model).absoluteString;
    if ([model isKindOfClass:[NSAttributedString class]]) return ((NSAttributedString *)model).string;
    if ([model isKindOfClass:[NSDate class]]) return [EvoISODateFormatter() stringFromDate:(id)model];
    if ([model isKindOfClass:[NSData class]]) return nil;
    
    
    _EvoModelMeta *modelMeta = [_EvoModelMeta metaWithClass:[model class]];
    if (!modelMeta || modelMeta->_keyMappedCount == 0) return nil;
    NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithCapacity:64];
    __unsafe_unretained NSMutableDictionary *dic = result; // avoid retain and release in block
    [modelMeta->_mapper enumerateKeysAndObjectsUsingBlock:^(NSString *propertyMappedKey, _EvoModelPropertyMeta *propertyMeta, BOOL *stop) {
        if (!propertyMeta->_getter) return;
        
        id value = nil;
        if (propertyMeta->_isCNumber) {
            value = ModelCreateNumberFromProperty(model, propertyMeta);
        } else if (propertyMeta->_nsType) {
            id v = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
            value = ModelToJSONObjectRecursive(v);
        } else {
            switch (propertyMeta->_type & EvoCodingTypeMask) {
                case EvoCodingTypeObject: {
                    id v = ((id (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
                    value = ModelToJSONObjectRecursive(v);
                    if (value == (id)kCFNull) value = nil;
                } break;
                case EvoCodingTypeClass: {
                    Class v = ((Class (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
                    value = v ? NSStringFromClass(v) : nil;
                } break;
                case EvoCodingTypeSEL: {
                    SEL v = ((SEL (*)(id, SEL))(void *) objc_msgSend)((id)model, propertyMeta->_getter);
                    value = v ? NSStringFromSelector(v) : nil;
                } break;
                default: break;
            }
        }
        if (!value) return;
        
        if (propertyMeta->_mappedToKeyPath) {
            NSMutableDictionary *superDic = dic;
            NSMutableDictionary *subDic = nil;
            for (NSUInteger i = 0, max = propertyMeta->_mappedToKeyPath.count; i < max; i++) {
                NSString *key = propertyMeta->_mappedToKeyPath[i];
                if (i + 1 == max) { // end
                    if (!superDic[key]) superDic[key] = value;
                    break;
                }
                
                subDic = superDic[key];
                if (subDic) {
                    if ([subDic isKindOfClass:[NSDictionary class]]) {
                        if (![subDic isKindOfClass:[NSMutableDictionary class]]) {
                            subDic = subDic.mutableCopy;
                            superDic[key] = subDic;
                        }
                    } else {
                        break;
                    }
                } else {
                    subDic = [NSMutableDictionary new];
                    superDic[key] = subDic;
                }
                superDic = subDic;
                subDic = nil;
            }
        } else {
            if (!dic[propertyMeta->_mappedToKey]) {
                dic[propertyMeta->_mappedToKey] = value;
            }
        }
    }];
    
    if (modelMeta->_hasCustomTransformFromDictonary) {
        BOOL suc = [((id<Evo>)model) modelTransformFromDictionary:dic];
        if (!suc) return nil;
    }
    return result;
}



@implementation NSObject (YYModel)

+ (instancetype)modelFromJSON:(id)json {
    if (!json || json == (id)kCFNull) return nil;
    NSObject *one = [self new];
    [one modelSetWithJSON:json];
    return one;
}

+ (instancetype)modelFromDictionary:(NSDictionary *)dictionary {
    if (!dictionary || dictionary == (id)kCFNull) return nil;
    if (![dictionary isKindOfClass:[NSDictionary class]]) return nil;
    NSObject *one = [self new];
    [one modelSetWithDictionary:dictionary];
    return one;
}

- (BOOL)modelSetWithJSON:(id)json {
    if (!json || json == (id)kCFNull) return NO;
    NSDictionary *dic = nil;
    NSData *jsonData = nil;
    if ([json isKindOfClass:[NSDictionary class]]) {
        dic = json;
    } else if ([json isKindOfClass:[NSString class]]) {
        jsonData = [(NSString *)json dataUsingEncoding : NSUTF8StringEncoding];
    } else if ([json isKindOfClass:[NSData class]]) {
        jsonData = json;
    }
    if (jsonData) {
        dic = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:NULL];
        if (![dic isKindOfClass:[NSDictionary class]]) dic = nil;
    }
    return [self modelSetWithDictionary:dic];
}

- (BOOL)modelSetWithDictionary:(NSDictionary *)dic {
    if (!dic || dic == (id)kCFNull) return NO;
    if (![dic isKindOfClass:[NSDictionary class]]) return NO;
    
    _EvoModelMeta *modelMeta = [_EvoModelMeta metaWithClass:object_getClass(self)];
    if (modelMeta->_keyMappedCount == 0) return NO;
    ModelSetContext context = {0};
    context.modelMeta = (__bridge void *)(modelMeta);
    context.model = (__bridge void *)(self);
    context.dictionary = (__bridge void *)(dic);
    
    if (modelMeta->_keyMappedCount >= CFDictionaryGetCount((CFDictionaryRef)dic)) {
        CFDictionaryApplyFunction((CFDictionaryRef)dic, ModelSetWithDictionaryFunction, &context);
        if (modelMeta->_keyPathPropertyMetas) {
            CFArrayApplyFunction((CFArrayRef)modelMeta->_keyPathPropertyMetas,
                                 CFRangeMake(0, CFArrayGetCount((CFArrayRef)modelMeta->_keyPathPropertyMetas)),
                                 ModelSetWithPropertyMetaArrayFunction,
                                 &context);
        }
    } else {
        CFArrayApplyFunction((CFArrayRef)modelMeta->_allPropertyMetas,
                             CFRangeMake(0, modelMeta->_keyMappedCount),
                             ModelSetWithPropertyMetaArrayFunction,
                             &context);
    }
    
    if (modelMeta->_hasCustomTransformFromDictonary) {
        return [((id<Evo>)self) modelTransformFromDictionary:dic];
    }
    return YES;
}

- (id)toJSONObject {
    /*
     Apple said:
     The top level object is an NSArray or NSDictionary.
     All objects are instances of NSString, NSNumber, NSArray, NSDictionary, or NSNull.
     All dictionary keys are instances of NSString.
     Numbers are not NaN or infinity.
     */
    id jsonObject = ModelToJSONObjectRecursive(self);
    if ([jsonObject isKindOfClass:[NSArray class]]) return jsonObject;
    if ([jsonObject isKindOfClass:[NSDictionary class]]) return jsonObject;
    return nil;
}

- (NSData *)toJSONData {
    id jsonObject = [self toJSONObject];
    if (!jsonObject) return nil;
    return [NSJSONSerialization dataWithJSONObject:jsonObject options:0 error:NULL];
}

- (NSString *)toJSONString {
    NSData *jsonData = [self toJSONData];
    if (jsonData.length == 0) return nil;
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

- (id)modelCopy{
    if (self == (id)kCFNull) return self;
    _EvoModelMeta *modelMeta = [_EvoModelMeta metaWithClass:self.class];
    if (modelMeta->_nsType) return [self copy];
    
    NSObject *one = [self.class new];
    [modelMeta->_allPropertyMetas enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        
    }];
    for (_EvoModelPropertyMeta *propertyMeta in modelMeta->_allPropertyMetas) {
        if (!propertyMeta->_getter || !propertyMeta->_setter) continue;
        
        if (propertyMeta->_isCNumber) {
            switch (propertyMeta->_type & EvoCodingTypeMask) {
                case EvoCodingTypeBool: {
                    bool num = ((bool (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, bool))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case EvoCodingTypeInt8:
                case EvoCodingTypeUInt8: {
                    uint8_t num = ((bool (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, uint8_t))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case EvoCodingTypeInt16:
                case EvoCodingTypeUInt16: {
                    uint16_t num = ((uint16_t (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, uint16_t))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case EvoCodingTypeInt32:
                case EvoCodingTypeUInt32: {
                    uint32_t num = ((uint32_t (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, uint32_t))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case EvoCodingTypeInt64:
                case EvoCodingTypeUInt64: {
                    uint64_t num = ((uint64_t (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, uint64_t))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case EvoCodingTypeFloat: {
                    float num = ((float (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, float))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case EvoCodingTypeDouble: {
                    double num = ((double (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, double))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                case EvoCodingTypeLongDouble: {
                    long double num = ((long double (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, long double))(void *) objc_msgSend)((id)one, propertyMeta->_setter, num);
                } break;
                default: break;
            }
        } else {
            switch (propertyMeta->_type & EvoCodingTypeMask) {
                case EvoCodingTypeObject:
                case EvoCodingTypeClass:
                case EvoCodingTypeBlock: {
                    id value = ((id (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)one, propertyMeta->_setter, value);
                } break;
                case EvoCodingTypeSEL:
                case EvoCodingTypePointer:
                case EvoCodingTypeCString: {
                    size_t value = ((size_t (*)(id, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_getter);
                    ((void (*)(id, SEL, size_t))(void *) objc_msgSend)((id)one, propertyMeta->_setter, value);
                } break;
                case EvoCodingTypeStruct:
                case EvoCodingTypeUnion:
                case EvoCodingTypeCArray: {
                    NSValue *value = [self valueForKey:NSStringFromSelector(propertyMeta->_getter)];
                    if (value) {
                        [self setValue:value forKey:propertyMeta->_name];
                    }
                } break;
                default: break;
            }
        }
    }
    return one;
}

- (void)modelEncodeWithCoder:(NSCoder *)aCoder {
    if (!aCoder) return;
    if (self == (id)kCFNull) {
        [((id<NSCoding>)self)encodeWithCoder:aCoder];
        return;
    }
    
    _EvoModelMeta *modelMeta = [_EvoModelMeta metaWithClass:self.class];
    if (modelMeta->_nsType) {
        [((id<NSCoding>)self)encodeWithCoder:aCoder];
        return;
    }
    
    for (_EvoModelPropertyMeta *propertyMeta in modelMeta->_allPropertyMetas) {
        if (!propertyMeta->_getter) return;
        
        if (propertyMeta->_isCNumber) {
            NSNumber *value = ModelCreateNumberFromProperty(self, propertyMeta);
            if (value) [aCoder encodeObject:value forKey:propertyMeta->_name];
        } else {
            switch (propertyMeta->_type & EvoCodingTypeMask) {
                case EvoCodingTypeObject: {
                    id value = ((id (*)(id, SEL))(void *)objc_msgSend)((id)self, propertyMeta->_getter);
                    if (value && (propertyMeta->_nsType || [value respondsToSelector:@selector(encodeWithCoder:)])) {
                        [aCoder encodeObject:value forKey:propertyMeta->_name];
                    }
                } break;
                case EvoCodingTypeSEL: {
                    SEL value = ((SEL (*)(id, SEL))(void *)objc_msgSend)((id)self, propertyMeta->_getter);
                    if (value) {
                        NSString *str = NSStringFromSelector(value);
                        [aCoder encodeObject:str forKey:propertyMeta->_name];
                    }
                } break;
                case EvoCodingTypeStruct:
                case EvoCodingTypeUnion:
                case EvoCodingTypeCArray: {
                    NSValue *value = [self valueForKey:NSStringFromSelector(propertyMeta->_getter)];
                    [aCoder encodeObject:value forKey:propertyMeta->_name];
                } break;
                    
                default:
                    break;
            }
        }
    }
}

- (id)modelInitWithCoder:(NSCoder *)aDecoder {
    if (!aDecoder) return self;
    if (self == (id)kCFNull) return self;
    _EvoModelMeta *modelMeta = [_EvoModelMeta metaWithClass:self.class];
    if (modelMeta->_nsType) return self;
    
    for (_EvoModelPropertyMeta *propertyMeta in modelMeta->_allPropertyMetas) {
        if (!propertyMeta->_setter) continue;
        
        if (propertyMeta->_isCNumber) {
            NSValue *value = [aDecoder decodeObjectForKey:propertyMeta->_name];
            if (value) [self setValue:value forKey:propertyMeta->_name];
        } else {
            EvoCodingType type = propertyMeta->_type & EvoCodingTypeMask;
            switch (type) {
                case EvoCodingTypeObject: {
                    id value = [aDecoder decodeObjectForKey:propertyMeta->_name];
                    ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)self, propertyMeta->_setter, value);
                } break;
                case EvoCodingTypeSEL: {
                    NSString *str = [aDecoder decodeObjectForKey:propertyMeta->_name];
                    if ([str isKindOfClass:[NSString class]]) {
                        SEL sel = NSSelectorFromString(str);
                        ((void (*)(id, SEL, SEL))(void *) objc_msgSend)((id)self, propertyMeta->_setter, sel);
                    }
                } break;
                case EvoCodingTypeStruct:
                case EvoCodingTypeUnion:
                case EvoCodingTypeCArray: {
                    NSValue *value = [aDecoder decodeObjectForKey:propertyMeta->_name];
                    if (value) [self setValue:value forKey:propertyMeta->_name];
                } break;
                    
                default:
                    break;
            }
        }
    }
    return self;
}

- (NSUInteger)evoHash {
    if (self == (id)kCFNull) return [self hash];
    _EvoModelMeta *modelMeta = [_EvoModelMeta metaWithClass:self.class];
    if (modelMeta->_nsType) return [self hash];
    
    NSUInteger value = 0;
    NSUInteger count = 0;
    for (_EvoModelPropertyMeta *propertyMeta in modelMeta->_allPropertyMetas) {
        if (!propertyMeta->_getter) continue;
        value ^= [[self valueForKey:NSStringFromSelector(propertyMeta->_getter)] hash];
        count++;
    }
    if (count == 0) value = (long)((__bridge void *)self);
    return value;
}

- (BOOL)isEqualToModel:(id)model {
    if (self == model) return YES;
    if (![model isMemberOfClass:self.class]) return NO;
    _EvoModelMeta *modelMeta = [_EvoModelMeta metaWithClass:self.class];
    if (modelMeta->_nsType) return [self isEqual:model];
    if ([self hash] != [model hash]) return NO;
    
    for (_EvoModelPropertyMeta *propertyMeta in modelMeta->_allPropertyMetas) {
        if (!propertyMeta->_getter) continue;
        id this = [self valueForKey:NSStringFromSelector(propertyMeta->_getter)];
        id that = [self valueForKey:NSStringFromSelector(propertyMeta->_getter)];
        if (this == that) continue;
        if (this == nil || that == nil) return NO;
        if ([this isEqual:that]) continue;
    }
    return YES;
}

@end



@implementation NSArray (Evo)

+ (NSArray *)modelArrayWithClass:(Class)cls json:(id)json {
    if (!json) return nil;
    NSArray *arr = nil;
    NSData *jsonData = nil;
    if ([json isKindOfClass:[NSArray class]]) {
        arr = json;
    } else if ([json isKindOfClass:[NSString class]]) {
        jsonData = [(NSString *)json dataUsingEncoding : NSUTF8StringEncoding];
    } else if ([json isKindOfClass:[NSData class]]) {
        jsonData = json;
    }
    if (jsonData) {
        arr = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:NULL];
        if (![arr isKindOfClass:[NSArray class]]) arr = nil;
    }
    return [self modelArrayWithClass:cls array:arr];
}

+ (NSArray *)modelArrayWithClass:(Class)cls array:(NSArray *)arr {
    if (!cls || !arr) return nil;
    NSMutableArray *result = [NSMutableArray new];
    for (NSDictionary *dic in arr) {
        if (![dic isKindOfClass:[NSDictionary class]]) continue;
        NSObject *obj = [cls modelFromDictionary:dic];
        if (obj) [result addObject:obj];
    }
    return result;
}

@end


@implementation NSDictionary (Evo)

+ (NSDictionary *)modelDictionaryWithClass:(Class)cls json:(id)json {
    if (!json) return nil;
    NSDictionary *dic = nil;
    NSData *jsonData = nil;
    if ([json isKindOfClass:[NSDictionary class]]) {
        dic = json;
    } else if ([json isKindOfClass:[NSString class]]) {
        jsonData = [(NSString *)json dataUsingEncoding : NSUTF8StringEncoding];
    } else if ([json isKindOfClass:[NSData class]]) {
        jsonData = json;
    }
    if (jsonData) {
        dic = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:NULL];
        if (![dic isKindOfClass:[NSDictionary class]]) dic = nil;
    }
    return [self modelDictionaryWithClass:cls dictionary:dic];
}

+ (NSDictionary *)modelDictionaryWithClass:(Class)cls dictionary:(NSDictionary *)dic {
    if (!cls || !dic) return nil;
    NSMutableDictionary *result = [NSMutableDictionary new];
    for (NSString *key in dic.allKeys) {
        if (![key isKindOfClass:[NSString class]]) continue;
        NSObject *obj = [cls modelFromDictionary:dic[key]];
        if (obj) result[key] = obj;
    }
    return result;
}

@end

