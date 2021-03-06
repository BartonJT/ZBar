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

#import <CoreGraphics/CoreGraphics.h>

@class AVCaptureVideoDataOutput, AVCaptureOutput;
@class ZBarCVImage, ZBarImage, ZBarImageScanner, ZBarSymbolSet;

@protocol ZBarCaptureDelegate;


@interface ZBarCaptureReader : NSObject
{
    AVCaptureVideoDataOutput *captureOutput;
    id<ZBarCaptureDelegate> captureDelegate;
    ZBarImageScanner *_scanner;
    CGRect scanCrop;
    CGSize size;
    CGFloat framesPerSecond;
    BOOL enableCache;

    dispatch_queue_t queue;
    ZBarImage *image;
    ZBarCVImage *result;
    volatile uint32_t state;
    int framecnt;
    unsigned long width, height;
    uint64_t t_frame, t_fps, t_scan;
    CGFloat dt_frame;
}

/**
 *  Supply a pre-configured image scanner.
 */
- (instancetype) initWithImageScanner: (ZBarImageScanner*) imageScanner;

/**
 *  This must be called before the session is started.
 */
- (void) willStartRunning;

/**
 *  This must be called *before* the session is stopped.
 */
- (void) willStopRunning;

/**
 *  Clears the internal result cache.
 */
- (void) flushCache;

/**
 *  Capture the next frame after processing. The captured image will
 *  follow the same delegate path as an image with decoded symbols.
 */
- (void) captureFrame;

/** The capture output.  add this to an instance of AVCaptureSession */
@property (nonatomic, readonly) AVCaptureOutput *captureOutput;

/** Delegate is notified of decode results and symbol tracking. */
@property (nonatomic, assign) id<ZBarCaptureDelegate> captureDelegate;

/** Access to image scanner for configuration. */
@property (nonatomic, readonly) ZBarImageScanner *scanner;

/** Region of image to scan in normalized coordinates.
 NB horizontal crop currently ignored... */
@property (nonatomic, assign) CGRect scanCrop;

/** Size of video frames. */
@property (nonatomic, readonly) CGSize size;

/** (Quickly) gate the reader function without interrupting the video
 stream. Also flushes the cache when enabled. Defaults to *NO* */
@property (nonatomic) BOOL enableReader;

/** Current frame rate (for debug/optimization).
 Only valid while running. */
@property (nonatomic, readonly) CGFloat framesPerSecond;

@property (nonatomic) BOOL enableCache;

@end


@protocol ZBarCaptureDelegate <NSObject>

/**
 *  Called when a new barcode is detected. The image refers to the
 *  video buffer and must not be retained for long.
 *
 *  @param captureReader The instance of ZBarCaptureReader that called 
 *  the method on its delegate.
 *
 *  @param image The image from the video buffer. Must not be retained 
 *  for long.
 */
- (void)       captureReader:(ZBarCaptureReader*)captureReader
  didReadNewSymbolsFromImage:(ZBarImage*)image;

@optional
/**
 *  Called when a potential/uncertain barcode is detected. Will also
 *  be called *after* captureReader:didReadNewSymbolsFromImage:
 *  when good barcodes are detected.
 */
- (void) captureReader:(ZBarCaptureReader*)captureReader
       didTrackSymbols:(ZBarSymbolSet*)symbols;

@end

