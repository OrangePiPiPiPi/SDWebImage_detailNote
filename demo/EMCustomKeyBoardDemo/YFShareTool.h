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

+ (instancetype) sharedScreenShot;

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
-(void)nativeShare:(NSArray *)items target:(id)target success:(SucceessBlock)successBlock;

//获得截图保存在本地的地址
-(NSString *)getScreenShotPathWithTargetScrollView:(UIScrollView *)scrollView;

//开启截屏分享功能
- (void)enableSharedScreenShot;

/**
 获取屏幕截图
 size：需求截取的尺寸
 **/
-(UIImage *)imageWithScreenshotWithSize:(CGSize)size;

/**
 shotImg:已取的的截屏图片，用于拼接二维码然后分享
 **/
-(void)shareCodeImageWithShot:(UIImage *)shotImg andResult:(SucceessBlock)resultBlock;

/**
 scrollView:截取scrollView成一张图片
 **/
-(UIImage *)getImageFromeScrollView:(UIScrollView *)scrollView;

@end

NS_ASSUME_NONNULL_END
