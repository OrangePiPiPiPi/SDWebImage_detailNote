//
//  YFNumAndCapitalLetterKeyboard.h
//
//  Created by fank on 2019/10/18.
//  Copyright © 2019 zhaochen. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface YFNumAndCapitalLetterKeyboard : UIView

//关闭键盘按钮文本颜色
@property(nonatomic,strong)UIColor *closeBtnTitleColor;

//关闭按钮所在view的背景颜色
@property(nonatomic,strong)UIColor *closeViewBgColor;

//切换键盘Block
@property(nonatomic,copy)void(^didChangeKeyboardTypeBlcok)(void);

@end

NS_ASSUME_NONNULL_END

//数字和大写字母键盘
