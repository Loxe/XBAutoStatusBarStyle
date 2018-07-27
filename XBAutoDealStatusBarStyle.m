//
//  XBAutoDealStatusBarStyle.m
//  TBJPro
//
//  Created by Binbin on 2018/7/26.
//  Copyright © 2018年 iloxe.com All rights reserved.
//

#import "XBAutoDealStatusBarStyle.h"
#import <objc/runtime.h>
static char AutoDealStatusBarStyleKey;
@implementation UIViewController (XBAutoDealStatusBarStyle)

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        
        SEL originalSelector = @selector(viewDidAppear:);
        SEL swizzledSelector = @selector(tbj_viewDidAppear:);
        
        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
        

        BOOL success = class_addMethod(class, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
        if (success) {
            class_replaceMethod(class, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}

- (void)tbj_viewDidAppear:(BOOL)animated
{
    if (self.autoDealStatusBarStyle) {
        [self setStatusBarStyle];
    }
    [self tbj_viewDidAppear:animated];
}

- (void)setStatusBarStyle {
    UIGraphicsBeginImageContext(CGSizeMake(kScreenWidth, 20));
    [self.view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *viewImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    UIColor *mostColor = [self mostColor:viewImage];
    if ([self isDarkColor:mostColor]) {
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent animated:YES];
    } else {
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
    }
}

-(BOOL)isDarkColor:(UIColor *)newColor{
    if (!newColor) {
        return NO;
    }
    const CGFloat *componentColors = CGColorGetComponents(newColor.CGColor);
    CGFloat colorBrightness = (componentColors[0] * 255 * 0.299) + (componentColors[1] * 255 * 0.587) + (componentColors[2] * 255 * 0.114);
    if (colorBrightness < 192){
        return YES;
    } else {
        return NO;
    }
    
}

CGContextRef CreateARGBBitmapContext(CGSize size)
{
    CGContextRef    context = NULL;
    CGColorSpaceRef colorSpace;
    void *          bitmapData;
    unsigned long   bitmapByteCount;
    unsigned long   bitmapBytesPerRow;
    
    // 获取图片宽高
    size_t pixelsWide = size.width;
    size_t pixelsHigh = size.height;
    
    //根据图片宽度设置缓存空间的大小 每个像素点是RGBA所以要*4
    bitmapBytesPerRow   = (pixelsWide * 4);
    bitmapByteCount     = (bitmapBytesPerRow * pixelsHigh);
    
    //使用通用RGB颜色空间
    colorSpace = CGColorSpaceCreateDeviceRGB();
    
    if (colorSpace == NULL)
    {
        fprintf(stderr, "Error allocating color space\n");
        return NULL;
    }
    
    // 配置一个读取context的颜色值用的图像数据内存空间。
    bitmapData = malloc( bitmapByteCount );
    if (bitmapData == NULL)
    {
        fprintf (stderr, "Memory not allocated!");
        CGColorSpaceRelease( colorSpace );
        return NULL;
    }

    context = CGBitmapContextCreate (bitmapData,
                                     pixelsWide,
                                     pixelsHigh,
                                     8,      // 8位
                                     bitmapBytesPerRow,
                                     colorSpace,
                                     kCGImageAlphaPremultipliedLast);
    if (context == NULL)
    {
        free (bitmapData);
        fprintf (stderr, "Context not created!");
    }
    
    CGColorSpaceRelease( colorSpace );
    return context;
}

-(UIColor*)mostColor:(UIImage *)image{
    
    //第一步 先把图片缩小 加快计算速度. 但越小结果误差可能越大
    CGSize thumbSize=CGSizeMake(50, 50);
    
    //图片缩小到指定尺寸
    UIGraphicsBeginImageContext(thumbSize);
    [image drawInRect:CGRectMake(0, 0, thumbSize.width, thumbSize.height)];
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    
    CGContextRef context = CreateARGBBitmapContext(thumbSize);
    //将图片会知道context上面
    CGRect drawRect = CGRectMake(0, 0, thumbSize.width, thumbSize.height);
    CGContextDrawImage(context, drawRect, image.CGImage);
    
    //第二步 取每个点的像素值
    unsigned char* data = CGBitmapContextGetData(context);
    if (data == NULL) return nil;
    
    NSCountedSet *cls= [NSCountedSet setWithCapacity:thumbSize.width*thumbSize.height];
    
    for (int x=0; x<thumbSize.height; x++) {
        for (int y=0; y<thumbSize.width; y++) {
            int offset = 4*(x*thumbSize.width+y);
            
            int red = data[offset];
            int green = data[offset+1];
            int blue = data[offset+2];
            int alpha =  data[offset+3];
            
            NSArray *clr=@[@(red),@(green),@(blue),@(alpha)];
            [cls addObject:clr];
            
        }
    }
    CGContextRelease(context);
    
    
    //第三步 找到出现次数最多的那个颜色
    NSEnumerator *enumerator = [cls objectEnumerator];
    NSArray *curColor = nil;
    
    NSArray *MaxColor=nil;
    NSUInteger MaxCount=0;
    
    while ( (curColor = [enumerator nextObject]) != nil )
    {
        NSUInteger tmpCount = [cls countForObject:curColor];
        if ( tmpCount < MaxCount ) continue;
        MaxCount=tmpCount;
        MaxColor=curColor;
    }

    return [UIColor colorWithRed:([MaxColor[0] intValue]/255.0f) green:([MaxColor[1] intValue]/255.0f) blue:([MaxColor[2] intValue]/255.0f) alpha:([MaxColor[3] intValue]/255.0f)];
}

- (BOOL)autoDealStatusBarStyle
{
    return [objc_getAssociatedObject(self, &AutoDealStatusBarStyleKey) boolValue];
}

- (void)setAutoDealStatusBarStyle:(BOOL)autoDealStatusBarStyle
{
    objc_setAssociatedObject(self, &AutoDealStatusBarStyleKey, @(autoDealStatusBarStyle), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

