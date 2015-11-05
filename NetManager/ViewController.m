//
//  ViewController.m
//  NetManager
//
//  Created by Robin on 11/3/15.
//  Copyright © 2015 Robin. All rights reserved.
//

#import "ViewController.h"
#import "UserModel.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}
- (IBAction)post:(id)sender {
    
    [UserModel loginWithMobile:@"18618321894" password:@"pppppp" superView:self.view success:^(UserModel *user, NSError *error) {
        NSLog(@"id: %@ \n  name: %@ \n sign: %@\n",user.userId,user.userName,user.sign);
    } failure:^(NSError *error) {
        NSLog(@"login error :  %@",error.debugDescription);
    }];
    
}
- (IBAction)get:(id)sender {
    
    [UserModel getUserInfo:@"5636dff1ef45bf0f5d000026" superView:self.view success:^(NSInteger statusCode, UserModel *user) {
        NSLog(@"id: %@ \n  name: %@ \n sign: %@\n",user.userId,user.userName,user.sign);
    } failure:^(NSError *error) {
        NSLog(@"get user info error :  %@",error.debugDescription);
    }];
    
}
- (IBAction)delete:(id)sender {
    [UserModel favourReview:@"55663e260c87cc7811006ab7" praise:YES callBack:^(NSInteger statusCode) {
        if (statusCode == 200) {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"提示" message:@"返回成功" delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
            [alertView show];
        }else{
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"提示" message:@"返回非200" delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
            [alertView show];
        }
    } failure:^(NSError *error) {
        NSLog(@"favour error :  %@",error.debugDescription);
    }];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
