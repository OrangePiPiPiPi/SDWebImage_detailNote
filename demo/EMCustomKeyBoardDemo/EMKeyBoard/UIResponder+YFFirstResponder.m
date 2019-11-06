//
//  UIResponder+YFFirstResponder.m
//
//  Created by fank on 2019/10/17.
//

#import "UIResponder+YFFirstResponder.h"

@implementation UIResponder (YFFirstResponder)

static __weak id YFTradeCurrentFirstResponder;

+ (void)inputText:(NSString *)text
{
    UIView <UITextInput> *textInput = [UIResponder firstResponderTextView];
    NSString *character = [NSString stringWithString:text];
    
    BOOL canEditor = YES;
    if ([textInput isKindOfClass:[UITextField class]]) {
        UITextField *textField = (UITextField *)textInput;
        if ([textField.delegate respondsToSelector:@selector(textField:shouldChangeCharactersInRange:replacementString:)]) {
            canEditor = [textField.delegate textField:textField shouldChangeCharactersInRange:NSMakeRange(textField.text.length, 0) replacementString:character];
        }
        
        if (canEditor) {
            [textField replaceRange:textField.selectedTextRange withText:text];
        }
    }
    
    if ([textInput isKindOfClass:[UITextView class]]) {
        UITextView *textView = (UITextView *)textInput;
        
        if ([textView.delegate respondsToSelector:@selector(textView:shouldChangeTextInRange:replacementText:)]) {
            canEditor = [textView.delegate textView:textView shouldChangeTextInRange:NSMakeRange(textView.text.length, 0) replacementText:character];
        }
        
        if (canEditor) {
            [textView replaceRange:textView.selectedTextRange withText:text];
        }
    }
}


+ (UIView <UITextInput> *)firstResponderTextView
{
    UIView <UITextInput> *textInput = (UIView <UITextInput> *)[UIResponder YFTradeCurrentFirstResponder];
    
    if ([textInput conformsToProtocol:@protocol(UIKeyInput)]) {
        return textInput;
    }
    return nil;
}

+ (UIResponder *)YFTradeCurrentFirstResponder {
    YFTradeCurrentFirstResponder = nil;
    [[UIApplication sharedApplication] sendAction:@selector(findYFTradeFirstResponder:) to:nil from:nil forEvent:nil];
    
    return YFTradeCurrentFirstResponder;
}

- (UIResponder *)YFTradeCurrentFirstResponder {
    return [[self class] YFTradeCurrentFirstResponder];
}

- (void)findYFTradeFirstResponder:(id)sender {
    YFTradeCurrentFirstResponder = self;
}

@end
