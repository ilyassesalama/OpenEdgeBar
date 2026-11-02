/// Current brightness and volume, as shown in the menu.
public struct Levels: Sendable, Equatable {
    /// 0...1, or nil when there is no built-in display (lid closed, desktop Mac).
    public var brightness: Double?
    /// 0...1, or nil when the output device has no volume control.
    public var volume: Double?
    public var isMuted: Bool

    public init(brightness: Double?, volume: Double?, isMuted: Bool) {
        self.brightness = brightness
        self.volume = volume
        self.isMuted = isMuted
    }
}

/// Whether edge gestures can work right now.
public enum EdgeStatus: Sendable, Equatable {
    case ready
    /// macOS has not allowed the app to send brightness and volume keys.
    case needsAccessibility
    /// No trackpad was found.
    case noTrackpad
}
