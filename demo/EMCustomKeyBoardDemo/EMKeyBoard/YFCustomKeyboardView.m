//
//  YFCustomKeyboardView.m
//
//  Created by fank on 2019/10/17.
//

#import "YFCustomKeyboardView.h"
#import "YFProvinceKeyboard.h"
#import "YFNumAndCapitalLetterKeyboard.h"

@interface YFCustomKeyboardView()

/**
 用于类型和键盘对应
 */
@property (nonatomic,strong)NSDictionary *typeDictionary;
/**
 省份键盘
 */
@property (nonatomic,strong)YFProvinceKeyboard *provinceKeyBoard;
/**
 数字和大写字母键盘
 */
@property (nonatomic,strong)YFNumAndCapitalLetterKeyboard *numAndCapitalLetterKeyboard;

@end

@implementation YFCustomKeyboardView


#pragma mark - init

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 260);
        [self addSubview:self.provinceKeyBoard];
        [self addSubview:self.numAndCapitalLetterKeyboard];
    }
    return self;
}


/**
 当键盘再次展示时

 @param newSuperview newSuperview
 */
- (void)willMoveToSuperview:(UIView *)newSuperview
{
    [super willMoveToSuperview:newSuperview];
}


#pragma mark - private

/**
 展示当前类型的键盘
 */
- (void)showKeyBoard
{
    for (NSNumber *typeNumber in self.typeDictionary.allKeys) {
        UIView *keyBoard = [self.typeDictionary objectForKey:typeNumber];
        keyBoard.hidden = (typeNumber.integerValue != self.keyboardType);
    }
}

#pragma mark - set & get

- (void)setKeyboardType:(YFCustomKeyboardType)keyboardType
{
    _keyboardType = keyboardType;
    [self showKeyBoard];
}

- (NSDictionary *)typeDictionary
{
    if (!_typeDictionary) {
        _typeDictionary = @{@(YFCustomKeyboardTypeProvince):self.provinceKeyBoard,
                            @(YFCustomKeyboardTypeNumAndCapitalLetter):self.numAndCapitalLetterKeyboard
                            };
    }
    return _typeDictionary;
}


-(YFProvinceKeyboard *)provinceKeyBoard{
    if (!_provinceKeyBoard) {
         __weak __typeof(self)weakSelf = self;
        _provinceKeyBoard = [[YFProvinceKeyboard alloc] initWithFrame:self.bounds];
        [_provinceKeyBoard setDidChangeKeyboardTypeBlcok:^{
             weakSelf.keyboardType = YFCustomKeyboardTypeNumAndCapitalLetter;
        }];
    }
    return _provinceKeyBoard;
}

-(YFNumAndCapitalLetterKeyboard *)numAndCapitalLetterKeyboard{
    if (!_numAndCapitalLetterKeyboard) {
         __weak __typeof(self)weakSelf = self;
        _numAndCapitalLetterKeyboard = [[YFNumAndCapitalLetterKeyboard alloc] initWithFrame:self.bounds];
        [_numAndCapitalLetterKeyboard setDidChangeKeyboardTypeBlcok:^{
            weakSelf.keyboardType = YFCustomKeyboardTypeProvince;
        }];
    }
    return _numAndCapitalLetterKeyboard;
}

@end
