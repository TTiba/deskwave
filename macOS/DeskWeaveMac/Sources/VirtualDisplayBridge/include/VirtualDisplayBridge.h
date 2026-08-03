#ifndef VirtualDisplayBridge_h
#define VirtualDisplayBridge_h

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Creates and retains a private CoreGraphics virtual display.
/// Returns NULL when the API is unavailable or the settings cannot be applied.
void *SSVCreateVirtualDisplay(
    uint32_t width,
    uint32_t height,
    double refreshRate
);

/// Returns the CoreGraphics display identifier for a retained virtual display.
uint32_t SSVVirtualDisplayID(void *display);

/// Releases a display previously returned by SSVCreateVirtualDisplay.
void SSVReleaseVirtualDisplay(void *display);

/// Returns true when the required private Objective-C classes exist.
bool SSVVirtualDisplayAPIAvailable(void);

#ifdef __cplusplus
}
#endif

#endif
