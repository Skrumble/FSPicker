//
//  FSPickerController.m
//  FSPicker
//
//  Created by Łukasz Cichecki on 23/02/16.
//  Copyright © 2016 Filestack. All rights reserved.
//

#import "FSPickerController.h"
#import "FSTheme.h"
#import "FSSourceListViewController.h"
#import "FSProtocols+Private.h"

#import "FSUploader.h"
#import "FSProgressModalViewController.h"

@interface FSPickerController () <FSUploaderDelegate>

@property FSUploader *uploader;

@end

static __weak FSPickerController *currentFSPickerController;

@implementation FSPickerController

+ (FSPickerController *)getCurrentFSPickerControllerDisplayed {
    return currentFSPickerController;
}

+ (void)closeCurrentFSPickerDisplayed {
    [self closeCurrentFSPickerDisplayedWithCompletion:nil];
}

+ (void)closeCurrentFSPickerDisplayedWithCompletion:(void (^)(void))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (currentFSPickerController) {
            NSLog(@"FSPICKER - CLOSE FSPickerController");
            currentFSPickerController.uploader = nil;
            [currentFSPickerController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
//            [currentFSPickerController dismissViewControllerAnimated:YES completion:completion];
        }
    });
}

- (void)dealloc {
    NSLog(@"FSPICKER - dealloc FSPickerController");
}

- (instancetype)initWithConfig:(FSConfig *)config theme:(FSTheme *)theme {
    if ((self = [super initWithRootViewController:[[FSSourceListViewController alloc] initWithConfig:config]])) {
        _config = config;
        _theme = theme;

        if (_theme) {
            [_theme applyToController:self];
        } else {
            [FSTheme applyDefaultToController:self];
        }
    }

    return self;
}

- (instancetype)initWithConfig:(FSConfig *)config {
    return [self initWithConfig:config theme:nil];
}

- (instancetype)init {
    return [self initWithConfig:nil theme:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    currentFSPickerController = self;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)didCancel {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.fsDelegate respondsToSelector:@selector(fsPickerDidCancel:)]) {
            [self.fsDelegate fsPickerDidCancel:self];
        }
    });
}

- (void)fsImageSelected:(UIImage *)asset withURL:(NSURL *)url {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.fsDelegate respondsToSelector:@selector(fsPicker:didFinishPickingWithUIImage:withURL:)]) {
            [self.fsDelegate fsPicker:self didFinishPickingWithUIImage:asset withURL:url];
        }
    });
}

#pragma mark - FSUPloader

+ (FSUploader *)createUploaderWithViewController:(UIViewController *)vc config:(FSConfig *)config source:(FSSource *)source {
    
// create the picker
    FSUploader *uploader = [[FSUploader alloc] initWithConfig:config source:source];
    uploader.pickerDelegate = (FSPickerController *)vc.navigationController;
    
// Loader View
    FSProgressModalViewController *uploadModal = [[FSProgressModalViewController alloc] init];
    uploadModal.modalPresentationStyle = UIModalPresentationOverCurrentContext;
    uploader.uploadModalDelegate = uploadModal;
    [vc presentViewController:uploadModal animated:YES completion:nil];
    
    if (currentFSPickerController) {
        currentFSPickerController.uploader = uploader;
    }
    return uploader;
}

- (void)fsUploadComplete:(FSBlob *)blob {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.fsDelegate respondsToSelector:@selector(fsPicker:pickedMediaWithBlob:)]) {
            [self.fsDelegate fsPicker:self pickedMediaWithBlob:blob];
        }
    });
}

- (void)fsUploadError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.fsDelegate respondsToSelector:@selector(fsPicker:pickingDidError:)]) {
            [self.fsDelegate fsPicker:self pickingDidError:error];
        }
    });
}

- (void)fsUploadFinishedWithBlobs:(NSArray<FSBlob *> *)blobsArray completion:(void (^)())completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.fsDelegate respondsToSelector:@selector(fsPicker:didFinishPickingMediaWithBlobs:)]) {
            [self.fsDelegate fsPicker:self didFinishPickingMediaWithBlobs:blobsArray];
        }
    });
}

@end
