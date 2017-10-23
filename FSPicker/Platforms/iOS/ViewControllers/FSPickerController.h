//
//  FSPickerController.h
//  FSPicker
//
//  Created by Łukasz Cichecki on 23/02/16.
//  Copyright © 2016 Filestack. All rights reserved.
//

@import UIKit;
#import "FSProtocols.h"
@class FSTheme;
@class FSConfig;
@class FSUploader;
@class FSSource;

@interface FSPickerController : UINavigationController

@property (nonatomic, copy) FSTheme *theme;
@property (nonatomic, copy) FSConfig *config;
@property (nonatomic, weak) id <FSPickerDelegate> fsDelegate;

- (instancetype)initWithConfig:(FSConfig *)config theme:(FSTheme *)theme;
- (instancetype)initWithConfig:(FSConfig *)config;

- (void)didCancel;

+ (FSPickerController *)getCurrentFSPickerControllerDisplayed;
+ (void)closeCurrentFSPickerDisplayed;

#pragma mark - FSUPloader

+ (FSUploader *)createUploaderWithViewController:(UIViewController *)vc config:(FSConfig *)config source:(FSSource *)source;

@end
