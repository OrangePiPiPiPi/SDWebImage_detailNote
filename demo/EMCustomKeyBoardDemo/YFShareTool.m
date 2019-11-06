//
//  YFShareTool.m
//  EMCustomKeyBoardDemo
//
//  Created by fank on 2019/10/22.
//  Copyright © 2019 zhaochen. All rights reserved.
//

#import "YFShareTool.h"
#import <Social/Social.h>

@interface YFShareTool()

@property (nonatomic, strong) UIView *shotView;
@property (nonatomic, weak) NSTimer *timer;//定时器
@property (nonatomic, assign) NSInteger timerNum;//定时器时间

@end

@implementation YFShareTool

//- (void)embedApplication:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions{
//      [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userDidTakeScreenshot:) name:UIApplicationUserDidTakeScreenshotNotification object:nil];
//}


//- (void)userDidTakeScreenshot:(NSNotification *)notification {
//    //UIImage *image = [self imageWithScreenshot];
//    //UIWindow *window = [[UIApplication sharedApplication].windows objectAtIndex:0];
//
//    _shotView = [[UIView alloc] initWithFrame:CGRectMake(0, [UIScreen mainScreen].bounds.size.height-200, [UIScreen mainScreen].bounds.size.width, 200)];
//    _shotView.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.5];
//
//    _timerNum = 4;
//    _timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(timerStepStart) userInfo:nil repeats:YES];
//    [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSDefaultRunLoopMode];
//}
//- (void)timerStepStart{
//    if (_timerNum == 0) {
//        if ([self.timer isValid]) {
//            [self.timer invalidate];
//            self.timer = nil;
//            [_shotView removeFromSuperview];
//        }
//        return;
//    }
//    _timerNum -= - 1;
//}

//- (void)dealloc {
//    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"UIApplicationUserDidTakeScreenshotNotification" object:nil];
//
//    [self.timer invalidate];
//    self.timer = nil;
//    [_shotView removeFromSuperview];
//}


/** 分享 */
+(void)nstiveShare:(NSArray *)items target:(id)target success:(SucceessBlock)successBlock {
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
+(NSString *)getScreenShotPathWithTargetScrollView:(UIScrollView *)scrollView{
    @try {
        @autoreleasepool {
            UIImage* image = nil;
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
            image = UIGraphicsGetImageFromCurrentImageContext();
            
            //恢复scrollView的偏移量
            scrollView.contentOffset = savedContentOffset;
            scrollView.frame = saveFrame;
            UIGraphicsEndImageContext();
            
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
        }
    }@catch (NSException *exception) {
        return nil;
    }
}

/** 删除沙盒中保存的截图 **/
+(void)clearSandBoxShareImage{
    //获取沙盒temp文件夹路径
    NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"YFScreenShotShareImage.png"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:filePath]) {
        [fileManager removeItemAtPath:filePath error:nil];
    }
}

@end
