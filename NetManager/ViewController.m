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
        
    } failure:^(NSError *error) {
        
    }];
    
}
- (IBAction)get:(id)sender {
    
    [UserModel getUserInfo:@"5636dff1ef45bf0f5d000026" superView:self.view success:^(NSInteger statusCode, UserModel *user) {
        
    } failure:^(NSError *error) {
        
    }];
    
}
- (IBAction)delete:(id)sender {
    [UserModel favourReview:@"55663e260c87cc7811006ab7" praise:YES callBack:^(NSInteger statusCode) {
        
    } failure:^(NSError *error) {
        
    }];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
