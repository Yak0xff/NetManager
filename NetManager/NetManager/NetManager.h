 

#import "AFHTTPSessionManager.h"


typedef NS_ENUM (NSInteger, ReqeustMethod){
    GET,
    POST,
    DELETE,
    UPLOAD,
    DOWNLOAD
};

@interface NetManager : AFHTTPSessionManager


// dispatch once
+ (instancetype)sharedInstance;

- (void)startRequest:(NSString *)URLString
          parameters:(NSDictionary *)parameters
             success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
             failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure;

@end
