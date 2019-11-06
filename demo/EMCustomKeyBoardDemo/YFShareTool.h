//
//  YFShareTool.h
//  EMCustomKeyBoardDemo
//
//  Created by fank on 2019/10/22.
//  Copyright © 2019 zhaochen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
typedef void(^SucceessBlock)(BOOL isSuccess, NSString* message);

@interface YFShareTool : NSObject

/**
 *  分享
 *  分享图片
 *  分享链接
 *  NSString *textToShare = @"分享内容";
 *  UIImage *imageToShare = [UIImage imageNamed:@"imageName"];
 *  NSURL *urlToShare = [NSURL URLWithString:@""];
 *  NSArray *items = @[urlToShare,textToShare,imageToShare];
 *  注：如果只分享一张图片，则items里只传入该图片的url，如果分享截图，则通过
 *  + (NSString *)getScreenShotPathWithTargetScrollView:(UIScrollView *)scrollView方法获取截图地址，在
 *  通过[NSURL fileURLWithPath:filePath]得到url传入items里面即可
 */
+(void)nstiveShare:(NSArray *)items target:(id)target success:(SucceessBlock)successBlock;

//获得截图保存在本地的地址
+(NSString *)getScreenShotPathWithTargetScrollView:(UIScrollView *)scrollView;

//- (void)embedApplication:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions;
//
//+ (instancetype) sharedScreenShot;

+(NSString *)getScreenShotPathWithTargetScrollView:(UIScrollView *)scrollView andMapView:(UIImage *)mapViewImg andMapViewY:(CGFloat)y;

@end

NS_ASSUME_NONNULL_END
