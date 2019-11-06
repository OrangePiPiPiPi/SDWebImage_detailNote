//
//  YFKeyboardButton.h
//
//  Created by fank on 2019/10/16.
//  Copyright © 2019 fank. All rights reserved.
//

#import <UIKit/UIKit.h>

/**
 按钮类型
 - YFKeyboardButtonTypeNone: 空白
 - YFKeyboardButtonTypeChinese,汉字
 - YFKeyboardButtonTypeNumber: 数字
 - YFKeyboardButtonTypeLetter: 字母
 - YFKeyboardButtonTypeDelete: 删除按钮
 */
typedef NS_ENUM(NSInteger,YFKeyboardButtonType) {
    YFKeyboardButtonTypeNone = 10000,
    YFKeyboardButtonTypeChinese,//汉字
    YFKeyboardButtonTypeNumber,//数字
    YFKeyboardButtonTypeLetter,//字母
    YFKeyboardButtonTypeDelete,//删除
};

@interface YFKeyboardButton : UIButton

@property (nonatomic,assign)YFKeyboardButtonType KeyboardButtonType;

@end


//键盘按钮
