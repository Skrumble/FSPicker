//
//  FSProtocols+Private.h
//  FSPicker
//
//  Created by Łukasz Cichecki on 22/04/16.
//  Copyright © 2016 Filestack. All rights reserved.
//

@class FSBlob;
@class UIImage;

@protocol FSUploaderDelegate <NSObject>
@optional
- (void)fsUploadProgress:(float)progress addToTotalProgress:(BOOL)addToTotalProgress;
- (void)fsUploadComplete:(FSBlob *)blob;
- (void)fsImageSelected:(UIImage *)asset withURL:(NSURL *)url;
- (void)fsUploadError:(NSError *)error;
- (void)fsUploadError:(NSError *)error withCompletion:(void(^)(void))completion;
- (void)fsUploadFinishedWithBlobs:(NSArray<FSBlob *> *)blobsArray completion:(void (^)())completion;
@end

@protocol FSExporterDelegate <NSObject>
@optional
- (void)fsExportComplete:(FSBlob *)blob;
- (void)fsExportError:(NSError *)error;
- (void)fsExportProgress:(float)progress addToTotalProgress:(BOOL)addToTotalProgress;
@end
