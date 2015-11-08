//
//  ViewController.m
//  NetManager
//
//  Created by Robin on 11/3/15.
//  Copyright © 2015 Robin. All rights reserved.
//

#import "ViewController.h"
#import "UserModel.h"
#import "KVStore.h"
#import "NSObject+Evo.h"

@interface ViewController ()

@property (nonatomic, strong) KVStore *store;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    
    self.store = [[KVStore alloc] init];
   
}


- (void)getData{
    KVStoreItem *item = [self.store getItemForKey:@"5636dff1ef45bf0f5d000026"];
    NSLog(@"%@",item.debugDescription);
}

- (void)saveUser:(UserModel *)user{
    
    user.sign = @"How to accurately avoid the unavailable time intervals of machines, ensure all jobs could process in a reasonable sequence, and meet the demand of every order, the significance of this problem is both in theory and practice. Firstly, according to the attribute of these unavailable time intervals, this paper divides the intervals into two kinds, deterministic and stochastic.如何及时准确的规避那些设备不可用的时间间隔，保障各工件加工的合理有序进行，从而可以更好的指导生产，满足各订单的要求。对这样问题的研究有着重要的理论和实践意义。首先，本文对所要研究的不可用时间间隔按其各自属性，将它们分为确定型时间间隔和随机型时间间隔。How to accurately avoid the unavailable time intervals of machines, ensure all jobs could process in a reasonable sequence, and meet the demand of every order, the significance of this problem is both in theory and practice. Firstly, according to the attribute of these unavailable time intervals, this paper divides the intervals into two kinds, deterministic and stochastic.如何及时准确的规避那些设备不可用的时间间隔，保障各工件加工的合理有序进行，从而可以更好的指导生产，满足各订单的要求。对这样问题的研究有着重要的理论和实践意义。首先，本文对所要研究的不可用时间间隔按其各自属性，将它们分为确定型时间间隔和随机型时间间隔。How to accurately avoid the unavailable time intervals of machines, ensure all jobs could process in a reasonable sequence, and meet the demand of every order, the significance of this problem is both in theory and practice. Firstly, according to the attribute of these unavailable time intervals, this paper divides the intervals into two kinds, deterministic and stochastic.如何及时准确的规避那些设备不可用的时间间隔，保障各工件加工的合理有序进行，从而可以更好的指导生产，满足各订单的要求。对这样问题的研究有着重要的理论和实践意义。首先，本文对所要研究的不可用时间间隔按其各自属性，将它们分为确定型时间间隔和随机型时间间隔。How to accurately avoid the unavailable time intervals of machines, ensure all jobs could process in a reasonable sequence, and meet the demand of every order, the significance of this problem is both in theory and practice. Firstly, according to the attribute of these unavailable time intervals, this paper divides the intervals into two kinds, deterministic and stochastic.如何及时准确的规避那些设备不可用的时间间隔，保障各工件加工的合理有序进行，从而可以更好的指导生产，满足各订单的要求。对这样问题的研究有着重要的理论和实践意义。首先，本文对所要研究的不可用时间间隔按其各自属性，将它们分为确定型时间间隔和随机型时间间隔。How to accurately avoid the unavailable time intervals of machines, ensure all jobs could process in a reasonable sequence, and meet the demand of every order, the significance of this problem is both in theory and practice. Firstly, according to the attribute of these unavailable time intervals, this paper divides the intervals into two kinds, deterministic and stochastic.如何及时准确的规避那些设备不可用的时间间隔，保障各工件加工的合理有序进行，从而可以更好的指导生产，满足各订单的要求。对这样问题的研究有着重要的理论和实践意义。首先，本文对所要研究的不可用时间间隔按其各自属性，将它们分为确定型时间间隔和随机型时间间隔。How to accurately avoid the unavailable time intervals of machines, ensure all jobs could process in a reasonable sequence, and meet the demand of every order, the significance of this problem is both in theory and practice. Firstly, according to the attribute of these unavailable time intervals, this paper divides the intervals into two kinds, deterministic and stochastic.如何及时准确的规避那些设备不可用的时间间隔，保障各工件加工的合理有序进行，从而可以更好的指导生产，满足各订单的要求。对这样问题的研究有着重要的理论和实践意义。首先，本文对所要研究的不可用时间间隔按其各自属性，将它们分为确定型时间间隔和随机型时间间隔。How to accurately avoid the unavailable time intervals of machines, ensure all jobs could process in a reasonable sequence, and meet the demand of every order, the significance of this problem is both in theory and practice. Firstly, according to the attribute of these unavailable time intervals, this paper divides the intervals into two kinds, deterministic and stochastic.如何及时准确的规避那些设备不可用的时间间隔，保障各工件加工的合理有序进行，从而可以更好的指导生产，满足各订单的要求。对这样问题的研究有着重要的理论和实践意义。首先，本文对所要研究的不可用时间间隔按其各自属性，将它们分为确定型时间间隔和随机型时间间隔。How to accurately avoid the unavailable time intervals of machines, ensure all jobs could process in a reasonable sequence, and meet the demand of every order, the significance of this problem is both in theory and practice. Firstly, according to the attribute of these unavailable time intervals, this paper divides the intervals into two kinds, deterministic and stochastic.如何及时准确的规避那些设备不可用的时间间隔，保障各工件加工的合理有序进行，从而可以更好的指导生产，满足各订单的要求。对这样问题的研究有着重要的理论和实践意义。首先，本文对所要研究的不可用时间间隔按其各自属性，将它们分为确定型时间间隔和随机型时间间隔。How to accurately avoid the unavailable time intervals of machines, ensure all jobs could process in a reasonable sequence, and meet the demand of every order, the significance of this problem is both in theory and practice. Firstly, according to the attribute of these unavailable time intervals, this paper divides the intervals into two kinds, deterministic and stochastic.如何及时准确的规避那些设备不可用的时间间隔，保障各工件加工的合理有序进行，从而可以更好的指导生产，满足各订单的要求。对这样问题的研究有着重要的理论和实践意义。首先，本文对所要研究的不可用时间间隔按其各自属性，将它们分为确定型时间间隔和随机型时间间隔。How to accurately avoid the unavailable time intervals of machines, ensure all jobs could process in a reasonable sequence, and meet the demand of every order, the significance of this problem is both in theory and practice. Firstly, according to the attribute of these unavailable time intervals, this paper divides the intervals into two kinds, deterministic and stochastic.如何及时准确的规避那些设备不可用的时间间隔，保障各工件加工的合理有序进行，从而可以更好的指导生产，满足各订单的要求。对这样问题的研究有着重要的理论和实践意义。首先，本文对所要研究的不可用时间间隔按其各自属性，将它们分为确定型时间间隔和随机型时间间隔。How to accurately avoid the unavailable time intervals of machines, ensure all jobs could process in a reasonable sequence, and meet the demand of every order, the significance of this problem is both in theory and practice. Firstly, according to the attribute of these unavailable time intervals, this paper divides the intervals into two kinds, deterministic and stochastic.如何及时准确的规避那些设备不可用的时间间隔，保障各工件加工的合理有序进行，从而可以更好的指导生产，满足各订单的要求。对这样问题的研究有着重要的理论和实践意义。首先，本文对所要研究的不可用时间间隔按其各自属性，将它们分为确定型时间间隔和随机型时间间隔。";
    
    
    
    NSTimeInterval begin, end, time;
    begin = CACurrentMediaTime();
     
    printf("Begin:   %8.2f\n", time * 1000);
    
    [self.store saveItemWithKey:user.userId value:[user toJSONData]];

    
    end = CACurrentMediaTime();
    time = end - begin;
    printf("finished:   %8.2f\n", time * 1000);
    
}


- (IBAction)post:(id)sender {
    
    [UserModel loginWithMobile:@"18618321894" password:@"pppppp" superView:self.view success:^(UserModel *user, NSError *error) {
        NSLog(@"id: %@ \n  name: %@ \n sign: %@\n",user.userId,user.userName,user.sign);
        [self saveUser:user];
    } failure:^(NSError *error) {
        NSLog(@"login error :  %@",error.debugDescription);
    }];
    
}
- (IBAction)get:(id)sender {
    
    [UserModel getUserInfo:@"5636dff1ef45bf0f5d000026" superView:self.view success:^(NSInteger statusCode, UserModel *user) {
        NSLog(@"id: %@ \n  name: %@ \n sign: %@\n",user.userId,user.userName,user.sign);
        [self saveUser:user];
    } failure:^(NSError *error) {
        NSLog(@"get user info error :  %@",error.debugDescription);
    }];
    
}
- (IBAction)delete:(id)sender {
    
    [self getData];
    
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
