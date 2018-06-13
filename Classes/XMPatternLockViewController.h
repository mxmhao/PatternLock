//
//  PatternLockViewController.h
//  TMASHttp(iphone)
//
//  Created by TWM01 on 2017/10/31.
//  Copyright © 2017年 noontec. All rights reserved.
//
//  手势锁

#import <UIKit/UIKit.h>

typedef NS_ENUM(short, PatternLockMode) {//控制器的用途
    PatternLockModeCheck = 0,       //检查密码
    PatternLockModeSet   = 1        //设置密码
};

@class XMPatternLockViewController;

@protocol XMPatternLockDelegate<NSObject>
@optional
//已经得到密码，PatternLockModeSet模式下要实现
- (void)patternLockViewController:(XMPatternLockViewController *)vc completeGetPassword:(NSInteger)password;
//密码检查正确，PatternLockModeSet模式下要实现
- (void)patternLockViewControllerDidCheckCorrect:(XMPatternLockViewController *)vc;
//忘记密码
- (void)patternLockViewControllerForgotPassword:(XMPatternLockViewController *)vc;
//密码频繁出错
- (void)patternLockViewControllerErrorFrequently:(XMPatternLockViewController *)vc;
@end

@interface XMPatternLockViewController : UIViewController

@property (nonatomic, assign) NSInteger rightPassword;//要匹配的正确手势密码
@property (nonatomic, assign) NSString *rightUserPassword;//用户登录密码
@property (nonatomic, weak) id<XMPatternLockDelegate> delegate;
@property (nonatomic, assign, readonly) PatternLockMode mode;

- (instancetype)initWithMode:(PatternLockMode)mode NS_DESIGNATED_INITIALIZER;

@end
