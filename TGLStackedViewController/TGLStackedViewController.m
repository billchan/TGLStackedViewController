//
//  TGLStackedViewController.m
//  TGLStackedViewController
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

#import "TGLStackedViewController.h"
#import "TGLStackedLayout.h"
#import "TGLExposedLayout.h"

#define SCROLL_PER_FRAME 5.0
#define SCROLL_ZONE_TOP 100.0
#define SCROLL_ZONE_BOTTOM 100.0

typedef NS_ENUM(NSInteger, TGLStackedViewControllerScrollDirection) {

    TGLStackedViewControllerScrollDirectionNone = 0,
    TGLStackedViewControllerScrollDirectionDown,
    TGLStackedViewControllerScrollDirectionUp
};

@interface TGLStackedViewController ()

@property (assign, nonatomic) CGPoint stackedContentOffset;

@property (strong, nonatomic) UIView *movingView;
@property (strong, nonatomic) NSIndexPath *movingIndexPath;

@property (assign, nonatomic) TGLStackedViewControllerScrollDirection scrollDirection;
@property (strong, nonatomic) CADisplayLink *scrollDisplayLink;

@property (nonatomic, assign) CGPoint startCenter;
@property (nonatomic, assign) CGPoint startLocation;
@property (nonatomic, strong) UICollectionViewCell *movingCell;

@end

@implementation TGLStackedViewController

@synthesize stackedLayout = _stackedLayout;

- (void)setMaxExposedVelocity:(CGFloat)maxExposedVelocity {
    if (maxExposedVelocity > 1.0f) maxExposedVelocity = 1.0f;
    else if (maxExposedVelocity < 0) maxExposedVelocity = 0;
    _maxExposedVelocity = maxExposedVelocity;
}

- (UICollectionViewLayout *)collectionViewLayout {
    return self.collectionView.collectionViewLayout;
}

- (instancetype)init {

    self = [super init];
    
    if (self) [self initController];
    
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {

    self = [super initWithCoder:aDecoder];
    
    if (self) [self initController];
    
    return self;
}

- (instancetype)initWithCollectionViewLayout:(UICollectionViewLayout *)layout {
    
    self = [super initWithCollectionViewLayout:layout];

    if (self) [self initController];
    
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];

    if (self) [self initController];
    
    return self;
}

- (void)initController {
    
    _stackedLayout = [[TGLStackedLayout alloc] init];
    
    _exposedLayoutMargin = UIEdgeInsetsMake(40.0, 0.0, 0.0, 0.0);
    _exposedItemSize = CGSizeZero;
    _exposedTopOverlap = 20.0;
    _exposedBottomOverlap = 20.0;
    
    _layoutAnimationDuration = 0.5;
    _minOffsetForReset = 100;
    _maxExposedVelocity = 0.7;
}

- (TGLExposedLayout *)exposedLayout:(NSIndexPath *)exposedItemIndexPath {
    TGLExposedLayout *exposedLayout = [[TGLExposedLayout alloc] initWithExposedItemIndex:exposedItemIndexPath.item];
    
    exposedLayout.layoutMargin = self.exposedLayoutMargin;
    exposedLayout.itemSize = self.exposedItemSize;
    exposedLayout.topOverlap = self.exposedTopOverlap;
    exposedLayout.bottomOverlap = self.exposedBottomOverlap;

    return exposedLayout;
}

#pragma mark - View life cycle

- (void)loadView {
    
    [super loadView];

    self.collectionView.collectionViewLayout = self.stackedLayout;
    
    _moveLongPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleGesture:)];
    self.moveLongPressGestureRecognizer.delegate = self;
    
    _movePanGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleGesture:)];
    self.movePanGestureRecognizer.delegate = self;

    [self.collectionView addGestureRecognizer:self.moveLongPressGestureRecognizer];
    [self.collectionView addGestureRecognizer:self.movePanGestureRecognizer];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    
    [self.collectionView.collectionViewLayout invalidateLayout];
}

#pragma mark - Accessors

- (void)setExposedItemIndexPath:(NSIndexPath *)exposedItemIndexPath {
    [self setExposedItemIndexPath:exposedItemIndexPath withInitialVelocity:0];
}

- (void)setStackedLayoutWithInitialVelocity:(CGFloat)velocity fromY:(CGFloat)y {
    if (self.exposedItemIndexPath == nil) {
        return;
    }
    
    UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:self.exposedItemIndexPath];
    
    CGRect cellFrame = cell.frame;
    cellFrame.origin.y = y;
    cell.frame = cellFrame;
    
    [self setExposedItemIndexPath:nil withInitialVelocity:velocity];
}

- (void)setExposedItemIndexPath:(NSIndexPath *)exposedItemIndexPath withInitialVelocity:(CGFloat)velocity {
    [self willChangeValueForKey:@"exposedItemIndexPath"];
    if (![exposedItemIndexPath isEqual:_exposedItemIndexPath]) {
        
        if (exposedItemIndexPath) {
            
            // Select newly exposed item, possibly
            // deslecting the previous selection,
            // and animate to exposed layout
            //
            [self.collectionView selectItemAtIndexPath:exposedItemIndexPath animated:YES scrollPosition:UICollectionViewScrollPositionNone];
            
            self.stackedContentOffset = self.collectionView.contentOffset;
            
            TGLExposedLayout *exposedLayout = [self exposedLayout:exposedItemIndexPath];
            
            [UIView animateWithDuration:self.layoutAnimationDuration delay:0 usingSpringWithDamping:1 initialSpringVelocity:velocity options:0 animations:^{
                [self.collectionView setCollectionViewLayout:exposedLayout animated:YES];
            } completion:^(BOOL finished) {
                if (self.exposedItemIndexPathOnCompletion) {
                    self.exposedItemIndexPathOnCompletion(exposedItemIndexPath);
                }
            }];
            
        } else {
            
            // Deselect the currently exposed item
            // and animate back to stacked layout
            //
            [self.collectionView deselectItemAtIndexPath:self.exposedItemIndexPath animated:YES];
            
            self.stackedLayout.overwriteContentOffset = YES;
            self.stackedLayout.contentOffset = self.stackedContentOffset;
            
            // Issue #10: Collapsing on iOS 8
            //
            // NOTE: This solution produces a warning message
            //       "trying to load collection view layout
            //        data when layout is locked" but seems
            //       to work nevertheless.
            //
            [self.collectionView performBatchUpdates:^ {
                
                [UIView animateWithDuration:self.layoutAnimationDuration delay:0 usingSpringWithDamping:1 initialSpringVelocity:velocity options:0 animations:^{
                    [self.collectionView setContentOffset:self.stackedContentOffset animated:YES];
                    [self.collectionView setCollectionViewLayout:self.stackedLayout animated:YES];
                } completion:^(BOOL finished) {
                    if (self.exposedItemIndexPathOnCompletion) {
                        self.exposedItemIndexPathOnCompletion(exposedItemIndexPath);
                    }
                }];
                
            } completion:nil];
        }
        
        _exposedItemIndexPath = exposedItemIndexPath;
    }
    [self didChangeValueForKey:@"exposedItemIndexPath"];
}

#pragma mark - CollectionViewDataSource protocol

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    
    // Currently, only one single section is
    // supported, therefore MUST NOT be != 1
    //
    return 1;
}

#pragma mark - CollectionViewDelegate protocol

- (BOOL)collectionView:(UICollectionView *)collectionView shouldHighlightItemAtIndexPath:(NSIndexPath *)indexPath {
    
    // When selecting unexposed items is not allowed,
    // prevent them from being highlighted and thus
    // selected by the collection view
    //
    return self.unexposedItemsAreSelectable || self.exposedItemIndexPath == nil || [indexPath isEqual:self.exposedItemIndexPath];
}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath {
    
    if (!self.unexposedItemsAreSelectable && self.exposedItemIndexPath) {
        
        // When selecting unexposed items is not allowed
        // make sure the currently exposed item remains
        // selected
        //
        [collectionView selectItemAtIndexPath:self.exposedItemIndexPath animated:NO scrollPosition:UICollectionViewScrollPositionNone];
    }
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {

    if ([indexPath isEqual:self.exposedItemIndexPath]) {

        // Collapse currently exposed item
        //
        self.exposedItemIndexPath = nil;
        
    } else if (self.unexposedItemsAreSelectable || self.exposedItemIndexPath == nil) {
            
        // Expose new item, possibly collapsing
        // the currently exposed item
        //
        self.exposedItemIndexPath = indexPath;
    }
}

#pragma mark - GestureRecognizerDelegate protocol

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer == self.movePanGestureRecognizer &&
        self.collectionView.collectionViewLayout == self.stackedLayout) {
        return NO;
    } else if (gestureRecognizer == self.moveLongPressGestureRecognizer &&
               self.collectionView.collectionViewLayout != self.stackedLayout) {
        return NO;
    }

    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

#pragma mark - Methods

- (BOOL)canMoveItemAtIndexPath:(NSIndexPath *)indexPath {
    
    // Overload this method to prevent items
    // from being dragged to another location
    //
    return YES;
}

- (NSIndexPath *)targetIndexPathForMoveFromItemAtIndexPath:(NSIndexPath *)sourceIndexPath toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath {
    
    // Overload this method to modify an item's
    // target location while being dragged to
    // another proposed location
    //
    return proposedDestinationIndexPath;
}

- (void)moveItemAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
    
    // Overload method to update collection
    // view data source when item has been
    // dragged to another location
}

#pragma mark - Gesture States
//Began State
- (void)gestureRecognizerStateBegan:(UIGestureRecognizer *)recognizer {
    self.startLocation = [recognizer locationInView:recognizer.view];
    
    NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:self.startLocation];
    
    if (indexPath && [self canMoveItemAtIndexPath:indexPath]) {
        
        UICollectionViewCell *movingCell = [self.collectionView cellForItemAtIndexPath:indexPath];
        UICollectionViewCell *prevCell = [self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:indexPath.item-1 inSection:indexPath.section]];
        
        self.movingView = [[UIView alloc] initWithFrame:movingCell.frame];
        self.movingView.backgroundColor = [UIColor clearColor];
        self.movingView.layer.cornerRadius = movingCell.layer.cornerRadius;
        self.movingView.layer.masksToBounds = YES;
        
        self.startCenter = self.movingView.center;
        
        UIImageView *movingImageView = [[UIImageView alloc] initWithImage:[self screenshotImageOfItem:movingCell]];
        movingImageView.backgroundColor = [UIColor clearColor];
        [self.movingView addSubview:movingImageView];
        
        if (prevCell == nil) {
            [self.collectionView addSubview:self.movingView];
            [self.collectionView sendSubviewToBack:self.movingView];
        } else {
            [self.collectionView insertSubview:self.movingView aboveSubview:prevCell];
        }
        
        self.movingIndexPath = indexPath;
        
        UICollectionViewLayout<TGLCollectionViewLayoutProtocol> *layout = (UICollectionViewLayout<TGLCollectionViewLayoutProtocol> *) self.collectionView.collectionViewLayout;
        layout.movingIndexPath = self.movingIndexPath;
        [layout invalidateLayout];
        
        self.movingCell = movingCell;
    }
}

//Changed State
- (void)gestureRecognizerStateChanged:(UIGestureRecognizer *)recognizer {
    CGPoint currentLocation = [recognizer locationInView:self.collectionView];
    CGPoint currentCenter = self.startCenter;
    
    currentCenter.y += (currentLocation.y - self.startLocation.y);
    
    self.movingView.center = currentCenter;
    
    if (recognizer == self.moveLongPressGestureRecognizer) {
        if (currentLocation.y < CGRectGetMinY(self.collectionView.bounds) + SCROLL_ZONE_TOP && self.collectionView.contentOffset.y > SCROLL_ZONE_TOP) {
            
            [self startScrollingUp];
            
        } else if (currentLocation.y > CGRectGetMaxY(self.collectionView.bounds) - SCROLL_ZONE_BOTTOM && self.collectionView.contentOffset.y < self.collectionView.contentSize.height - CGRectGetHeight(self.collectionView.bounds) - SCROLL_ZONE_BOTTOM) {
            
            [self startScrollingDown];
            
        } else if (self.scrollDirection != TGLStackedViewControllerScrollDirectionNone) {
            
            [self stopScrolling];
        }
        
        if (self.scrollDirection == TGLStackedViewControllerScrollDirectionNone) {
            
            [self updateLayoutAtMovingLocation:currentLocation];
        }
    }
}

//Ended State
- (void)gestureRecognizerStateEnded:(UIGestureRecognizer *)recognizer {
    [self stopScrolling];
    
    UICollectionViewLayoutAttributes *layoutAttributes = [self.collectionView.collectionViewLayout layoutAttributesForItemAtIndexPath:self.movingIndexPath];
    
    self.movingIndexPath = nil;
    
    CGFloat initialVel = 0;
    if ([recognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        UIPanGestureRecognizer *panGest = (UIPanGestureRecognizer *)recognizer;
        
        UIView *view = self.movingView;
        CGPoint velGest = [panGest velocityInView:recognizer.view];
        CGRect frame = view.frame;
        CGPoint origin = frame.origin;
        CGPoint velocity = CGPointMake(origin.x == 0 ? 0 : velGest.x / frame.origin.x ,
                                       origin.y == 0 ? 0 : velGest.y / frame.origin.y);
        initialVel = MIN(velocity.y, self.maxExposedVelocity);
    }
    
    __weak typeof(self) weakSelf = self;
    void (^completed)(BOOL finished) = ^(BOOL finished){
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf.movingView removeFromSuperview];
        strongSelf.movingView = nil;
        
        UICollectionViewLayout<TGLCollectionViewLayoutProtocol> *layout = (UICollectionViewLayout<TGLCollectionViewLayoutProtocol> *) self.collectionView.collectionViewLayout;
        layout.movingIndexPath = self.movingIndexPath;
        [layout invalidateLayout];
    };
        
    CGFloat offset = CGRectGetMinY(self.movingView.frame) - CGRectGetMinY(self.movingCell.frame);
    if ([recognizer isKindOfClass:[UIPanGestureRecognizer class]] &&
        fabsf(offset) > self.minOffsetForReset) {
        self.movingCell.frame = self.movingView.frame;
        completed(YES);
        if (offset < 0) initialVel = 0;
        [self setExposedItemIndexPath:nil withInitialVelocity:initialVel];
    } else {
        __weak typeof(self) weakSelf = self;
        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:1 initialSpringVelocity:initialVel options:0 animations:^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            strongSelf.movingView.frame = layoutAttributes.frame;
        } completion:completed];
    }
    
    self.movingCell = nil;
}

#pragma mark - Actions
- (void)handleGesture:(UIGestureRecognizer *)recognizer {
    if ([recognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        UIPanGestureRecognizer *panGest = (UIPanGestureRecognizer *)recognizer;
        [panGest setTranslation:CGPointMake(0, 0) inView:recognizer.view];
    }
    
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan: {
            if ([recognizer isKindOfClass:[UIPanGestureRecognizer class]] && !self.panGestureEnabled) {
                return;
            }
            if (recognizer == self.moveLongPressGestureRecognizer) {
                self.collectionView.scrollEnabled = NO;
            }
            [self gestureRecognizerStateBegan:recognizer];
            break;
        }

        case UIGestureRecognizerStateChanged: {
            if ([recognizer isKindOfClass:[UIPanGestureRecognizer class]] && !self.panGestureEnabled) {
                return;
            }
            if (!self.movingView) {
                [self gestureRecognizerStateBegan:recognizer];
            }
            if (self.movingIndexPath) {
                [self gestureRecognizerStateChanged:recognizer];
            }
            break;
        }

        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateFailed:
        case UIGestureRecognizerStateCancelled: {
            if (self.movingIndexPath) {
                [self gestureRecognizerStateEnded:recognizer];
            }
            if (recognizer == self.moveLongPressGestureRecognizer) {
                self.collectionView.scrollEnabled = YES;
            }
            break;
        }
            
        default:
            
            break;
    }
}

#pragma mark - Scrolling

- (void)startScrollingUp {
    
    [self startScrollingInDirection:TGLStackedViewControllerScrollDirectionUp];
}

- (void)startScrollingDown {
    
    [self startScrollingInDirection:TGLStackedViewControllerScrollDirectionDown];
}

- (void)startScrollingInDirection:(TGLStackedViewControllerScrollDirection)direction {

    if (direction != TGLStackedViewControllerScrollDirectionNone && direction != self.scrollDirection) {

        [self stopScrolling];

        self.scrollDirection = direction;
        self.scrollDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(handleScrolling:)];

        [self.scrollDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    }
}

- (void)stopScrolling {
    
    if (self.scrollDirection != TGLStackedViewControllerScrollDirectionNone) {
        
        self.scrollDirection = TGLStackedViewControllerScrollDirectionNone;
        
        [self.scrollDisplayLink invalidate];
        self.scrollDisplayLink = nil;
    }
}

- (void)handleScrolling:(CADisplayLink *)displayLink {
    
    switch (self.scrollDirection) {
            
        case TGLStackedViewControllerScrollDirectionUp: {

            CGPoint offset = self.collectionView.contentOffset;

            offset.y -= SCROLL_PER_FRAME;
            
            if (offset.y > 0.0) {
                
                self.collectionView.contentOffset = offset;
                
                CGPoint center = self.movingView.center;

                center.y -= SCROLL_PER_FRAME;
                self.movingView.center = center;

            } else {

                [self stopScrolling];

                CGPoint currentLocation = [self.moveLongPressGestureRecognizer locationInView:self.collectionView];
                
                [self updateLayoutAtMovingLocation:currentLocation];
            }

            break;
        }
            
        case TGLStackedViewControllerScrollDirectionDown: {
            
            CGPoint offset = self.collectionView.contentOffset;
            
            offset.y += SCROLL_PER_FRAME;
            
            if (offset.y < self.collectionView.contentSize.height - CGRectGetHeight(self.collectionView.bounds)) {

                self.collectionView.contentOffset = offset;

                CGPoint center = self.movingView.center;

                center.y += SCROLL_PER_FRAME;
                self.movingView.center = center;

            } else {
                
                [self stopScrolling];
                
                CGPoint currentLocation = [self.moveLongPressGestureRecognizer locationInView:self.collectionView];
                
                [self updateLayoutAtMovingLocation:currentLocation];
            }
            
            break;
        }
            
        default:
            break;
    }
}

#pragma mark - Helpers

- (UIImage *)screenshotImageOfItem:(UICollectionViewCell *)item {
    
    UIGraphicsBeginImageContextWithOptions(item.bounds.size, item.isOpaque, 0.0f);
    
    [item.layer renderInContext:UIGraphicsGetCurrentContext()];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();

    return image;
}

- (void)updateLayoutAtMovingLocation:(CGPoint)movingLocation {
    
    [self.stackedLayout invalidateLayoutIfNecessaryWithMovingLocation:movingLocation
                                                          targetBlock:^ (NSIndexPath *sourceIndexPath, NSIndexPath *proposedDestinationIndexPath) {
        
                                                              return [self targetIndexPathForMoveFromItemAtIndexPath:sourceIndexPath toProposedIndexPath:proposedDestinationIndexPath];
                                                          }
                                                          updateBlock:^ (NSIndexPath *fromIndexPath, NSIndexPath *toIndexPath){
                                                              
                                                              [self moveItemAtIndexPath:fromIndexPath toIndexPath:toIndexPath];
                                                              
                                                              if (fromIndexPath.item > toIndexPath.item) {
                                                                  UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:toIndexPath];
                                                                  [self.collectionView insertSubview:self.movingView belowSubview:cell];
                                                              } else if (fromIndexPath.item < toIndexPath.item) {
                                                                  UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:toIndexPath];
                                                                  [self.collectionView insertSubview:self.movingView belowSubview:cell];
                                                              }
                                                              
                                                              self.movingIndexPath = toIndexPath;
                                                          }];
}

@end
