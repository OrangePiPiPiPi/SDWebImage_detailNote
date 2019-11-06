//
//  SDWebImageCompat.m
//  SDWebImage
//
//  Created by Olivier Poitrey on 11/12/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import "SDWebImageCompat.h"

#if !__has_feature(objc_arc)
#error SDWebImage is ARC only. Either turn on ARC for the project or use -fobjc-arc flag
#endif

/**
 1、很多地方都调用了 scaledImageForKey方法，比如根据key从磁盘缓存中获取图片后已经是一张UIImage了，为什么进一步调用了scaledImageForKey？
 命名图片时候以xxx@2x.png、xxx@3x.png结尾，但在创建Image时并不需在后面添加倍数，只需调用[UIImage imageNamed:@"xxxx"]即可，因为Xcode会帮我们根据当前分辨率自动添加后缀。
 eg:如果你有一张5050的二倍图片，当你以[UIImage imageNamed:@"xxxx@2x"]的方法加载图片的时候，你会发现图片被拉伸了，它的大小变为100100，这是因为Xcode会自动添加二倍图后缀，以xxx@2x@2x去查找图片，当它找不到的时候就把xxx@2x图片当做一倍图片处理，所以图片的size就变大了，而ScaledImageForKey方法就是解决这件事情，以防url里面包含@"2x"、@"3x"等字符串，从而使图片size变大。
 **/

inline UIImage *SDScaledImageForKey(NSString *key, UIImage *image) {
    if (!image) {
        return nil;
    }
    
    if ([image.images count] > 0) {
        // 动画图片数组
        NSMutableArray *scaledImages = [NSMutableArray array];

        for (UIImage *tempImage in image.images) {
            [scaledImages addObject:SDScaledImageForKey(key, tempImage)];
        }

        return [UIImage animatedImageWithImages:scaledImages duration:image.duration];
    }
    else {
        if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
            CGFloat scale = 1.0;
            //// 比如屏幕为320x480时，scale为1，屏幕为640x960时，scale为2
            if (key.length >= 8) {
                 // “@2x.png”的长度为7，所以此处添加了这个判断，很巧妙
                // Search @2x. or @3x. at the end of the string, before a 3 to 4 extension length (only if key len is 8 or more @2x./@3x. + 4 len ext)
                NSRange range = [key rangeOfString:@"@2x." options:0 range:NSMakeRange(key.length - 8, 5)];
                if (range.location != NSNotFound) {
                    scale = 2.0;
                }
                
                range = [key rangeOfString:@"@3x." options:0 range:NSMakeRange(key.length - 8, 5)];
                if (range.location != NSNotFound) {
                    scale = 3.0;
                }
            }

            UIImage *scaledImage = [[UIImage alloc] initWithCGImage:image.CGImage scale:scale orientation:image.imageOrientation];
            image = scaledImage;
        }
        return image;
    }
}

NSString *const SDWebImageErrorDomain = @"SDWebImageErrorDomain";
