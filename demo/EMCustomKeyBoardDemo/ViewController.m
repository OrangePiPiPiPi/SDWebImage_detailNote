//
//  ViewController.m
//  EMCustomKeyBoardDemo
//
//  Created by zhaochen on 2019/1/7.
//  Copyright © 2019年 zhaochen. All rights reserved.
//

#import "ViewController.h"
#import "YFCustomKeyboardView.h"
#import "YFShareTool.h"
#import "UIImageView+WebCache.h"

@interface ViewController ()
{
    UIScrollView *_contentScrollView;
}

@property (weak, nonatomic) IBOutlet UITextField *numberTF;

@property (weak, nonatomic) IBOutlet UITextField *asciiTF;

@property (weak, nonatomic) IBOutlet UITextField *passwordTF;

@property (weak, nonatomic) IBOutlet UITextField *stockInputTF;

@property (weak, nonatomic) IBOutlet UITextField *stockPositionTF;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self numberKeyboard];
    [self asciiKeyboard];
    [self secureKeyboard];
    [self stockInputKeyboard];
    [self stockPositionKeyboard];
    
    [self setUpView];
}














-(void)setUpView{
    
    CGFloat scrollViewW = [UIScreen mainScreen].bounds.size.width;
    CGFloat screenH = [UIScreen mainScreen].bounds.size.height;
    _contentScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, scrollViewW, screenH)];
    _contentScrollView.backgroundColor = [UIColor yellowColor];
    [self.view addSubview:_contentScrollView];
    
    
    UIImageView *imgView = [[UIImageView alloc] initWithFrame:CGRectMake(100, 100, 50, 50)];
   // [imgView sd_setImageWithURL:[NSURL URLWithString:@"http://180.153.42.245:88/apk/images/yiqi/banner_img1.png"]];
    
    [imgView sd_setImageWithURL:[NSURL URLWithString:@"http://180.153.42.245:88/apk/images/yiqi/banner_img1.png"] placeholderImage:[UIImage imageNamed:@"icon_shop_empty"] options:SDWebImageRefreshCached];
    [_contentScrollView addSubview:imgView];
    
    
    UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(300, 200, 50, 50)];
    [btn setTitle:@"分享" forState:UIControlStateNormal];
    btn.backgroundColor =[UIColor redColor];
    [btn addTarget:self action:@selector(shareBtnClick) forControlEvents:UIControlEventTouchUpInside];
    [_contentScrollView addSubview:btn];
    
    
    UIButton *btn2 = [[UIButton alloc] initWithFrame:CGRectMake(300, 300, 50, 50)];
    [btn2 setTitle:@"分享2" forState:UIControlStateNormal];
    btn2.backgroundColor =[UIColor redColor];
    [btn2 addTarget:self action:@selector(shareBtnClick2) forControlEvents:UIControlEventTouchUpInside];
    [_contentScrollView addSubview:btn2];
    
    for (NSInteger i=0; i<28; i++) {
        UILabel *lab = [[UILabel alloc] initWithFrame:CGRectMake(30, 10+i*70, scrollViewW/2, 70)];
        lab.backgroundColor = [UIColor whiteColor];
        lab.text = @"哈哈哈哈哈哈哈哈哈";
        [_contentScrollView addSubview:lab];
        if (i==27) {
             lab.text = @"我是最后一个lab";
            _contentScrollView.contentSize = CGSizeMake(scrollViewW, CGRectGetMaxY(lab.frame)+30);
        }
    }
}

/***
 
 UIImage *mapViewImg = [_mapView takeSnapshot]; //截图
 UIImageView *mapImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(whiteView2.frame)+kSize(144)+kSize(48), _mapView.width, _mapView.height)];
 mapImgView.image = mapViewImg;
 UIScrollView *tempScrollView = _scrollView;
 [tempScrollView addSubview:mapImgView];
 
 NSString *filePath = [YFShareTool getScreenShotPathWithTargetScrollView:tempScrollView];
 
 if (!filePath) {
 NSLog(@"获取截图失败");
 return;
 }
 NSURL *shareImgUlr = [NSURL fileURLWithPath:filePath];
 NSArray *activityItemsArray = @[shareImgUlr];
 [YFShareTool nstiveShare:activityItemsArray target:self success:^(BOOL isSuccess, NSString * _Nonnull message) {
 if (isSuccess) {
 NSLog(@"=====分享成功");
 [mapImgView removeFromSuperview];
 }else{
 NSLog(@"=====分享失败");
 [mapImgView removeFromSuperview];
 }
 }];
 

 **/


-(void)shareBtnClick{
    
    NSString *filePath = [YFShareTool getScreenShotPathWithTargetScrollView:_contentScrollView];
    
    if (!filePath) {
        NSLog(@"获取截图失败");
        return;
    }
    
    NSURL *shareImgUlr = [NSURL fileURLWithPath:filePath];
    
    
//    NSString *textToShare = @"ff";
//    UIImage *imageToShare = [UIImage imageNamed:@"icon_shop_empty.png"];
//    NSURL *urlToShare = [NSURL URLWithString:@"www.baidu.com"];
//    NSArray *items = @[textToShare,imageToShare,urlToShare];
     NSString * path = [[NSBundle mainBundle]pathForResource:@"icon_shop_empty" ofType:@"png"];
    NSURL *shareUrl1 = [NSURL fileURLWithPath:path];
    NSString *shareText = @"分享的标题";
    UIImage *shareImage = [UIImage imageNamed:@"icon_shop_empty.png"];
    NSURL *shareUrl = [NSURL URLWithString:@"https://www.jianshu.com/u/15d37d620d5b"];
    //NSURL *localImgUrl = [NSURL url];
    
   // NSString *fileUrl = [YFShareTool getScreenShotWithTargetScrollView:_contentScrollView];
    
    NSArray *activityItemsArray = @[shareImgUlr];
    [YFShareTool nstiveShare:activityItemsArray target:self success:^(BOOL isSuccess, NSString * _Nonnull message) {
        if (isSuccess) {
            NSLog(@"=====分享成功");
        }else{
            NSLog(@"=====分享失败");
        }
    }];
}

- (void)numberKeyboard
{
    YFCustomKeyboardView *keyboardView = [[YFCustomKeyboardView alloc] init];
    keyboardView.keyboardType = YFCustomKeyboardTypeNumAndCapitalLetter;;
    self.numberTF.inputView = keyboardView;
}

- (void)asciiKeyboard
{
    YFCustomKeyboardView *keyboardView = [[YFCustomKeyboardView alloc] init];
   // keyboardView.keyboardType = EMCustomKeyboardTypeASCII;
    self.asciiTF.inputView = keyboardView;
}


- (void)secureKeyboard
{
    self.passwordTF.secureTextEntry = YES;
    YFCustomKeyboardView *keyboardView = [[YFCustomKeyboardView alloc] init];
  //  keyboardView.keyboardType = EMCustomKeyboardTypeSecury;
    self.passwordTF.inputView = keyboardView;
}

- (void)stockInputKeyboard
{
    YFCustomKeyboardView *keyboardView = [[YFCustomKeyboardView alloc] init];
//    keyboardView.keyboardType = EMCustomKeyboardTypeStockInput;
     keyboardView.keyboardType = YFCustomKeyboardTypeProvince;
    self.stockInputTF.inputView = keyboardView;
}

- (void)stockPositionKeyboard
{
    YFCustomKeyboardView *keyboardView = [[YFCustomKeyboardView alloc] init];
  //  keyboardView.keyboardType = EMCustomKeyboardTypeStockPosition;
    //keyboardView.stockPositionBtnClickBlock = ^(EMKeyboardButtonType KeyboardButtonType) {
       
   // };
    self.stockPositionTF.inputView = keyboardView;
}

@end
