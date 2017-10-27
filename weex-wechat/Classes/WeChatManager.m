//
//  WeChatManager.m
//  WeexWeChat
//
//  Created by Doabit on 2017/10/25.
//  Copyright © 2017年 doabit. All rights reserved.
//

#import "WeChatManager.h"

#import <WXApi.h>

static int const MAX_THUMBNAIL_SIZE = 120;

@interface WeChatManager () <WXApiDelegate, UIAlertViewDelegate>

@property (nonatomic, copy) WXModuleCallback weChatCallBack;     // 微信结果回调js方法

@end

@implementation WeChatManager

#pragma mark - System Delegate & DataSource

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 1) {
        NSURL *url = [NSURL URLWithString:[WXApi getWXAppInstallUrl]];
        [[UIApplication sharedApplication] openURL:url];
    }
}


#pragma mark - Public Method

+ (instancetype)shareInstance
{
    static WeChatManager *_instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[WeChatManager alloc] init];
    });

    return _instance;
}


#pragma mark - Wechat Method

/* 检验是否安装了微信 */
- (BOOL)checkInstallWX
{
    BOOL install = [WXApi isWXAppInstalled];
    if (install) {
        return YES;
    } else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@""
                                                        message:@"需要安装微信进行操作"
                                                       delegate:self
                                              cancelButtonTitle:nil
                                              otherButtonTitles:@"取消",@"安装", nil];
        [alert show];
    }

    return NO;
}

- (void)login:(NSDictionary *)options callback:(WXModuleCallback)callback
{
    if (!self.checkInstallWX) {
        return;
    }

    self.weChatCallBack = callback;
    SendAuthReq* req = [[SendAuthReq alloc] init];

    if ([options objectForKey:@"scene"]) {
        req.scope = [options objectForKey:@"scene"];
    } else {
        req.scope = @"snsapi_userinfo";
    }

    if ([options objectForKey:@"state"]) {
        req.state = [options objectForKey:@"state"];
    }
    if ([WXApi sendReq:req]) {
       NSLog(@"login success");
    }else {
       NSLog(@"login fail");
    }
}

- (void)initWXAPI:(NSString *)appId {
    self.appid = appId;
    [WXApi registerApp: appId];
}

- (void)registerApp:(NSString *)appId callback:(WXModuleCallback)callback {
    [self initWXAPI: appId];

    callback(@{@"result":@"success"});
}

- (void)pay:(NSDictionary *)options callback:(WXModuleCallback)callback {

    if (!self.checkInstallWX) {
        return;
    }

    self.weChatCallBack = callback;

    NSArray *requiredParams;

    if ([options objectForKey:@"mch_id"]) {
        requiredParams = @[@"mch_id", @"prepay_id", @"timestamp", @"nonce", @"sign"];
    } else {
        requiredParams = @[@"partnerid", @"prepayid", @"timestamp", @"noncestr", @"sign"];
    }

    for (NSString *key in requiredParams) {
        if (![options objectForKey:key]) {
            callback(@{@"msg":@"参数格式错误", @"resCode":@"-2"});
            return;
        }
    }

    PayReq *req = [[PayReq alloc] init];

    req.partnerId = [options objectForKey:requiredParams[0]];
    req.prepayId = [options objectForKey:requiredParams[1]];
    req.timeStamp = [[options objectForKey:requiredParams[2]] intValue];
    req.nonceStr = [options objectForKey:requiredParams[3]];
    req.package = @"Sign=WXPay";
    req.sign = [options objectForKey:requiredParams[4]];

    if ([WXApi sendReq:req]) {
    } else {
        callback(@{@"msg":@"发送请求失败", @"resCode":@"-2"});
    }
}

- (void)share:(NSDictionary *)options scene:(int)scene callback:(WXModuleCallback)callback {
    self.weChatCallBack = callback;
    // if not installed
    if (![WXApi isWXAppInstalled]) {
        callback(@{@"msg":@"微信未安装", @"resCode":@"-2"});
        return;
    }

    SendMessageToWXReq* req = [[SendMessageToWXReq alloc] init];

    req.scene = scene;

    // message or text
    NSDictionary *message = options;
    NSString *type = [options objectForKey:@"type"];
    BOOL isText = [type isEqualToString:@"text"];
    if (isText) {
        req.bText = YES;
        req.text = [options objectForKey:@"content"];

        if (![WXApi sendReq:req]) {
            callback(@{@"msg":@"发送请求失败", @"resCode":@"-2"});
        }

    } else {
        req.bText = NO;

        req.message = [self buildSharingMessage:message];
        if (![WXApi sendReq:req]) {
            callback(@{@"msg":@"发送请求失败", @"resCode":@"-2"});
        }
    }
}


#pragma mark - Wechat Method

-(void) onResp:(BaseResp*)resp{
    NSLog(@"resp %d",resp.errCode);
    /*
     enum  WXErrCode {
     WXSuccess           = 0,    成功
     WXErrCodeCommon     = -1,  普通错误类型
     WXErrCodeUserCancel = -2,    用户点击取消并返回
     WXErrCodeSentFail   = -3,   发送失败
     WXErrCodeAuthDeny   = -4,    授权失败
     WXErrCodeUnsupport  = -5,   微信不支持
     };
     */
    if ([resp isKindOfClass:[SendAuthResp class]]) {   //授权登录的类。
        if (resp.errCode == 0) {  //成功。
            SendAuthResp *resp2 = (SendAuthResp *)resp;
            NSLog(@"返回的CODE：%@", resp2.code);
            NSString *errCode = [NSString stringWithFormat:@"%d", resp2.errCode];
            if (self.weChatCallBack) {
                NSDictionary *result = @{@"resCode": errCode, @"msg": @"授权登陆成功", @"code": resp2.code};
                self.weChatCallBack(result);
                self.weChatCallBack = nil;
            }
        }
    } else if([resp isKindOfClass:[PayResp class]]){
        //支付返回结果，实际支付结果需要微信服务器端查询
        NSString *strMsg = [NSString stringWithFormat:@"支付结果"];
        NSString *errCode = @"";
        NSMutableDictionary *body = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                     strMsg,@"msg",
                                     errCode,@"resCode", nil];
        switch (resp.errCode) {
            case WXSuccess:
                errCode = [NSString stringWithFormat:@"%d",resp.errCode];
                strMsg = @"支付结果：成功！";
                body[@"msg"] = strMsg;
                body[@"resCode"] = errCode;
                NSLog(@"支付成功，retcode = %d", resp.errCode);
                break;

            default:
                errCode = [NSString stringWithFormat:@"%d",resp.errCode];
                body[@"msg"] = resp.errStr;
                body[@"resCode"] = errCode;
                NSLog(@"错误，retcode = %d, retstr = %@", resp.errCode,resp.errStr);
                NSLog(@"error %@",resp.errStr);
                break;
        }
        if (self.weChatCallBack) {
            self.weChatCallBack(body);
            self.weChatCallBack = nil;
        }
    } else if ([resp isKindOfClass:[SendMessageToWXResp class]]){
        SendMessageToWXResp *resp2 = (SendMessageToWXResp *)resp;
        NSLog(@"分享的返回");

        NSString *errCode = [NSString stringWithFormat:@"%d", resp2.errCode];
        if (self.weChatCallBack) {
            NSDictionary *result = @{@"resCode": errCode, @"msg": @"分享成功"};
            self.weChatCallBack(result);
            self.weChatCallBack = nil;
        }
    } else { //失败
        NSLog(@"error %@",resp.errStr);
        UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"失败"
                                                       message:[NSString stringWithFormat:@"reason : %@",resp.errStr]
                                                      delegate:nil
                                             cancelButtonTitle:@"取消"
                                             otherButtonTitles:@"确定", nil, nil];
        [alert show];

    }
}


#pragma mark "Private methods"

- (WXMediaMessage *)buildSharingMessage:(NSDictionary *)message
{
    WXMediaMessage *wxMediaMessage = [WXMediaMessage message];
    wxMediaMessage.title = [message objectForKey:@"title"];
    wxMediaMessage.description = [message objectForKey:@"description"];
    wxMediaMessage.mediaTagName = [message objectForKey:@"mediaTagName"];
    wxMediaMessage.messageExt = [message objectForKey:@"messageExt"];
    wxMediaMessage.messageAction = [message objectForKey:@"messageAction"];
    if ([message objectForKey:@"image"])
    {
        [wxMediaMessage setThumbImage:[self getUIImageFromURL:[message objectForKey:@"image"]]];
    }

    id mediaObject = nil;
    NSDictionary *media = message;

    NSString *type = [media objectForKey:@"type"];
    NSArray *types = @[@"app", @"emotion", @"file", @"image", @"music", @"video", @"webpage"];
    int typeIndex = (int)[types indexOfObject:type];

    switch (typeIndex)
    {
        case 0:
            mediaObject = [WXAppExtendObject object];
            ((WXAppExtendObject*)mediaObject).extInfo = [media objectForKey:@"extInfo"];
            ((WXAppExtendObject*)mediaObject).url = [media objectForKey:@"url"];
            break;

        case 1:
            mediaObject = [WXEmoticonObject object];
            ((WXEmoticonObject*)mediaObject).emoticonData = [self getNSDataFromURL:[media objectForKey:@"emotion"]];
            break;

        case 2:
            mediaObject = [WXFileObject object];
            ((WXFileObject*)mediaObject).fileData = [self getNSDataFromURL:[media objectForKey:@"file"]];
            ((WXFileObject*)mediaObject).fileExtension = [media objectForKey:@"fileExtension"];
            break;

        case 3:
            mediaObject = [WXImageObject object];
            ((WXImageObject*)mediaObject).imageData = [self getNSDataFromURL:[media objectForKey:@"image"]];
            break;

        case 4:
            mediaObject = [WXMusicObject object];
            ((WXMusicObject*)mediaObject).musicUrl = [media objectForKey:@"url"];
            ((WXMusicObject*)mediaObject).musicDataUrl = [media objectForKey:@"url"];
            break;

        case 5:
            mediaObject = [WXVideoObject object];
            ((WXVideoObject*)mediaObject).videoUrl = [media objectForKey:@"url"];
            break;
        default:
            mediaObject = [WXWebpageObject object];
            ((WXWebpageObject *)mediaObject).webpageUrl = [media objectForKey:@"url"];
    }

    wxMediaMessage.mediaObject = mediaObject;
    return wxMediaMessage;
}

- (NSData *)getNSDataFromURL:(NSString *)url
{
    NSData *data = nil;

    if ([url hasPrefix:@"http://"] || [url hasPrefix:@"https://"])
    {
        data = [NSData dataWithContentsOfURL:[NSURL URLWithString:url]];
    }
    else if ([url hasPrefix:@"data:image"])
    {
        // a base 64 string
        NSURL *base64URL = [NSURL URLWithString:url];
        data = [NSData dataWithContentsOfURL:base64URL];
    }
    else if ([url rangeOfString:@"temp:"].length != 0)
    {
        url =  [NSTemporaryDirectory() stringByAppendingPathComponent:[url componentsSeparatedByString:@"temp:"][1]];
        data = [NSData dataWithContentsOfFile:url];
    }
    else
    {
        // local file
        url = [[NSBundle mainBundle] pathForResource:[url stringByDeletingPathExtension] ofType:[url pathExtension]];
        data = [NSData dataWithContentsOfFile:url];
    }

    return data;
}

- (UIImage *)getUIImageFromURL:(NSString *)url
{
    NSData *data = [self getNSDataFromURL:url];
    UIImage *image = [UIImage imageWithData:data];

    if (image.size.width > MAX_THUMBNAIL_SIZE || image.size.height > MAX_THUMBNAIL_SIZE)
    {
        CGFloat width = 0;
        CGFloat height = 0;

        // calculate size
        if (image.size.width > image.size.height)
        {
            width = MAX_THUMBNAIL_SIZE;
            height = width * image.size.height / image.size.width;
        }
        else
        {
            height = MAX_THUMBNAIL_SIZE;
            width = height * image.size.width / image.size.height;
        }

        // scale it
        UIGraphicsBeginImageContext(CGSizeMake(width, height));
        [image drawInRect:CGRectMake(0, 0, width, height)];
        UIImage *scaled = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        return scaled;
    }

    return image;
}

@end
