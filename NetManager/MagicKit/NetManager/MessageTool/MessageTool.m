

#import "MessageTool.h"


@interface MessageTool ()
+ (MessageTool *)shareInstance;

- (void)buildProcessMessage:(NSString *)message;

- (void)buildProcessMessage:(NSString *)message view:(UIView *)view;

- (void)buildMessage:(NSString *)message isError:(BOOL)yesOrNo;

- (void)buildMessage:(NSString *)message view:(UIView *)view isError:(BOOL)yesOrNo;
@end


@implementation MessageTool

@synthesize showMessage;

+ (MessageTool *)shareInstance {
    static MessageTool *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[MessageTool alloc] init];
    });
    
    return sharedInstance;
    
}

- (void)showDuration {
    [showMessage hide:YES afterDelay:1.46f];
    
}

- (void)buildMessage:(NSString *)message view:(UIView *)view isError:(BOOL)yesOrNo {
    [showMessage removeFromSuperview];
    showMessage = [[MBProgressHUD alloc] initWithView:view];
    showMessage.labelFont = [UIFont systemFontOfSize:16];
    
    if (!yesOrNo)
        [showMessage setCustomView:[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"success.png"]]];
    else
        [showMessage setCustomView:[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"error.png"]]];
    [showMessage setMode:MBProgressHUDModeCustomView];
    [view addSubview:showMessage];
    showMessage.labelText = message;
    [showMessage show:YES];
    [self performSelectorOnMainThread:@selector(showDuration) withObject:nil waitUntilDone:YES];
}

- (void)buildMessage:(NSString *)message isError:(BOOL)yesOrNo {
    [showMessage removeFromSuperview];
    showMessage = [[MBProgressHUD alloc] initWithView:[self getTopLevelWindow]];
    showMessage.labelFont = [UIFont systemFontOfSize:16];
    
    if (!yesOrNo)
        [showMessage setCustomView:[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"success.png"]]];
    else
        [showMessage setCustomView:[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"error.png"]]];
    [showMessage setMode:MBProgressHUDModeCustomView];
    
    [[self getTopLevelWindow] addSubview:showMessage];
    showMessage.labelText = message;
    [showMessage show:YES];
    [self performSelectorOnMainThread:@selector(showDuration) withObject:nil waitUntilDone:YES];
}

- (UIWindow *)getTopLevelWindow {
    UIWindow *window = nil;
    for (UIWindow *_window in [[UIApplication sharedApplication] windows]) {
        if (window == nil) {
            window = _window;
        }
        if (_window.windowLevel > window.windowLevel) {
            window = _window;
        }
    }
    
    return window;
}

- (void)buildProcessMessage:(NSString *)message {
    [showMessage removeFromSuperview];
    showMessage = [[MBProgressHUD alloc] initWithView:[self getTopLevelWindow]];
    [[self getTopLevelWindow] addSubview:showMessage];
    showMessage.labelText = message;
    [showMessage show:YES];
}

- (void)buildProcessMessage:(NSString *)message view:(UIView *)view {
    [showMessage removeFromSuperview];
    showMessage = [[MBProgressHUD alloc] initWithView:view];
    [view addSubview:showMessage];
    showMessage.labelText = message;
    [showMessage show:YES];
}

+ (void)showMessage:(NSString *)message view:(UIView *)view isError:(BOOL)yesOrNo {
    MessageTool *sharedInstance = [MessageTool shareInstance];
    [sharedInstance buildMessage:message view:view isError:yesOrNo];
}

+ (void)showMessage:(NSString *)message isError:(BOOL)yesOrNo {
    MessageTool *sharedInstance = [MessageTool shareInstance];
    [sharedInstance buildMessage:message isError:yesOrNo];
}

+ (MBProgressHUD *)showProcessMessage:(NSString *)message {
    MessageTool *sharedInstance = [MessageTool shareInstance];
    [sharedInstance buildProcessMessage:message];
    return sharedInstance.showMessage;
}

+ (MBProgressHUD *)showProcessMessage:(NSString *)message view:(UIView *)view {
    MessageTool *sharedInstance = [MessageTool shareInstance];
    [sharedInstance buildProcessMessage:message view:view];
    return sharedInstance.showMessage;
}

@end
