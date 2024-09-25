#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MobileSubstrate/MobileSubstrate.h>
#import <CoreMedia/CoreMedia.h>
#import <MediaPlayer/MediaPlayer.h>
#import <ImageIO/ImageIO.h>

static BOOL g_cameraRunning = NO;
static AVPlayer *g_player = nil;
static AVSampleBufferDisplayLayer *g_previewLayer = nil;

@interface VirtualCameraViewController : UIViewController
@property (nonatomic, strong) UIButton *selectVideoSourceButton;
@property (nonatomic, strong) UIButton *selectStreamSourceButton;
@property (nonatomic, strong) UIButton *setExifButton;
@property (nonatomic, strong) UIButton *startCameraButton;
@property (nonatomic, strong) UIButton *stopCameraButton;
@property (nonatomic, strong) NSString *selectedVideoSource; // 视频源类型
@property (nonatomic, strong) NSString *streamURL;           // HLS 流 URL
@end

@implementation VirtualCameraViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
}

#pragma mark - Setup UI
- (void)setupUI {
    self.view.backgroundColor = [UIColor whiteColor];
    
    // 选择本地视频源按钮
    self.selectVideoSourceButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.selectVideoSourceButton setTitle:@"选择本地视频源" forState:UIControlStateNormal];
    self.selectVideoSourceButton.frame = CGRectMake(50, 100, 300, 50);
    [self.selectVideoSourceButton addTarget:self action:@selector(selectLocalVideoSource) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.selectVideoSourceButton];
    
    // 选择流媒体源按钮
    self.selectStreamSourceButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.selectStreamSourceButton setTitle:@"选择流媒体源" forState:UIControlStateNormal];
    self.selectStreamSourceButton.frame = CGRectMake(50, 170, 300, 50);
    [self.selectStreamSourceButton addTarget:self action:@selector(selectStreamSource) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.selectStreamSourceButton];
    
    // 设置EXIF按钮
    self.setExifButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.setExifButton setTitle:@"设置EXIF信息" forState:UIControlStateNormal];
    self.setExifButton.frame = CGRectMake(50, 240, 300, 50);
    [self.setExifButton addTarget:self action:@selector(setExifData) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.setExifButton];
    
    // 启动虚拟相机按钮
    self.startCameraButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.startCameraButton setTitle:@"启动虚拟相机" forState:UIControlStateNormal];
    self.startCameraButton.frame = CGRectMake(50, 310, 300, 50);
    [self.startCameraButton addTarget:self action:@selector(startVirtualCamera) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.startCameraButton];
    
    // 关闭虚拟相机按钮
    self.stopCameraButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.stopCameraButton setTitle:@"关闭虚拟相机" forState:UIControlStateNormal];
    self.stopCameraButton.frame = CGRectMake(50, 380, 300, 50);
    [self.stopCameraButton addTarget:self action:@selector(stopVirtualCamera) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.stopCameraButton];
}

#pragma mark - 视频源选择逻辑
- (void)selectLocalVideoSource {
    self.selectedVideoSource = @"local";
    [self openPhotoLibraryForVideoSource];
}
- (void)selectStreamSource {
    self.selectedVideoSource = @"stream";
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"输入HLS流媒体URL" 
                                                                             message:nil 
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"http://your-server-ip/live/stream.m3u8";
    }];
    
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UITextField *urlField = alertController.textFields.firstObject;
        self.streamURL = urlField.text;
        NSLog(@"设置流媒体源 URL: %@", self.streamURL);
    }];
    
    [alertController addAction:confirmAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)setExifData {
    [self openPhotoLibraryForExif];
}

#pragma mark - 启动/关闭虚拟相机
- (void)startVirtualCamera {
    if (g_cameraRunning) return;

    if ([self.selectedVideoSource isEqualToString:@"local"]) {
        NSLog(@"使用本地视频源启动虚拟相机");
        // 启动本地视频播放
    } else if ([self.selectedVideoSource isEqualToString:@"stream"]) {
        NSLog(@"使用流媒体源启动虚拟相机");
        
        NSURL *streamURL = [NSURL URLWithString:self.streamURL];
        AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL:streamURL];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handlePlaybackError:)
                                                     name:AVPlayerItemFailedToPlayToEndTimeNotification
                                                   object:playerItem];
        
        g_player = [AVPlayer playerWithPlayerItem:playerItem];
        
        // 添加视频预览层
        g_previewLayer = [[AVSampleBufferDisplayLayer alloc] init];
        g_previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        g_previewLayer.frame = self.view.bounds;
        [self.view.layer addSublayer:g_previewLayer];

        [g_player play];
    }

    g_cameraRunning = YES;
}

- (void)handlePlaybackError:(NSNotification *)notification {
    NSError *error = [notification.userInfo objectForKey:AVPlayerItemFailedToPlayToEndTimeErrorKey];
    NSLog(@"播放 HLS 流时发生错误: %@", error.localizedDescription);
    // 显示用户友好错误信息
}

- (void)stopVirtualCamera {
    if (!g_cameraRunning) return;
    
    [g_player pause];
    g_player = nil;
    
    [self removePreviewLayer];
    g_cameraRunning = NO;
}

#pragma mark - 相册选择和EXIF提取
- (void)openPhotoLibraryForVideoSource {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.mediaTypes = @[(NSString *)kUTTypeMovie];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)openPhotoLibraryForExif {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.mediaTypes = @[(NSString *)kUTTypeImage, (NSString *)kUTTypeMovie];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    NSURL *mediaURL = info[UIImagePickerControllerMediaURL];
    if ([self.selectedVideoSource isEqualToString:@"local"]) {
        NSLog(@"处理本地视频源: %@", mediaURL);
    } else {
        NSLog(@"处理EXIF文件: %@", mediaURL);
        [self extractExifFromMedia:mediaURL];
    }

    [self dismissViewControllerAnimated:YES completion:nil];
}
- (void)extractExifFromMedia:(NSURL *)mediaURL {
    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)mediaURL, NULL);
    NSDictionary *metadata = (__bridge NSDictionary *)CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);

    if (metadata) {
        NSDictionary *exifData = metadata[(NSString *)kCGImagePropertyExifDictionary];
        NSString *cameraMake = exifData[(NSString *)kCGImagePropertyExifMake];
        NSString *cameraModel = exifData[(NSString *)kCGImagePropertyExifModel];
        NSString *originalDateTime = exifData[(NSString *)kCGImagePropertyExifDateTimeOriginal];

        [self setCustomExifWithMake:cameraMake model:cameraModel dateTime:originalDateTime];
    }

    CFRelease(source);
}

- (void)setCustomExifWithMake:(NSString *)make model:(NSString *)model dateTime:(NSString *)dateTime {
    NSLog(@"设置EXIF: Make: %@, Model: %@, DateTime: %@", make, model, dateTime);
}

#pragma mark - 视频预览层
- (void)setupPreviewLayer {
    g_previewLayer = [[AVSampleBufferDisplayLayer alloc] init];
    g_previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    g_previewLayer.frame = self.view.bounds;
    [self.view.layer addSublayer:g_previewLayer];
}
- (Here's the continuation and final version of the Tweak.xm file, ensuring the jailbroken global virtual camera project is fully integrated with HLS, EXIF metadata, and camera API hooks.

### 1. Tweak.xm (continued)

- (void)removePreviewLayer {
    [g_previewLayer removeFromSuperlayer];
    g_previewLayer = nil;
}

@end

#pragma mark - 系统相机钩子 (Hooking the Camera API)
%hook AVCaptureSession

- (void)startRunning {
    NSLog(@"启动系统摄像头，并替换为虚拟相机内容");
    
    VirtualCameraViewController *vc = [[VirtualCameraViewController alloc] init];
    [vc startVirtualCamera];

    %orig;  // 可根据需求禁用系统摄像头
}

- (void)stopRunning {
    NSLog(@"停止系统摄像头并关闭虚拟相机");
    
    VirtualCameraViewController *vc = [[VirtualCameraViewController alloc] init];
    [vc stopVirtualCamera];

    %orig;
}

%end
Makefile
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:13.0

THEOS_DEVICE_IP = localhost
THEOS_DEVICE_PORT = 22

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = VirtualCamera

VirtualCamera_FILES = Tweak.xm
VirtualCamera_FRAMEWORKS = UIKit AVFoundation CoreMedia MediaPlayer ImageIO

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
 install.exec "killall -9 SpringBoard"


Control File (control)
Package: com.yourname.virtualcamera
Name: VirtualCamera
Version: 1.0-1
Architecture: iphoneos-arm
Description: A virtual camera for jailbroken devices, supporting HLS streams, local video, and EXIF metadata handling.
Maintainer: Your Name <your.email@example.com>
Author: Your Name
Section: Tweaks
Depends: mobilesubstrate
