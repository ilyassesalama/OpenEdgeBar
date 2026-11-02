// Declarations for Apple's private MultitouchSupport framework.
//
// Nothing here is linked: the framework is opened with dlopen and each function is looked up with
// dlsym, using the function pointer types below. Layouts were checked on macOS 27 (arm64) and
// match the x86_64 slice.
#pragma once

#include <CoreFoundation/CoreFoundation.h>
#include <stdbool.h>
#include <stdint.h>

typedef struct {
    float x;
    float y;
} MTPoint;

typedef struct {
    MTPoint position;
    MTPoint velocity;
} MTVector;

typedef CF_ENUM(int32_t, MTTouchState) {
    MTTouchStateNotTracking = 0,
    MTTouchStateStartInRange = 1,
    MTTouchStateHoverInRange = 2,
    MTTouchStateMakeTouch = 3,
    MTTouchStateTouching = 4,
    MTTouchStateBreakTouch = 5,
    MTTouchStateLingerInRange = 6,
    MTTouchStateOutOfRange = 7,
};

/// One contact in a frame. 96 bytes.
typedef struct {
    int32_t frame;
    double timestamp;
    /// Stable for the life of the contact; small numbers that get reused.
    int32_t pathIndex;
    MTTouchState state;
    int32_t fingerID;
    int32_t handID;
    /// Position 0...1, with x = 0 at the left and y = 0 at the bottom (nearest the user).
    MTVector normalized;
    float zTotal;
    float zPressure;
    float angle;
    float majorAxis;
    float minorAxis;
    /// Millimeters.
    MTVector absolute;
    int32_t field14;
    int32_t field15;
    float zDensity;
} MTTouch;

_Static_assert(sizeof(MTTouch) == 96, "MTTouch must be 96 bytes");

typedef CFTypeRef MTDeviceRef;
typedef CFTypeRef MTActuatorRef;

/// Called on a private background thread, one per device. `touches` is only valid during the call.
typedef void (*MTContactFrameCallback)(MTDeviceRef device, const MTTouch *touches, int32_t count, double timestamp, int32_t frame);

typedef CFMutableArrayRef (*MTDeviceCreateListFunction)(void);
typedef bool (*MTRegisterContactFrameCallbackFunction)(MTDeviceRef device, MTContactFrameCallback callback);
typedef bool (*MTUnregisterContactFrameCallbackFunction)(MTDeviceRef device, MTContactFrameCallback callback);
typedef int32_t (*MTDeviceStartFunction)(MTDeviceRef device, int32_t runMode);
typedef int32_t (*MTDeviceStopFunction)(MTDeviceRef device);
typedef int32_t (*MTDeviceGetFamilyIDFunction)(MTDeviceRef device, int32_t *familyID);
typedef int32_t (*MTDeviceGetDeviceIDFunction)(MTDeviceRef device, uint64_t *deviceID);
/// Hundredths of a millimeter.
typedef int32_t (*MTDeviceGetSensorSurfaceDimensionsFunction)(MTDeviceRef device, int32_t *width, int32_t *height);

/// Create rule: the caller releases the result. NULL when the device has no actuator.
typedef MTActuatorRef (*MTActuatorCreateFromDeviceIDFunction)(uint64_t deviceID);
/// Pass 0 for `options`.
typedef int32_t (*MTActuatorOpenFunction)(MTActuatorRef actuator, uint32_t options);
typedef int32_t (*MTActuatorCloseFunction)(MTActuatorRef actuator);
/// `actuationID` picks a waveform (3, 4 and 6 are light, medium and strong on every actuator revision).
/// Pass 0 for `flags`. `intensity` 1 plays the full designed waveform. `timeScale` 0 keeps the default length.
typedef int32_t (*MTActuatorActuateFunction)(MTActuatorRef actuator, int32_t actuationID, uint32_t flags, float intensity, float timeScale);

/// MTDeviceStart run mode that skips the "Recognized family" line on stdout.
static const int32_t MTRunModeQuiet = 0x10000000;
