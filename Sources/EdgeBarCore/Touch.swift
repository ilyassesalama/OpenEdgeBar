import Foundation

/// One finger on the trackpad, in normalized trackpad coordinates.
public struct Touch: Sendable, Equatable {
    /// Stable for the life of the contact; reused after the finger lifts.
    public var id: Int
    /// 0 is the left edge, 1 is the right edge.
    public var x: Double
    /// 0 is the bottom edge (near you), 1 is the top edge (near the keyboard).
    public var y: Double

    public init(id: Int, x: Double, y: Double) {
        self.id = id
        self.x = x
        self.y = y
    }
}

/// Every finger touching one trackpad at one moment. A finger that lifted is simply absent.
public struct TouchFrame: Sendable, Equatable {
    /// Seconds, monotonic. Only differences matter.
    public var timestamp: TimeInterval
    public var touches: [Touch]

    public init(timestamp: TimeInterval, touches: [Touch]) {
        self.timestamp = timestamp
        self.touches = touches
    }
}

/// The modifier keys that change how edge gestures behave.
public struct Modifiers: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let function = Modifiers(rawValue: 1 << 0)
    public static let option = Modifiers(rawValue: 1 << 1)
    public static let shift = Modifiers(rawValue: 1 << 2)
}
