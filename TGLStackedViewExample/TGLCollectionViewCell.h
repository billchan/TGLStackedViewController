//
//  TGLCollectionViewCell.h
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

#import <UIKit/UIKit.h>
#import "ShadowLoyaltyTintCardViewController.h"

@interface TGLCollectionViewCell : UICollectionViewCell
{
    CGFloat screenWidth;
    ShadowLoyaltyTintCardViewController *shadowLoyaltyTintCardViewController;
}
@property (copy, nonatomic) NSString *title;
@property (copy, nonatomic) UIColor *color;

@property (weak, nonatomic) IBOutlet UIImageView *imageViewBG;
@property (weak, nonatomic) IBOutlet UIView * viewBack;
//@property (weak, nonatomic) IBOutlet UIView * viewFrontTemplate;

@property (weak, nonatomic) IBOutlet UIButton *btnFlip;

- (void)flipTransitionWithOptions:(UIViewAnimationOptions)options halfway:(void (^)(BOOL finished))halfway completion:(void (^)(BOOL finished))completion;

- (ShadowLoyaltyTintCardViewController *)shadowLoyaltyTintCardViewController;

- (void)setShadowLoyaltyTintCardViewController:(ShadowLoyaltyTintCardViewController *)newValue;

@end
