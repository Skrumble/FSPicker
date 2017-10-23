//
//  FSUploader.m
//  FSPicker
//
//  Created by Łukasz Cichecki on 14/04/16.
//  Copyright © 2016 Filestack. All rights reserved.
//

#import <Filestack/Filestack.h>
#import <Filestack/Filestack+FSPicker.h>

#import "UIImage+Rotate.h"

#import "FSPickerController.h"
#import "FSSource.h"
#import "FSConfig.h"
#import "FSSession.h"
#import "FSUploader.h"
#import "FSContentItem.h"
#import "FSDownloader.h"
@import Photos;
@interface FSUploader ()

@property (nonatomic, strong) FSConfig *config;
@property (nonatomic, strong) FSSource *source;
@property (nonatomic, strong) NSMutableArray <FSBlob *> *blobsArray;

@end

@implementation FSUploader

- (void)dealloc {
    NSLog(@"FSPICKER - dealloc FSUploader");
    // make sure to quit the picker
    if (self.config.shouldCloseAfterDownload) {
        [FSPickerController closeCurrentFSPickerDisplayed];
    }
}

- (instancetype)initWithConfig:(FSConfig *)config source:(FSSource *)source {
    if ((self = [super init])) {
        _config = config;
        _source = source;
        _blobsArray = [[NSMutableArray alloc] init];
    }

    return self;
}

#pragma mark - Uploads Finish

- (void)finishUpload {
    NSLog(@"FSPicker - finish upload FSUploader");
    
    // Complete upload progress
    if ([self.uploadModalDelegate respondsToSelector:@selector(fsUploadProgress:addToTotalProgress:)]) {
        [self.uploadModalDelegate fsUploadProgress:1.0 addToTotalProgress:NO];
    }
    
    // fsUploadFinishedWithBlobs Delegate
    if ([self.uploadModalDelegate respondsToSelector:@selector(fsUploadFinishedWithBlobs:completion:)]) {
        __weak typeof(self) weakSelf = self;
        [self.uploadModalDelegate fsUploadFinishedWithBlobs:nil completion:^{
            if ([weakSelf.pickerDelegate respondsToSelector:@selector(fsUploadFinishedWithBlobs:completion:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf.pickerDelegate fsUploadFinishedWithBlobs:weakSelf.blobsArray completion:nil];
                });
            }
        }];
    }
    
    // Close view on config
    if (self.config.shouldCloseAfterDownload) {
        [FSPickerController closeCurrentFSPickerDisplayed];
    }
}

#pragma mark - Camera

- (void)uploadCameraItemWithInfo:(NSDictionary<NSString *,id> *)info {
// Original IMAGE
    if (info[UIImagePickerControllerOriginalImage]) {
        UIImage *image = info[UIImagePickerControllerOriginalImage];
        UIImage *rotatedImage = [image fixRotation];
        NSData *imageData = UIImageJPEGRepresentation(rotatedImage, 0.8);
        NSString *fileName = [NSString stringWithFormat:@"Image_%@.jpg", [NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterShortStyle]];
        NSCharacterSet *dateFormat = [NSCharacterSet characterSetWithCharactersInString:@"/: "];
        fileName = [[fileName componentsSeparatedByCharactersInSet:dateFormat] componentsJoinedByString:@"-"];
        
        [self uploadCameraItem:imageData fileName:fileName];
    }
// URL
    else if (info[UIImagePickerControllerMediaURL]) {
        NSURL *fileURL = info[UIImagePickerControllerMediaURL];
        NSString *fileName = fileURL.lastPathComponent;
        NSData *videoData = [NSData dataWithContentsOfURL:fileURL];
        
        [self uploadCameraItem:videoData fileName:fileName];
    }
}

- (void)uploadCameraItem:(NSData *)itemData fileName:(NSString *)fileName {
    BOOL delegateRespondsToUploadProgress = [self.uploadModalDelegate respondsToSelector:@selector(fsUploadProgress:addToTotalProgress:)];
    
    Filestack *filestack = [[Filestack alloc] initWithApiKey:self.config.apiKey];
    FSStoreOptions *storeOptions = [self.config.storeOptions copy];
    
    if (!storeOptions) {
        storeOptions = [[FSStoreOptions alloc] init];
    }
    
    storeOptions.fileName = fileName;
    storeOptions.mimeType = nil;
    
    [filestack store:itemData withOptions:storeOptions progress:^(NSProgress *uploadProgress) {
        if (delegateRespondsToUploadProgress) {
            double fractionCompleted = uploadProgress.fractionCompleted;
            [self.uploadModalDelegate fsUploadProgress:fractionCompleted addToTotalProgress:NO];
        }
    } completionHandler:^(FSBlob *blob, NSError *error) {
        [self messageDelegateWithBlob:blob error:error];
        [self finishUpload];
    }];
}

#pragma mark - Local File

- (void)uploadLocalItems:(NSArray<PHAsset *> *)items {
    BOOL delegateRespondsToUploadProgress = [self.uploadModalDelegate respondsToSelector:@selector(fsUploadProgress:addToTotalProgress:)];
    NSUInteger totalNumberOfItems = items.count;
    __weak typeof(self) weakSelf = self;
    
    Filestack *filestack = [[Filestack alloc] initWithApiKey:self.config.apiKey];
    FSStoreOptions *storeOptions = [self.config.storeOptions copy];
    
    if (!storeOptions) {
        storeOptions = [[FSStoreOptions alloc] init];
    }
    
    storeOptions.mimeType = nil;
    
    PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
    options.version = PHVideoRequestOptionsVersionOriginal;
    
// DISPATCH GROUP: called after all upload is done
    dispatch_group_t allFileUploadedGroup = dispatch_group_create();
    for (PHAsset *item in items) { dispatch_group_enter(allFileUploadedGroup); }
    dispatch_group_notify(allFileUploadedGroup, dispatch_get_main_queue(), ^{
        [weakSelf finishUpload];
    });
    
    for (PHAsset *item in items) {
        double __block progressToAdd = 0.0;
        double __block currentItemProgress = 0.0;
        [self uploadLocalMediaContentAsset:item usingFilestack:filestack storeOptions:storeOptions progress:^(NSProgress *uploadProgress) {
            progressToAdd = uploadProgress.fractionCompleted * (1.0 / totalNumberOfItems) - currentItemProgress;
            currentItemProgress = uploadProgress.fractionCompleted * (1.0 / totalNumberOfItems);
            [self.uploadModalDelegate fsUploadProgress:progressToAdd addToTotalProgress:YES];
        } completionHandler:^(FSBlob *blob, NSError *error) {
            [weakSelf messageDelegateWithBlob:blob error:error];
            dispatch_group_leave(allFileUploadedGroup);
        }];
    }
}

#pragma mark - Cloud / Drive

- (void)uploadCloudItems:(NSArray<FSContentItem *> *)items {
    NSUInteger totalNumberOfItems = items.count;
    __block NSNumber *uploadedItems = @(0);
    
    FSDownloader *downloader;
    FSSession *session = [[FSSession alloc] initWithConfig:self.config mimeTypes:self.source.mimeTypes];
    
    // We have to upload AND download the item.
    if (self.config.shouldDownload) {
        downloader = [[FSDownloader alloc] init];
        totalNumberOfItems *= 2;
    }
    
    // DISPATCH GROUP: called after all upload is done
    __weak typeof(self) weakSelf = self;
    dispatch_group_t allFileUploadedGroup = dispatch_group_create();
    for (PHAsset *item in items) { dispatch_group_enter(allFileUploadedGroup); }
    dispatch_group_notify(allFileUploadedGroup, dispatch_get_main_queue(), ^{
        [weakSelf finishUpload];
    });
    
    for (FSContentItem *item in items) {
        NSDictionary *parameters = [session toQueryParametersWithFormat:@"fpurl"];
        
        [Filestack pickFSURL:item.linkPath parameters:parameters completionHandler:^(FSBlob *blob, NSError *error) {
            
            // update the progress
            @synchronized(uploadedItems) {
                uploadedItems = @(uploadedItems.integerValue+1);
                [self updateProgress:uploadedItems.integerValue total:totalNumberOfItems];
            }
            
            if (self.config.shouldDownload == NO || error) {
                [self messageDelegateWithBlob:blob error:error];
                dispatch_group_leave(allFileUploadedGroup);
                return;
            }
            
            [downloader download:blob security:self.config.storeOptions.security completionHandler:^(NSString *fileURL, NSError *error) {
                
                @synchronized(uploadedItems) {
                    uploadedItems = @(uploadedItems.integerValue+1);
                    [self updateProgress:uploadedItems.integerValue total:totalNumberOfItems];
                }
                
                blob.internalURL = fileURL;
                [self messageDelegateWithBlob:blob error:error];
                
                dispatch_group_leave(allFileUploadedGroup);
            }];
            
        }];
    }
}

#pragma mark - Upload Action

- (void)uploadLocalMediaContentAsset:(PHAsset *)asset usingFilestack:(Filestack *)filestack storeOptions:(FSStoreOptions *)storeOptions progress:(void (^)(NSProgress *uploadProgress))progress completionHandler:(void (^)(FSBlob *blob, NSError *error))completionHandler {
    if (asset.mediaType == PHAssetMediaTypeImage) {
        [self uploadLocalImageAsset:asset usingFilestack:filestack storeOptions:storeOptions progress:progress completionHandler:completionHandler];
    }
    else if (asset.mediaType == PHAssetMediaTypeVideo) {
        [self uploadLocalVideoAsset:asset usingFilestack:filestack storeOptions:storeOptions progress:progress completionHandler:completionHandler];
    }
    else {
        // no handle yet
        if (completionHandler) {
            completionHandler (nil, nil);
        }
    }
}

- (void)uploadLocalImageAsset:(PHAsset *)asset usingFilestack:(Filestack *)filestack storeOptions:(FSStoreOptions *)storeOptions progress:(void (^)(NSProgress *uploadProgress))progress completionHandler:(void (^)(FSBlob *blob, NSError *error))completionHandler {

    PHImageRequestOptions *option = [[PHImageRequestOptions alloc] init];
    option.networkAccessAllowed = YES;
    
    [[PHImageManager defaultManager] requestImageDataForAsset:asset options:option resultHandler:^(NSData * imageData, NSString * dataUTI, UIImageOrientation orientation, NSDictionary * info) {
        NSURL *imageURL = info[@"PHImageFileURLKey"];
        NSString *fileName = imageURL.lastPathComponent;
        storeOptions.fileName = fileName;

        [filestack store:imageData withOptions:storeOptions progress:progress completionHandler:completionHandler];
    }];
}

- (void)uploadLocalVideoAsset:(PHAsset *)asset usingFilestack:(Filestack *)filestack storeOptions:(FSStoreOptions *)storeOptions progress:(void (^)(NSProgress *uploadProgress))progress completionHandler:(void (^)(FSBlob *blob, NSError *error))completionHandler {

    PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
    options.version = PHVideoRequestOptionsVersionOriginal;
    options.networkAccessAllowed = YES;

    [[PHImageManager defaultManager] requestAVAssetForVideo:asset options:options resultHandler:^(AVAsset *asset, AVAudioMix *audioMix, NSDictionary *info) {
        if ([asset isKindOfClass:[AVURLAsset class]] == NO) {
            if (completionHandler) { completionHandler(nil, nil); }
            return;
        }
            
        NSURL *URL = ((AVURLAsset *)asset).URL;
        NSData *data = [NSData dataWithContentsOfURL:URL];
        NSString *fileName = URL.lastPathComponent;
        storeOptions.fileName = fileName;

        [filestack store:data withOptions:storeOptions progress:progress completionHandler:completionHandler];
    }];
}

#pragma mark - Delegates

- (void)updateProgress:(NSUInteger)uploadedItems total:(NSUInteger)totalItems {
    dispatch_async(dispatch_get_main_queue(), ^{
    if ([self.uploadModalDelegate respondsToSelector:@selector(fsUploadProgress:addToTotalProgress:)]) {
        float currentProgress = (float)uploadedItems / totalItems;
        [self.uploadModalDelegate fsUploadProgress:currentProgress addToTotalProgress:NO];
    }
    });
}

- (void)messageDelegateWithBlob:(FSBlob *)blob error:(NSError *)error {
    if (blob) {
        [self.blobsArray addObject:blob];

        if ([self.uploadModalDelegate respondsToSelector:@selector(fsUploadComplete:)]) {
            [self.uploadModalDelegate fsUploadComplete:blob];
        }

        if ([self.pickerDelegate respondsToSelector:@selector(fsUploadComplete:)]) {
            [self.pickerDelegate fsUploadComplete:blob];
        }
    } else {
        // make sure that the loader is dismiss before calling the picker delegate
        // this way the delegate can present
        typeof(self) weakSelf = self;
        if ([self.uploadModalDelegate respondsToSelector:@selector(fsUploadError:withCompletion:)]) {
            [self.uploadModalDelegate fsUploadError:error withCompletion:^{
                if ([weakSelf.pickerDelegate respondsToSelector:@selector(fsUploadError:)]) {
                   [weakSelf.pickerDelegate fsUploadError:error];
                }
            }];
        }
    }
}

@end
