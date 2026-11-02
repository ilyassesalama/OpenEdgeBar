import AppKit
import EdgeBarCore

/// The hardware media keys, as defined in IOKit's ev_keymap.h.
public enum MediaKey: Int32, Sendable, CaseIterable {
    case soundUp = 0
    case soundDown = 1
    case brightnessUp = 2
    case brightnessDown = 3
    case mute = 7
    case play = 16
    case next = 17
    case previous = 18

    /// The key that performs a step.
    public static func forStep(_ control: EdgeControl, _ direction: StepDirection) -> MediaKey {
        switch (control, direction) {
        case (.volume, .up): .soundUp
        case (.volume, .down): .soundDown
        case (.brightness, .up): .brightnessUp
        case (.brightness, .down): .brightnessDown
        }
    }

    /// The key for an action, if it presses one.
    public static func forAction(_ action: EdgeAction) -> (key: MediaKey, fine: Bool)? {
        switch action {
        case let .step(control, direction, fine): (forStep(control, direction), fine)
        case .toggleMute: (.mute, false)
        case .playPause: (.play, false)
        case .nextTrack: (.next, false)
        case .previousTrack: (.previous, false)
        case .slideArmed, .slideBegan, .slideEnded: nil
        }
    }
}

/// Presses media keys the same way the keyboard does, so macOS shows its own volume and brightness
/// display and plays its own feedback.
///
/// Needs the Accessibility permission (Post Event access). Without it, posting silently does nothing.
@MainActor
public enum MediaKeyPoster {
    private static let keyDown = 0xA
    private static let keyUp = 0xB
    /// NX_SUBTYPE_AUX_CONTROL_BUTTONS
    private static let auxControlButtons: Int16 = 8

    public static func press(_ key: MediaKey, fine: Bool = false) {
        for state in [keyDown, keyUp] {
            guard let event = makeEvent(key, state: state, fine: fine) else { return }
            event.post(tap: .cghidEventTap)
        }
    }

    /// `data1` packs the key in the high 16 bits and the key state in bits 8–15.
    static func data1(_ key: MediaKey, state: Int) -> Int {
        (Int(key.rawValue) << 16) | (state << 8)
    }

    /// The event's own flags decide what macOS does: Shift-Option means a quarter step, and Option
    /// alone would open Sound or Displays settings. They are set explicitly so modifiers the user is
    /// holding (for Require Fn or Option) never leak in.
    static func flags(state: Int, fine: Bool) -> CGEventFlags {
        var flags = CGEventFlags(rawValue: UInt64(state << 8))
        if fine {
            flags.formUnion([.maskShift, .maskAlternate])
        }
        return flags
    }

    /// The timestamp must be real: with 0, macOS sometimes misses the key-up and auto-repeats the
    /// key until the volume reaches zero.
    static func makeEvent(_ key: MediaKey, state: Int, fine: Bool) -> CGEvent? {
        let event = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(state << 8)),
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            subtype: auxControlButtons,
            data1: data1(key, state: state),
            data2: -1
        )?.cgEvent
        event?.flags = flags(state: state, fine: fine)
        return event
    }
}

/// The permission to press keys for the user. It appears under Accessibility in System Settings.
@MainActor
public enum KeyPermission {
    nonisolated public static var isGranted: Bool {
        CGPreflightPostEventAccess()
    }

    /// Shows the system prompt the first time; after that, macOS only lists the app in Settings.
    public static func request() {
        _ = CGRequestPostEventAccess()
    }

    public static func openSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
