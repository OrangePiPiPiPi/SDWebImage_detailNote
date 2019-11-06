//
//  YFNumAndCapitalLetterKeyboard.m
//
//  Created by fank on 2019/10/16.
//  Copyright © 2019 fank. All rights reserved.
//

#import "YFNumAndCapitalLetterKeyboard.h"
#import "YFKeyboardButton.h"
#import "UIResponder+YFFirstResponder.h"
#import "UIColor+EMColor.h"

@interface YFNumAndCapitalLetterKeyboard (){
    CGFloat _kScreenWidth;//屏幕宽度
    CGFloat _btnVerticalMargin;//键盘按钮垂直间距
    CGFloat _topViewHeight;//关闭键盘按钮container高度
    UIView *_topCloseView;//关闭键盘按钮containerView
    UIButton *_closeBtn;//关闭键盘按钮
    CGFloat _commonButtonFont;//按钮字体大小
    UIButton *_changeTypeBtn;//切换键盘按钮
}
//所有高度
@property (nonatomic,assign)CGFloat buttonHeight;
//输入按钮宽度
@property (nonatomic,assign)CGFloat buttonWeight;
//按钮之前的间距
@property (nonatomic,assign)CGFloat buttonSpace;

@property (nonatomic,strong)NSArray *firstRowTitles;

@property (nonatomic,strong)NSArray *secondRowTitles;

@property (nonatomic,strong)NSArray *thirdRowTitles;

@property (nonatomic,strong)NSArray *fourRowTitles;

@end

@implementation YFNumAndCapitalLetterKeyboard

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor colorWithHex:@"#f1f1f1"];
        
        self.firstRowTitles = @[@"1",@"2",@"3",@"4",@"5",@"6",@"7",@"8",@"9",@"0"];
        self.secondRowTitles  = @[@"Q",@"W",@"E",@"R",@"T",@"Y",@"U",@"O",@"P",@"字"];
        self.thirdRowTitles = @[@"A",@"S",@"D",@"F",@"G",@"H",@"J",@"K",@"L"];
        self.fourRowTitles = @[@"Z",@"X",@"C",@"V",@"B",@"N",@"M",@"delete"];
        
        self.buttonSpace = 5;
        _topViewHeight = 35;
        _btnVerticalMargin = 10;
        _commonButtonFont = 20.0f;
        _kScreenWidth = [UIScreen mainScreen].bounds.size.width;
        self.buttonHeight = (frame.size.height - _topViewHeight - _btnVerticalMargin*4)/4;
        self.buttonWeight = [self btnWidth];
        
        [self createKeyBoard];
    }
    return self;
}


- (void)createKeyBoard
{
    _topCloseView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, _kScreenWidth, _topViewHeight)];
    _topCloseView.backgroundColor = [UIColor colorWithHex:@"#e5e5e5"];
    [self addSubview:_topCloseView];
    
    CGFloat btnW = 2*_topViewHeight;
    _closeBtn = [[UIButton alloc] initWithFrame:CGRectMake(_kScreenWidth-btnW, 0, btnW,_topCloseView.frame.size.height)];
    [_closeBtn setTitle:@"关闭" forState:UIControlStateNormal];
    [_closeBtn setTitleColor:[UIColor colorWithHex:@"#4897ff"] forState:UIControlStateNormal];
    [_closeBtn.titleLabel setFont:[UIFont systemFontOfSize:15]];
    [_closeBtn addTarget:self action:@selector(colseBtnClick) forControlEvents:UIControlEventTouchUpInside];
    [_topCloseView addSubview:_closeBtn];
    
    _changeTypeBtn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, btnW,_topCloseView.frame.size.height)];
    [_changeTypeBtn setTitle:@"切换" forState:UIControlStateNormal];
    [_changeTypeBtn setTitleColor:[UIColor colorWithHex:@"#4897ff"] forState:UIControlStateNormal];
    [_changeTypeBtn.titleLabel setFont:[UIFont systemFontOfSize:15]];
    [_changeTypeBtn addTarget:self action:@selector(changeKeyboardTypeBtnClick) forControlEvents:UIControlEventTouchUpInside];
    [_topCloseView addSubview:_changeTypeBtn];
    
    [self createFirstRow:CGRectGetMaxY(_topCloseView.frame)+5];
}

//第一行的view
- (void)createFirstRow:(CGFloat)offsetY
{
    CGFloat secondOffsetY = 0.0;
    //距两边间距
    CGFloat sideSpace = 2;
    for (int i = 0; i < self.firstRowTitles.count; i++) {
        YFKeyboardButton *btn = [self createBtn];
        [btn setTitle:self.firstRowTitles[i] forState:UIControlStateNormal];
        btn.frame = CGRectMake(sideSpace+i*(self.buttonSpace+self.buttonWeight), offsetY, self.buttonWeight, self.buttonHeight);
        btn.KeyboardButtonType = YFKeyboardButtonTypeNumber;
        btn.titleLabel.font = [UIFont systemFontOfSize:_commonButtonFont];
        [self addSubview:btn];
        secondOffsetY = CGRectGetMaxY(btn.frame) + _btnVerticalMargin;
    }
   [self createSecondRow:secondOffsetY];
}

//第二行的view
- (void)createSecondRow:(CGFloat)offsetY
{
    CGFloat thirdOffsetY = 0.0;
    //距两边间距
    CGFloat sideSpace = (_kScreenWidth-self.secondRowTitles.count*self.buttonWeight - (self.secondRowTitles.count-1)*self.buttonSpace)/2;
    for (int i = 0; i < self.secondRowTitles.count; i++) {
        YFKeyboardButton *btn = [self createBtn];
        [btn setTitle:self.secondRowTitles[i] forState:UIControlStateNormal];
        btn.frame = CGRectMake(sideSpace+i*(self.buttonSpace+self.buttonWeight), offsetY, self.buttonWeight, self.buttonHeight);
        btn.KeyboardButtonType = YFKeyboardButtonTypeLetter;
        btn.titleLabel.font = [UIFont systemFontOfSize:_commonButtonFont];
        if ([self.secondRowTitles[i] isEqualToString:@"字"]) {
            [btn setTitleColor:[UIColor colorWithHex:@"#e5e5e5"] forState:UIControlStateNormal];
            [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateSelected];
        }
        [self addSubview:btn];
        thirdOffsetY = CGRectGetMaxY(btn.frame) + _btnVerticalMargin;
    }
    [self createThirdRow:thirdOffsetY];
}

//第三行的view
- (void)createThirdRow:(CGFloat)offsetY
{
    CGFloat fourOffsetY = 0.0;
    //距两边间距
    CGFloat sideSpace = (_kScreenWidth-self.thirdRowTitles.count*self.buttonWeight - (self.thirdRowTitles.count-1)*self.buttonSpace)/2;
    for (int i = 0; i < self.thirdRowTitles.count; i++) {
        YFKeyboardButton *btn = [self createBtn];
        [btn setTitle:self.thirdRowTitles[i] forState:UIControlStateNormal];
        btn.frame = CGRectMake(sideSpace+i*(self.buttonSpace+self.buttonWeight), offsetY, self.buttonWeight, self.buttonHeight);
        btn.KeyboardButtonType = YFKeyboardButtonTypeLetter;
        btn.titleLabel.font = [UIFont systemFontOfSize:_commonButtonFont];
        [self addSubview:btn];
        fourOffsetY = CGRectGetMaxY(btn.frame) + _btnVerticalMargin;
    }
    [self createFourthRow:fourOffsetY];
}

//第四行的view
- (void)createFourthRow:(CGFloat)offsetY
{
    //距两边间距
    CGFloat sideSpace = (_kScreenWidth-self.fourRowTitles.count*self.buttonWeight - (self.fourRowTitles.count-1)*self.buttonSpace)/2;
    for (int i = 0; i < self.fourRowTitles.count; i++) {
        YFKeyboardButton *btn = [self createBtn];
        [self addSubview:btn];
        if (i == self.fourRowTitles.count-1) {
            btn.KeyboardButtonType = YFKeyboardButtonTypeDelete;
            CGFloat tempBtnW = 2*_buttonWeight;
              btn.frame = CGRectMake(_kScreenWidth-10-tempBtnW, offsetY, tempBtnW, self.buttonHeight);
            btn.backgroundColor = [UIColor yellowColor];
        }else{
            [btn setTitle:self.fourRowTitles[i] forState:UIControlStateNormal];
            btn.KeyboardButtonType = YFKeyboardButtonTypeLetter;
            btn.frame = CGRectMake(sideSpace*0.5+i*(self.buttonSpace+self.buttonWeight), offsetY, self.buttonWeight, self.buttonHeight);
            btn.titleLabel.font = [UIFont systemFontOfSize:_commonButtonFont];
        }
    }
}

- (YFKeyboardButton *)createBtn
{
    YFKeyboardButton *btn = [YFKeyboardButton buttonWithType:UIButtonTypeCustom];
    [btn addTarget:self action:@selector(btnClick:) forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

//切换键盘
-(void)changeKeyboardTypeBtnClick
{
    if (self.didChangeKeyboardTypeBlcok) {
        self.didChangeKeyboardTypeBlcok();
    }
}

//关闭键盘
-(void)colseBtnClick
{
    UIView <UITextInput> *textView = [UIResponder firstResponderTextView];
    [textView resignFirstResponder];
}

- (void)btnClick:(YFKeyboardButton *)btn
{
    if ([btn.titleLabel.text isEqualToString:@"字"]) {
        return;
    }
    UIView <UITextInput> *textView = [UIResponder firstResponderTextView];
    switch (btn.KeyboardButtonType) {
        case YFKeyboardButtonTypeNumber:{
            [self inputText:btn.titleLabel.text];
        }
            break;
        case YFKeyboardButtonTypeLetter:{
            [self inputText:btn.titleLabel.text];
        }
            break;
        case YFKeyboardButtonTypeDelete:{
            [textView deleteBackward];
        }
            break;
        default:
            break;
    }
}

- (void)inputText:(NSString *)text
{
    [UIResponder inputText:text];
}

/**
 按钮的宽度
 
 @return 按钮的宽度
 */
- (CGFloat)btnWidth
{
    return (_kScreenWidth-self.buttonSpace*self.firstRowTitles.count)/self.firstRowTitles.count;
}

/**
 设置关闭按钮文字颜色
 */
-(void)setCloseBtnTitleColor:(UIColor *)closeBtnTitleColor{
    _closeBtnTitleColor = closeBtnTitleColor;
    [_closeBtn setTitleColor:closeBtnTitleColor forState:UIControlStateNormal];
    [_changeTypeBtn setTitleColor:closeBtnTitleColor forState:UIControlStateNormal];
}

/**
 设置关闭按钮所在view颜色
 */
-(void)setCloseViewBgColor:(UIColor *)closeViewBgColor{
    _closeViewBgColor = closeViewBgColor;
    _topCloseView.backgroundColor = closeViewBgColor;
}

@end
