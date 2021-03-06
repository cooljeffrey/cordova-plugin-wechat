//
//  CDVWechat.h
//  cordova-plugin-wechat
//
//  Created by xu.li on 12/23/13.
//
//

#import <Cordova/CDV.h>
#import "WXApi.h"
#import "WXApiObject.h"
#import <AssetsLibrary/ALAssetsLibrary.h>
#import <AssetsLibrary/ALAssetRepresentation.h>

enum  CDVWechatSharingType {
    CDVWXSharingTypeApp = 1,
    CDVWXSharingTypeEmotion,
    CDVWXSharingTypeFile,
    CDVWXSharingTypeImage,
    CDVWXSharingTypeMusic,
    CDVWXSharingTypeVideo,
    CDVWXSharingTypeWebPage
};

@interface CDVWechat:CDVPlugin <WXApiDelegate>

@property (nonatomic, strong) NSString *currentCallbackId;
@property (nonatomic, strong) NSString *wechatAppId;

- (void)isWXAppInstalled:(CDVInvokedUrlCommand *)command;
- (void)share:(CDVInvokedUrlCommand *)command;
- (void)sendAuthRequest:(CDVInvokedUrlCommand *)command;
- (void)registerApp:(NSString *)wechatAppId;

@end
