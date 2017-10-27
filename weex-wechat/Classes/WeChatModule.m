//
//  WeChatModule.m
//  WeexWeChat
//
//  Created by Doabit on 2017/10/25.
//  Copyright © 2017年 doabit. All rights reserved.
//

#import "WeChatModule.h"
#import "WeChatManager.h"

@implementation WeChatModule

@synthesize weexInstance;

WX_EXPORT_METHOD(@selector(registerApp:callback:))
WX_EXPORT_METHOD(@selector(login:callback:))
WX_EXPORT_METHOD(@selector(pay:callback:))
WX_EXPORT_METHOD(@selector(shareToSession:callback:))
WX_EXPORT_METHOD(@selector(shareToTimeLine:callback:))

- (void)registerApp:(NSString *)appid callback:(WXModuleCallback)callback
{
    [[WeChatManager shareInstance] registerApp:appid callback:callback];
}

- (void)login:(NSDictionary *)options callback:(WXModuleCallback)callback
{
    [[WeChatManager shareInstance] login:options callback:callback];
}

- (void)pay:(NSDictionary *)options callback:(WXModuleCallback)callback {
     [[WeChatManager shareInstance] pay:options callback:callback];
}

- (void)shareToSession:(NSDictionary *)options callback:(WXModuleCallback)callback {
    [[WeChatManager shareInstance] share:options scene:WXSceneSession callback:callback];
}

- (void)shareToTimeLine:(NSDictionary *)options callback:(WXModuleCallback)callback {
    [[WeChatManager shareInstance] share:options scene:WXSceneTimeline callback:callback];
}
@end
