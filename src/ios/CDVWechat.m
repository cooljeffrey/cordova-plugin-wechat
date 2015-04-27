//
//  CDVWechat.m
//  cordova-plugin-wechat
//
//  Created by xu.li on 12/23/13.
//
//

#import "CDVWechat.h"
#import "CDVFile.h"


@implementation CDVWechat

#pragma mark "API"

- (void)isWXAppInstalled:(CDVInvokedUrlCommand *)command
{
    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:[WXApi isWXAppInstalled]];
    
    [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
}

- (void)share:(CDVInvokedUrlCommand *)command
{
    // if not installed
    if (![WXApi isWXAppInstalled])
    {
        [self failWithCallbackID:command.callbackId withMessage:@"未安装微信"];
        return ;
    }

    // check arguments
    NSDictionary *params = [command.arguments objectAtIndex:0];
    if (!params)
    {
        [self failWithCallbackID:command.callbackId withMessage:@"参数格式错误"];
        return ;
    }
    
    // save the callback id
    self.currentCallbackId = command.callbackId;
    
    SendMessageToWXReq* req = [[SendMessageToWXReq alloc] init];
    
    // check the scene
    if ([params objectForKey:@"scene"])
    {
        req.scene = (int)[[params objectForKey:@"scene"] integerValue];
    }
    else
    {
        req.scene = WXSceneTimeline;
    }
    
    // message or text?
    NSDictionary *message = [params objectForKey:@"message"];
    
    if (message)
    {
        req.bText = NO;

        // async
        [self.commandDelegate runInBackground:^{
            req.message = [self buildSharingMessage:message];
            if (![WXApi sendReq:req])
            {
                [self failWithCallbackID:command.callbackId withMessage:@"参数错误"];
                self.currentCallbackId = nil;
            }
        }];
    }
    else
    {
        req.bText = YES;
        req.text = [params objectForKey:@"text"];
        
        if (![WXApi sendReq:req])
        {
            [self failWithCallbackID:command.callbackId withMessage:@"参数错误"];
            self.currentCallbackId = nil;
        }
    }
}

- (void)sendAuthRequest:(CDVInvokedUrlCommand *)command
{
    SendAuthReq* req =[[SendAuthReq alloc] init];

    // scope
    req.scope = [command.arguments objectAtIndex:0];
    if ([command.arguments count] > 0)
    {
        req.scope = [command.arguments objectAtIndex:0];
    }
    else
    {
        req.scope = @"snsapi_userinfo";
    }
    
    // state
    if ([command.arguments count] > 1)
    {
        req.state = [command.arguments objectAtIndex:1];
    }
    
    if ([WXApi sendReq:req]) {
        // save the callback id
        self.currentCallbackId = command.callbackId;
    } else {
        [self failWithCallbackID:command.callbackId withMessage:@"参数错误"];
    }
}

- (void)registerApp:(NSString *)wechatAppId
{
    self.wechatAppId = wechatAppId;
    
    [WXApi registerApp:wechatAppId];

    NSLog(@"Register wechat app: %@", wechatAppId);
}

#pragma mark "WXApiDelegate"

/**
 * Not implemented
 */
- (void)onReq:(BaseReq *)req
{
    NSLog(@"%@", req);
}

- (void)onResp:(BaseResp *)resp
{
    BOOL success = NO;
    NSString *message = @"Unknown";
    NSDictionary *response = nil;
    
    switch (resp.errCode)
    {
        case WXSuccess:
            success = YES;
            break;
            
        case WXErrCodeCommon:
            message = @"普通错误类型";
            break;
            
        case WXErrCodeUserCancel:
            message = @"用户点击取消并返回";
            break;
            
        case WXErrCodeSentFail:
            message = @"发送失败";
            break;
            
        case WXErrCodeAuthDeny:
            message = @"授权失败";
            break;
            
        case WXErrCodeUnsupport:
            message = @"微信不支持";
            break;
    }
    
    if (success)
    {
        if ([resp isKindOfClass:[SendAuthResp class]])
        {
            // fix issue that lang and country could be nil for iPhone 6 which caused crash.
            SendAuthResp* authResp = (SendAuthResp*)resp;
            response = @{
                         @"code": authResp.code != nil ? authResp.code : @"",
                         @"state": authResp.state != nil ? authResp.state : @"",
                         @"lang": authResp.lang != nil ? authResp.lang : @"",
                         @"country": authResp.country != nil ? authResp.country : @"",
                         };
            
            CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:response];
            
            [self.commandDelegate sendPluginResult:commandResult callbackId:self.currentCallbackId];
        }
        else
        {
            [self successWithCallbackID:self.currentCallbackId];
        }
    }
    else
    {
        [self failWithCallbackID:self.currentCallbackId withMessage:message];
    }
    
    self.currentCallbackId = nil;
}

#pragma mark "CDVPlugin Overrides"

- (void)handleOpenURL:(NSNotification *)notification
{
    NSURL* url = [notification object];
    
    if ([url isKindOfClass:[NSURL class]] && [url.scheme isEqualToString:self.wechatAppId])
    {
        [WXApi handleOpenURL:url delegate:self];
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
    if ([message objectForKey:@"thumb"])
    {
        [wxMediaMessage setThumbImage:[self getThumbImageFromURL:[message objectForKey:@"thumb"]]];
    }
    
    // media parameters
    id mediaObject = nil;
    NSDictionary *media = [message objectForKey:@"media"];
    
    // check types
    NSInteger type = [[media objectForKey:@"type"] integerValue];
    switch (type)
    {
        case CDVWXSharingTypeApp:
            mediaObject = [WXAppExtendObject object];
            ((WXAppExtendObject*)mediaObject).extInfo = [media objectForKey:@"extInfo"];
            ((WXAppExtendObject*)mediaObject).url = [media objectForKey:@"url"];
        break;
    
        case CDVWXSharingTypeEmotion:
            mediaObject = [WXEmoticonObject object];
            ((WXEmoticonObject*)mediaObject).emoticonData = [self getNSDataFromURL:[media objectForKey:@"emotion"]];
        break;
        
        case CDVWXSharingTypeFile:
            mediaObject = [WXFileObject object];
            ((WXFileObject*)mediaObject).fileData = [self getNSDataFromURL:[media objectForKey:@"file"]];
        break;
        
        case CDVWXSharingTypeImage:
            mediaObject = [WXImageObject object];
            ((WXImageObject*)mediaObject).imageData = [self getNSDataFromURL:[media objectForKey:@"image"]];
        break;
        
        case CDVWXSharingTypeMusic:
            mediaObject = [WXMusicObject object];
            ((WXMusicObject*)mediaObject).musicUrl = [media objectForKey:@"musicUrl"];
            ((WXMusicObject*)mediaObject).musicDataUrl = [media objectForKey:@"musicDataUrl"];
        break;
        
        case CDVWXSharingTypeVideo:
            mediaObject = [WXVideoObject object];
            ((WXVideoObject*)mediaObject).videoUrl = [media objectForKey:@"videoUrl"];
        break;
        
        case CDVWXSharingTypeWebPage:
        default:
        mediaObject = [WXWebpageObject object];
        ((WXWebpageObject *)mediaObject).webpageUrl = [media objectForKey:@"webpageUrl"];
    }

    wxMediaMessage.mediaObject = mediaObject;
    return wxMediaMessage;
}

- (NSData *)getNSDataFromURL:(NSString *)url
{
    __block NSData* data = nil;

    NSURL *uri = [NSURL URLWithString:url];
    
    if ([url hasPrefix:@"http://"] || [url hasPrefix:@"https://"])
    {
        data = [NSData dataWithContentsOfURL:[NSURL URLWithString:url]];
    }
    else
    {
        NSString *filepath = @"";
        if ([[uri scheme] isEqualToString:kCDVFilesystemURLPrefix] && [[uri host] isEqualToString:@"localhost"]) {
            
            NSString *path = [uri path];
            NSString *query = [uri query];
            if ([path hasPrefix:@"/assets-library/"]) {
                path = [NSString stringWithFormat:@"assets-library:/%@", [path substringFromIndex: [@"/assets-library" length]]];
                uri = [NSURL URLWithString:[[path stringByAppendingString:@"?"] stringByAppendingString:query]];
                data = [self getNSDataFromAssetsLibrary:uri];
            } else {
                NSRange slashRange = [path rangeOfString:@"/" options:0 range:NSMakeRange(1, path.length-1)];
                if (slashRange.location == NSNotFound) {
                    filepath = @"";
                }
                filepath = [path substringFromIndex:slashRange.location];
                data = [NSData dataWithContentsOfFile:filepath];
            }
        } else if ([[uri scheme] isEqualToString:@"assets-library"]) {
            data = [self getNSDataFromAssetsLibrary:uri];
        } else {
            // local file
            url = [[NSBundle mainBundle] pathForResource:[url stringByDeletingPathExtension] ofType:[url pathExtension]];
            data = [NSData dataWithContentsOfFile:url];
        }
    }
    return data;
}

- (NSData*)getNSDataFromAssetsLibrary:(NSURL *) uri
{
    __block NSData* data = nil;
    
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0);
    
    dispatch_async(queue, ^{
        [library assetForURL:uri resultBlock:^(ALAsset *asset) {
            ALAssetRepresentation *rep = [asset defaultRepresentation];
            long long imageDataSize = [rep size];
            uint8_t* imageDataBytes = malloc(imageDataSize);
            [rep getBytes:imageDataBytes fromOffset:0 length:imageDataSize error:nil];
            
            data = [NSData dataWithBytesNoCopy:imageDataBytes length:imageDataSize freeWhenDone:YES];
            dispatch_semaphore_signal(sema);
        } failureBlock:^(NSError *error) {
            dispatch_semaphore_signal(sema);
        }];
    });
    
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    return data;
}

-(UIImage*)shrinkImage:(UIImage*)srcImg :(float)targetSize {
    float compressionVal = 1.0;
    float maxVal = targetSize;
    
    UIImage *compressedImage = srcImg; //get UIImage from imageView
    
    int iterations = 0;
    int totalIterations = 0;
    
    float initialCompressionVal = 0.00000000f;
    
    while (((((float)(UIImageJPEGRepresentation(compressedImage, compressionVal).length))) > maxVal) && (totalIterations < 1024)) {
        
        compressionVal = (((compressionVal)+((compressionVal)*((float)(((float)maxVal)/((float)(((float)(UIImageJPEGRepresentation(compressedImage, compressionVal).length))))))))/(2));
        compressionVal *= 0.97;//subtracts 3% of it's current value just incase above algorithm limits at just above MaxVal and while loop becomes infinite.
        
        if (initialCompressionVal == 0.00000000f) {
            initialCompressionVal = compressionVal;
        }
        
        iterations ++;
        
        if ((iterations >= 3) || (compressionVal < 0.1)) {
            iterations = 0;
            compressionVal = 1.0f;
            compressedImage = [UIImage imageWithData:UIImageJPEGRepresentation(compressedImage, compressionVal)];
            
            float resizeAmount = 1.0f;
            resizeAmount = (resizeAmount+initialCompressionVal)/(2);//percentage
            resizeAmount *= 0.97;//3% boost just incase image compression algorithm reaches a limit.
            resizeAmount = 1/(resizeAmount);//value
            initialCompressionVal = 0.00000000f;
            
            
            UIView *imageHolder = [[UIView alloc] initWithFrame:CGRectMake(0,0,(int)floorf((float)(compressedImage.size.width/(resizeAmount))), (int)floorf((float)(compressedImage.size.height/(resizeAmount))))];//round down to ensure frame isnt larger than image itself
            
            UIImageView *theResizedImage = [[UIImageView alloc] initWithFrame:CGRectMake(0,0,(int)ceilf((float)(compressedImage.size.width/(resizeAmount))), (int)ceilf((float)(compressedImage.size.height/(resizeAmount))))];//round up to ensure image fits
            theResizedImage.image = compressedImage;
            
            
            [imageHolder addSubview:theResizedImage];
            
            
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(imageHolder.frame.size.width, imageHolder.frame.size.height), YES, 1.0f);
            CGContextRef resize_context = UIGraphicsGetCurrentContext();
            [imageHolder.layer renderInContext:resize_context];
            compressedImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
            
            //after 3 compressions, if we still haven't shrunk down to maxVal size, apply the maximum compression we can, then resize the image (90%?), then re-start the process, this time compressing the compressed version of the image we were checking.
        }
        
        totalIterations ++;
        
    }
    
    if (totalIterations >= 1024) {
        NSLog(@"Image was too big, gave up on trying to re-size");//too many iterations failsafe. Gave up on trying to resize.
        return nil;
    } else {
        NSData *imageData = UIImageJPEGRepresentation(compressedImage, compressionVal);
        return [UIImage imageWithData:imageData];//save new image to UIImageView.
    }
}

- (UIImage *)getUIImageFromURL:(NSString *)url
{
    NSData *data = [self getNSDataFromURL:url];
    return [UIImage imageWithData:data];
}

- (UIImage *)getThumbImageFromURL:(NSString *)url
{
    __block NSData* data = nil;
    
    NSURL *uri = [NSURL URLWithString:url];
    
    if ([url hasPrefix:@"http://"] || [url hasPrefix:@"https://"])
    {
        data = [NSData dataWithContentsOfURL:[NSURL URLWithString:url]];
    }
    else
    {
        NSString *filepath = @"";
        if ([[uri scheme] isEqualToString:kCDVFilesystemURLPrefix] && [[uri host] isEqualToString:@"localhost"]) {
            
            NSString *path = [uri path];
            NSString *query = [uri query];
            if ([path hasPrefix:@"/assets-library/"]) {
                path = [NSString stringWithFormat:@"assets-library:/%@", [path substringFromIndex: [@"/assets-library" length]]];
                uri = [NSURL URLWithString:[[path stringByAppendingString:@"?"] stringByAppendingString:query]];
                data = [self getNSDataFromAssetsLibrary:uri];
            } else {
                NSRange slashRange = [path rangeOfString:@"/" options:0 range:NSMakeRange(1, path.length-1)];
                if (slashRange.location == NSNotFound) {
                    filepath = @"";
                }
                filepath = [path substringFromIndex:slashRange.location];
                data = [NSData dataWithContentsOfFile:filepath];
            }
        } else if ([[uri scheme] isEqualToString:@"assets-library"]) {
            data = [self getNSDataFromAssetsLibrary:uri];
        } else {
            // local file
            url = [[NSBundle mainBundle] pathForResource:[url stringByDeletingPathExtension] ofType:[url pathExtension]];
            data = [NSData dataWithContentsOfFile:url];
        }
    }
    return [self shrinkImage:[UIImage imageWithData:data] :25000];
}

- (void)successWithCallbackID:(NSString *)callbackID
{
    [self successWithCallbackID:callbackID withMessage:@"OK"];
}

- (void)successWithCallbackID:(NSString *)callbackID withMessage:(NSString *)message
{
    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:message];
    [self.commandDelegate sendPluginResult:commandResult callbackId:callbackID];
}

- (void)failWithCallbackID:(NSString *)callbackID withError:(NSError *)error
{
    [self failWithCallbackID:callbackID withMessage:[error localizedDescription]];
}

- (void)failWithCallbackID:(NSString *)callbackID withMessage:(NSString *)message
{
    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:message];
    [self.commandDelegate sendPluginResult:commandResult callbackId:callbackID];
}

@end
