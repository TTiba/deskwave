#import "VirtualDisplayBridge.h"

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

// These declarations describe undocumented CoreGraphics Objective-C classes.
// Classes are looked up by name at runtime so no private symbol is linked.
@interface SSVVirtualDisplayDescriptor : NSObject
@property(nonatomic) uint32_t vendorID;
@property(nonatomic) uint32_t productID;
@property(nonatomic) uint32_t serialNum;
@property(strong, nonatomic) NSString *name;
@property(nonatomic) CGSize sizeInMillimeters;
@property(nonatomic) uint32_t maxPixelsWide;
@property(nonatomic) uint32_t maxPixelsHigh;
@property(nonatomic) CGPoint redPrimary;
@property(nonatomic) CGPoint greenPrimary;
@property(nonatomic) CGPoint bluePrimary;
@property(nonatomic) CGPoint whitePoint;
@property(retain, nonatomic) dispatch_queue_t queue;
@property(copy, nonatomic) dispatch_block_t terminationHandler;
@end

@interface SSVVirtualDisplayMode : NSObject
- (instancetype)initWithWidth:(uint32_t)width
                       height:(uint32_t)height
                  refreshRate:(double)refreshRate;
@end

@interface SSVVirtualDisplaySettings : NSObject
@property(strong, nonatomic) NSArray *modes;
@property(nonatomic) uint32_t hiDPI;
@end

@interface SSVVirtualDisplay : NSObject
@property(readonly, nonatomic) uint32_t displayID;
- (instancetype)initWithDescriptor:(SSVVirtualDisplayDescriptor *)descriptor;
- (BOOL)applySettings:(SSVVirtualDisplaySettings *)settings;
@end

bool SSVVirtualDisplayAPIAvailable(void) {
    return NSClassFromString(@"CGVirtualDisplay") != Nil
        && NSClassFromString(@"CGVirtualDisplayDescriptor") != Nil
        && NSClassFromString(@"CGVirtualDisplayMode") != Nil
        && NSClassFromString(@"CGVirtualDisplaySettings") != Nil;
}

void *SSVCreateVirtualDisplay(uint32_t width,
                              uint32_t height,
                              double refreshRate) {
    if (!SSVVirtualDisplayAPIAvailable()
            || width == 0
            || height == 0
            || width > UINT32_MAX / 2
            || height > UINT32_MAX / 2) {
        return NULL;
    }

    Class descriptorClass = NSClassFromString(@"CGVirtualDisplayDescriptor");
    Class displayClass = NSClassFromString(@"CGVirtualDisplay");
    Class modeClass = NSClassFromString(@"CGVirtualDisplayMode");
    Class settingsClass = NSClassFromString(@"CGVirtualDisplaySettings");

    SSVVirtualDisplayDescriptor *descriptor =
        (SSVVirtualDisplayDescriptor *)[[descriptorClass alloc] init];
    descriptor.queue = dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0);
    descriptor.name = @"Tablet Android";
    descriptor.vendorID = 0x5353;
    descriptor.productID = 0x0002;
    descriptor.serialNum = 0x0002;
    // Render at 2× internally so text and UI edges stay sharp before the
    // capture is scaled to the tablet's 1792 × 1120 transport resolution.
    descriptor.maxPixelsWide = width * 2;
    descriptor.maxPixelsHigh = height * 2;
    descriptor.sizeInMillimeters = CGSizeMake(256.0, 160.0);

    // sRGB/Rec. 709 chromaticity coordinates.
    descriptor.whitePoint = CGPointMake(0.3127, 0.3290);
    descriptor.redPrimary = CGPointMake(0.6400, 0.3300);
    descriptor.greenPrimary = CGPointMake(0.3000, 0.6000);
    descriptor.bluePrimary = CGPointMake(0.1500, 0.0600);
    descriptor.terminationHandler = ^{
        NSLog(@"Second Screen: o macOS encerrou a tela virtual.");
    };

    SSVVirtualDisplay *display =
        (SSVVirtualDisplay *)[[displayClass alloc] initWithDescriptor:descriptor];
    if (display == nil) {
        return NULL;
    }

    SSVVirtualDisplayMode *mode =
        (SSVVirtualDisplayMode *)[[modeClass alloc] initWithWidth:width
                                                          height:height
                                                     refreshRate:refreshRate];
    SSVVirtualDisplaySettings *settings =
        (SSVVirtualDisplaySettings *)[[settingsClass alloc] init];
    settings.hiDPI = 1;
    settings.modes = @[mode];

    if (![display applySettings:settings]) {
        return NULL;
    }

    return (__bridge_retained void *)display;
}

uint32_t SSVVirtualDisplayID(void *display) {
    if (display == NULL) {
        return 0;
    }
    SSVVirtualDisplay *virtualDisplay =
        (__bridge SSVVirtualDisplay *)display;
    return virtualDisplay.displayID;
}

void SSVReleaseVirtualDisplay(void *display) {
    if (display == NULL) {
        return;
    }
    id object = CFBridgingRelease(display);
    object = nil;
}
