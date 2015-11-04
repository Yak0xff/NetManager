

#import "EvoRuntime.h"
#import <libkern/OSAtomic.h>


EvoCodingType EvoEncodingGetType(const char *typeEncoding){
    
    char *type = (char *)typeEncoding;
    if (!type) return EvoCodingTypeUnknown;
    size_t len = strlen(type);
    if (len == 0) return EvoCodingTypeUnknown;
    
    EvoCodingType qualifier = 0;
    bool prefix = true;
    while (prefix) {
        switch (*type) {
            case 'r': {
                qualifier |= EvoCodingTypeQualifierConst;
                type++;
            } break;
            case 'n': {
                qualifier |= EvoCodingTypeQualifierIn;
                type++;
            } break;
            case 'N': {
                qualifier |= EvoCodingTypeQualifierInout;
                type++;
            } break;
            case 'o': {
                qualifier |= EvoCodingTypeQualifierOut;
                type++;
            } break;
            case 'O': {
                qualifier |= EvoCodingTypeQualifierBycopy;
                type++;
            } break;
            case 'R': {
                qualifier |= EvoCodingTypeQualifierByref;
                type++;
            } break;
            case 'V': {
                qualifier |= EvoCodingTypeQualifierOneway;
                type++;
            } break;
            default: { prefix = false; } break;
        }
    }
    
    len = strlen(type);
    if (len == 0) return EvoCodingTypeUnknown | qualifier;
    
    switch (*type) {
        case 'v': return EvoCodingTypeVoid | qualifier;
        case 'B': return EvoCodingTypeBool | qualifier;
        case 'c': return EvoCodingTypeInt8 | qualifier;
        case 'C': return EvoCodingTypeUInt8 | qualifier;
        case 's': return EvoCodingTypeInt16 | qualifier;
        case 'S': return EvoCodingTypeUInt16 | qualifier;
        case 'i': return EvoCodingTypeInt32 | qualifier;
        case 'I': return EvoCodingTypeUInt32 | qualifier;
        case 'l': return EvoCodingTypeInt32 | qualifier;
        case 'L': return EvoCodingTypeUInt32 | qualifier;
        case 'q': return EvoCodingTypeInt64 | qualifier;
        case 'Q': return EvoCodingTypeUInt64 | qualifier;
        case 'f': return EvoCodingTypeFloat | qualifier;
        case 'd': return EvoCodingTypeDouble | qualifier;
        case 'D': return EvoCodingTypeLongDouble | qualifier;
        case '#': return EvoCodingTypeClass | qualifier;
        case ':': return EvoCodingTypeSEL | qualifier;
        case '*': return EvoCodingTypeCString | qualifier;
        case '?': return EvoCodingTypePointer | qualifier;
        case '[': return EvoCodingTypeCArray | qualifier;
        case '(': return EvoCodingTypeUnion | qualifier;
        case '{': return EvoCodingTypeStruct | qualifier;
        case '@': {
            if (len == 2 && *(type + 1) == '?')
                return EvoCodingTypeBlock | qualifier;
            else
                return EvoCodingTypeObject | qualifier;
        } break;
        default: return EvoCodingTypeUnknown | qualifier;
    }
}

@implementation EvoIvarInfo

- (instancetype)initWithIvar:(Ivar)ivar{
    if (!ivar) {
        return nil;
    }
    
    self = [super init];
    
    _ivar = ivar;
    const char *name = ivar_getName(ivar);
    if (name) {
        _name = [NSString stringWithUTF8String:name];
    }
    _offset = ivar_getOffset(ivar);
    const char *typeEncoding = ivar_getTypeEncoding(ivar);
    if (typeEncoding) {
        _typeEncoding = [NSString stringWithUTF8String:typeEncoding];
        _type = EvoEncodingGetType(typeEncoding);
    }
    return self;
}

@end


@implementation EvoMethodInfo

- (instancetype)initWithMethod:(Method)method{
    if (!method) {
        return nil;
    }
    self = [super init];
    
    _method = method;
    _sel = method_getName(method); // 获取方法名
    _imp = method_getImplementation(method); //获取方法实现
    const char *name = sel_getName(_sel); // 获取方法的C字符串
    if (name) {
        _name = [NSString stringWithUTF8String:name];
    }
    
    const char *typeEncoding = method_getTypeEncoding(method); // 获取方法参数的类型
    if (typeEncoding) {
        _typeEncoding = [NSString stringWithUTF8String:typeEncoding];
    }
    char *returnType = method_copyReturnType(method); // 获取方法返回类型
    if (returnType) {
        _returnTypeEncoding = [NSString stringWithUTF8String:returnType];
        free(returnType);
    }
    unsigned int argumentCount = method_getNumberOfArguments(method); // 获取参数个数
    if (argumentCount > 0) {
        NSMutableArray *argumentTypes = [NSMutableArray new];
        for (unsigned int i = 0; i < argumentCount; i++) {
            char *argumentType = method_copyArgumentType(method, i);
            if (argumentType) {
                NSString *type = [NSString stringWithUTF8String:argumentType];
                [argumentTypes addObject:type ? type : @""];
                free(argumentType);
            } else {
                [argumentTypes addObject:@""];
            }
        }
        _argumentTypeEncodings = argumentTypes;
    }
    
    return self;
}

@end


@implementation EvoPropertyInfo

- (instancetype)initWithProperty:(objc_property_t)property{
    if (!property) return nil;
    self = [self init];
    _property = property;
    const char *name = property_getName(property);
    if (name) {
        _name = [NSString stringWithUTF8String:name];
    }
    
    EvoCodingType type = 0;
    unsigned int attrCount;
    objc_property_attribute_t *attrs = property_copyAttributeList(property, &attrCount);
    for (unsigned int i = 0; i < attrCount; i++) {
        switch (attrs[i].name[0]) {
            case 'T': { // Type encoding
                if (attrs[i].value) {
                    _typeEncoding = [NSString stringWithUTF8String:attrs[i].value];
                    type = EvoEncodingGetType(attrs[i].value);
                    if (type & EvoCodingTypeObject) {
                        size_t len = strlen(attrs[i].value);
                        if (len > 3) {
                            char name[len - 2];
                            name[len - 3] = '\0';
                            memcpy(name, attrs[i].value + 2, len - 3);
                            _cls = objc_getClass(name);
                        }
                    }
                }
            } break;
            case 'V': { // Instance variable
                if (attrs[i].value) {
                    _ivarName = [NSString stringWithUTF8String:attrs[i].value];
                }
            } break;
            case 'R': {
                type |= EvoCodingTypePropertyReadonly;
            } break;
            case 'C': {
                type |= EvoCodingTypePropertyCopy;
            } break;
            case '&': {
                type |= EvoCodingTypePropertyRetain;
            } break;
            case 'N': {
                type |= EvoCodingTypePropertyNonatomic;
            } break;
            case 'D': {
                type |= EvoCodingTypePropertyDynamic;
            } break;
            case 'W': {
                type |= EvoCodingTypePropertyWeak;
            } break;
            case 'P': {
                type |= EvoCodingTypePropertyGarbage;
            } break;
            case 'G': {
                type |= EvoCodingTypePropertyCustomGetter;
                if (attrs[i].value) {
                    _getter = [NSString stringWithUTF8String:attrs[i].value];
                }
            } break;
            case 'S': {
                type |= EvoCodingTypePropertyCustomSetter;
                if (attrs[i].value) {
                    _setter = [NSString stringWithUTF8String:attrs[i].value];
                }
            } break;
            default:
                break;
        }
    }
    if (attrs) {
        free(attrs);
        attrs = NULL;
    }
    
    _type = type;
    if (_name.length) {
        if (!_getter) {
            _getter = _name;
        }
        if (!_setter) {
            _setter = [NSString stringWithFormat:@"set%@%@:", [_name substringToIndex:1].uppercaseString, [_name substringFromIndex:1]];
        }
    }
    return self;
}

@end


@implementation EvoRuntime{
    BOOL _needUpdate;
}

- (instancetype)initWithClass:(Class)cls{
    if (!cls) {
        return nil;
    }
    self = [super init];
    _cls = cls;
    _superCls = class_getSuperclass(cls);
    _isMeta = class_isMetaClass(cls);
    if (!_isMeta) {
        _metaCls = objc_getMetaClass(class_getName(cls));
    }
    _name = NSStringFromClass(cls);
    [self _update];
    
    _superRuntime = [self.class runtimeInfoFromClass:_superCls];
    
    return self;
}


- (instancetype)initWithClsName:(NSString *)clsName{
    Class cls = NSClassFromString(clsName);
    return [self initWithClass:cls];
}

- (void)_update{
    _ivarInfos = nil;
    _methodInfos = nil;
    _propertyInfos = nil;
    
    Class cls = self.cls;
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    if (methods) {
        NSMutableDictionary *methodInfos = [NSMutableDictionary new];
        _methodInfos = methodInfos;
        for (unsigned int i = 0; i < methodCount; i++) {
            EvoMethodInfo *info = [[EvoMethodInfo alloc] initWithMethod:methods[i]];
            if (info.name) methodInfos[info.name] = info;
        }
        free(methods);
    }
    unsigned int propertyCount = 0;
    objc_property_t *properties = class_copyPropertyList(cls, &propertyCount);
    if (properties) {
        NSMutableDictionary *propertyInfos = [NSMutableDictionary new];
        _propertyInfos = propertyInfos;
        for (unsigned int i = 0; i < propertyCount; i++) {
            EvoPropertyInfo *info = [[EvoPropertyInfo alloc] initWithProperty:properties[i]];
            if (info.name) propertyInfos[info.name] = info;
        }
        free(properties);
    }
    
    unsigned int ivarCount = 0;
    Ivar *ivars = class_copyIvarList(cls, &ivarCount);
    if (ivars) {
        NSMutableDictionary *ivarInfos = [NSMutableDictionary new];
        _ivarInfos = ivarInfos;
        for (unsigned int i = 0; i < ivarCount; i++) {
            EvoIvarInfo *info = [[EvoIvarInfo alloc] initWithIvar:ivars[i]];
            if (info.name) ivarInfos[info.name] = info;
        }
        free(ivars);
    }
    _needUpdate = NO;
}

- (void)setNeedUpdate {
    _needUpdate = YES;
}

+ (instancetype)runtimeInfoFromClass:(Class)cls{
    if (!cls) return nil;
    static CFMutableDictionaryRef classCache;
    static CFMutableDictionaryRef metaCache;
    static dispatch_once_t onceToken;
    static OSSpinLock lock;
    dispatch_once(&onceToken, ^{
        classCache = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        metaCache = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        lock = OS_SPINLOCK_INIT;
    });
    OSSpinLockLock(&lock);
    EvoRuntime *info = CFDictionaryGetValue(class_isMetaClass(cls) ? metaCache : classCache, (__bridge const void *)(cls));
    if (info && info->_needUpdate) {
        [info _update];
    }
    OSSpinLockUnlock(&lock);
    if (!info) {
        info = [[EvoRuntime alloc] initWithClass:cls];
        if (info) {
            OSSpinLockLock(&lock);
            CFDictionarySetValue(info.isMeta ? metaCache : classCache, (__bridge const void *)(cls), (__bridge const void *)(info));
            OSSpinLockUnlock(&lock);
        }
    }
    return info;
}

+ (instancetype)runtimeInfoFromClassName:(NSString *)clsName{
    Class cls = NSClassFromString(clsName);
    return [self runtimeInfoFromClass:cls];
}

@end
