//
//  YFShareTool.m
//  EMCustomKeyBoardDemo
//
//  Created by fank on 2019/10/22.
//  Copyright © 2019 zhaochen. All rights reserved.
//

#import "YFShareTool.h"
#import <Social/Social.h>
#import "YFShareCoverView.h"
#import "SGQRCodeGenerateManager.h"
#import "UILabel+Factory.h"

@interface YFShareTool()

@property (nonatomic, strong) YFShareCoverView *shotView;
@property (nonatomic, weak) NSTimer *timer;//定时器
@property (nonatomic, assign) NSInteger timerNum;//定时器时间
@end

@implementation YFShareTool

//初始化
+ (instancetype) sharedScreenShot{
    static YFShareTool *sharedToolInstance = nil;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        sharedToolInstance = [[self alloc] init];
    });
    return sharedToolInstance;
}

- (void)enableSharedScreenShot{
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    if ([appDelegate.currentUser.isLogin boolValue]) {
        //已登录
         [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userDidTakeScreenshot:) name:UIApplicationUserDidTakeScreenshotNotification object:nil];
    }
}

//一般系统截屏,
- (void)userDidTakeScreenshot:(NSNotification *)notification{
    //获取屏幕截图
    CGFloat imgW = kSizePt(91)-2*kSizePt(2);
    CGFloat imgH = kSizePt(159) - kSizePt(42) - kSizePt(2);
    CGFloat targetH = (kSelfWidth*imgH)/imgW;
    CGSize imageSize = CGSizeMake(kSelfWidth, targetH);
    //此处的imageSize是根据设计图宽高比截取不变形的图片
    UIImage *image = [self imageWithScreenshotWithSize:imageSize];
    
    KWS(ws);
    _shotView = [[YFShareCoverView alloc] initWithFrame:[UIScreen mainScreen].bounds ScreenShot:image];
    [_shotView setDidShareScreenShotBlock:^{
        //分享
        [ws clear];
        [ws shareCodeImageWithShot:image andResult:^(BOOL isSuccess, NSString * _Nonnull message) {
            
        }];
    }];
    [_shotView setDidHideBlock:^{
       [ws clear];
    }];
    [_shotView show];

    if (self.timer){
        self.timer = nil;
    };
    _timerNum = 5;
    _timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(timerStepStart) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSDefaultRunLoopMode];
}

- (void)timerStepStart{
    if (_timerNum == 0) {
        if ([self.timer isValid]) {
            [self clear];
        }
        return;
    }
    _timerNum -= 1;
}

-(void)clear{
    [self.timer invalidate];
    self.timer = nil;
    if (_shotView) {
        [UIView animateWithDuration:0.5 animations:^{
            CGRect tempFrame = _shotView.frame;
            tempFrame.origin.x += kSelfWidth;
            _shotView.frame = tempFrame;
        } completion:^(BOOL finished) {
           [_shotView removeFromSuperview];
        }];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationUserDidTakeScreenshotNotification object:nil];
    [self.timer invalidate];
    self.timer = nil;
    [_shotView removeFromSuperview];
}

//将截屏和二维码拼接分享
-(void)shareCodeImageWithShot:(UIImage *)shotImg andResult:(SucceessBlock)resultBlock{
    UIView *codeView = [self getCodeView];
    UIScrollView *contentScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, kSelfWidth, kSelfHeight+codeView.height)];
    contentScrollView.backgroundColor = [UIColor whiteColor];
    UIImageView *shotImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, kSelfWidth, kSelfHeight)];
    shotImgView.image = shotImg;
    [contentScrollView addSubview:shotImgView];
    
    codeView.y = MAX_Y(shotImgView);
    [contentScrollView addSubview:codeView];
    contentScrollView.contentSize = CGSizeMake(kSelfWidth, MAX_Y(codeView));
    NSString *filePath = [self getScreenShotPathWithTargetScrollView:contentScrollView];
    if (notNull(filePath)) {
        NSURL *shareImgUlr = [NSURL fileURLWithPath:filePath];
        NSArray *activityItemsArray = @[shareImgUlr];
        UIViewController *targetVc = [UIApplication sharedApplication].keyWindow.rootViewController;
        [self nativeShare:activityItemsArray target:targetVc success:^(BOOL isSuccess, NSString * _Nonnull message) {
            if (resultBlock) {
               resultBlock(isSuccess,message);
            }
        }];
    }else{
         [[Message sharedMessage] showFlashMessage:@"分享失败,请稍后重试"];
    }
}

//二维码和应用图标名称view
-(UIView *)getCodeView{
    AppDelegate *delegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NSString *roleType = ![delegate.currentUser.isGongWu boolValue]?@"RENT":@"LOGISTICS";
    NSString *downLoadAddress = judgeNSStringNull(delegate.currentUser.webPageURL, @"");
    NSString *organId = [NSString stringWithFormat:@"?organ=%@",delegate.currentUser.organID];
    NSString *deploySign = [NSString stringWithFormat:@"=%@",delegate.currentUser.deploySign];
    NSString *message = [NSString stringWithFormat:@"&message=%@",delegate.currentUser.authId];
    NSString *bundleStr = [NSString stringWithFormat:@"|%@",kBundleID];
    NSString *typeStr = [NSString stringWithFormat:@"|%@",roleType];
    NSString *parm = [NSString stringWithFormat:@"%@%@%@%@%@%@",downLoadAddress,organId,deploySign,message,bundleStr,typeStr];
    //二维码
    UIImage *codeImg = [SGQRCodeGenerateManager generateWithDefaultQRCodeData:parm imageViewWidth:kSizePt(45)];
    NSDictionary *infoPlist = [[NSBundle mainBundle] infoDictionary];
    //app图标
    NSString *icon = [[infoPlist valueForKeyPath:@"CFBundleIcons.CFBundlePrimaryIcon.CFBundleIconFiles"] lastObject];
    //app名称
    NSString *appName = [infoPlist objectForKey:@"CFBundleDisplayName"];
    
    UIView *codeView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kSelfWidth, kSizePt(55))];
    codeView.backgroundColor = [UIColor whiteColor];
    UIImageView *codeImgView = [[UIImageView alloc] initWithFrame:CGRectMake(kSizePt(5), kSizePt(5), kSizePt(45), kSizePt(45))];
    codeImgView.image = codeImg;
    [codeView addSubview:codeImgView];
    
    UIImageView *iconImgView = [[UIImageView alloc] initWithFrame:CGRectMake(kSizePt(5)+MAX_X(codeImgView), codeImgView.y, kSizePt(20), kSizePt(20))];
    iconImgView.image = [UIImage imageNamed:icon];
    [codeView addSubview:iconImgView];
    
    CGFloat labH = [UILabel labelSizeWithString:@"公务用车易" fontSize:kFontPt(10)].height;
    UILabel *appNameLab = [UILabel factoryLabelWithTextColor:colorWithRGBString(kColor333333) fontSize:kFontPt(10)];
    appNameLab.frame = CGRectMake(iconImgView.x, codeImgView.height-labH, codeView.width/3, labH);
    appNameLab.text = appName;
    [codeView addSubview:appNameLab];
    return  codeView;
}


/** 分享 */
-(void)nativeShare:(NSArray *)items target:(id)target success:(SucceessBlock)successBlock {
    if (items.count == 0 || target == nil) {
        NSLog(@"items和target不能为空");
        return;
    }
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
    if (@available(iOS 11.0, *)) {//UIActivityTypeMarkupAsPDF是在iOS 11.0 之后才有的
        activityVC.excludedActivityTypes = @[UIActivityTypePostToVimeo,UIActivityTypeOpenInIBooks,UIActivityTypeAirDrop];
        
    } else if (@available(iOS 9.0, *)) {//UIActivityTypeOpenInIBooks是在iOS 9.0 之后才有的
        activityVC.excludedActivityTypes = @[UIActivityTypePostToVimeo,UIActivityTypeOpenInIBooks,UIActivityTypeAirDrop];
    }else {
        activityVC.excludedActivityTypes = @[UIActivityTypePostToVimeo,UIActivityTypeAirDrop];
    }
    activityVC.completionWithItemsHandler = ^(UIActivityType  _Nullable activityType, BOOL completed, NSArray * _Nullable returnedItems, NSError * _Nullable activityError) {
        //completed:YES:分享成功，NO:分享失败
        if (successBlock) {
            successBlock(completed, @"");
        }
        //删除暂存图片
        [self clearSandBoxShareImage];
    };
    UIViewController *vc2 = target;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        //iPad
        activityVC.popoverPresentationController.sourceView = vc2.view;
        [vc2 presentViewController:activityVC animated:YES completion:nil];
    } else {
        //iPhone
        [vc2 presentViewController:activityVC animated:YES completion:nil];
    }
}

/** 获取长截图 **/
-(NSString *)getScreenShotPathWithTargetScrollView:(UIScrollView *)scrollView{
    @try {
            UIImage* image = [self getImageFromeScrollView:scrollView];
            if (image) {
                //清空之前的数据
                [self clearSandBoxShareImage];
                //获取沙盒temp文件夹路径
                NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"YFScreenShotShareImage.png"];
                //保存图片
                BOOL isSaveSuccess = [UIImagePNGRepresentation(image) writeToFile:filePath atomically:YES];
                if (isSaveSuccess) {
                    return filePath;
                }else{
                    return nil;
                }
            }
            return nil;
    }@catch (NSException *exception) {
        return nil;
    }
}

-(UIImage *)getImageFromeScrollView:(UIScrollView *)scrollView{
    @try {
        @autoreleasepool {
            UIGraphicsBeginImageContextWithOptions(scrollView.contentSize, YES, 0.0);
            //保存scrollView当前的偏移量
            CGPoint savedContentOffset = scrollView.contentOffset;
            CGRect saveFrame = scrollView.frame;
            //将scrollView的偏移量设置为(0,0)
            [scrollView setContentOffset:CGPointZero animated:NO];
            
            CGRect tempScrollViewFrame = scrollView.frame;
            tempScrollViewFrame.size.height = scrollView.contentSize.height;
            tempScrollViewFrame.size.width = scrollView.contentSize.width;
            scrollView.frame = tempScrollViewFrame;
            
            //在当前上下文中渲染出scrollView
            [scrollView.layer renderInContext:UIGraphicsGetCurrentContext()];
            
            //截取当前上下文生成Image
            UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
            
            //恢复scrollView的偏移量
            scrollView.contentOffset = savedContentOffset;
            scrollView.frame = saveFrame;
            UIGraphicsEndImageContext();
            return image;
        }
    }@catch (NSException *exception) {
        return nil;
    }
}

/** 删除沙盒中保存的截图 **/
-(void)clearSandBoxShareImage{
    //获取沙盒temp文件夹路径
    NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"YFScreenShotShareImage.png"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:filePath]) {
        [fileManager removeItemAtPath:filePath error:nil];
    }
}

//截取当前屏幕
-(NSData *)dataWithScreenshotWithSize:(CGSize)targetSize
{
    CGSize imageSize = CGSizeZero;
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    if (UIInterfaceOrientationIsPortrait(orientation)){
       imageSize = targetSize;
    }else{
       imageSize = CGSizeMake(targetSize.height, targetSize.width);
    }
    UIGraphicsBeginImageContextWithOptions(imageSize, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    for (UIWindow *window in [[UIApplication sharedApplication] windows])
    {
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, window.center.x, window.center.y);
        CGContextConcatCTM(context, window.transform);
        CGContextTranslateCTM(context, -window.bounds.size.width * window.layer.anchorPoint.x, -window.bounds.size.height * window.layer.anchorPoint.y);
        if (orientation == UIInterfaceOrientationLandscapeLeft)
        {
            CGContextRotateCTM(context, M_PI_2);
            CGContextTranslateCTM(context, 0, -imageSize.width);
        }
        else if (orientation == UIInterfaceOrientationLandscapeRight)
        {
            CGContextRotateCTM(context, -M_PI_2);
            CGContextTranslateCTM(context, -imageSize.height, 0);
        } else if (orientation == UIInterfaceOrientationPortraitUpsideDown) {
            CGContextRotateCTM(context, M_PI);
            CGContextTranslateCTM(context, -imageSize.width, -imageSize.height);
        }
        if ([window respondsToSelector:@selector(drawViewHierarchyInRect:afterScreenUpdates:)])
        {
            [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:YES];
        }
        else
        {
            [window.layer renderInContext:context];
        }
        CGContextRestoreGState(context);
    }
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return UIImagePNGRepresentation(image);
}

//返回截取到的图片
-(UIImage *)imageWithScreenshotWithSize:(CGSize)size
{
    NSData *imageData = [self dataWithScreenshotWithSize:size];
    return [UIImage imageWithData:imageData];
}

@end
