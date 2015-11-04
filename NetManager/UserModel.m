 

#import "UserModel.h"
#import "NetManager-Swift.h"

@implementation UserModel


+ (void)loginWithMobile:(NSString *)mobile
               password:(NSString *)password
              superView:(UIView *)superView
                success:(void (^)(UserModel *user, NSError *error))success
                failure:(void (^)(NSError *error))failure{
    
    
    [[APIManager manager] loginWithMobile:mobile password:password superView:superView callBack:^(NSInteger statusCode, id responseObject) {
        if (statusCode != 200) {
            failure(nil);
        }else{
            success(responseObject,nil);
        }
    }];
}


+ (void)getUserInfo:(NSString *)uid
          superView:(UIView *)superView
            success:(void (^)(NSInteger statusCode, UserModel *user))success
            failure:(void (^)(NSError *error))failure{
    
    [[APIManager manager] getUserInfo:uid superView:superView callBack:^(NSInteger statusCode, id responseObject) {
        if (statusCode != 200) {
            failure(nil);
        }else{
            success(statusCode,responseObject);
        }
    }];
}

+ (void)favourReview:(NSString *)rid
              praise:(BOOL)praise
            callBack:(void (^)(NSInteger statusCode))success
             failure:(void (^)(NSError *error))failure{
    [[APIManager manager] favourReview:rid praise:praise callBack:^(NSInteger statusCode) {
        if (statusCode != 200) {
            failure(nil);
        }else{
            success(statusCode);
        }
    }];
}

@end
