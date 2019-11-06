//
//  UIImage+WebP.h
//  SDWebImage
//
//  Created by Olivier Poitrey on 07/06/13.
//  Copyright (c) 2013 Dailymotion. All rights reserved.
//

#ifdef SD_WEBP

#import <UIKit/UIKit.h>

// Fix for issue #416 Undefined symbols for architecture armv7 since WebP introduction when deploying to device
void WebPInitPremultiplyNEON(void);

void WebPInitUpsamplersNEON(void);

void VP8DspInitNEON(void);

@interface UIImage (WebP)

+ (UIImage *)sd_imageWithWebPData:(NSData *)data;

@end

#endif


/**
 参考：https://www.jianshu.com/p/8ec776dc4e5d
 
 
 #ifdef _XXXX  （ifdef 即 if define ）
 　　...程序段1...
 #elif defined _YYYY
 ...程序段3...（相当于else if）
 　　#else
 　　...程序段2...
 　　#endif
 　　 
 >这表明如果_XXXX已被#define定义过，则对程序段1进行编译；再如果定义了_YYYY,执行程序段3，否则对程序段2进行编译。
 
 　　例：
 　　#define NUM
 　　.............
 
 　　#ifdef NUM
 　　 printf("之前NUM有过定义啦！:) \n");
 　　#else
 　　 printf("之前NUM没有过定义！:( \n");
 　　#endif
 
 >如果程序开头有#define NUM这行，即NUM有定义，碰到下面#ifdef NUM的时候，当然执行第一个printf。否则第二个printf将被执行。
 　　 我认为，用这种，可以很方便的开启/关闭整个程序的某项特定功能。
 
 2：
 　　#ifndef _XXXX
 　　...程序段1...
 　　#else
 　　...程序段2...
 　　#endif
 
 >这里使用了#ifndef，表示的是if not def。和#ifdef相反的状况（如果没有定义了标识符_XXXX，那么执行程序段1，否则执行程序段2）
 
 
 3：
 　　#if 常量
 　　...程序段1...
 　　#else
 　　...程序段2...
 　　#endif
 　　
 >注意：#if后必须跟常量，不能是宏（因为宏是在运行阶段才有，#if是预编译阶段，找不到宏）；
 如果常量为真（非0，随便什么数字，只要不是0），就执行程序段1，否则执行程序段2。
 　我认为，这种方法可以将测试代码加进来。当需要开启测试的时候，只要将常量变1就好了。而不要测试的时候，只要将常量变0。
 
 **/
