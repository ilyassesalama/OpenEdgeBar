/// The options that change how touches turn into actions.
public struct GestureSettings: Sendable, Equatable {
    /// Brightness on the right and volume on the left.
    public var swapSides = false
    /// Slides must start in the lower quarter of the trackpad.
    public var bottomQuarterOnly = false
    /// Slides only work while Fn or Option is held.
    public var requireModifier = false
    /// Holding Shift-Option gives quarter steps.
    public var fineControl = true
    /// Double-tap the top-right corner to mute.
    public var quickMute = true
    /// Swipe along the bottom edge to skip tracks.
    public var mediaStrip = true
    /// Tap the bottom edge to play or pause. Off by default: clicks near the edge would trigger it.
    public var tapToPlay = false
    /// How far a finger travels per step, as a multiplier. Higher means less travel.
    public var sensitivity = 1.0
    /// Width of each side edge, as a fraction of the trackpad width. Wide by default so the edges
    /// are easy to find while learning; narrow it once they become habit.
    public var edgeWidth = 0.15

    public static let sensitivityRange = 0.5...3.0
    public static let sensitivityStep = 0.25
    public static let edgeWidthRange = 0.03...0.2
    public static let edgeWidthStep = 0.01

    public init() {}
}
