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

<<<<<<< HEAD
static inline AVCaptureDevicePosition
AVPositionForUICamera (UIImagePickerControllerCameraDevice camera)
{
    switch(camera) {
    case UIImagePickerControllerCameraDeviceRear:
        return(AVCaptureDevicePositionBack);
    case UIImagePickerControllerCameraDeviceFront:
        return(AVCaptureDevicePositionFront);
    }
=======
static CGFloat const ZBRVCControlsHeight = 54.0f;
static NSString *const ZBRVCFocusObserver = @"adjustingFocus";

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
    
<<<<<<< HEAD
>>>>>>> 2ffc30c... Customised version of ZBar being used by rDriveway.
    return(-1);
=======
    return -1;
>>>>>>> 56cb785... Tweaking files to allow for animations when scanner is focusing or reading barcodes.
}

static inline UIImagePickerControllerCameraDevice
UICameraForAVPosition (AVCaptureDevicePosition position)
{
    switch (position)
    {
<<<<<<< HEAD
    case AVCaptureDevicePositionBack:
        return(UIImagePickerControllerCameraDeviceRear);
    case AVCaptureDevicePositionFront:
        return(UIImagePickerControllerCameraDeviceFront);
    }
=======
        case AVCaptureDevicePositionBack:
            return UIImagePickerControllerCameraDeviceRear;
        case AVCaptureDevicePositionFront:
            return UIImagePickerControllerCameraDeviceFront;
        case AVCaptureDevicePositionUnspecified:
            break;
    }
    
<<<<<<< HEAD
>>>>>>> 2ffc30c... Customised version of ZBar being used by rDriveway.
    return(-1);
=======
    return -1;
>>>>>>> 56cb785... Tweaking files to allow for animations when scanner is focusing or reading barcodes.
}

static inline AVCaptureDevice*
AVDeviceForUICamera (UIImagePickerControllerCameraDevice camera)
{
    AVCaptureDevicePosition position = AVPositionForUICamera(camera);
<<<<<<< HEAD
    if(position < 0)
        return(nil);
=======
    
    if (position < 0)
    {
        return nil;
    }
>>>>>>> 2ffc30c... Customised version of ZBar being used by rDriveway.

#if !TARGET_IPHONE_SIMULATOR
<<<<<<< HEAD
    NSArray *allDevices =
        [AVCaptureDevice devicesWithMediaType: AVMediaTypeVideo];
<<<<<<< HEAD
    for(AVCaptureDevice *device in allDevices)
        // FIXME how to quantify "best" of several (theoretical) possibilities
        if(device.position == position)
            return(device);
=======
=======
    NSArray *allDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
>>>>>>> 56cb785... Tweaking files to allow for animations when scanner is focusing or reading barcodes.
    for (AVCaptureDevice *device in allDevices)
    {
        // FIXME how to quantify "best" of several (theoretical) possibilities
        if (device.position == position)
        {
            return device;
        }
    }
>>>>>>> 2ffc30c... Customised version of ZBar being used by rDriveway.
#endif
    return nil;
}

static inline AVCaptureTorchMode
AVTorchModeForUIFlashMode (UIImagePickerControllerCameraFlashMode mode)
{
    switch (mode)
    {
<<<<<<< HEAD
    case UIImagePickerControllerCameraFlashModeAuto:
        return(AVCaptureTorchModeAuto);
    case UIImagePickerControllerCameraFlashModeOn:
        return(AVCaptureTorchModeOn);
    case UIImagePickerControllerCameraFlashModeOff:
        break;
    }
=======
        case UIImagePickerControllerCameraFlashModeAuto:
            return AVCaptureTorchModeAuto;
        case UIImagePickerControllerCameraFlashModeOn:
            return AVCaptureTorchModeOn;
        case UIImagePickerControllerCameraFlashModeOff:
            break;
    }
    
<<<<<<< HEAD
>>>>>>> 2ffc30c... Customised version of ZBar being used by rDriveway.
    return(AVCaptureTorchModeOff);
=======
    return AVCaptureTorchModeOff;
>>>>>>> 56cb785... Tweaking files to allow for animations when scanner is focusing or reading barcodes.
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
    AVCaptureDevice *device = nil;
#if !TARGET_IPHONE_SIMULATOR
    device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
#endif
    
    if (device)
    {
        cameraDevice = UICameraForAVPosition(device.position);
    }
    else
    {
        cameraDevice = UIImagePickerControllerCameraDeviceRear;
    }

    // create our own scanner to store configuration,
    // independent of whether view is loaded
    scanner = [ZBarImageScanner new];
    [scanner setSymbology:0
                   config:ZBAR_CFG_X_DENSITY
                       to:3];
    [scanner setSymbology:0
                   config:ZBAR_CFG_Y_DENSITY
                       to:3];
}

- (id) init
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

- (id) initWithCoder:(NSCoder*) decoder
{
    self = [super initWithCoder:decoder];
    
    if (!self)
    {
        return nil;
    }

    [self _init];
    return self;
}

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
<<<<<<< HEAD
=======
    
>>>>>>> 2ffc30c... Customised version of ZBar being used by rDriveway.
    [super dealloc];
}

- (void) initControls
{
<<<<<<< HEAD
    if(!showsZBarControls && controls) {
=======
    if (!showsZBarControls && controls)
    {
>>>>>>> 2ffc30c... Customised version of ZBar being used by rDriveway.
        [controls removeFromSuperview];
        [controls release];
        controls = nil;
    }
<<<<<<< HEAD
    if(!showsZBarControls)
        return;

    UIView *view = self.view;
    if(controls) {
=======
    
    if (!showsZBarControls)
    {
        return;
    }

    UIView *view = self.view;
    
    if (controls)
    {
<<<<<<< HEAD
>>>>>>> 2ffc30c... Customised version of ZBar being used by rDriveway.
        assert(controls.superview == view);
        [view bringSubviewToFront: controls];
=======
        NSAssert(controls.superview == view, @"The wrong constrols has been obtained");
        [view bringSubviewToFront:controls];
>>>>>>> 56cb785... Tweaking files to allow for animations when scanner is focusing or reading barcodes.
        return;
    }

    CGRect r = view.bounds;
<<<<<<< HEAD
    r.origin.y = r.size.height - 54;
    r.size.height = 54;
    controls = [[UIView alloc]
                   initWithFrame: r];
    controls.autoresizingMask =
        UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleHeight |
        UIViewAutoresizingFlexibleTopMargin;
    controls.backgroundColor = [UIColor blackColor];

    UIToolbar *toolbar =
        [UIToolbar new];
    r.origin.y = 0;
    toolbar.frame = r;
    toolbar.barStyle = UIBarStyleBlackOpaque;
    toolbar.autoresizingMask =
        UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleHeight;

    UIButton *info =
        [UIButton buttonWithType: UIButtonTypeInfoLight];
    [info addTarget: self
          action: @selector(info)
          forControlEvents: UIControlEventTouchUpInside];

    toolbar.items =
        [NSArray arrayWithObjects:
            [[[UIBarButtonItem alloc]
                 initWithBarButtonSystemItem: UIBarButtonSystemItemCancel
                 target: self
                 action: @selector(cancel)]
                autorelease],
            [[[UIBarButtonItem alloc]
                 initWithBarButtonSystemItem: UIBarButtonSystemItemFlexibleSpace
                 target: nil
                 action: nil]
                autorelease],
            [[[UIBarButtonItem alloc]
                 initWithCustomView: info]
                autorelease],
            nil];
    [controls addSubview: toolbar];
    [toolbar release];

    [view addSubview: controls];
=======
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
>>>>>>> 2ffc30c... Customised version of ZBar being used by rDriveway.
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
<<<<<<< HEAD
<<<<<<< HEAD
    self.view = [[UIView alloc]
                    initWithFrame: CGRectMake(0, 0, 320, 480)];
=======
    UIView *view = [[UIView alloc] initWithFrame: CGRectMake(0, 0, 320, 480)];
=======
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
>>>>>>> 56cb785... Tweaking files to allow for animations when scanner is focusing or reading barcodes.
    self.view = view;
    [view release];
>>>>>>> 2ffc30c... Customised version of ZBar being used by rDriveway.
}


#pragma mark - View Lifecycle -

- (void) viewDidLoad
{
    [super viewDidLoad];
<<<<<<< HEAD
    UIView *view = self.view;
    view.backgroundColor = [UIColor blackColor];
    view.autoresizingMask =
        UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleHeight;

    readerView = [[ZBarReaderView alloc]
                     initWithImageScanner: scanner];
    CGRect bounds = view.bounds;
    CGRect r = bounds;
    NSUInteger autoresize =
        UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleHeight;
=======
    
    UIView *view = self.view;
    view.backgroundColor = [UIColor blackColor];
    view.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                             UIViewAutoresizingFlexibleHeight);

    _readerView = [[ZBarReaderView alloc] initWithImageScanner:scanner];
    CGRect bounds = view.bounds;
    CGRect r = bounds;
    NSUInteger autoresize = (UIViewAutoresizingFlexibleWidth |
                             UIViewAutoresizingFlexibleHeight);
>>>>>>> 2ffc30c... Customised version of ZBar being used by rDriveway.

    if (showsZBarControls ||
        self.parentViewController.modalViewController == self)
    {
        autoresize |= UIViewAutoresizingFlexibleBottomMargin;
<<<<<<< HEAD
        r.size.height -= 54;
    }
=======
        //r.size.height -= ZBRVCControlsHeight;
    }

    self.readerView.frame = r;
    self.readerView.autoresizingMask = autoresize;
    
<<<<<<< HEAD
>>>>>>> 2ffc30c... Customised version of ZBar being used by rDriveway.
    readerView.frame = r;
    readerView.autoresizingMask = autoresize;
=======
>>>>>>> 56cb785... Tweaking files to allow for animations when scanner is focusing or reading barcodes.
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
    zlog(@"willAppear: anim=%d orient=%d",
         animated, self.interfaceOrientation);
    [self initControls];
    
    // Add autofocus observer.
    AVCaptureDevice *camDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    int flags = NSKeyValueObservingOptionNew;
    [camDevice addObserver:self
                forKeyPath:ZBRVCFocusObserver
                   options:flags
                   context:nil];

    
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
    // Remove autofocus observer.
    AVCaptureDevice *camDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    [camDevice removeObserver:self forKeyPath:ZBRVCFocusObserver];
    
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

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orient
{
    return((supportedOrientationsMask >> orient) & 1);
}

- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation) orient
                                 duration:(NSTimeInterval) duration
{
    zlog(@"willRotate: orient=%d #%g", orient, duration);
    rotating = YES;
    if (self.readerView)
    {
        [self.readerView willRotateToInterfaceOrientation:orient
                                                 duration:duration];
    }
}

- (void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)orient
                                          duration:(NSTimeInterval)duration
{
    zlog(@"willAnimateRotation: orient=%d #%g", orient, duration);
    if (helpController)
    {
        [helpController willAnimateRotationToInterfaceOrientation:orient
                                                         duration:duration];
    }
    
    if (self.readerView)
    {
        [self.readerView setNeedsLayout];
    }
}

- (void) didRotateFromInterfaceOrientation:(UIInterfaceOrientation)orient
{
    zlog(@"didRotate(%d): orient=%d", rotating, orient);
    
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
        [self dismissModalViewControllerAnimated:YES];
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

- (void)takePicture
{
    if (TARGET_IPHONE_SIMULATOR)
    {
        [cameraSim takePicture];
        // FIXME return selected image
    }
    else if (self.readerView)
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

- (void) setCameraCaptureMode:(UIImagePickerControllerCameraCaptureMode)mode
{
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


#pragma mark - Autofocus Observer -

- (void) observeValueForKeyPath:(NSString *)keyPath
                       ofObject:(id)object
                         change:(NSDictionary *)change
                        context:(void *)context
{
    // Note: The camera in the iPad 2 does not autofocus and so will not receive these events.
    if ([keyPath isEqualToString:ZBRVCFocusObserver])
    {
        BOOL adjustingFocus = [ [change objectForKey:NSKeyValueChangeNewKey] isEqualToNumber:[NSNumber numberWithInt:1] ];
        NSLog(@"Adjusting focus: %@", adjustingFocus ? @"Yes" : @"No");
        
        [UIView animateWithDuration:.25
                         animations:^{
                             
                             CGRect frame = self.readerView.targetOutline.frame;
                             
                             if (adjustingFocus)
                             {
                                 frame.size.width  = frame.size.width  * 1.10f;
                                 frame.size.height = frame.size.height * 1.10f;
                             }
                             else
                             {
                                 frame.size.width  = frame.size.width  / 110 * 100;
                                 frame.size.height = frame.size.height / 110 * 100;
                             }
                             
                             self.readerView.targetOutline.frame = frame;
                         }
                         completion:^(BOOL finished) {
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

DEPRECATED_PROPERTY(sourceType, setSourceType, UIImagePickerControllerSourceType, UIImagePickerControllerSourceTypeCamera, NO)
DEPRECATED_PROPERTY(allowsEditing, setAllowsEditing, BOOL, NO, NO)
DEPRECATED_PROPERTY(allowsImageEditing, setAllowsImageEditing, BOOL, NO, NO)
DEPRECATED_PROPERTY(showsCameraControls, setShowsCameraControls, BOOL, NO, NO)
DEPRECATED_PROPERTY(showsHelpOnFail, setShowsHelpOnFail, BOOL, NO, YES)
DEPRECATED_PROPERTY(cameraMode, setCameraMode, ZBarReaderControllerCameraMode, ZBarReaderControllerCameraModeSampling, NO)
DEPRECATED_PROPERTY(takesPicture, setTakesPicture, BOOL, NO, NO)
DEPRECATED_PROPERTY(maxScanDimension, setMaxScanDimension, NSInteger, 640, YES)

@end
