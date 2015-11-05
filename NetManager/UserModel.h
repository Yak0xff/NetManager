

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface UserModel : NSObject<NSCoding>

@property (nonatomic, strong) NSString *userId;
@property (nonatomic, strong) NSString *userName;
@property (nonatomic, strong) NSString *sign;


+ (void)loginWithMobile:(NSString *)mobile
               password:(NSString *)password
              superView:(UIView *)superView
                success:(void (^)(UserModel *user, NSError *error))success
                failure:(void (^)(NSError *error))failure;


+ (void)getUserInfo:(NSString *)uid
          superView:(UIView *)superView
            success:(void (^)(NSInteger statusCode, UserModel *user))success
            failure:(void (^)(NSError *error))failure;


+ (void)favourReview:(NSString *)rid
              praise:(BOOL)praise
            callBack:(void (^)(NSInteger statusCode))success
             failure:(void (^)(NSError *error))failure;


@end
