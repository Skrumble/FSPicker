//
//  FSSourceListViewController.m
//  FSPicker
//
//  Created by Łukasz Cichecki on 02/03/16.
//  Copyright © 2016 Filestack. All rights reserved.
//

#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>

#import "FSConfig.h"
#import "FSSource.h"
#import "FSConfig+Private.h"
#import "FSSaveController.h"
#import "FSSourceTableViewCell.h"
#import "FSAlbumsViewController.h"
#import "FSSourceViewController.h"
#import "FSSearchViewController.h"
#import "FSSaveController+Private.h"
#import "UIAlertController+FSPicker.h"
#import "FSPickerController+Private.h"
#import "FSSourceListViewController.h"
#import "FSSaveSourceViewController.h"
#import "FSProgressModalViewController.h"

#import "Skrumble-Swift.h"

@interface FSSourceListViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, assign) BOOL inPickMode;
@property (nonatomic, strong) FSConfig *config;
@property (nonatomic, copy) NSMutableArray<NSArray<FSSource *> *> *dataSources;
@property (nonatomic, copy) NSMutableArray<NSString *> *dataSourcesSectionTitles;

@end

@implementation FSSourceListViewController

- (instancetype)initWithConfig:(FSConfig *)config {
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        _config = config;
        _dataSources = [[NSMutableArray alloc] init];
        _dataSourcesSectionTitles = [[NSMutableArray alloc] init];
    }

    return self;
}

- (void)dealloc {
    NSLog(@"FSPICKER - dealloc FSSourceListViewController");
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _inPickMode = [self.navigationController isMemberOfClass:[FSPickerController class]];

    [self setupTitleAndNavigation];
    [self setupDataSources];

    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)dismissController {
    if (self.inPickMode) {
        [(FSPickerController *)self.navigationController didCancel];
    } else {
        [(FSSaveController *)self.navigationController didCancel];
    }
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - View setup

- (void)setupDataSources {
    if (!self.config) {
        return;
    }

    BOOL forSaving = NO;

    if (!self.inPickMode) {
        forSaving = YES;
    }

    NSArray *localSources = [self.config fsLocalSourcesForSaving:forSaving];
    NSArray *remoteSources = [self.config fsRemoteSourcesForSaving:forSaving];

    if (localSources.count != 0) {
        [self addDataSource:localSources withSectionTitle:@"Local"];
    }

    if (remoteSources.count != 0) {
        [self addDataSource:remoteSources withSectionTitle:@"Cloud"];
    }
}

- (void)addDataSource:(NSArray<FSSource *> *)dataSource withSectionTitle:(NSString *)sectionTitle {
    [self.dataSources addObject:dataSource];
    [self.dataSourcesSectionTitles addObject:sectionTitle];
}

- (void)setupTitleAndNavigation {
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle:@"Cancel"
                                                                     style:UIBarButtonItemStylePlain
                                                                    target:self
                                                                    action:@selector(dismissController)];

    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:@"Back"
                                                                   style:UIBarButtonItemStylePlain
                                                                  target:nil
                                                                  action:nil];

    self.navigationItem.leftBarButtonItem = cancelButton;
    self.navigationItem.backBarButtonItem = backButton;

    self.title = self.config.title ? self.config.title : @"Filestack";
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.dataSources.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dataSources[section].count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (self.dataSourcesSectionTitles.count <= 1) {
        return nil;
    }

    return self.dataSourcesSectionTitles[section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    FSSourceTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"fsCell"];

    if (!cell) {
        cell = [[FSSourceTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"fsCell"];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    FSSource *source = [self sourceAtIndexPath:indexPath];
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    UIImage *image = [[UIImage imageNamed:source.icon
                                 inBundle:bundle
            compatibleWithTraitCollection:nil] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

    cell.imageView.image = image;
    cell.textLabel.text = source.name;

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    FSSource *source = [self sourceAtIndexPath:indexPath];

    if ([source.identifier isEqualToString:FSSourceCameraRoll]) { // Picker and export.
        [self cameraRollSourceSelected:source atIndexPath:indexPath];
    } else if ([source.identifier isEqualToString:FSSourceImageSearch]) { // Picker only.
        FSSearchViewController *searchController = [[FSSearchViewController alloc] initWithConfig:self.config source:source];
        [self.navigationController pushViewController:searchController animated:YES];
    } else if ([source.identifier isEqualToString:FSSourceCamera]) { // Picker only.
        [self setupAndPresentImagePickerControllerForCellAtIndexPath:indexPath];
    } else { // Picker and export.
        if (self.inPickMode) {
            FSSourceViewController *destinationController = [[FSSourceViewController alloc] initWithConfig:self.config source:source];
            [self.navigationController pushViewController:destinationController animated:YES];
        } else {
            FSSaveSourceViewController *destinationController = [[FSSaveSourceViewController alloc] initWithConfig:self.config source:source];
            [self.navigationController pushViewController:destinationController animated:YES];
        }
    }
}

- (FSSource *)sourceAtIndexPath:(NSIndexPath *)indexPath {
    return self.dataSources[indexPath.section][indexPath.row];
}

# pragma mark - Source Selected

- (void)cameraRollSourceSelected:(FSSource *)source atIndexPath:(NSIndexPath *)indexPath {
    if (self.inPickMode) {
        PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
        FSAlbumsViewController *destinationController = [[FSAlbumsViewController alloc] initWithConfig:self.config source:source];
        if(status == PHAuthorizationStatusAuthorized){
            
            [self.navigationController pushViewController:destinationController animated:YES];
            
        } else {
            [DevicePermission checkPhotoAlbumPermission:self completion:^(BOOL permission) {
                if( permission ){
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.navigationController pushViewController:destinationController animated:YES];
                    });
                }
            }];
        }
    } else {
        FSExporter *exporter = [[FSExporter alloc] initWithConfig:self.config];
        exporter.exporterDelegate = (FSSaveController *)self.navigationController;
        [exporter saveDataToCameraRoll];
    }
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - UIImagePickerController

- (void)setupAndPresentImagePickerControllerForCellAtIndexPath:(NSIndexPath *)indexPath {
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        UIAlertController *alert = [UIAlertController fsAlertNoCamera];
        [self presentViewController:alert animated:YES completion:^{
            [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        }];
        return;
    }
    
    NSString *mediaType = AVMediaTypeVideo;
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:mediaType];
    if(authStatus == AVAuthorizationStatusAuthorized){
        [self openCameraController];
    } else {
        [DevicePermission checkCameraPermission:self completion:^(BOOL permission) {
            if (permission) {
                [self openCameraController];
            }
        }];
    }
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}
- (void)openCameraController {
    UIImagePickerController *pickerController = [[UIImagePickerController alloc] init];
    
    pickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
    pickerController.mediaTypes = [self imagePickerMediaTypes];
    pickerController.allowsEditing = NO;
    pickerController.delegate = self;
    
    if (self.config.defaultToFrontCamera) {
        pickerController.cameraDevice = UIImagePickerControllerCameraDeviceFront;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentViewController:pickerController animated:YES completion:nil];
    });
}
- (NSArray *)imagePickerMediaTypes {
    NSMutableArray *mediaTypes = [[NSMutableArray alloc] init];

    if ([self.config showImages]) {
        [mediaTypes addObject:@"public.image"];
    }

    if ([self.config showVideos]) {
        [mediaTypes addObject:@"public.movie"];
    }

    return mediaTypes;
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    [picker dismissViewControllerAnimated:YES completion:^{
        
        if (self.config.shouldUpload == NO) {
            FSPickerController *pickerController = (FSPickerController *)self.navigationController;
            UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
            if ([pickerController respondsToSelector:@selector(fsImageSelected:withURL:)]) {
                [pickerController fsImageSelected:image withURL:nil];
            }
            if (self.config.shouldCloseAfterDownload) {
                [FSPickerController closeCurrentFSPickerDisplayed];
            }
        }

        FSUploader *uploader = [FSPickerController createUploaderWithViewController:self config:self.config source:nil];
        [uploader uploadCameraItemWithInfo:info];
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

@end
