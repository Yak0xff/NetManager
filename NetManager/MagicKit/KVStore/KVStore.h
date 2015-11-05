 

#import <Foundation/Foundation.h>


/**
 *  创建此类的目的是为了统一管理存储数据和meta数据
 */

@interface KVStoreItem : NSObject

@property (nonatomic, strong) NSString *key; //键
@property (nonatomic, strong) NSData *value; //值
@property (nonatomic, strong) NSString *fileName; //文件存储时的文件名
@property (nonatomic, assign) NSUInteger size; //所存储数据的大小
@property (nonatomic, assign) NSUInteger modTime; // 修改时的时间戳
@property (nonatomic, assign) NSUInteger accessTime; // 最后一次访问的时间戳（淘汰算法使用标记）
@property (nonatomic, strong) NSData *extentionData; //可能存在的其他扩展数据

@end


//数据存储格式
typedef NS_ENUM(NSUInteger, KVStoreType) {
    KVStoreTypeFile = 0,  //KVStoreItem的fileName不可为空
    KVStoreTypeSQLite = 1, //KVStoreItem的fileName将被忽略
    KVStoreTypeMixed = 2 //如果KVStoreItem的fileName不为空，则存文件，否则存SQLite
};

@interface KVStore : NSObject

//当前数据存储位置、类型获取
@property (nonatomic, readonly) NSString *path;
@property (nonatomic, readonly) KVStoreType type;

//是否打印错误日志
@property (nonatomic, assign) BOOL errorLogsEnabled;

////KVStore  初始化方法
- (instancetype)init;  //使用默认的存储路径和类型 ：  默认路径： Documents目录下，默认类型： KVStoreTypeSQLite

//自定义存储路径和类型
- (instancetype)initWithPath:(NSString *)path storeType:(KVStoreType)type; //指定初始化方法



//*************当前数据状态方法********************
// 判断指定key的item是否存在
- (BOOL)itemExistsForKey:(NSString *)key;

// 当前存储item的数量
- (NSUInteger)getItemsCount;

// 当前存储item的总大小
- (NSUInteger)getItemsSize;

//*************数据存储方法********************

- (BOOL)saveItem:(KVStoreItem *)item;

//指定key和value存储
// @Warning   此方法只能使用在存储类型为SQLite时使用，其他类型时，则永远失败
//
- (BOOL)saveItemWithKey:(NSString *)key value:(NSData *)value;

//指定key和value存储，并可指定文件名或者扩展数据
- (BOOL)saveItemWithKey:(NSString *)key value:(NSData *)value fileName:(NSString *)fileName extentionData:(NSData *)exData;



//*************数据移除方法********************

// 根据指定的key移除对应的item
- (BOOL)removeItemWithKey:(NSString *)key;

// 根据一组key值移除相对应的一组item
// @Warning   使用此方法的时候，keys数组中必须保存为非字符串类型
//
- (BOOL)removeItemWithKeys:(NSArray *)keys;

// 当文件大小大于某个大小得时候，移除所有存储的item
- (BOOL)removeItemsWhenLargerThanSize:(NSUInteger)size;

// 当存储时间大于某个时间点的时候，移除给定时间点之前的所有item
- (BOOL)removeItemsWhenEarlierThanTime:(NSUInteger)time;

// 当所有存储数据的大小到达指定的大小时，根据淘汰算法，移除相应的item
- (BOOL)removeItemsToFitSize:(NSUInteger)size;

// 当存储的item数量到达指定的个数时，根据淘汰算法，移除相应的item
- (BOOL)removeItemsToFitCount:(NSUInteger)maxCount;

// 移除所有存储的item
- (BOOL)removeAllItems;

// 带有进度的移除方法
- (void)removeAllItemsWithProgress:(void(^)(NSUInteger removedCount, NSUInteger totalCount))progress finished:(void(^)(BOOL error))finished;



//*************数据获取方法********************

// 根据指定key，取出对应的item
- (KVStoreItem *)getItemForKey:(NSString *)key;

// 根据指定key，取出对应item的value
- (NSData *)getItemValueForKey:(NSString *)key;

// 根据指定的一组key，取出对应的一组item
// @Warning   使用此方法的时候，keys数组中必须保存为非字符串类型
//
- (NSArray *)getItemsForKeys:(NSArray *)keys;

// 根据指定的一组key，取出对应的一组value （字典中数据格式为：key:value）
// @Warning   使用此方法的时候，keys数组中必须保存为非字符串类型
//
- (NSDictionary *)getItemValueForKeys:(NSArray *)keys;



@end
