//
//  TGLBaseLayout.h
//  TGLStackedViewExample
//
//  Created by Mark Glagola on 3/19/15.
//  Copyright (c) 2015 Tim Gleue • interactive software. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol TGLCollectionViewLayoutProtocol

/** Index path of item currently being moved, and thus being hidden */
@property (strong, nonatomic) NSIndexPath *movingIndexPath;

@end
