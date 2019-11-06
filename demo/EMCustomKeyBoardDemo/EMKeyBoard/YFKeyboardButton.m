//
//  YFKeyboardButton.m
//
//  Created by fank on 2019/10/16.
//  Copyright © 2019 fank. All rights reserved.

#import "YFKeyboardButton.h"
#import "UIColor+EMColor.h"
#import "UIImage+EMColor.h"

@implementation YFKeyboardButton

- (void)setKeyboardButtonType:(YFKeyboardButtonType)KeyboardButtonType
{
    _KeyboardButtonType = KeyboardButtonType;
    
    self.backgroundColor = [UIColor colorWithHex:@"#d2d2d2"];
    
    [self setBackgroundImage:[UIImage imageWithColor:[UIColor grayColor]] forState:(UIControlStateSelected)];
    
    switch (KeyboardButtonType) {
        case YFKeyboardButtonTypeChinese:{
            [self configKeyboardButtonTypeWithIsFunctionKeyBoard:NO];
            [self configKeyboardButtonTypeWithisNumberKeyBoard:NO];
        }
            break;
        case YFKeyboardButtonTypeNumber:{
            [self configKeyboardButtonTypeWithIsFunctionKeyBoard:NO];
            [self configKeyboardButtonTypeWithisNumberKeyBoard:NO];
        }
            break;
        case YFKeyboardButtonTypeLetter:{
            [self configKeyboardButtonTypeWithIsFunctionKeyBoard:NO];
            [self configKeyboardButtonTypeWithisNumberKeyBoard:NO];
        }
            break;
        case YFKeyboardButtonTypeDelete:{
            [self setImage:[UIImage imageNamed:@"button_backspace_delete"] forState:UIControlStateNormal];
            [self configKeyboardButtonTypeWithIsFunctionKeyBoard:YES];
            [self configKeyboardButtonTypeWithisNumberKeyBoard:NO];
        }
            break;
        default:
            break;
    }
}


/**
 数字键盘和字母键盘按钮样式

 @param isNumberKeyBoard 是否是数字键盘
 */
- (void)configKeyboardButtonTypeWithisNumberKeyBoard:(BOOL)isNumberKeyBoard
{
    if (isNumberKeyBoard) {
        self.layer.borderWidth = 0.5;
        self.layer.borderColor = [[UIColor colorWithHex:@"#dadada"] CGColor];
    }else{
        self.layer.cornerRadius = 5;
        self.clipsToBounds = YES;
    }
}



/**
 功能按钮和可输入按钮样式

 @param isFunctionKeyBoard 是否是功能按钮
 */
- (void)configKeyboardButtonTypeWithIsFunctionKeyBoard:(BOOL)isFunctionKeyBoard
{
    if (isFunctionKeyBoard) {
        [self setTitleColor:[UIColor colorWithHex:@"#3d3d3d"] forState:UIControlStateNormal];
        self.titleLabel.font = [UIFont systemFontOfSize:18];
        [self setBackgroundImage:[UIImage imageWithColor:[UIColor colorWithHex:@"#e5e5e5"]] forState:UIControlStateNormal];
    }else{
        [self setTitleColor:[UIColor colorWithHex:@"#000000"] forState:UIControlStateNormal];
        self.titleLabel.font = [UIFont systemFontOfSize:24];
         [self setBackgroundImage:[UIImage imageWithColor:[UIColor whiteColor]] forState:UIControlStateNormal];
    }
}


@end
