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

#import <ZBarSDK/ZBarReaderView.h>

#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>

#define MODULE ZBarReaderView
#import <ZBarSDK/ZBarCaptureReader.h>
#import "debug.h"


#define DEGREES_TO_RADIANS(angle) (angle / 180.0 * M_PI)

static NSString *const ZBRVFocusObserver = @"adjustingFocus";


@implementation ZBarReaderView

@synthesize
    readerDelegate,
    tracksSymbols,
    trackingColor,
    torchMode,
    showsFPS,
    zoom,
    maxZoom,
    scanCrop,
    previewTransform,
    captureReader,
    isAnimatingTargetOutline = _isAnimatingTargetOutline,
    targetOutlineFrame       = _targetOutlineFrame,
    targetOutline            = _targetOutline,
    device,
    session;

@dynamic
    scanner,
    allowsPinchZoom,
    enableCache;


#pragma mark - Initialisation Methods -

- (void) initSubviews
{
    preview = [[AVCaptureVideoPreviewLayer layerWithSession: session] retain];
    CGRect bounds = self.bounds;
    bounds.origin = CGPointZero;
    preview.bounds = bounds;
    preview.position = CGPointMake(bounds.size.width / 2,
                                   bounds.size.height / 2);
    
    AVCaptureVideoPreviewLayer *videoPreview = (AVCaptureVideoPreviewLayer *)preview;
    videoPreview.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.layer addSublayer: preview];
    
    
    NSAssert(preview, @"Failed ot initialise preview");

    overlay = [CALayer new];
    overlay.backgroundColor = [UIColor clearColor].CGColor;
    [preview addSublayer:overlay];

#ifndef NDEBUG
    overlay.borderWidth = 2;
    overlay.borderColor = [UIColor colorWithRed:1
                                          green:0
                                           blue:0
                                          alpha:0.5].CGColor;
    cropLayer = [CALayer new];
    cropLayer.backgroundColor = [UIColor clearColor].CGColor;
    cropLayer.borderWidth = 2;
    cropLayer.borderColor = [UIColor colorWithRed:0
                                            green:0
                                             blue:1
                                            alpha:0.5].CGColor;
    [overlay addSublayer:cropLayer];
#endif

    tracking = [CALayer new];
    tracking.opacity = 0;
    tracking.borderWidth = 1;
    tracking.backgroundColor = [UIColor clearColor].CGColor;
    [overlay addSublayer:tracking];

    trackingColor = [[UIColor greenColor] retain];
    tracking.borderColor = trackingColor.CGColor;

    fpsView = [UIView new];
    fpsView.backgroundColor = [UIColor colorWithWhite: 0
                                                alpha: .333];
    fpsView.layer.cornerRadius = 12;
    fpsView.hidden = YES;
    [self addSubview:fpsView];

    fpsLabel = [[UILabel alloc] initWithFrame: CGRectMake(0, 0, 80, 32)];
    fpsLabel.backgroundColor = [UIColor clearColor];
    fpsLabel.textColor = [UIColor colorWithRed:0.333
                                         green:0.666
                                          blue:1
                                         alpha:1];
    fpsLabel.font = [UIFont systemFontOfSize:18];
    fpsLabel.textAlignment = UITextAlignmentRight;
    [fpsView addSubview:fpsLabel];

    self.zoom = 1.25;
    
    NSString *pngFileExtension = @"png";
    UIImage *_targetImage = [[UIImage alloc] initWithContentsOfFile:
                                [[NSBundle mainBundle] pathForResource:@"squaretarget2" ofType:pngFileExtension]];
    
    UIImage *_targetImage2 = [[UIImage alloc] initWithContentsOfFile:
                                [[NSBundle mainBundle] pathForResource:@"squaretarget2_green" ofType:pngFileExtension]];

    _targetOutline = [[UIImageView alloc] initWithImage:_targetImage];
    _targetOutline.animationImages = [NSArray arrayWithObjects:
                                      _targetImage2,
                                      nil];
    _targetOutline.animationDuration = 5.0f;
    _targetOutline.animationRepeatCount = 0;
    
    [_targetImage  release];
    [_targetImage2 release];
    
    _targetOutline.autoresizingMask = (UIViewAutoresizingFlexibleTopMargin   |
                                       UIViewAutoresizingFlexibleRightMargin |
                                       UIViewAutoresizingFlexibleLeftMargin  |
                                       UIViewAutoresizingFlexibleBottomMargin);
    
    _targetOutlineFrame = _targetOutline.frame;
    CGFloat viewWidth  = self.frame.size.width;
    CGFloat viewHeight = self.frame.size.height;
    _targetOutlineFrame.origin.x = (3 * viewWidth / 4) - (3 * _targetOutlineFrame.size.width / 4);
    _targetOutlineFrame.origin.y = (1 * viewHeight / 10) - (1 * _targetOutlineFrame.size.height / 10);
    
    _targetOutline.frame = _targetOutlineFrame;
    
    [self addSubview:_targetOutline];
}

- (void) _initWithImageScanner:(ZBarImageScanner*)scanner
{
    NSAssert(scanner, @"A valid scanner object was not passed");

    _isAnimatingTargetOutline = NO;
    tracksSymbols = YES;
    interfaceOrientation = UIInterfaceOrientationPortrait;
    torchMode = 2; // AVCaptureTorchModeAuto
    scanCrop = effectiveCrop = CGRectMake(0, 0, 1, 1);
    imageScale = 1;
    previewTransform = CGAffineTransformIdentity;
    maxZoom = 2;

    pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self
                                                      action:@selector(handlePinch)];
    [self addGestureRecognizer:pinch];
    
    
    session = [[AVCaptureSession alloc] init];
    
    NSNotificationCenter *notify = [NSNotificationCenter defaultCenter];
    
    [notify addObserver:self
               selector:@selector(onVideoError:)
                   name:AVCaptureSessionRuntimeErrorNotification
                 object:session];
    
    [notify addObserver:self
               selector:@selector(onVideoStart:)
                   name:AVCaptureSessionDidStartRunningNotification
                 object:session];
    
    [notify addObserver:self
               selector:@selector(onVideoStop:)
                   name:AVCaptureSessionDidStopRunningNotification
                 object:session];
    
    [notify addObserver:self
               selector:@selector(onVideoStop:)
                   name:AVCaptureSessionWasInterruptedNotification
                 object:session];
    
    [notify addObserver:self
               selector:@selector(onVideoStart:)
                   name:AVCaptureSessionInterruptionEndedNotification
                 object:session];
    
    self.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    captureReader = [[ZBarCaptureReader alloc] initWithImageScanner:scanner];
    captureReader.captureDelegate = (id<ZBarCaptureDelegate>)self;
    [session addOutput: captureReader.captureOutput];
    
    if ([session canSetSessionPreset: AVCaptureSessionPreset640x480])
    {
        session.sessionPreset = AVCaptureSessionPreset640x480;
    }
    
    [captureReader addObserver:self
                    forKeyPath:@"size"
                       options:0
                       context:NULL];
    
    [self initSubviews];
    
    // Add autofocus observer.
    int flags = NSKeyValueObservingOptionNew;
    [device addObserver:self
             forKeyPath:ZBRVFocusObserver
                options:flags
                context:nil];
}

- (id) initWithImageScanner:(ZBarImageScanner*)scanner
{
    self = [super initWithFrame:CGRectMake(0, 0, 320, 426)];
    
    if (!self)
    {
        return nil;
    }

    self.backgroundColor = [UIColor blackColor];
    self.contentMode = UIViewContentModeScaleAspectFill;
    self.clipsToBounds = YES;
    self.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                             UIViewAutoresizingFlexibleHeight);

    [self _initWithImageScanner:scanner];
    return self;
}

- (id) init
{
    ZBarImageScanner *scanner = [[[ZBarImageScanner alloc] init] autorelease];
    
    self = [self initWithImageScanner:scanner];
    
    if (!self)
    {
        return nil;
    }

    [scanner setSymbology:0
                   config:ZBAR_CFG_X_DENSITY
                       to:3];
    [scanner setSymbology:0
                   config:ZBAR_CFG_Y_DENSITY
                       to:3];
    return self;
}

- (id) initWithCoder:(NSCoder*)decoder
{
    self = [super initWithCoder:decoder];
    
    if (!self)
    {
        return nil;
    }
    
    ZBarImageScanner *scanner = [[[ZBarImageScanner alloc] init] autorelease];
    [self _initWithImageScanner:scanner];

    [scanner setSymbology:0
                   config:ZBAR_CFG_X_DENSITY
                       to:3];
    [scanner setSymbology:0
                   config:ZBAR_CFG_Y_DENSITY
                       to:3];
    
    return self ;
}


#pragma mark - Deallocation Methods -

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    // Remove autofocus observer.
    device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    [device removeObserver:self forKeyPath:ZBRVFocusObserver];
    
    if (showsFPS)
    {
        @try
        {
            [captureReader removeObserver:self
                               forKeyPath:@"framesPerSecond"];
        }
        @catch(...) { }
    }
    @try
    {
        [captureReader removeObserver:self
                           forKeyPath:@"size"];
    }
    @catch(...) { }
    
    captureReader.captureDelegate = nil;
    [captureReader release];
    captureReader = nil;
    
    [device release];
    device = nil;
    
    [input release];
    input = nil;
    
    [session release];
    session = nil;
    
    
    [preview removeFromSuperlayer];
    [preview release];
    preview = nil;
    
    [overlay release];
    overlay = nil;
    
    [cropLayer release];
    cropLayer = nil;
    
    [tracking release];
    tracking = nil;
    
    [trackingColor release];
    trackingColor = nil;
    
    [fpsLabel release];
    fpsLabel = nil;
    
    [fpsView release];
    fpsView = nil;
    
    [pinch release];
    pinch = nil;
    
    [_targetOutline release];
    _targetOutline = nil;
    
    [super dealloc];
}


#pragma mark - UIView Methods -

- (void) layoutSubviews
{
    CGRect bounds = self.bounds;
    
    if (!bounds.size.width || !bounds.size.height)
    {
        return;
    }
    
    [CATransaction begin];
    
    if (animationDuration)
    {
        [CATransaction setAnimationDuration:animationDuration];
        [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:
                                                   kCAMediaTimingFunctionEaseInEaseOut]];
    }
    else
    {
        [CATransaction setDisableActions:YES];
    }
    
    [super layoutSubviews];
    fpsView.frame = CGRectMake(bounds.size.width - 80, bounds.size.height - 32,
                               80 + 12, 32 + 12);
    
    // orient view bounds to match camera image
    CGSize psize;
    if (UIInterfaceOrientationIsPortrait(interfaceOrientation))
    {
        psize = CGSizeMake(bounds.size.height, bounds.size.width);
    }
    else
    {
        psize = bounds.size;
    }
    
    // calculate scale from view coordinates to image coordinates
    // FIXME assumes AVLayerVideoGravityResizeAspectFill
    CGFloat scalex = imageSize.width / psize.width;
    CGFloat scaley = imageSize.height / psize.height;
    imageScale = (scalex < scaley) ? scalex : scaley;
    
    if (!imageScale)
    {
        imageScale = 1;
    }
    // apply zoom
    imageScale /= zoom;
    
    // scale crop by zoom factor
    CGFloat z = 1 / zoom;
    CGFloat t = (1 - z) / 2;
    CGRect zoomCrop = CGRectMake(scanCrop.origin.x * z + t,
                                 scanCrop.origin.y * z + t,
                                 scanCrop.size.width * z,
                                 scanCrop.size.height * z);
    
    // convert effective preview area to normalized image coordinates
    CGRect previewCrop;
    
    if (scalex < scaley &&
        imageSize.height)
    {
        previewCrop.size = CGSizeMake(z, psize.height * imageScale / imageSize.height);
    }
    else if (imageSize.width)
    {
        previewCrop.size = CGSizeMake(psize.width * imageScale / imageSize.width, z);
    }
    else
    {
        previewCrop.size = CGSizeMake(1, 1);
    }
    
    previewCrop.origin = CGPointMake((1 - previewCrop.size.width) / 2,
                                     (1 - previewCrop.size.height) / 2);
    
    // clip crop to visible preview area
    effectiveCrop = CGRectIntersection(zoomCrop, previewCrop);
    
    if (CGRectIsNull(effectiveCrop))
    {
        effectiveCrop = zoomCrop;
    }
    
    // size preview to match image in view coordinates
    CGFloat viewScale = 1 / imageScale;
    
    if (imageSize.width && imageSize.height)
    {
        psize = CGSizeMake(imageSize.width * viewScale,
                           imageSize.height * viewScale);
    }
    
    preview.bounds = CGRectMake(0, 0, psize.height, psize.width);
    // center preview in view
    preview.position = CGPointMake(bounds.size.width / 2,
                                   bounds.size.height / 2);
    
    CGFloat angle = rotationForInterfaceOrientation(interfaceOrientation);
    CATransform3D xform = CATransform3DMakeAffineTransform(previewTransform);
    preview.transform = CATransform3DRotate(xform, angle, 0, 0, 1);
    
    // scale overlay to match actual image
    if (imageSize.width && imageSize.height)
    {
        overlay.bounds = CGRectMake(0, 0, imageSize.width, imageSize.height);
    }
    else
    {
        overlay.bounds = CGRectMake(0, 0, psize.width, psize.height);
    }
    
    // center overlay in preview
    overlay.position = CGPointMake(psize.height / 2, psize.width / 2);
    
    // image coordinates rotated from preview
    xform = CATransform3DMakeRotation(M_PI_2, 0, 0, 1);
    overlay.transform = CATransform3DScale(xform, viewScale, viewScale, 1);
    tracking.borderWidth = imageScale;
    
#ifndef NDEBUG
    preview.backgroundColor = [UIColor yellowColor].CGColor;
    overlay.borderWidth = 2 * imageScale;
    cropLayer.borderWidth = 2 * imageScale;
    cropLayer.frame = CGRectMake(effectiveCrop.origin.x * imageSize.width,
                                 effectiveCrop.origin.y * imageSize.height,
                                 effectiveCrop.size.width * imageSize.width,
                                 effectiveCrop.size.height * imageSize.height);
    zlog(@"layoutSubviews: bounds=%@ orient=%ld image=%@ crop=%@ zoom=%g\n"
         @"=> preview=%@ crop=(z%@ p%@ %@ i%@) scale=%g %c %g = 1/%g",
         NSStringFromCGSize(bounds.size), (long)interfaceOrientation,
         NSStringFromCGSize(imageSize), NSStringFromCGRect(scanCrop), zoom,
         NSStringFromCGSize(psize), NSStringFromCGRect(zoomCrop),
         NSStringFromCGRect(previewCrop), NSStringFromCGRect(effectiveCrop),
         NSStringFromCGRect(cropLayer.frame),
         scalex, (scalex > scaley) ? '>' : '<', scaley, viewScale);
#endif
    
    [self resetTracking];
    [self updateCrop];
    
    [CATransaction commit];
    animationDuration = 0;
}


#pragma mark - View Orientation Methods -

static inline CGFloat rotationForInterfaceOrientation (int orient)
{
    // resolve camera/device image orientation to view/interface orientation
    switch(orient)
    {
        case UIInterfaceOrientationLandscapeLeft:
            return(M_PI_2);
        case UIInterfaceOrientationPortraitUpsideDown:
            return(M_PI);
        case UIInterfaceOrientationLandscapeRight:
            return(3 * M_PI_2);
        case UIInterfaceOrientationPortrait:
            return(2 * M_PI);
    }
    
    return 0;
}

- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)orient
                                 duration:(NSTimeInterval)duration
{
    if (interfaceOrientation != orient)
    {
        zlog(@"orient=%ld #%g", (long)orient, duration);
        interfaceOrientation = orient;
        animationDuration = duration;
    }
}


#pragma mark - Setter/Getter Methods -

- (void) updateCrop
{
    captureReader.scanCrop = effectiveCrop;
}

- (ZBarImageScanner*) scanner
{
    return captureReader.scanner;
}

- (void) setImageSize:(CGSize)size
{
    zlog(@"imageSize=%@", NSStringFromCGSize(size));
    imageSize = size;

    // FIXME bug in AVCaptureVideoPreviewLayer fails to update preview location
    preview.bounds = CGRectMake(0, 0, size.width, size.height);

    [self setNeedsLayout];
}

- (void) setDevice:(AVCaptureDevice*)newdev
{
    id olddev = device;
    AVCaptureInput *oldinput = input;
    assert(!olddev == !oldinput);
    
    NSError *error = nil;
    device = [newdev retain];
    
    if (device)
    {
        assert([device hasMediaType: AVMediaTypeVideo]);
        input = [[AVCaptureDeviceInput alloc] initWithDevice:newdev
                                                       error:&error];
        assert(input);
    }
    else
    {
        input = nil;
    }
    
    [session beginConfiguration];
    
    if(oldinput)
    {
        [session removeInput: oldinput];
    }
    if(input)
    {
        [session addInput: input];
    }
    
    [session commitConfiguration];
    
    [olddev release];
    [oldinput release];
}

- (BOOL) enableCache
{
    return captureReader.enableCache;
}

- (void) setEnableCache:(BOOL)enable
{
    captureReader.enableCache = enable;
}

- (void) setTorchMode:(NSInteger)mode
{
    if (running && [device isTorchModeSupported: mode])
    {
        @try
        {
            device.torchMode = mode;
        }
        @catch(...) { }
    }
}

- (void) setScanCrop:(CGRect)r
{
    if (CGRectEqualToRect(scanCrop, r))
    {
        return;
    }
    
    scanCrop = r;
    [self setNeedsLayout];
}

- (void) setTracksSymbols:(BOOL)track
{
    if (track == tracksSymbols)
    {
        return;
    }
    
    tracksSymbols = track;
    [self resetTracking];
}

- (BOOL) allowsPinchZoom
{
    return pinch.enabled;
}

- (void) setAllowsPinchZoom:(BOOL)enabled
{
    pinch.enabled = enabled;
}

- (void) setTrackingColor:(UIColor*)color
{
    if (!color)
    {
        return;
    }
    
    [trackingColor release];
    trackingColor = [color retain];
    tracking.borderColor = trackingColor.CGColor;
}

- (void) setShowsFPS:(BOOL)show
{
    if (show == showsFPS)
    {
        return;
    }
    
    fpsView.hidden = !show;
    
    @try
    {
        if(show)
        {
            [captureReader addObserver:self
                            forKeyPath:@"framesPerSecond"
                               options:0
                               context:NULL];
        }
        else
        {
            [captureReader removeObserver:self
                               forKeyPath:@"framesPerSecond"];
        }
    }
    @catch(...) { }
}

- (void) setZoom:(CGFloat)z
{
    if (z < 1.0)
    {
        z = 1.0;
    }
    
    if (z > maxZoom)
    {
        z = maxZoom;
    }
    
    if (z == zoom)
    {
        return;
    }
    
    zoom = z;

    [self setNeedsLayout];
}

- (void) setZoom:(CGFloat)z
        animated:(BOOL)animated
{
    [CATransaction begin];
    
    if (animated)
    {
        [CATransaction setAnimationDuration:0.1];
        [CATransaction setAnimationTimingFunction:
            [CAMediaTimingFunction functionWithName:
                kCAMediaTimingFunctionLinear]];
    }
    else
    {
        [CATransaction setDisableActions:YES];
    }
    
    // FIXME animate from current value
    self.zoom = z;
    [self layoutIfNeeded];
    [CATransaction commit];
}

- (void) setPreviewTransform:(CGAffineTransform)xfrm
{
    previewTransform = xfrm;
    [self setNeedsLayout];
}


#pragma mark -

- (void) resetTracking
{
    [tracking removeAllAnimations];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    CGSize size = overlay.bounds.size;
    CGRect crop = effectiveCrop;
    tracking.frame = CGRectMake(crop.origin.x * size.width,
                                crop.origin.y * size.height,
                                crop.size.width * size.width,
                                crop.size.height * size.height);
    tracking.opacity = 0;
    [CATransaction commit];
}

- (void) start
{
    if (started)
    {
        return;
    }
    
    started = YES;

    [self resetTracking];
    fpsLabel.text = @"--- fps ";

    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    
    [session startRunning];
    captureReader.enableReader = YES;
}

- (void) stop
{
    if (!started)
    {
        return;
    }
    
    started = NO;

    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
    
    captureReader.enableReader = NO;
    [session stopRunning];
}

- (void) flushCache
{
    [captureReader flushCache];
}

- (void) configureDevice
{
    if ([device isFocusModeSupported: AVCaptureFocusModeContinuousAutoFocus])
    {
        device.focusMode = AVCaptureFocusModeContinuousAutoFocus;
    }
    
    if ([device isTorchModeSupported: torchMode])
    {
        device.torchMode = torchMode;
    }
}


- (void) lockDevice
{
    if (!running || locked)
    {
        assert(0);
        
        return;
    }
    
    // lock device and set focus mode
    NSError *error = nil;
    if ([device lockForConfiguration:&error])
    {
        locked = YES;
        [self configureDevice];
    }
    else
    {
        zlog(@"failed to lock device: %@", error);
        // just keep trying
        [self performSelector:@selector(lockDevice)
                   withObject:nil
                   afterDelay:0.5];
    }
}


#pragma mark - UIGestureRecognizer Callback -

- (void) handlePinch
{
    if (pinch.state == UIGestureRecognizerStateBegan)
    {
        zoom0 = zoom;
    }
    
    CGFloat z = zoom0 * pinch.scale;
    [self setZoom:z
         animated:YES];

    if ((zoom < 1.5) != (z < 1.5))
    {
        int d = (z < 1.5) ? 3 : 2;
        ZBarImageScanner *scanner = self.scanner;
        @synchronized(scanner)
        {
            [scanner setSymbology:0
                           config:ZBAR_CFG_X_DENSITY
                               to:d];
            [scanner setSymbology:0
                           config:ZBAR_CFG_Y_DENSITY
                               to:d];
        }
    }
}


#pragma mark - Tracking Methods -

- (void) didTrackSymbols:(ZBarSymbolSet*)syms
{
    // Change the target image to a green square to indicate a successful read.
    [self.targetOutline startAnimating];
    
    // Ensure that all animation has stopped after ten seconds.
    CGFloat animationTime = 2.0f;
    [self.targetOutline performSelector:@selector(stopAnimating)
                             withObject:self.targetOutline
                             afterDelay:animationTime];
    
    if (!tracksSymbols)
    {
        return;
    }

    int n = syms.count;
    NSAssert(n, @"n has no value");
    
    if (!n)
    {
        return;
    }

    ZBarSymbol *sym = nil;
    
    for (ZBarSymbol *s in syms)
    {
        if (!sym || s.type == ZBAR_QRCODE || s.quality > sym.quality)
        {
            sym = s;
        }
    }
    
    NSAssert(sym, @"Sym has no value");
    
    if (!sym)
    {
        return;
    }
}


#pragma mark - Autofocus Animations -

- (void) animateIncreasingFocus
{
    self.isAnimatingTargetOutline = YES;
    
    [UIView animateWithDuration:0.50
                     animations:^{
                         
                         CGRect frame = self.targetOutline.bounds;
                         
                         frame.size.width  = frame.size.width  * 1.10f;
                         frame.size.height = frame.size.height * 1.10f;
                         
                         CGAffineTransform transform = CGAffineTransformMakeRotation(DEGREES_TO_RADIANS(45));
                         self.targetOutline.transform = transform;
                         
                         self.targetOutline.bounds = frame;
                     }
                     completion:^(BOOL finished) {
                         
                         [self animateDecreasingFocus];
                     }];
}


- (void) animateDecreasingFocus
{
    [UIView animateWithDuration:0.50
                     animations:^{
                         
                         CGRect frame = self.targetOutline.bounds;
                         
                         frame.size.width  = frame.size.width  / 110 * 80;
                         frame.size.height = frame.size.height / 110 * 80;
                         
                         CGAffineTransform transform = CGAffineTransformMakeRotation(DEGREES_TO_RADIANS(-45));
                         self.targetOutline.transform = transform;
                         self.targetOutline.bounds = frame;
                     }
                     completion:^(BOOL finished) {
                         
                         [self animateOriginalFrame];
                     }];
}


- (void) animateOriginalFrame
{
    [UIView animateWithDuration:0.25
                     animations:^{
                         
                         CGRect frame = self.targetOutline.bounds;
                         
                         CGAffineTransform transform = CGAffineTransformMakeRotation(DEGREES_TO_RADIANS(0));
                         self.targetOutline.transform = transform;
                         
                         frame.size.width  = frame.size.width  / 80 * 100;
                         frame.size.height = frame.size.height / 80 * 100;
                         
                         self.targetOutline.bounds = frame;
                     }
                     completion:^(BOOL finished) {
                         
                         self.isAnimatingTargetOutline = NO;
                     }];
}


#pragma mark - NSKeyValueObserving -

- (void) observeValueForKeyPath:(NSString*)keyPath
                       ofObject:(id)object
                         change:(NSDictionary*)change
                        context:(void*)context
{   
    // Note: The camera in the iPad 2 does not autofocus and so will not receive these events.
    if ([keyPath isEqualToString:ZBRVFocusObserver])
    {
        BOOL adjustingFocus = [[change objectForKey:NSKeyValueChangeNewKey] isEqualToNumber:[NSNumber numberWithInt:1]];
        
        if (adjustingFocus)
        {
            if (!self.isAnimatingTargetOutline &&
                self.window != nil)
            {
                [self animateIncreasingFocus];
            }
        }
    }
    
    if (object == captureReader)
    {
        if ([keyPath isEqualToString: @"size"])
        {
            // Adjust preview to match image size
            [self setImageSize: captureReader.size];
        }
        else if ([keyPath isEqualToString: @"framesPerSecond"])
        {
            fpsLabel.text = [NSString stringWithFormat: @"%.2ffps ",
                             captureReader.framesPerSecond];
        }
    }
}


#pragma mark - AVCaptureSession Notifications -

- (void) onVideoStart:(NSNotification*)note
{
    zlog(@"onVideoStart: running=%d %@", running, note);
    
    if (running)
    {
        return;
    }
    
    running = YES;
    locked = NO;
    
    [self lockDevice];
    
    if ([readerDelegate respondsToSelector:@selector(readerViewDidStart:)])
    {
        [readerDelegate readerViewDidStart:self];
    }
}

- (void) onVideoStop:(NSNotification*)note
{
    zlog(@"onVideoStop: %@", note);
    
    if (!running)
    {
        return;
    }
    
    running = NO;
    
    if (locked)
    {
        [device unlockForConfiguration];
    }
    else
    {
        [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                 selector:@selector(lockDevice)
                                                   object:nil];
    }
    
    locked = NO;
    
    if (readerDelegate &&
        [readerDelegate respondsToSelector:@selector(readerView:didStopWithError:)])
    {
        [readerDelegate readerView:self
                  didStopWithError:nil];
    }
}

- (void) onVideoError: (NSNotification*) note
{
    zlog(@"onVideoError: %@", note);
    
    if (running)
    {
        // FIXME does session always stop on error?
        running = started = NO;
        [device unlockForConfiguration];
    }
    
    NSError *err = [note.userInfo objectForKey: AVCaptureSessionErrorKey];
    
    if (readerDelegate &&
        [readerDelegate respondsToSelector:@selector(readerView:didStopWithError:)])
    {
        [readerDelegate readerView:self
                  didStopWithError:err];
    }
    else
    {
        NSLog(@"ZBarReaderView: ERROR during capture: %@: %@",
              [err localizedDescription],
              [err localizedFailureReason]);
    }
}


#pragma mark - ZBarCaptureDelegate -

- (void) captureReader:(ZBarCaptureReader*)reader
       didTrackSymbols:(ZBarSymbolSet*)syms
{
    [self didTrackSymbols: syms];
}

- (void)       captureReader:(ZBarCaptureReader*)reader
  didReadNewSymbolsFromImage:(ZBarImage*)zimg
{
    zlog(@"scanned %d symbols: %@", zimg.symbols.count, zimg);
    
    if (!readerDelegate)
    {
        return;
    }
    
    UIImageOrientation orient = [UIDevice currentDevice].orientation;
    
    if (!UIDeviceOrientationIsValidInterfaceOrientation(orient))
    {
        orient = interfaceOrientation;
        
        if (orient == UIInterfaceOrientationLandscapeLeft)
        {
            orient = UIDeviceOrientationLandscapeLeft;
        }
        else if (orient == UIInterfaceOrientationLandscapeRight)
        {
            orient = UIDeviceOrientationLandscapeRight;
        }
    }
    switch (orient)
    {
        case UIDeviceOrientationPortraitUpsideDown:
            orient = UIImageOrientationLeft;
            break;
        case UIDeviceOrientationLandscapeLeft:
            orient = UIImageOrientationUp;
            break;
        case UIDeviceOrientationLandscapeRight:
            orient = UIImageOrientationDown;
            break;
        default:
            orient = UIImageOrientationRight;
            break;
    }
    
    UIImage *uiimg = [zimg UIImageWithOrientation: orient];
    
    [readerDelegate readerView:self
                didReadSymbols:zimg.symbols
                     fromImage:uiimg];
}


@end

