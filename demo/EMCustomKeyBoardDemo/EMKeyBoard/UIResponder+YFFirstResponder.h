//
//  UIResponder+YFFirstResponder.h
//
//  Created by fank on 2019/10/17.
//

#import <UIKit/UIKit.h>

@interface UIResponder (YFFirstResponder)

+ (void)inputText:(NSString *)text;

+ (UIResponder *)YFTradeCurrentFirstResponder;

+ (UIView <UITextInput> *)firstResponderTextView;

@end

