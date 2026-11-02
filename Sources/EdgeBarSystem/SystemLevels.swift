import AudioToolbox
import CoreAudio
import CoreGraphics
import Foundation

/// Reads and sets the real brightness of the built-in display and the volume of the current output.
@MainActor
public final class SystemLevels {
    public init() {}

    public func read() -> Levels {
        Levels(brightness: Brightness.get(), volume: Volume.get(), isMuted: Volume.isMuted())
    }

    public func setBrightness(_ value: Double) {
        Brightness.set(value)
    }

    public func setVolume(_ value: Double) {
        Volume.set(value)
        // Like the volume keys: changing the volume unmutes.
        if Volume.isMuted() {
            Volume.setMuted(false)
        }
    }
}

// MARK: - Volume

/// The default output device's main volume, through CoreAudio.
enum Volume {
    private static let volumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    private static let muteAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioObjectPropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )

    /// nil when the device has no adjustable volume (HDMI, DisplayPort, aggregate devices).
    static func get() -> Double? {
        guard let device = defaultOutputDevice(), isSettable(device, volumeAddress) else { return nil }
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = volumeAddress
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return nil }
        return Double(value)
    }

    static func set(_ value: Double) {
        guard let device = defaultOutputDevice(), isSettable(device, volumeAddress) else { return }
        var newValue = Float32(min(max(value, 0), 1))
        var address = volumeAddress
        AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &newValue)
    }

    static func isMuted() -> Bool {
        guard let device = defaultOutputDevice() else { return false }
        var address = muteAddress
        guard AudioObjectHasProperty(device, &address) else { return false }
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &muted) == noErr else { return false }
        return muted != 0
    }

    static func setMuted(_ muted: Bool) {
        guard let device = defaultOutputDevice(), isSettable(device, muteAddress) else { return }
        var value: UInt32 = muted ? 1 : 0
        var address = muteAddress
        AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
    }

    private static func defaultOutputDevice() -> AudioObjectID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        guard status == noErr, device != kAudioObjectUnknown else { return nil }
        return device
    }

    private static func isSettable(_ device: AudioObjectID, _ address: AudioObjectPropertyAddress) -> Bool {
        var address = address
        guard AudioObjectHasProperty(device, &address) else { return false }
        var settable: DarwinBoolean = false
        return AudioObjectIsPropertySettable(device, &address, &settable) == noErr && settable.boolValue
    }
}

// MARK: - Brightness

/// The built-in display's brightness, through the private DisplayServices framework.
enum Brightness {
    private struct Functions: @unchecked Sendable {
        typealias Get = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
        typealias Set = @convention(c) (CGDirectDisplayID, Float) -> Int32
        typealias CanChange = @convention(c) (CGDirectDisplayID) -> Bool

        let get: Get
        let set: Set
        let canChange: CanChange

        static let shared: Functions? = {
            guard let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW),
                  let get = dlsym(handle, "DisplayServicesGetBrightness"),
                  let set = dlsym(handle, "DisplayServicesSetBrightness"),
                  let canChange = dlsym(handle, "DisplayServicesCanChangeBrightness")
            else { return nil }
            return Functions(
                get: unsafeBitCast(get, to: Get.self),
                set: unsafeBitCast(set, to: Set.self),
                canChange: unsafeBitCast(canChange, to: CanChange.self)
            )
        }()
    }

    /// nil when there is no built-in display, for example with the lid closed.
    static func get() -> Double? {
        guard let functions = Functions.shared, let display = builtInDisplay(functions) else { return nil }
        var value: Float = 0
        guard functions.get(display, &value) == 0 else { return nil }
        return Double(value)
    }

    static func set(_ value: Double) {
        guard let functions = Functions.shared, let display = builtInDisplay(functions) else { return }
        _ = functions.set(display, Float(min(max(value, 0), 1)))
    }

    /// The built-in display is not always the main one, and disappears in clamshell mode.
    private static func builtInDisplay(_ functions: Functions) -> CGDirectDisplayID? {
        var displays = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(UInt32(displays.count), &displays, &count) == .success else { return nil }
        return displays.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 && functions.canChange($0) }
    }
}
