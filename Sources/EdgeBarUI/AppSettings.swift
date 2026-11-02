import EdgeBarCore
import EdgeBarSystem
import Foundation
import Observation

public enum Appearance: String, CaseIterable, Sendable {
    case system
    case light
    case dark
}

/// Every user option, saved to UserDefaults as it changes.
@MainActor
@Observable
public final class AppSettings {
    public var gesture: GestureSettings {
        didSet { saveGesture() }
    }
    public var haptics: HapticStrength {
        didSet { defaults.set(haptics.rawValue, forKey: Key.haptics) }
    }
    public var freezeCursor: Bool {
        didSet { defaults.set(freezeCursor, forKey: Key.freezeCursor) }
    }
    public var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }
    /// The welcome tour has been finished or skipped once.
    public var hasCompletedSetup: Bool {
        didSet { defaults.set(hasCompletedSetup, forKey: Key.hasCompletedSetup) }
    }

    @ObservationIgnored private let defaults = UserDefaults.standard

    public init() {
        let fallback = GestureSettings()
        var gesture = fallback
        gesture.swapSides = defaults.object(forKey: Key.swapSides) as? Bool ?? fallback.swapSides
        gesture.bottomQuarterOnly = defaults.object(forKey: Key.bottomQuarterOnly) as? Bool ?? fallback.bottomQuarterOnly
        gesture.requireModifier = defaults.object(forKey: Key.requireModifier) as? Bool ?? fallback.requireModifier
        gesture.fineControl = defaults.object(forKey: Key.fineControl) as? Bool ?? fallback.fineControl
        gesture.quickMute = defaults.object(forKey: Key.quickMute) as? Bool ?? fallback.quickMute
        gesture.mediaStrip = defaults.object(forKey: Key.mediaStrip) as? Bool ?? fallback.mediaStrip
        gesture.tapToPlay = defaults.object(forKey: Key.tapToPlay) as? Bool ?? fallback.tapToPlay
        gesture.sensitivity = Self.clamp(
            defaults.object(forKey: Key.sensitivity) as? Double ?? fallback.sensitivity,
            to: GestureSettings.sensitivityRange
        )
        gesture.edgeWidth = Self.clamp(
            defaults.object(forKey: Key.edgeWidth) as? Double ?? fallback.edgeWidth,
            to: GestureSettings.edgeWidthRange
        )
        self.gesture = gesture
        haptics = defaults.string(forKey: Key.haptics).flatMap(HapticStrength.init(rawValue:)) ?? .medium
        freezeCursor = defaults.object(forKey: Key.freezeCursor) as? Bool ?? true
        appearance = defaults.string(forKey: Key.appearance).flatMap(Appearance.init(rawValue:)) ?? .system
        hasCompletedSetup = defaults.bool(forKey: Key.hasCompletedSetup)
    }

    private func saveGesture() {
        defaults.set(gesture.swapSides, forKey: Key.swapSides)
        defaults.set(gesture.bottomQuarterOnly, forKey: Key.bottomQuarterOnly)
        defaults.set(gesture.requireModifier, forKey: Key.requireModifier)
        defaults.set(gesture.fineControl, forKey: Key.fineControl)
        defaults.set(gesture.quickMute, forKey: Key.quickMute)
        defaults.set(gesture.mediaStrip, forKey: Key.mediaStrip)
        defaults.set(gesture.tapToPlay, forKey: Key.tapToPlay)
        defaults.set(gesture.sensitivity, forKey: Key.sensitivity)
        defaults.set(gesture.edgeWidth, forKey: Key.edgeWidth)
    }

    private static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private enum Key {
        static let swapSides = "swapSides"
        static let bottomQuarterOnly = "bottomQuarterOnly"
        static let requireModifier = "requireModifier"
        static let fineControl = "fineControl"
        static let quickMute = "quickMute"
        static let mediaStrip = "mediaStrip"
        static let tapToPlay = "tapToPlay"
        static let sensitivity = "sensitivity"
        static let edgeWidth = "edgeWidth"
        static let haptics = "hapticStrength"
        static let freezeCursor = "freezeCursor"
        static let appearance = "appearance"
        static let hasCompletedSetup = "hasCompletedSetup"
    }
}
