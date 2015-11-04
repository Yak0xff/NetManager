//
// 本类专门负责获取运行时类的信息
// 包括：数据类型列表、方法列表、属性列表、类信息等
//
//
// 参考地址：
// https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html
// https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtPropertyIntrospection.html
//


#import <Foundation/Foundation.h>
#import <objc/runtime.h>


// 数据类型编码
typedef NS_OPTIONS(NSUInteger, EvoCodingType) {
    //基本数据类型
    EvoCodingTypeMask       = 0x1F, ///< mask of type value
    EvoCodingTypeUnknown    = 0, ///< unknown
    EvoCodingTypeVoid       = 1, ///< void
    EvoCodingTypeBool       = 2, ///< bool
    EvoCodingTypeInt8       = 3, ///< char / BOOL
    EvoCodingTypeUInt8      = 4, ///< unsigned char
    EvoCodingTypeInt16      = 5, ///< short
    EvoCodingTypeUInt16     = 6, ///< unsigned short
    EvoCodingTypeInt32      = 7, ///< int
    EvoCodingTypeUInt32     = 8, ///< unsigned int
    EvoCodingTypeInt64      = 9, ///< long long
    EvoCodingTypeUInt64     = 10, ///< unsigned long long
    EvoCodingTypeFloat      = 11, ///< float
    EvoCodingTypeDouble     = 12, ///< double
    EvoCodingTypeLongDouble = 13, ///< long double
    EvoCodingTypeObject     = 14, ///< id
    EvoCodingTypeClass      = 15, ///< Class
    EvoCodingTypeSEL        = 16, ///< SEL
    EvoCodingTypeBlock      = 17, ///< block
    EvoCodingTypePointer    = 18, ///< void*
    EvoCodingTypeStruct     = 19, ///< struct
    EvoCodingTypeUnion      = 20, ///< union
    EvoCodingTypeCString    = 21, ///< char*
    EvoCodingTypeCArray     = 22, ///< char[10] (for example)
    
    //修饰符
    EvoCodingTypeQualifierMask   = 0xFE0,  ///< mask of qualifier
    EvoCodingTypeQualifierConst  = 1 << 5, ///< const
    EvoCodingTypeQualifierIn     = 1 << 6, ///< in
    EvoCodingTypeQualifierInout  = 1 << 7, ///< inout
    EvoCodingTypeQualifierOut    = 1 << 8, ///< out
    EvoCodingTypeQualifierBycopy = 1 << 9, ///< bycopy
    EvoCodingTypeQualifierByref  = 1 << 10, ///< byref
    EvoCodingTypeQualifierOneway = 1 << 11, ///< oneway
    
    //属性
    EvoCodingTypePropertyMask         = 0x1FF000, ///< mask of property
    EvoCodingTypePropertyReadonly     = 1 << 12, ///< readonly
    EvoCodingTypePropertyCopy         = 1 << 13, ///< copy
    EvoCodingTypePropertyRetain       = 1 << 14, ///< retain
    EvoCodingTypePropertyNonatomic    = 1 << 15, ///< nonatomic
    EvoCodingTypePropertyWeak         = 1 << 16, ///< weak
    EvoCodingTypePropertyCustomGetter = 1 << 17, ///< getter=
    EvoCodingTypePropertyCustomSetter = 1 << 18, ///< setter=
    EvoCodingTypePropertyDynamic      = 1 << 19, ///< @dynamic
    EvoCodingTypePropertyGarbage      = 1 << 20,
};


EvoCodingType EvoEncodingGetType(const char *typeEncoding);


//实例变量信息  Ivar's information
@interface EvoIvarInfo : NSObject

@property (nonatomic, assign, readonly) Ivar ivar;
@property (nonatomic, strong, readonly) NSString *name;
@property (nonatomic, assign, readonly) ptrdiff_t offset;
@property (nonatomic, strong, readonly) NSString *typeEncoding;
@property (nonatomic, assign, readonly) EvoCodingType type;

- (instancetype)initWithIvar:(Ivar)ivar;

@end

//方法信息   Method's information
@interface EvoMethodInfo : NSObject

@property (nonatomic, assign, readonly) Method method;
@property (nonatomic, strong, readonly) NSString *name;
@property (nonatomic, assign, readonly) SEL sel;
@property (nonatomic, assign, readonly) IMP imp;
@property (nonatomic, strong, readonly) NSString *typeEncoding;
@property (nonatomic, strong, readonly) NSString *returnTypeEncoding;
@property (nonatomic, strong, readonly) NSArray *argumentTypeEncodings;

- (instancetype)initWithMethod:(Method)method;

@end

//属性信息   Property's information
@interface EvoPropertyInfo : NSObject

@property (nonatomic, assign, readonly) objc_property_t property;
@property (nonatomic, strong, readonly) NSString *name;
@property (nonatomic, assign, readonly) EvoCodingType type;
@property (nonatomic, strong, readonly) NSString *typeEncoding;
@property (nonatomic, strong, readonly) NSString *ivarName;
@property (nonatomic, assign, readonly) Class cls; //< may be nil
@property (nonatomic, strong, readonly) NSString *getter; //< getter (nonnull)
@property (nonatomic, strong, readonly) NSString *setter; //< setter (nonnull)

- (instancetype)initWithProperty:(objc_property_t)property;

@end

@interface EvoRuntime : NSObject

@property (nonatomic, assign, readonly) Class cls;
@property (nonatomic, assign, readonly) Class superCls;
@property (nonatomic, assign, readonly) Class metaCls;
@property (nonatomic, assign, readonly) BOOL isMeta;
@property (nonatomic, strong, readonly) NSString *name;

@property (nonatomic, strong, readonly)  EvoRuntime *superRuntime;

@property (nonatomic, strong, readonly) NSDictionary *ivarInfos;
@property (nonatomic, strong, readonly) NSDictionary *methodInfos;
@property (nonatomic, strong, readonly) NSDictionary *propertyInfos;


/**
 *  如果类中新增加了属性或者方法，可以调用此方法刷新缓存中类的相关信息
 */
- (void)setNeedUpdate;

/**
 *  根据给定的类来获取它的runtime信息
 *
 *  @param cls 给定的类
 *
 *  @return EvoRuntime
 */
+ (instancetype)runtimeInfoFromClass:(Class)cls;

+ (instancetype)runtimeInfoFromClassName:(NSString *)clsName;

@end
