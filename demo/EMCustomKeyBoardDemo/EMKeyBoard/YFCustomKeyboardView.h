//
//  YFCustomKeyboardView.h
//
//  Created by fank on 2019/10/17.
//  自定义键盘

#import <UIKit/UIKit.h>


/**
 自定义键盘类型
 */
typedef NS_ENUM(NSInteger,YFCustomKeyboardType) {
   
    YFCustomKeyboardTypeProvince, //省份键盘
    YFCustomKeyboardTypeNumAndCapitalLetter, //数字和大写字母键盘
    
};

@interface YFCustomKeyboardView : UIView

@property (nonatomic,assign)YFCustomKeyboardType keyboardType;


@end

