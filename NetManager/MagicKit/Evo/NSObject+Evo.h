

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

- (void)modelEncodeWithCoder:(NSCoder *)aCoder;
- (id)modelInitWithCoder:(NSCoder *)aDecoder;

- (NSUInteger)hash;

// model判断是否相同
- (BOOL)IsEqualToModel:(id)model;


@end



@interface NSArray (Evo)

+ (NSArray *)modelArrayWithClass:(Class)cls json:(id)json;

@end



@interface NSDictionary (Evo)

+ (NSDictionary *)modelDictionaryWithClass:(Class)cls json:(id)json;

@end


@protocol Evo <NSObject>
@optional

/**
 Custom property mapper.
 
 @discussion If the key in JSON/Dictionary does not match to the model's property name,
 implements this method and returns the additional mapper.
 
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
 The generic class mapper for container properties.
 
 @discussion If the property is a container object, such as NSArray/NSSet/NSDictionary,
 implements this method and returns a property->class mapper, tells which kind of
 object will be add to the array/set/dictionary.
 
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
 All the properties in blacklist will be ignored in model transform process.
 Returns nil to ignore this feature.
 
 @return An array of property's name (Array<NSString>).
 */
+ (NSArray *)modelPropertyBlacklist;

/**
 If a property is not in the whitelist, it will be ignored in model transform process.
 Returns nil to ignore this feature.
 
 @return An array of property's name (Array<NSString>).
 */
+ (NSArray *)modelPropertyWhitelist;

/**
 If the default json-to-model transform does not fit to your model object, implement
 this method to do additional process. You can also use this method to validate the
 model's properties.
 
 @discussion If the model implements this method, it will be called at the end of
 `+modelWithJSON:`, `+modelWithDictionary:`, `-modelSetWithJSON:` and `-modelSetWithDictionary:`.
 If this method returns NO, the transform process will ignore this model.
 
 @param dic  The json/kv dictionary.
 
 @return Returns YES if the model is valid, or NO to ignore this model.
 */
- (BOOL)modelTransformFromDictionary:(NSDictionary *)dic;

/**
 If the default model-to-json transform does not fit to your model class, implement
 this method to do additional process. You can also use this method to validate the
 json dictionary.
 
 @discussion If the model implements this method, it will be called at the end of
 `-modelToJSONObject` and `-modelToJSONString`.
 If this method returns NO, the transform process will ignore this json dictionary.
 
 @param dic  The json dictionary.
 
 @return Returns YES if the model is valid, or NO to ignore this model.
 */
- (BOOL)modelTransformToDictionary:(NSMutableDictionary *)dic;

@end

