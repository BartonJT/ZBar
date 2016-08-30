//------------------------------------------------------------------------
//  Copyright 2010 (c) Jeff Brown <spadix@users.sourceforge.net>
//
//  This file is part of the ZBar Bar Code Reader.
//
//  The ZBar Bar Code Reader is free software; you can redistribute it
//  and/or modify it under the terms of the GNU Lesser Public License as
//  published by the Free Software Foundation; either version 2.1 of
//  the License, or (at your option) any later version.
//
//  The ZBar Bar Code Reader is distributed in the hope that it will be
//  useful, but WITHOUT ANY WARRANTY; without even the implied warranty
//  of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU Lesser Public License for more details.
//
//  You should have received a copy of the GNU Lesser Public License
//  along with the ZBar Bar Code Reader; if not, write to the Free
//  Software Foundation, Inc., 51 Franklin St, Fifth Floor,
//  Boston, MA  02110-1301  USA
//
//  http://sourceforge.net/projects/zbar
//------------------------------------------------------------------------

#import <ZBarSDK/ZBarReaderViewController.h>
#import <ZBarSDK/ZBarReaderView.h>
#import <ZBarSDK/ZBarCaptureReader.h>
#import <ZBarSDK/ZBarHelpController.h>
#import <ZBarSDK/ZBarCameraSimulator.h>

#define MODULE ZBarReaderViewController
#import "debug.h"
#import "math.h"

static CGFloat const ZBRVCControlsHeight = 54.0f;

static inline AVCaptureDevicePosition
AVPositionForUICamera (UIImagePickerControllerCameraDevice camera)
{
    switch (camera)
    {
        case UIImagePickerControllerCameraDeviceRear:
            return AVCaptureDevicePositionBack;
        case UIImagePickerControllerCameraDeviceFront:
            return AVCaptureDevicePositionFront;
    }
    
    return -1;
}

static inline UIImagePickerControllerCameraDevice
UICameraForAVPosition (AVCaptureDevicePosition position)
{
    switch (position)
    {
        case AVCaptureDevicePositionBack:
            return UIImagePickerControllerCameraDeviceRear;
        case AVCaptureDevicePositionFront:
            return UIImagePickerControllerCameraDeviceFront;
        case AVCaptureDevicePositionUnspecified:
            break;
    }
    
    return -1;
}

static inline AVCaptureDevice*
AVDeviceForUICamera (UIImagePickerControllerCameraDevice camera)
{
    AVCaptureDevicePosition position = AVPositionForUICamera(camera);
    
    if (position < 0)
    {
        return nil;
    }

#if !TARGET_IPHONE_SIMULATOR
    NSArray *allDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in allDevices)
    {
        // FIXME how to quantify "best" of several (theoretical) possibilities
        if (device.position == position)
        {
            return device;
        }
    }
#endif
    return nil;
}

static inline AVCaptureTorchMode
AVTorchModeForUIFlashMode (UIImagePickerControllerCameraFlashMode mode)
{
    switch (mode)
    {
        case UIImagePickerControllerCameraFlashModeAuto:
            return AVCaptureTorchModeAuto;
        case UIImagePickerControllerCameraFlashModeOn:
            return AVCaptureTorchModeOn;
        case UIImagePickerControllerCameraFlashModeOff:
            break;
    }
    
    return AVCaptureTorchModeOff;
}

static inline NSString*
AVSessionPresetForUIVideoQuality (UIImagePickerControllerQualityType quality)
{
#if !TARGET_IPHONE_SIMULATOR
    switch(quality)
    {
    case UIImagePickerControllerQualityTypeHigh:
        return AVCaptureSessionPresetHigh;
    case UIImagePickerControllerQualityType640x480:
        return AVCaptureSessionPreset640x480;
    case UIImagePickerControllerQualityTypeMedium:
        return AVCaptureSessionPresetMedium;
    case UIImagePickerControllerQualityTypeLow:
        return AVCaptureSessionPresetLow;
    case UIImagePickerControllerQualityTypeIFrame1280x720:
        return AVCaptureSessionPresetiFrame1280x720;
    case UIImagePickerControllerQualityTypeIFrame960x540:
        return AVCaptureSessionPresetiFrame960x540;
    }
#endif
    return nil;
}


@implementation ZBarReaderViewController

@synthesize
    scanner,
    readerDelegate,
    readerView = _readerView,
    showsZBarControls,
    supportedOrientationsMask,
    tracksSymbols,
    enableCache,
    cameraOverlayView,
    cameraViewTransform,
    cameraDevice,
    cameraFlashMode,
    videoQuality,
    scanCrop;

@dynamic
    sourceType,
    allowsEditing,
    allowsImageEditing,
    showsCameraControls,
    showsHelpOnFail,
    cameraMode,
    takesPicture,
    maxScanDimension;


#pragma mark - Class Methods -

+ (BOOL) isSourceTypeAvailable:(UIImagePickerControllerSourceType)sourceType
{
    BOOL isAvailable = NO;
    
    if (sourceType == UIImagePickerControllerSourceTypeCamera)
    {
        isAvailable = (TARGET_IPHONE_SIMULATOR ||
                       [UIImagePickerController isSourceTypeAvailable:sourceType]);
    }
    
    return isAvailable;
}

+ (BOOL) isCameraDeviceAvailable:(UIImagePickerControllerCameraDevice)camera
{
    BOOL isAvailable = (TARGET_IPHONE_SIMULATOR ||
                        [UIImagePickerController isCameraDeviceAvailable:camera]);
    
    return isAvailable;
}

+ (BOOL) isFlashAvailableForCameraDevice:(UIImagePickerControllerCameraDevice)camera
{
    BOOL isAvailable = (TARGET_IPHONE_SIMULATOR ||
                        [UIImagePickerController isFlashAvailableForCameraDevice:camera]);
    
    return isAvailable;
}

+ (NSArray*) availableCaptureModesForCameraDevice:(UIImagePickerControllerCameraDevice)camera
{
    NSArray *array = nil;
    
    if (![self isCameraDeviceAvailable:camera])
    {
        array = [NSArray array];
    }
    else
    {
        // The current reader only supports automatic detection.
        array = [NSArray arrayWithObject:[NSNumber numberWithInteger:UIImagePickerControllerCameraCaptureModeVideo]];
    }
    
    return array;
}


#pragma mark - Initialisation Methods -

- (void) _init
{
    supportedOrientationsMask =
        ZBarOrientationMask(UIInterfaceOrientationPortrait);
    showsZBarControls = YES;
    tracksSymbols = YES;
    enableCache = YES;
    scanCrop = CGRectMake(0, 0, 1, 1);
    cameraViewTransform = CGAffineTransformIdentity;

    cameraFlashMode = UIImagePickerControllerCameraFlashModeAuto;
    videoQuality = UIImagePickerControllerQualityType640x480;
    
    if (!TARGET_IPHONE_SIMULATOR)
    {
        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        cameraDevice = UICameraForAVPosition(device.position);
    }
    else
    {
        cameraDevice = nil;
    }

    // create our own scanner to store configuration,
    // independent of whether the view is loaded
    scanner = [[ZBarImageScanner alloc] init];
    
    [scanner setSymbology:0
                   config:ZBAR_CFG_X_DENSITY
                       to:3];
    
    [scanner setSymbology:0
                   config:ZBAR_CFG_Y_DENSITY
                       to:3];
}

- (instancetype) init
{
    if (!TARGET_IPHONE_SIMULATOR &&
       !NSClassFromString(@"AVCaptureSession"))
    {
        // fallback to old interface
        zlog(@"Falling back to ZBarReaderController");
        [self release];
        
        id aSelf = [[ZBarReaderController alloc] init];
        return aSelf;
    }

    self = [super init];
    
    if (!self)
    {
        return nil;
    }

    self.wantsFullScreenLayout = YES;
    [self _init];
    
    return self;
}

- (instancetype) initWithCoder:(NSCoder*) decoder
{
    self = [super initWithCoder:decoder];
    
    if (!self)
    {
        return nil;
    }

    [self _init];
    return self;
}

- (void) initControls
{
    if (!showsZBarControls && controls)
    {
        [controls removeFromSuperview];
        [controls release];
        controls = nil;
    }
    
    if (!showsZBarControls)
    {
        return;
    }

    UIView *view = self.view;
    
    if (controls)
    {
        NSAssert(controls.superview == view, @"The wrong constrols has been obtained");
        [view bringSubviewToFront:controls];
        return;
    }

    CGRect r = view.bounds;
    r.origin.y = r.size.height - ZBRVCControlsHeight;
    r.size.height = ZBRVCControlsHeight;
    controls = [[UIView alloc] initWithFrame:r];
    controls.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                 UIViewAutoresizingFlexibleTopMargin);
    controls.backgroundColor = [UIColor clearColor];

    UIToolbar *toolbar = [[UIToolbar alloc] init];
    r.origin.y = 0;
    toolbar.frame = r;
    toolbar.barStyle = UIBarStyleDefault;
    toolbar.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                UIViewAutoresizingFlexibleHeight);

    UIButton *info = [UIButton buttonWithType:UIButtonTypeInfoLight];
    [info addTarget:self
             action:@selector(info)
   forControlEvents:UIControlEventTouchUpInside];
    
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                  target:self
                                                                                  action:@selector(cancel)];
    
    UIBarButtonItem *space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                           target:nil
                                                                           action:nil];
    
    UIBarButtonItem *infoButton = [[UIBarButtonItem alloc] initWithCustomView:info];

    toolbar.items = [NSArray arrayWithObjects:
                        cancelButton,
                        space,
                        infoButton,
                        nil];
    
    [cancelButton release];
    [space release];
    [infoButton release];
    
    [controls addSubview:toolbar];
    [toolbar release];

    [view addSubview:controls];
}

- (void) initVideoQuality
{
    NSAssert(_readerView, @"No reader view");
    
    if (!_readerView)
    {
        return;
    }

    AVCaptureSession *session = _readerView.session;
    NSString *preset = AVSessionPresetForUIVideoQuality(videoQuality);
    
    if (session && preset && [session canSetSessionPreset:preset])
    {
        zlog(@"set session preset=%@", preset);
        session.sessionPreset = preset;
    }
    else
    {
        zlog(@"unable to set session preset=%@", preset);
    }
}

- (void) loadView
{
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
    self.view = view;
    [view release];
}


#pragma mark - Memory Management -

- (void) cleanup
{
    [cameraOverlayView removeFromSuperview];
    cameraSim.readerView = nil;
    [cameraSim release];
    cameraSim = nil;
    _readerView.readerDelegate = nil;
    [_readerView release];
    _readerView = nil;
    [controls release];
    controls = nil;
    [shutter release];
    shutter = nil;
}

- (void) dealloc
{
    [self cleanup];
    [cameraOverlayView release];
    cameraOverlayView = nil;
    [scanner release];
    scanner = nil;
    
    [super dealloc];
}


#pragma mark - View Lifecycle -

- (void) viewDidLoad
{
    [super viewDidLoad];
    
    UIView *view = self.view;
    view.backgroundColor = [UIColor blackColor];
    view.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                             UIViewAutoresizingFlexibleHeight);

    _readerView = [[ZBarReaderView alloc] initWithImageScanner:scanner];
    CGRect bounds = view.bounds;
    CGRect r = bounds;
    NSUInteger autoresize = (UIViewAutoresizingFlexibleWidth |
                             UIViewAutoresizingFlexibleHeight);

    if (showsZBarControls ||
        self.parentViewController.presentedViewController == self)
    {
        autoresize |= UIViewAutoresizingFlexibleBottomMargin;
        //r.size.height -= ZBRVCControlsHeight;
    }

    self.readerView.frame = r;
    self.readerView.autoresizingMask = autoresize;
    
    AVCaptureDevice *device = AVDeviceForUICamera(cameraDevice);
    if (device &&
        device != self.readerView.device)
    {
        self.readerView.device = device;
    }
    
    self.readerView.torchMode = AVTorchModeForUIFlashMode(cameraFlashMode);
    [self initVideoQuality];

    self.readerView.readerDelegate = (id<ZBarReaderViewDelegate>)self;
    self.readerView.scanCrop = scanCrop;
    self.readerView.previewTransform = cameraViewTransform;
    self.readerView.tracksSymbols = tracksSymbols;
    self.readerView.enableCache = enableCache;
    [view addSubview:self.readerView];

    shutter = [[UIView alloc] initWithFrame:r];
    shutter.backgroundColor = [UIColor blackColor];
    shutter.opaque = NO;
    shutter.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                UIViewAutoresizingFlexibleHeight);
    [view addSubview:shutter];

    if (cameraOverlayView)
    {
        NSAssert(!cameraOverlayView.superview, @"Camera overlay does not have a superview");
        [cameraOverlayView removeFromSuperview];
        [view addSubview:cameraOverlayView];
    }

    [self initControls];

    if (TARGET_IPHONE_SIMULATOR)
    {
        cameraSim = [[ZBarCameraSimulator alloc] initWithViewController:self];
        cameraSim.readerView = self.readerView;
    }
}

- (void) viewDidUnload
{
    [cameraOverlayView removeFromSuperview];
    [self cleanup];
    [super viewDidUnload];
}

- (void) viewWillAppear:(BOOL)animated
{
    NSInteger orientation = (NSInteger)self.interfaceOrientation;
    
    zlog(@"willAppear: anim=%d orient=%ld",
         animated, (long)orientation);
    [self initControls];

    
    [super viewWillAppear:animated];

    [self.readerView willRotateToInterfaceOrientation:self.interfaceOrientation
                                             duration:0];
    [self.readerView performSelector:@selector(start)
                          withObject:nil
                          afterDelay:0.001];
    shutter.alpha = 1;
    shutter.hidden = NO;

    UIApplication *app = [UIApplication sharedApplication];
    BOOL willHideStatusBar =
        !didHideStatusBar && self.wantsFullScreenLayout && !app.statusBarHidden;
    
    if (willHideStatusBar)
    {
        [app setStatusBarHidden:YES
                  withAnimation:UIStatusBarAnimationFade];
    }
    didHideStatusBar = didHideStatusBar || willHideStatusBar;
}

- (void) viewWillDisappear:(BOOL)animated
{    
    self.readerView.captureReader.enableReader = NO;

    if (didHideStatusBar)
    {
        [[UIApplication sharedApplication] setStatusBarHidden:NO
                                                withAnimation:UIStatusBarAnimationFade];
        didHideStatusBar = NO;
    }

    [super viewWillDisappear:animated];
}

- (void) viewDidDisappear:(BOOL)animated
{
    // stopRunning can take a really long time (>1s observed),
    // so defer until the view transitions are complete
    [self.readerView stop];
    
    [super viewDidDisappear:animated];
}

- (void) dismissModalViewControllerAnimated:(BOOL)animated
{
    if (didHideStatusBar)
    {
        [[UIApplication sharedApplication] setStatusBarHidden:NO
                                                withAnimation:UIStatusBarAnimationFade];
        
        didHideStatusBar = NO;
    }
    
    [super dismissModalViewControllerAnimated:animated];
}


#pragma mark - View Rotation Code -

- (BOOL) shouldAutorotate
{
    return TRUE;
}


- (UIInterfaceOrientationMask) supportedInterfaceOrientations
{
    return supportedOrientationsMask;
}


- (void) viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    zlog(@"will transition to size.");
    
    if (helpController)
    {
        [helpController viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    }
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context)
                                                {
                                                    rotating = YES;
                                                    
                                                    if (self.readerView)
                                                    {
                                                        [self.readerView willRotateToInterfaceOrientation:self.interfaceOrientation
                                                                                                 duration:0];
                                                    }
                                                    
                                                    if (self.readerView)
                                                    {
                                                        [self.readerView setNeedsLayout];
                                                    }
                                                }
                                 completion:^(id<UIViewControllerTransitionCoordinatorContext> context)
                                                {
                                                    zlog(@"didRotate");
                                                    
                                                    if (!rotating && self.readerView)
                                                    {
                                                        // work around UITabBarController bug: willRotate is not called
                                                        // for non-portrait initial interface orientation
                                                        [self.readerView willRotateToInterfaceOrientation:self.interfaceOrientation
                                                                                                 duration:0];
                                                        [self.readerView setNeedsLayout];
                                                    }
                                                    
                                                    rotating = NO;
                                                }];
}


- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)orientation
                                 duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:orientation duration:duration];
    
    zlog(@"willRotate: orient=%ld #%g", (long)orientation, duration);
    
    rotating = YES;
    
    if (self.readerView)
    {
        [self.readerView willRotateToInterfaceOrientation:orientation
                                                 duration:duration];
    }
}

- (void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)orientation
                                          duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:orientation duration:duration];
    
    zlog(@"willAnimateRotation: orient=%ld #%g", (long)orientation, duration);
    
    if (helpController)
    {
        [helpController willAnimateRotationToInterfaceOrientation:orientation
                                                         duration:duration];
    }
    
    if (self.readerView)
    {
        [self.readerView setNeedsLayout];
    }
}

- (void) didRotateFromInterfaceOrientation:(UIInterfaceOrientation)orientation
{
    [super didRotateFromInterfaceOrientation:orientation];
    
    zlog(@"didRotate(%d): orient=%ld", rotating, (long)orientation);
    
    if (!rotating && self.readerView)
    {
        // work around UITabBarController bug: willRotate is not called
        // for non-portrait initial interface orientation
        [self.readerView willRotateToInterfaceOrientation:self.interfaceOrientation
                                                 duration:0];
        [self.readerView setNeedsLayout];
    }
    
    rotating = NO;
}


#pragma mark - Object Methods -

- (void) setTracksSymbols:(BOOL)track
{
    tracksSymbols = track;
    
    if (self.readerView)
    {
        self.readerView.tracksSymbols = track;
    }
}

- (void) setEnableCache:(BOOL)enable
{
    enableCache = enable;
    
    if (self.readerView)
    {
        self.readerView.enableCache = enable;
    }
}

- (void) setScanCrop:(CGRect)r
{
    scanCrop = r;
    
    if (self.readerView)
    {
        self.readerView.scanCrop = r;
    }
}

- (void) setCameraOverlayView:(UIView*)newview
{
    UIView *oldview = cameraOverlayView;
    [oldview removeFromSuperview];

    cameraOverlayView = [newview retain];
    
    if ([self isViewLoaded] && newview)
    {
        [self.view addSubview:newview];
    }

    [oldview release];
}

- (void) setCameraViewTransform:(CGAffineTransform)xfrm
{
    cameraViewTransform = xfrm;
    
    if (self.readerView)
    {
        self.readerView.previewTransform = xfrm;
    }
}

- (void) cancel
{
    if (!readerDelegate)
    {
        return;
    }
    
    SEL cb = @selector(imagePickerControllerDidCancel:);
    
    if ([readerDelegate respondsToSelector:cb])
    {
        [readerDelegate imagePickerControllerDidCancel:(UIImagePickerController*)self];
    }
    else
    {
        [self dismissViewControllerAnimated:YES completion:^{}];
    }
}

- (void) info
{
    [self showHelpWithReason:@"INFO"];
}

- (void) showHelpWithReason:(NSString*)reason
{
    if (helpController)
    {
        return;
    }
    
    helpController = [[ZBarHelpController alloc] initWithReason:reason];
    helpController.delegate = (id<ZBarHelpDelegate>)self;
    helpController.wantsFullScreenLayout = YES;
    
    UIView *helpView = helpController.view;
    helpView.alpha = 0;
    helpView.frame = self.view.bounds;
    
    [helpController viewWillAppear:YES];
    
    [self.view addSubview:helpView];
    
    [UIView beginAnimations:@"ZBarHelp"
                    context:nil];
    helpController.view.alpha = 1;
    
    [UIView commitAnimations];
}

- (void) takePicture
{
    if (!TARGET_IPHONE_SIMULATOR &&
        self.readerView)
    {
        [self.readerView.captureReader captureFrame];
    }
}

- (void) setCameraDevice:(UIImagePickerControllerCameraDevice)camera
{
    cameraDevice = camera;
    
    if (self.readerView)
    {
        AVCaptureDevice *device = AVDeviceForUICamera(camera);
        
        if (device)
        {
            self.readerView.device = device;
        }
    }
}

- (void) setCameraFlashMode:(UIImagePickerControllerCameraFlashMode)mode
{
    cameraFlashMode = mode;
    
    if (self.readerView)
    {
        self.readerView.torchMode = AVTorchModeForUIFlashMode(mode);
    }
}

- (UIImagePickerControllerCameraCaptureMode)cameraCaptureMode
{
    return(UIImagePickerControllerCameraCaptureModeVideo);
}

- (void) setCameraCaptureMode:(UIImagePickerControllerCameraCaptureMode)aMode
{
    int mode = (int)aMode;
    
    NSAssert2(mode == UIImagePickerControllerCameraCaptureModeVideo,
              @"attempt to set unsupported value (%d)"
              @" for %@ property", mode, @"cameraCaptureMode");
}

- (void) setVideoQuality:(UIImagePickerControllerQualityType)quality
{
    videoQuality = quality;
    
    if (self.readerView)
    {
        [self initVideoQuality];
    }
}


#pragma mark - ZBarHelpDelegate -

- (void) helpControllerDidFinish:(ZBarHelpController*)help
{
    NSAssert(help == helpController, @"Incorrect help controller returned.");
    [help viewWillDisappear:YES];
    [UIView beginAnimations:@"ZBarHelp"
                    context:NULL];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(removeHelp:done:context:)];
    help.view.alpha = 0;
    [UIView commitAnimations];
}

- (void) removeHelp:(NSString*)tag
               done:(NSNumber*)done
            context:(void*)ctx
{
    if ([tag isEqualToString:@"ZBarHelp"] && helpController)
    {
        [helpController.view removeFromSuperview];
        [helpController release];
        helpController = nil;
    }
}


#pragma mark - ZBarReaderViewDelegate -

- (void) readerView:(ZBarReaderView*)readerView
     didReadSymbols:(ZBarSymbolSet*)syms
          fromImage:(UIImage*)image
{    
    if (readerDelegate)
    {
        [readerDelegate imagePickerController:(UIImagePickerController*)self
                didFinishPickingMediaWithInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                               image,
                                               UIImagePickerControllerOriginalImage,
                                               syms,
                                               ZBarReaderControllerResults,
                                               nil]];
    }
}

- (void) readerViewDidStart:(ZBarReaderView*)readerView
{
    if (!shutter.hidden)
    {
        [UIView animateWithDuration:0.25f
                         animations:^{
                             
                             shutter.alpha = 0;
                         }
                         completion:^(BOOL finished) {
                             
                             shutter.hidden = YES;
                         }];
    }
}


#pragma mark - "deprecated" properties -

#define DEPRECATED_PROPERTY(getter, setter, type, val, ignore) \
    - (type) getter                                    \
    {                                                  \
        return(val);                                   \
    }                                                  \
    - (void) setter: (type) v                          \
    {                                                  \
        NSAssert2(ignore || v == val,                  \
                  @"attempt to set unsupported value (%d)" \
                  @" for %@ property", val, @#getter); \
    }

DEPRECATED_PROPERTY(sourceType, setSourceType, UIImagePickerControllerSourceType, (int)UIImagePickerControllerSourceTypeCamera, NO)
DEPRECATED_PROPERTY(allowsEditing, setAllowsEditing, BOOL, NO, NO)
DEPRECATED_PROPERTY(allowsImageEditing, setAllowsImageEditing, BOOL, NO, NO)
DEPRECATED_PROPERTY(showsCameraControls, setShowsCameraControls, BOOL, NO, NO)
DEPRECATED_PROPERTY(showsHelpOnFail, setShowsHelpOnFail, BOOL, NO, YES)
DEPRECATED_PROPERTY(cameraMode, setCameraMode, ZBarReaderControllerCameraMode, ZBarReaderControllerCameraModeSampling, NO)
DEPRECATED_PROPERTY(takesPicture, setTakesPicture, BOOL, NO, NO)
DEPRECATED_PROPERTY(maxScanDimension, setMaxScanDimension, NSInteger, 640, YES)

@end
