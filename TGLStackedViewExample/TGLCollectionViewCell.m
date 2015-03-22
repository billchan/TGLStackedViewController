//
//  TGLCollectionViewCell.m
//  TGLStackedViewExample
//
//  Created by Tim Gleue on 07.04.14.
//  Copyright (c) 2014 Tim Gleue ( http://gleue-interactive.com )
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import <QuartzCore/QuartzCore.h>

#import "TGLCollectionViewCell.h"

#import "LoyaltyCardBackViewController.h"

#import "const.h"


@interface TGLCollectionViewCell ()

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *consHgh;

@end

@implementation TGLCollectionViewCell
@synthesize viewBack;

- (void)awakeFromNib {
    
    [super awakeFromNib];
    
    //    UIImage *image = [[UIImage imageNamed:@"Background"] resizableImageWithCapInsets:UIEdgeInsetsMake(10.0, 10.0, 10.0, 10.0)];
    
    //    self.imageView.image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    
    //    self.imageView.image = [UIImage imageNamed:@"kk"];
    //    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    //    self.imageView.backgroundColor = [UIColor whiteColor];
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    screenWidth = screenRect.size.width;
    self.consHgh.constant  = HGH_CARD/320. * screenWidth;
    
    self.imageView.tintColor = self.color;
    
    self.nameLabel.text = self.title;
    
//    [self bringSubviewToFront:self.nameLabel];
//    [self bringSubviewToFront:self.btnFlip];
}

#pragma mark - Accessors

- (void)setTitle:(NSString *)title {
    
    _title = [title copy];
    
    self.nameLabel.text = self.title;
}

- (void)setColor:(UIColor *)color {
    
    _color = [color copy];
    
    self.imageView.tintColor = self.color;
}

-(void)flipToFornt
{
    [self flipTransitionWithOptions:UIViewAnimationOptionTransitionFlipFromRight halfway:^(BOOL finished) {
        ///TODO: UI update
        viewBack.hidden = YES;
        self.imageViewBG.hidden = NO;
    } completion:nil];
}

- (IBAction)handleBtnFlip:(id)sender {
    
    ///lazy init flipped view
    if(!viewBack)
    {
        UIStoryboard * storyboardCard = [UIStoryboard storyboardWithName:@"StaticLoyalCard_card" bundle:nil];
        
        LoyaltyCardBackViewController *controller= [storyboardCard instantiateViewControllerWithIdentifier:@"backView"];

        viewBack = controller.view;
        
        viewBack.center = self.imageViewBG.center;
        
        viewBack.frame  = self.imageViewBG.frame;

        controller.consHgh.constant  = HGH_CARD/320. * screenWidth;

//        [self sendSubviewToBack:viewBack];
//        [self sendSubviewToBack:self.imageViewBG];
//        [self bringSubviewToFront:self.btnFlip];
        
        [self addSubview:viewBack];
        viewBack.hidden = YES;
        
        [controller.btnFlip addTarget:self action:@selector(flipToFornt) forControlEvents:UIControlEventTouchUpInside];
    }
    
    [self flipTransitionWithOptions:UIViewAnimationOptionTransitionFlipFromLeft halfway:^(BOOL finished) {
        ///TODO: UI update
        viewBack.hidden = NO;
        self.imageViewBG.hidden = YES;
    } completion:nil];
}

- (void)flipTransitionWithOptions:(UIViewAnimationOptions)options halfway:(void (^)(BOOL finished))halfway completion:(void (^)(BOOL finished))completion
{
    CGFloat degree = (options & UIViewAnimationOptionTransitionFlipFromRight) ? -M_PI_2 : M_PI_2;
    
    CGFloat duration = 0.4;
    CGFloat distanceZ = 2000;
    CGFloat translationZ = self.frame.size.width / 2;
    CGFloat scaleXY = (distanceZ - translationZ) / distanceZ;
    
    CATransform3D rotationAndPerspectiveTransform = CATransform3DIdentity;
    rotationAndPerspectiveTransform.m34 = 1.0 / -distanceZ; // perspective
    rotationAndPerspectiveTransform = CATransform3DTranslate(rotationAndPerspectiveTransform, 0, 0, translationZ);
    
    rotationAndPerspectiveTransform = CATransform3DScale(rotationAndPerspectiveTransform, scaleXY, scaleXY, 1.0);
    self.layer.transform = rotationAndPerspectiveTransform;
    
    [UIView animateWithDuration:duration / 2 animations:^{
        self.layer.transform = CATransform3DRotate(rotationAndPerspectiveTransform, degree, 0.0f, 1.0f, 0.0f);
    } completion:^(BOOL finished){
        if (halfway) halfway(finished);
        self.layer.transform = CATransform3DRotate(rotationAndPerspectiveTransform, -degree, 0.0f, 1.0f, 0.0f);
        [UIView animateWithDuration:duration / 2 animations:^{
            self.layer.transform = rotationAndPerspectiveTransform;
        } completion:^(BOOL finished){
            self.layer.transform = CATransform3DIdentity;
            if (completion) completion(finished);
        }];
    }];
}

-(UIView * )viewFrontTemplate
{
    if (!_viewFrontTemplate)
    {
        UIStoryboard * storyboardCard = [UIStoryboard storyboardWithName:@"StaticLoyalCard_card" bundle:nil];
        
        [self setShadowLoyaltyTintCardViewController: [storyboardCard instantiateViewControllerWithIdentifier:@"tintedPaymentCard"]];
        
        _viewFrontTemplate = [self shadowLoyaltyTintCardViewController].view;
        _viewFrontTemplate.frame  = CGRectMake(0, 0, screenWidth, HGH_CARD/320. * screenWidth);
//        _viewFrontTemplate.center = self.imageViewBG.center;
        
//        controller.consHgh.constant  = HGH_CARD/320. * screenWidth;
        
        [self addSubview:_viewFrontTemplate];
//        [self insertSubview:_viewFrontTemplate aboveSubview:self.btnFlip];
//        [_viewFrontTemplate layoutSubviews];
//        [_viewFrontTemplate layoutIfNeeded];
        
//        [_viewFrontTemplate setUserInteractionEnabled:YES];
    
//        CGPoint p = self.btnFlip.center;
//        
//        [self.btnFlip removeFromSuperview];
//        [self addSubview:self.btnFlip];
//        
//        self.btnFlip.center = CGPointMake(100, 100);
        
        [self.shadowLoyaltyTintCardViewController.btnFlip addTarget:self action:@selector(handleBtnFlip:) forControlEvents:UIControlEventTouchUpInside];
        
        self.shadowLoyaltyTintCardViewController.btnFlip.hidden = YES;
    }
//
//    [self bringSubviewToFront:self.btnFlip];
//    self.btnFlip.enabled = YES;
//    self.btnFlip.layer.zPosition = 1000;
    
    
    return _viewFrontTemplate;
    
    ///TODO: update field when layout
}
- (ShadowLoyaltyTintCardViewController *)shadowLoyaltyTintCardViewController {
    return shadowLoyaltyTintCardViewController;
}

- (void)setShadowLoyaltyTintCardViewController:(ShadowLoyaltyTintCardViewController *)newValue {
    shadowLoyaltyTintCardViewController = newValue;
}

@end
