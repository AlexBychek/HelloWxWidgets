/////////////////////////////////////////////////////////////////////////////
// Name:        src/osx/carbon/screencapture.mm
// Purpose:     wxOSXCreateCGImageFromDisplay for macos 15
// Author:      Oleksandr Bychek
// Modified by:
// Created:     2024-11-08
// Copyright:   (c) Oleksandr Bycheks
// Licence:     wxWindows licence
/////////////////////////////////////////////////////////////////////////////

#include "wx/osx/core/private.h"

#import <ScreenCaptureKit/ScreenCaptureKit.h>

@interface ScreenCaptureManager : NSObject
    @property CGImageRef capturedImage;
    @property dispatch_semaphore_t semaphore;

//    - (CGImageRef) requestScreenCapturePermissions;
//    - (void) startCaptureWithDisplay:(SCDisplay*)display;
@end

@implementation ScreenCaptureManager

- (instancetype)init
{
    self = [super init];
    if (self) {
        _semaphore = dispatch_semaphore_create(0);
        _capturedImage = nil;
    }
    return self;
}

- (CGImageRef)createImageByDisplay:(NSInteger)displayIndex
{
    self.semaphore = dispatch_semaphore_create(0);

    if (@available(macOS 15.0, *))
    {
        [SCShareableContent getShareableContentWithCompletionHandler:^(SCShareableContent * _Nullable shareableContent, NSError * _Nullable error)
        {
            if (error)
            {
                NSLog(@"Error getting shareable content: %@", error.localizedDescription);
                return;
            }

            SCDisplay *display = shareableContent.displays[displayIndex];
            if (!display)
            {
                NSLog(@"No display available for capture");
                return;
            }

            [self startCaptureWithDisplay:display];
        }];
    }
    else
    {
        NSLog(@"ScreenCaptureKit is available only on macOS 15 or later.");
    }

    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    dispatch_release(self.semaphore);

    return CGImageCreateCopy(self.capturedImage);
}

- (void) startCaptureWithDisplay:(SCDisplay*)display
{
    if (@available(macOS 15.0, *))
    {
        SCContentFilter *filter = [[SCContentFilter alloc] initWithDisplay:display excludingWindows:@[]];
        SCStreamConfiguration *configuration = [[SCStreamConfiguration alloc] init];
        configuration.capturesAudio = NO;
        configuration.excludesCurrentProcessAudio = YES;
        configuration.preservesAspectRatio = YES;
        configuration.showsCursor = NO;
        configuration.captureResolution = SCCaptureResolutionBest;
        configuration.width = NSWidth(filter.contentRect) * filter.pointPixelScale;
        configuration.height = NSHeight(filter.contentRect) * filter.pointPixelScale;
        //configuration.pixelFormat = 'BGRA';

        [SCScreenshotManager captureImageWithFilter:filter configuration:configuration completionHandler:^(CGImageRef  _Nullable cgImage, NSError * _Nullable error)
        {
            if (!error)
            {
                self.capturedImage = CGImageCreateCopy(cgImage);
            }
            else
            {
                NSLog(@"%@", error);
            }
            dispatch_semaphore_signal(self.semaphore);
        }];
    }
    else
    {
        NSLog(@"ScreenCaptureKit is available only on macOS 15 or later.");
    }
}
@end

CGImageRef wxOSXCreateCGImageFromDisplay(int displayIndex)
{
    @autoreleasepool
    {
        ScreenCaptureManager *manager = [[ScreenCaptureManager alloc] init];
        return [manager createImageByDisplay:displayIndex];
    }
}