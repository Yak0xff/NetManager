

#import <Foundation/Foundation.h>
#import <MBProgressHUD/MBProgressHUD.h>

@interface MessageTool : NSObject<MBProgressHUDDelegate> {
    MBProgressHUD *showMessage;
}
@property(nonatomic, strong) MBProgressHUD *showMessage;

+ (void)showMessage:(NSString *)message isError:(BOOL)yesOrNo;

+ (void)showMessage:(NSString *)message view:(UIView *)view isError:(BOOL)yesOrNo;

+ (MBProgressHUD *)showProcessMessage:(NSString *)message;

+ (MBProgressHUD *)showProcessMessage:(NSString *)message view:(UIView *)view;



@end
