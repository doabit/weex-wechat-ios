//
//  WeChatManager.h
//  WeexWeChat
//
//  Created by Doabit on 2017/10/25.
//  Copyright © 2017年 doabit. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WeexSDK/WeexSDK.h>
#import <WechatOpenSDK/WXApi.h>

@interface WeChatManager : NSObject<WXApiDelegate>

+ (instancetype)shareInstance;

/* 调用微信 */

- (void)registerApp:(NSString *)appid callback:(WXModuleCallback)callback;

- (void)login:(NSDictionary *)options callback:(WXModuleCallback)callback;

- (void)pay:(NSDictionary *)options callback:(WXModuleCallback)callback;

- (void)share:(NSDictionary *)options scene:(int)scene callback:(WXModuleCallback)callback;

- (BOOL) checkInstallWX;

@property (nonatomic, strong) NSString *appid;

@end
