//
//  PatternLockViewController.m
//
//  Created by mxm on 2017/2/31.
//  Copyright © 2017年 mxm. All rights reserved.
//
//  手势锁

#import "XMPatternLockViewController.h"
//#import "Toast+UIView.h"

@interface XMPatternLockViewController ()
{
    NSMutableArray<UIImageView *> *_images;  //所有的点图片
    NSMutableArray<UIImageView *> *_selectedImages;//所有已选中的点，有顺序之分
    CGPoint _endPoint;          //手指当前的触点坐标
    UIImageView *_imageView;    //用来显示动态绘画的手势图片
    CGRect _clipRect;           //画图时裁剪区域
    BOOL _lockShowing;          //是否正在显示错误的手势
    UILabel *_labShowError;     //错误提示
    
    UIColor *_lineColor;        //正在画的线条颜色
    
    UIColor *_lineNormalColor;  //正常线条的颜色
    UIImage *_image;            //默认点图片
    UIImage *_highlightedImage; //高亮点图片
    
    UIColor *_lineErrorColor;   //密码错误时线条的颜色
    UIImage *_errorImage;       //密码错误时的点图片
    
    NSInteger _password;        //设置密码时用来保存第一次输入的密码
    short _errorCount;          //剩余的密码输入次数
}

@end

@implementation XMPatternLockViewController
#pragma mark - 生命周期
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (instancetype)initWithMode:(PatternLockMode)mode
{
    self = [super init];
    if (self) {
        _mode = mode;
        if (PatternLockModeSet == _mode) {
            self.title = @"绘制解锁图案";
        }
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    _images = [NSMutableArray arrayWithCapacity:9];
    _selectedImages = [NSMutableArray arrayWithCapacity:9];
    _lockShowing = NO;
    _errorCount = 5;//默认5次机会
    _imageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:_imageView];
    
    _lineNormalColor = [UIColor colorWithRed:0 green:127/255.0 blue:269/255.0 alpha:1];
    _lineErrorColor = [UIColor redColor];
    _lineColor = _lineNormalColor;
    
    CGFloat screenWidth = self.view.bounds.size.width;
    CGFloat screenHeight = self.view.bounds.size.height;
    
    _image = [self imageWithColor:[UIColor grayColor] size:CGSizeMake(20, 20)];
    _highlightedImage = [self imageWithColor:_lineNormalColor size:CGSizeMake(20, 20)];
    _errorImage = [self imageWithColor:_lineErrorColor size:CGSizeMake(20, 20)];
    
    CGFloat imgW = 40;
    CGFloat space = (screenWidth - 3 * imgW)/4;//点之间的空隙
    CGFloat y = screenHeight - 140 - 3 * imgW - 2*space;
    
    UIImageView *iv;
    for (int i=0; i<9; i++) {
        iv = [[UIImageView alloc] initWithFrame:CGRectMake(
               space*(i%3+1) + i%3*imgW,
               y + i/3*imgW + i/3*space, imgW, imgW)];
        iv.image = _image;
        iv.highlightedImage = _highlightedImage;
        iv.tag = i+1;//从1开始，方便计算密码
        iv.contentMode = UIViewContentModeCenter;
        [_images addObject:iv];
        [_imageView addSubview:iv];
    }
    
    //裁剪区域刚好包含9个点就行了
    _clipRect.origin = _images.firstObject.frame.origin;
    _clipRect.size.width = screenWidth - 2*space;
    _clipRect.size.height = _clipRect.size.width;
    
    _labShowError = [[UILabel alloc] initWithFrame:CGRectMake(0, 100, screenWidth, 66)];
    _labShowError.textColor = [UIColor redColor];
    _labShowError.textAlignment = NSTextAlignmentCenter;
    _labShowError.font = [UIFont systemFontOfSize:18];
    _labShowError.numberOfLines = 0;
    [self.view addSubview:_labShowError];
    
    if (PatternLockModeCheck == _mode) {
        _labShowError.text = @"绘制解锁图案";
//        _labShowError.hidden = YES;
        //忘记手势密码按钮
        UIButton *btnForget = [UIButton buttonWithType:UIButtonTypeCustom];
        CGRect frame = self.view.bounds;
        frame.origin.x = 60;
        frame.origin.y -= 70 + 44;
        frame.size.height = 44;
        frame.size.width -= 60 * 20;
        btnForget.frame = frame;
        [self.view addSubview:btnForget];//这个放在添加约束之前
        [btnForget setTitle:@"忘记图案" forState:UIControlStateNormal];
        [btnForget setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
        [btnForget addTarget:self action:@selector(forgetPassword) forControlEvents:UIControlEventTouchUpInside];
    } else {
        _labShowError.text = @"绘制新解锁图案";
    }
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

#pragma mark - 响应者方法
//开始手势
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self touchBegan:[touches anyObject] withEvent:event];
    [super touchesBegan:touches withEvent:event];//防止其他按钮点击无效，这个要调用
}

//移动中触发，画线过程中会一直调用画线方法
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self touchMoved:[touches anyObject] withEvent:event];
    [super touchesMoved:touches withEvent:event];
}
//手势结束触发
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    if (PatternLockModeCheck == _mode) {
        [self checkPassword];
    } else {
        [self checkTwiceEnterPassword];
    }
    [super touchesEnded:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self clearPattern];
    [super touchesCancelled:touches withEvent:event];
}

#pragma mark - 手势事件方法, 自己写的
- (void)touchBegan:(UITouch *)touch withEvent:(UIEvent *)event
{
    if (!touch) return;
    
    if (_lockShowing) {
        [self clearPattern];
    }
    for (UIImageView *iv in _images) {
        if ([iv pointInside:[touch locationInView:iv] withEvent:event]) {//判断按键坐标是否在手势开始范围内,是则为选中的开始按键
            [_selectedImages addObject:iv];
            iv.highlighted = YES;
            break;
        }
    }
}

- (void)touchMoved:(UITouch *)touch withEvent:(UIEvent *)event
{
    if (!touch) return;
    
    _endPoint = [touch locationInView:_imageView];
    for (UIImageView *img in _images) {
        if ([img pointInside:[touch locationInView:img] withEvent:event]) {//点中了
            if (!img.highlighted) {//在这之前未点中
                //检测这条线上有没有经过其他未选中的点
                if (_selectedImages.count > 0) {
                    CGPoint center1 = img.center;
                    CGPoint center2 = _selectedImages.lastObject.center;//上一个选中点的中心
                    CGPoint center = CGPointMake((center1.x + center2.x)/2, (center1.y + center2.y)/2);//这条线的中心点
                    for (UIImageView *imgPre in _images) {
                        if (!imgPre.highlighted && CGPointEqualToPoint(imgPre.center, center)) {
                            imgPre.highlighted = YES;//有经过的点就选中
                            [_selectedImages addObject:imgPre];
                            break;
                        }
                    }
                }
                //选中当前点
                img.highlighted = YES;
                [_selectedImages addObject:img];
            }
            break;
        }
    }
    _imageView.image = [self drawLine];//每次移动过程中都要调用这个方法，把画出的图输出显示
}

- (UIImage *)drawLine
{
    if (_selectedImages.count <= 0) return nil;
    
    UIGraphicsBeginImageContextWithOptions(_imageView.frame.size, NO, 0);//设置画图的大小为imageview的大小
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(context, 4);//线条粗细
    CGContextSetStrokeColorWithColor(context, _lineColor.CGColor);
    
    CGContextAddRect(context, _clipRect);//设置裁剪区域，防止线条超出范围
    CGContextClip(context);//裁剪
//    UIRectClip(_clipRect);//裁剪，等于上面两步
    
    //以下部分超出裁剪区域的会自动裁剪掉，不用自己去裁剪
    CGPoint point = _selectedImages.firstObject.center;
    CGContextMoveToPoint(context, point.x, point.y);//设置画线起点
    //从起点画线到选中的按键中心，并切换画线的起点
    for (NSUInteger i = 1, count = _selectedImages.count; i < count; ++i) {
        point = _selectedImages[i].center;
        CGContextAddLineToPoint(context, point.x, point.y);
        CGContextMoveToPoint(context, point.x, point.y);//拆分成多条线，线条的宽度才可随意设置
    }
    //画移动中的最后一条线
    CGContextAddLineToPoint(context, _endPoint.x, _endPoint.y);
    //填充颜色
    CGContextStrokePath(context);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();//画图输出
    UIGraphicsEndImageContext();//结束画线
    return image;
}

//清空图形
- (void)clearPattern
{
    if (_lockShowing) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self];
    }
    _imageView.image = nil;
    for (UIImageView *iv in _selectedImages) {
        iv.highlighted = NO;
        iv.highlightedImage = _highlightedImage;
    }
    [_selectedImages removeAllObjects];
    _lineColor = _lineNormalColor;
    _lockShowing = NO;
}

NS_INLINE
NSInteger GetPatternPassword(NSArray *selectedImages)//获取手势密码
{
    NSInteger pwd = 0;
    for (UIImageView *iv in selectedImages) {//组装密码，9位数int类型
        pwd = pwd*10 + iv.tag;
    }
    return pwd;
}

//检查密码
- (void)checkPassword
{
    NSInteger pwd = GetPatternPassword(_selectedImages);
    if (0 == pwd) return;//没有选中任何点
    
    if (pwd == _rightPassword) { //密码正确
        [self clearPattern];
        if ([_delegate respondsToSelector:@selector(patternLockViewControllerDidCheckCorrect:)]) {
            [_delegate patternLockViewControllerDidCheckCorrect:self];
        }
//        [self dismissViewControllerAnimated:NO completion:nil];
        return;
    }
    --_errorCount;
    if (_errorCount < 1) {//已经没有机会了，直接退出登录
        [self logout];
//        if ([_delegate respondsToSelector:@selector(patternLockViewControllerErrorFrequently:)]) {
//            [_delegate patternLockViewControllerErrorFrequently:self];
//        }
        [self clearPattern];
        return;
    }
    NSString *format = @"图案绘制错误！您还剩%d次尝试机会";
    _labShowError.text = [NSString stringWithFormat:format, _errorCount];
    [self showErrorState];
}

//检查两次输入的密码
- (void)checkTwiceEnterPassword
{
    NSInteger pwd = GetPatternPassword(_selectedImages);
    if (0 == pwd) return;//没有选中任何点
    
    if (0 == _password) {//第一次输入
        if (pwd < 1000) {//连线少于4个点
            _labShowError.text = @"至少连接4个点，请重试。";//提示
            [self showErrorState];
        } else {
            _password = pwd;
            _labShowError.text = @"再次绘制图案进行确认";
            [self clearPattern];//清空，准备第二次绘制
        }
        return;
    }
    if (pwd == _password) {//第二次输入
        NSLog(@"两次输入的密码相同");
        [self clearPattern];
//        _endPoint = _selectedImages.lastObject.center;//切除尾巴
//        _imageView.image = [self drawLine];//重新生成图片，其他的状态不变
        //保存密码
        if ([_delegate respondsToSelector:@selector(patternLockViewController:completeGetPassword:)]) {
            [_delegate patternLockViewController:self completeGetPassword:_password];
        }
        //显示密码设置成功
        
        //延迟退出
//        [self dismissViewControllerAnimated:NO completion:nil];
    } else {
        _labShowError.text = @"绘制的图案不一致！请重试。";
        [self showErrorState];
    }
}

//显示错误状态
- (void)showErrorState
{
    _labShowError.hidden = NO;
    //添加一个抖动动画
    CABasicAnimation* shake = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
    shake.fromValue = [NSNumber numberWithFloat:-5];
    shake.toValue = [NSNumber numberWithFloat:5];
    shake.duration = 0.1;//执行时间
    shake.autoreverses = YES; //是否重复
    shake.repeatCount = 3;//次数
    [_labShowError.layer addAnimation:shake forKey:@"shakeAnimation"];
    
    //密码不正确，替换图形的颜色，显示几秒后清空
    for (UIImageView *iv in _selectedImages) {
        iv.highlighted = NO;
        iv.highlightedImage = _errorImage;
        iv.highlighted = YES;
    }
    _lineColor = _lineErrorColor;//线条颜色
    _endPoint = _selectedImages.lastObject.center;//切除尾巴
    _imageView.image = [self drawLine];
    
    _lockShowing = YES;
    [self performSelector:@selector(clearPattern) withObject:nil afterDelay:2];//2秒后清空
}

- (void)logout
{
    //弹出密码输入框
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"输入错误已超过5次！请重新登录。" message:nil preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) this = self;
    [ac addAction:[UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        if ([this.delegate respondsToSelector:@selector(patternLockViewControllerErrorFrequently:)]) {
            [this.delegate patternLockViewControllerErrorFrequently:self];
        }
    }]];
    [self presentViewController:ac animated:YES completion:nil];
}

#pragma mark - 点击事件方法
- (void)forgetPassword
{
    //弹出密码输入框[HelperMethod GetLocalizeTextForKey:@"用户验证"]
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"请输入密码" message:nil preferredStyle:UIAlertControllerStyleAlert];
    __block UITextField *txt;
    [ac addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.secureTextEntry = YES;
        txt = textField;
    }];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) this = self;
    [ac addAction:[UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        if ([this.rightUserPassword isEqualToString:txt.text]) {//密码正确
            if ([this.delegate respondsToSelector:@selector(patternLockViewControllerDidCheckCorrect:)]) {
                [this.delegate patternLockViewControllerDidCheckCorrect:this];
            }
        } else {
//            [this.view makeToast:@"密码错误"];
        }
        txt = nil;
    }]];
    [self presentViewController:ac animated:YES completion:nil];
}

//点图片生成，没人切图😂
- (UIImage *)imageWithColor:(UIColor *)color size:(CGSize)size
{
    if (!color || size.width <= 0 || size.height <= 0) return nil;
    CGRect rect = CGRectMake(0.0f, 0.0f, size.width, size.height);
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextFillEllipseInRect(context, rect);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@end
