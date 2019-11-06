//
//  YFProvinceKeyboard.h
//
//  Created by fank on 2019/10/16.
//  Copyright © 2019 fank. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface YFProvinceKeyboard : UIView

//关闭键盘按钮文本颜色
@property(nonatomic,strong)UIColor *closeBtnTitleColor;

//关闭按钮所在view的背景颜色
@property(nonatomic,strong)UIColor *closeViewBgColor;

//切换键盘Block
@property(nonatomic,copy)void(^didChangeKeyboardTypeBlcok)(void);

@end

NS_ASSUME_NONNULL_END

//显示省份的键盘
