

#import <Foundation/Foundation.h>

@interface NSObject (Evo)

/**
 *  json转换为model
 *
 *  @param json NSDictionary、NSString、NSData
 *
 *  @return model
 */
+ (instancetype)modelFromJSON:(id)json;
+ (instancetype)modelFromDictionary:(NSDictionary *)dictionary;

/**
 *  检查json数据是否合法
 *
 *  @param json
 *
 *  @return
 */
- (BOOL)modelSetWithJSON:(id)json;
- (BOOL)modelSetWithDictionary:(NSDictionary *)dictionary;

/**
 *  Model 转 JSON 对象
 *
 *  @return JSONObject
 */
- (id)toJSONObject;
- (id)toJSONData;
- (id)toJSONString;


- (id)modelCopy;

// 序列化使用
- (void)modelEncodeWithCoder:(NSCoder *)aCoder;
- (id)modelInitWithCoder:(NSCoder *)aDecoder;

// Object  hash编码
- (NSUInteger)evoHash;

// model判断是否相同
- (BOOL)isEqualToModel:(id)model;


@end



@interface NSArray (Evo)

/**
 *  JSON 转为model数组
 *
 *  @param cls  model类
 *  @param json 接送
 *
 *  @return model数组
 */
+ (NSArray *)modelArrayWithClass:(Class)cls json:(id)json;

@end



@interface NSDictionary (Evo)
/**
 *  JSON 转为字典
 *
 *  @param cls  model类
 *  @param json 接送
 *
 *  @return model字典
 */
+ (NSDictionary *)modelDictionaryWithClass:(Class)cls json:(id)json;

@end


@protocol Evo <NSObject>
@optional

/**
 自定义属性对应字典
 
 @discussion 如果model类中定义的属性和json返回数据中的属性不一致，需要重写此方法来指定对应关系，否则可以不重写
 
 Example:
 
 json:
 {
 "n":"Harry Pottery",
 "p": 256,
 "ext" : {
 "desc" : "A book written by J.K.Rowing."
 }
 }
 
 model:
 @interface Book : NSObject
 @property NSString *name;
 @property NSInteger page;
 @property NSString *desc;
 @end
 
 @implementation Book
 + (NSDictionary *)modelPropertyMapper {
 return @{@"name" : @"n",
 @"page" : @"p",
 @"desc" : @"ext.desc"};
 }
 @end
 
 @return A custom mapper for properties.
 */
+ (NSDictionary *)modelPropertyMapper;

/**
    如果model类中包含有集合类型的属性，需要重写此方法，指定集合类型中的数据类型和json数据中属性的对应关系，否则不重写
 
 @discussion 当model中的集合类型中不包含其他model的时候，不能重写此方法
 
 Example:
 @class YYShadow, YYBorder, YYAttachment;
 
 @interface YYAttributes
 @property NSString *name;
 @property NSArray *shadows;
 @property NSSet *borders;
 @property NSDictionary *attachments;
 @end
 
 @implementation YYAttributes
 + (NSDictionary *)modelContainerPropertyGenericClass {
 return @{@"shadows" : [YYShadow class],
 @"borders" : YYBorder.class,
 @"attachments" : @"YYAttachment" };
 }
 @end
 
 @return A class mapper.
 */
+ (NSDictionary *)modelContainerPropertyGenericClass;

/**
当需要忽略json中的某些字段的时候，可以重写此方法，将需要忽略的字段加入黑名单中
 
 @return An array of property's name (Array<NSString>).
 */
+ (NSArray *)modelPropertyBlacklist;

/**
对应黑名单，这里是白名单
 
 @return An array of property's name (Array<NSString>).
 */
+ (NSArray *)modelPropertyWhitelist;

/**
如果model中的某些属性和json中的数据类型不一致的时候，需要重写此方法，进行类型转换，例如： NSNumber  ->  NSDate
 
 @discussion If the model implements this method, it will be called at the end of
 `+modelWithJSON:`, `+modelWithDictionary:`, `-modelSetWithJSON:` and `-modelSetWithDictionary:`.
 If this method returns NO, the transform process will ignore this model.
 
 @param dic  The json/kv dictionary.
 
 @return Returns YES if the model is valid, or NO to ignore this model.
 */
- (BOOL)modelTransformFromDictionary:(NSDictionary *)dic;

/**
和modelTransformFromDictionary方法相反
 
 @discussion If the model implements this method, it will be called at the end of
 `-modelToJSONObject` and `-modelToJSONString`.
 If this method returns NO, the transform process will ignore this json dictionary.
 
 @param dic  The json dictionary.
 
 @return Returns YES if the model is valid, or NO to ignore this model.
 */
- (BOOL)modelTransformToDictionary:(NSMutableDictionary *)dic;

@end

