 

#import "UserModel.h"
#import "NetManager-Swift.h"

#import "NSObject+Evo.h"

@implementation UserModel


+ (NSDictionary *)modelPropertyMapper{
    return @{
             @"userId" : @"id",
             @"userName" : @"name"
             };
}


- (void)encodeWithCoder:(NSCoder *)aCoder{
    [self modelEncodeWithCoder:aCoder];
}

- (id)initWithCoder:(NSCoder *)aDecoder{
    return [self modelInitWithCoder:aDecoder];
}
 

+ (void)loginWithMobile:(NSString *)mobile
               password:(NSString *)password
              superView:(UIView *)superView
                success:(void (^)(UserModel *user, NSError *error))success
                failure:(void (^)(NSError *error))failure{
    
    
    [[APIManager manager] loginWithMobile:mobile password:password superView:superView callBack:^(NSInteger statusCode, id responseObject) {
        if (statusCode != 200) {
            failure(nil);
        }else{
            
            
            NSString *Json_path=[[NSBundle mainBundle] pathForResource:@"json" ofType:@"json"];
            NSData *data=[NSData dataWithContentsOfFile:Json_path];
            
            id JsonObject=[NSJSONSerialization JSONObjectWithData:data
                                                          options:NSJSONReadingAllowFragments
                                                            error:nil];
            
            UserModel *user = [UserModel modelFromJSON:JsonObject];
            success(user,nil);
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
            UserModel *user = [UserModel modelFromJSON:responseObject];
            success(statusCode,user);
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
