//
// FSGridViewController.m
// FSPicker
//
// Created by Łukasz Cichecki on 24/02/16.
// Copyright (c) 2016 Filestack. All rights reserved.
//

#import "FSGridViewController.h"
#import "UICollectionViewFlowLayout+FSPicker.h"
#import "FSCollectionViewCell.h"
#import "FSImageFetcher.h"
#import "FSBarButtonItem.h"
#import "FSPickerController.h"
#import "FSConfig.h"
#import "FSImage.h"
#import "FSUploader.h"
#import "FSProgressModalViewController.h"
#import "FSPickerController+Private.h"

@interface FSGridViewController ()

@property (nonatomic, strong) FSConfig *config;
@property (nonatomic, strong) FSSource *source;
@property (nonatomic, assign) CGSize itemSize;
@property (nonatomic, assign) BOOL toolbarColorsSet;
@property (nonatomic, strong) PHCachingImageManager *cachingImageManager;
@property (nonatomic, strong) NSMutableArray<PHAsset *> *selectedAssets;
@property (nonatomic, strong) NSMutableArray<NSIndexPath *> *selectedIndexPaths;
@property (nonatomic, strong) UIImage *selectedOverlay;
@property (nonatomic, strong, readonly) UIBarButtonItem *uploadButton;

@end

@implementation FSGridViewController

- (instancetype)initWithConfig:(FSConfig *)config source:(FSSource *)source {
    if ((self = [super initWithCollectionViewLayout:[[UICollectionViewFlowLayout alloc] init]])) {
        _config = config;
        _source = source;
        _cachingImageManager = [[PHCachingImageManager alloc] init];
        self.collectionView.allowsMultipleSelection = YES;
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
    return self;
}

- (void)applicationWillEnterForeground {
    [self.collectionView reloadData];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupCollectionView];
    [self setupToolbar];
    self.selectedAssets = [[NSMutableArray alloc] init];
    self.selectedIndexPaths = [[NSMutableArray alloc] init];
    self.selectedOverlay = [FSImage cellSelectedOverlay];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setToolbarHidden:YES animated:YES];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - User Action

- (void)uploadSelectedAssets {
        
    if (self.config.shouldUpload) {
        FSUploader *uploader = [FSPickerController createUploaderWithViewController:self config:self.config source:self.source];
        [uploader uploadLocalItems:self.selectedAssets];
        [self clearSelectedAssets];
    }
    else {
        PHAsset *asset = self.selectedAssets.firstObject;
        PHImageRequestOptions *requestOptions = [[PHImageRequestOptions alloc] init];
        requestOptions.resizeMode   = PHImageRequestOptionsResizeModeExact;
        requestOptions.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
        requestOptions.synchronous = YES;
        requestOptions.networkAccessAllowed = YES;
        
        PHImageManager *manager = [PHImageManager defaultManager];
        [manager requestImageForAsset:asset targetSize:PHImageManagerMaximumSize contentMode:PHImageContentModeDefault options:requestOptions resultHandler:^void(UIImage *image, NSDictionary *info) {
            if ([((FSPickerController *)self.navigationController) respondsToSelector:@selector(fsImageSelected:withURL:)]) {
                NSURL *url = (NSURL *)[info objectForKey:@"PHImageFileURLKey"];
                [((FSPickerController *)self.navigationController) fsImageSelected:image withURL:url];
            }
        }];
    }
}

- (void)clearSelectedAssets {
    [self.selectedAssets removeAllObjects];
    
    for (NSIndexPath *indexPath in [self.selectedIndexPaths copy]) {
        [self collectionView:self.collectionView didDeselectItemAtIndexPath:indexPath];
    }
    
    [self.selectedIndexPaths removeAllObjects];
    [self updateToolbar];
}

#pragma mark - Collection view

- (void)setupCollectionView {
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];

    [layout calculateAndSetItemSizeReversed:NO];
    layout.minimumInteritemSpacing = 2;
    layout.minimumLineSpacing = 2;
    self.itemSize = layout.itemSize;
    self.collectionView.collectionViewLayout = layout;
    self.collectionView.alwaysBounceVertical = YES;
    [self.collectionView registerClass:[FSCollectionViewCell class] forCellWithReuseIdentifier:@"fsCell"];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.assetsFetchResult.count;
}
- (NSInteger)getReversedIndexPathRow:(NSIndexPath *)indexPath {
    return (self.assetsFetchResult.count-1) - indexPath.row;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    FSCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"fsCell" forIndexPath:indexPath];
    PHAsset *asset = self.assetsFetchResult[ [self getReversedIndexPathRow:indexPath] ];

    if ([self.selectedIndexPaths containsObject:indexPath]) {
        [self markCellAsSelected:cell atIndexPath:indexPath];
    } else {
        cell.overlayImageView.image = nil;
    }

    cell.type = FSCollectionViewCellTypeMedia;

    [FSImageFetcher imageForAsset:asset
          withCachingImageManager:self.cachingImageManager
                        thumbSize:self.itemSize.width
                      contentMode:PHImageContentModeAspectFill
                      imageResult:^(UIImage *image) {
        cell.imageView.image = image;
    }];

    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    FSCollectionViewCell *cell = (FSCollectionViewCell *)[collectionView cellForItemAtIndexPath:indexPath];
    [self markCellAsSelected:cell atIndexPath:indexPath];
    [self.selectedAssets addObject:self.assetsFetchResult[ [self getReversedIndexPathRow:indexPath] ]];
    [self.selectedIndexPaths addObject:indexPath];

    if (self.config.selectMultiple) {
        [self updateToolbar];
    } else {
        [self uploadSelectedAssets];
    }
}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath {
    FSCollectionViewCell *cell = (FSCollectionViewCell *)[collectionView cellForItemAtIndexPath:indexPath];
    cell.overlayImageView.image = nil;
    [self.selectedAssets removeObject:self.assetsFetchResult[ [self getReversedIndexPathRow:indexPath] ]];
    [self.selectedIndexPaths removeObject:indexPath];
    [self updateToolbar];
}

- (void)markCellAsSelected:(FSCollectionViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    cell.overlayImageView.image = self.selectedOverlay;
    cell.selected = YES;
    [self.collectionView selectItemAtIndexPath:indexPath animated:NO scrollPosition:UICollectionViewScrollPositionNone];
}

#pragma mark - Toolbar

- (void)setupToolbar {
    [self setToolbarItems:@[[self spaceButtonItem], [self uploadButtonItem], [self spaceButtonItem]] animated:NO];
}

- (UIBarButtonItem *)spaceButtonItem {
    return [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
}

- (UIBarButtonItem *)uploadButtonItem {
    return [[UIBarButtonItem alloc] initWithTitle:nil style:UIBarButtonItemStylePlain target:self action:@selector(uploadSelectedAssets)];
}

- (void)updateToolbar {
    if (!self.toolbarColorsSet) {
        self.toolbarColorsSet = YES;
        self.navigationController.toolbar.barTintColor = [FSBarButtonItem appearance].backgroundColor;
        self.navigationController.toolbar.tintColor = [FSBarButtonItem appearance].normalTextColor;
    }

    if (self.selectedAssets.count > 0) {
        [self.navigationController setToolbarHidden:NO animated:YES];
        [self updateToolbarButtonTitle];
    } else {
        [self.navigationController setToolbarHidden:YES animated:YES];
    }
}

- (void)updateToolbarButtonTitle {
    NSString *title;

    if ((long)self.selectedAssets.count > self.config.maxFiles && self.config.maxFiles != 0) {
        title = [NSString stringWithFormat:@"Maximum %lu file%@", (long)self.config.maxFiles, self.config.maxFiles > 1 ? @"s" : @""];
        self.uploadButton.enabled = NO;
    } else {
        title = [NSString stringWithFormat:@"Upload %lu file%@", (unsigned long)self.selectedAssets.count, self.selectedAssets.count > 1 ? @"s" : @""];
        self.uploadButton.enabled = YES;
    }

    [self.uploadButton setTitle:title];
}

- (UIBarButtonItem *)uploadButton {
    return self.toolbarItems[1];
}

#pragma mark - Collection layout

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [self updateCollectionViewLayoutWithSize];
}

- (void)updateCollectionViewLayoutWithSize {
    UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout;

    [layout calculateAndSetItemSizeReversed:YES];
    self.itemSize = layout.itemSize;
    [layout invalidateLayout];
}

@end
