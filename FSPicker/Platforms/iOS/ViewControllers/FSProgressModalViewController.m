//
//  FSProgressModalViewController.m
//  FSPicker
//
//  Created by Łukasz Cichecki on 14/04/16.
//  Copyright © 2016 Filestack. All rights reserved.
//

#import "FSProgressModalViewController.h"
#import "KAProgressLabel.h"

@interface FSProgressModalViewController ()

@property (nonatomic, strong) KAProgressLabel *progressLabel;

@end

@implementation FSProgressModalViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor colorWithRed:1 green:1 blue:1 alpha:0.915];
//    self.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];

    self.progressLabel = [[KAProgressLabel alloc] initWithFrame:CGRectMake(0, 0, 150, 150)];
    self.progressLabel.trackWidth = 15;
    self.progressLabel.progressWidth = 15;
    self.progressLabel.fillColor = [UIColor clearColor];
    self.progressLabel.textColor = [UIColor blackColor];
    self.progressLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressLabel.labelVCBlock = ^(KAProgressLabel *label) {
        label.text = [NSString stringWithFormat:@"%.0f%%", (label.progress * 100)];
    };

    NSLayoutConstraint *constW = [NSLayoutConstraint constraintWithItem:self.progressLabel attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:150];

    NSLayoutConstraint *constH = [NSLayoutConstraint constraintWithItem:self.progressLabel attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:150];

    [self.progressLabel addConstraints:@[constW, constH]];

    NSLayoutConstraint *constX = [NSLayoutConstraint constraintWithItem:self.progressLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeCenterX multiplier:1 constant:0];

    NSLayoutConstraint *constY = [NSLayoutConstraint constraintWithItem:self.progressLabel attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeCenterY multiplier:1 constant:0];

    [self.view addSubview:self.progressLabel];
    [self.view addConstraints:@[constX, constY]];
    
    // Close Button
    // to implement later
//    UIView *closeView = [[UIView alloc] initWithFrame:CGRectMake(10, 20, 50, 50)];
//    [closeView setOpaque:NO];
//    closeView.backgroundColor = [UIColor clearColor];
//    [self.view addSubview:closeView];
//    UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(closeLoaderClickAction:)];
//    [closeView addGestureRecognizer:gesture];
//
//    UIImageView *closeImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"icn_close"]];
//    closeImage.translatesAutoresizingMaskIntoConstraints = NO;
//    [closeView addSubview:closeImage];
//
//    constW = [NSLayoutConstraint constraintWithItem:closeImage attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:15];
//    constH = [NSLayoutConstraint constraintWithItem:closeImage attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:15];
//    [closeImage addConstraints:@[constW, constH]];
//
//    constX = [NSLayoutConstraint constraintWithItem:closeImage attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:closeView attribute:NSLayoutAttributeCenterX multiplier:1 constant:0];
//    constY = [NSLayoutConstraint constraintWithItem:closeImage attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:closeView attribute:NSLayoutAttributeCenterY multiplier:1 constant:0];
//    [self.view addConstraints:@[constX, constY]];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - User Action

- (void)closeLoaderClickAction:(id)sender {
    
}

#pragma mark - Delegate

- (void)fsUploadProgress:(float)progress addToTotalProgress:(BOOL)addToTotalProgress {
    dispatch_async(dispatch_get_main_queue(), ^{
    @synchronized (self.progressLabel) {
        if (addToTotalProgress) {
            float totalProgress = (float)self.progressLabel.progress + progress;
            if ((int)totalProgress > 1) {
                totalProgress = 1.0;
            }
            [self.progressLabel setProgress:(double)totalProgress];
        } else {
            [self.progressLabel setProgress:(double)progress timing:TPPropertyAnimationTimingEaseOut duration:0.5 delay:0.0];
        }
    }
    });
}

- (void)fsExportProgress:(float)progress addToTotalProgress:(BOOL)addToTotalProgress {
    [self fsUploadProgress:progress addToTotalProgress:addToTotalProgress];
}

- (void)fsUploadFinishedWithBlobs:(NSArray<FSBlob *> *)blobsArray completion:(void (^)())completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self dismissViewControllerAnimated:YES completion:^{
            if (completion) {
                completion();
            }
        }];
    });
}

- (void)fsUploadError:(NSError *)error {
    [self fsUploadError:error withCompletion:nil];
}

- (void)fsUploadError:(NSError *)error withCompletion:(void(^)(void))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self dismissViewControllerAnimated:YES completion:completion];
    });
}

- (void)fsExportComplete:(FSBlob *)blob {
    [self fsUploadFinishedWithBlobs:nil completion:nil];
}

- (void)fsExportError:(NSError *)error {
    [self fsUploadError:error];
}

@end
