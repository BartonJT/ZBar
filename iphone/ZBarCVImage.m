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

#import "ZBarCVImage.h"
#define MODULE ZBarCVImage
#import "debug.h"

static NSOperationQueue *_conversionQueue;

static const void*
asyncProvider_getBytePointer (void *info)
{
    // block until data is available
    ZBarCVImage *image = info;
    assert(image);
    [image waitUntilConverted];
    void *buf = image.rgbBuffer;
    assert(buf);
    return(buf);
}

static const CGDataProviderDirectCallbacks asyncProvider = {
    .version = 0,
    .getBytePointer = asyncProvider_getBytePointer,
    .releaseBytePointer = NULL,
    .getBytesAtPosition = NULL,
    .releaseInfo = (void*)CFRelease,
};

@implementation ZBarCVImage

@synthesize
    pixelBuffer = _pixelBuffer,
    rgbBuffer   = _rgbBuffer;


#pragma mark - Deallocation Method -

- (void) dealloc
{
    _pixelBuffer = NULL;
    
    if (_rgbBuffer)
    {
        free(_rgbBuffer);
        _rgbBuffer = NULL;
    }
    
    [conversion release];
    conversion = nil;
    
    [super dealloc];
}


#pragma mark - Object Methods -

- (void) setPixelBuffer:(CVPixelBufferRef)newbuf
{
    CVPixelBufferRef oldbuf = _pixelBuffer;
    
    if (newbuf)
    {
        CVPixelBufferRetain(newbuf);
    }
    
    _pixelBuffer = newbuf;
    
    if (oldbuf)
    {
        CVPixelBufferRelease(oldbuf);
    }
}

- (void) waitUntilConverted
{
    // operation will at least have been queued already
    NSOperation *op = [conversion retain];
    
    if (!op)
    {
        return;
    }
    
    [op waitUntilFinished];
    [op release];
}

- (UIImage*) UIImageWithOrientation:(UIImageOrientation)orient
{
    if (!conversion && !self.rgbBuffer)
    {
        // Start format conversion in separate thread
        
        if (!_conversionQueue)
        {
            _conversionQueue = [[NSOperationQueue alloc] init];
            _conversionQueue.maxConcurrentOperationCount = 1;
        }
        else
        {
            [_conversionQueue waitUntilAllOperationsAreFinished];
        }

        conversion = [[NSInvocationOperation alloc] initWithTarget:self
                                                          selector:@selector(convertCVtoRGB)
                                                            object:nil];
        [_conversionQueue addOperation:conversion];
        [conversion release];
    }

    // create UIImage before converted data is available
    CGSize size = self.size;
    int w = size.width;
    int h = size.height;

    CGDataProviderRef datasrc =
        CGDataProviderCreateDirect([self retain], 3 * w * h, &asyncProvider);
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGImageRef cgimg =
        CGImageCreate(w, h, 8, 24, 3 * w, cs,
                      kCGBitmapByteOrderDefault, datasrc,
                      NULL, YES, kCGRenderingIntentDefault);
    CGColorSpaceRelease(cs);
    CGDataProviderRelease(datasrc);

    UIImage *uiimg = [UIImage imageWithCGImage:cgimg
                                         scale:1
                                   orientation:orient];
    CGImageRelease(cgimg);

    return uiimg;
}

// convert video frame to a CGImage compatible RGB format
// FIXME this is temporary until we can find the native way...
- (void) convertCVtoRGB
{
    timer_start;
    unsigned long format = self.format;
    assert(format == zbar_fourcc('C','V','2','P'));
    
    if (format != zbar_fourcc('C','V','2','P'))
    {
        return;
    }

    CVPixelBufferLockBaseAddress(self.pixelBuffer, kCVPixelBufferLock_ReadOnly);
    long w = CVPixelBufferGetWidth(self.pixelBuffer);
    long h = CVPixelBufferGetHeight(self.pixelBuffer);
    long dy = CVPixelBufferGetBytesPerRowOfPlane(self.pixelBuffer, 0);
    long duv = CVPixelBufferGetBytesPerRowOfPlane(self.pixelBuffer, 1);
    uint8_t *py = CVPixelBufferGetBaseAddressOfPlane(self.pixelBuffer, 0);
    uint8_t *puv = CVPixelBufferGetBaseAddressOfPlane(self.pixelBuffer, 1);
    
    if (!py || !puv || dy < w || duv < w)
    {
        goto error;
    }

    long datalen = 3 * w * h;
    // Quartz accesses some undocumented amount past allocated data?
    // ...allocate extra to compensate
    uint8_t *pdst = _rgbBuffer = malloc(datalen + 3 * w);
    
    if (!pdst)
    {
        goto error;
    }
    
    [self setData:self.rgbBuffer
       withLength:datalen];

    for (int y = 0; y < h; y++)
    {
        const uint8_t *qy = py;
        const uint8_t *quv = puv;
        
        for (int x = 0; x < w; x++)
        {
            int Y1 = *(qy++) - 16;
            int Cb = *(quv) - 128;
            int Cr = *(quv + 1) - 128;
            Y1 *= 4769;
            quv += (x & 1) << 1;
            int r = (Y1 + 6537 * Cr + 2048) / 4096;
            int g = (Y1 - 1604 * Cb - 3329 * Cr + 2048) / 4096;
            int b = (Y1 + 8263 * Cb + 2048) / 4096;

            r = (r | -!!(r >> 8)) & -((r >> 8) >= 0);
            g = (g | -!!(g >> 8)) & -((g >> 8) >= 0);
            b = (b | -!!(b >> 8)) & -((b >> 8) >= 0);

            *(pdst++) = r;
            *(pdst++) = g;
            *(pdst++) = b;
        }
        
        py += dy;
        
        if (y & 1)
        {
            puv += duv;
        }
    }

error:
    CVPixelBufferUnlockBaseAddress(self.pixelBuffer, kCVPixelBufferLock_ReadOnly);
    zlog(@"convert time %gs", timer_elapsed(t_start, timer_now()));

    // release buffer as soon as conversion is complete
    self.pixelBuffer = NULL;

    conversion = nil;
}

@end
