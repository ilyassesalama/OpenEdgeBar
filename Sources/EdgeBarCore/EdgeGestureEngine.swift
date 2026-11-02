import Foundation

/// Turns raw trackpad frames into edge actions.
///
/// One engine per trackpad. Feed it every frame in order; it keeps track of each finger from
/// the moment it lands until it lifts, and decides what that finger is doing:
///
/// - A finger that lands on a side edge and moves mostly vertically becomes a slide. Each
///   step distance of travel is one step of brightness or volume.
/// - A short, still tap in the top-right corner, twice in quick succession, toggles mute.
/// - A quick horizontal swipe that starts on the bottom rim skips tracks; a tap there plays
///   or pauses when enabled.
///
/// Anything else is left alone: ordinary pointing, clicking and dragging, and any finger moving
/// alongside another finger (two-finger scroll).
public struct EdgeGestureEngine: Sendable {
    /// Distances are in trackpad heights; horizontal travel is converted with `aspectRatio`, so a
    /// distance means the same physical length in any direction. Edge zones stay fractions of the
    /// width or height. Times are seconds.
    public enum Tuning {
        /// Vertical travel per step at sensitivity 1.
        public static let baseStepDistance = 0.06
        /// Fine control steps are quarter steps, so make them come a little faster.
        public static let fineStepScale = 0.5
        /// Vertical travel before an edge touch counts as a slide.
        public static let slideActivationDistance = 0.025
        /// Activation distance multiplier while another finger is on the trackpad.
        public static let crowdedActivationScale = 2.5
        /// A slide never starts sooner than this after the finger lands, which gives a second
        /// finger time to land and reveal a two-finger scroll.
        public static let slideMinimumAge = 0.06
        /// Before activating, vertical travel must beat horizontal travel by this factor.
        public static let slideDirectionRatio = 2.0
        /// Horizontal travel that rules out a slide before it starts.
        public static let slideMaxHorizontalDrift = 0.08
        /// Another finger counts as resting (a thumb on the trackpad) while it stays within this.
        public static let restingTolerance = 0.02
        /// Slides with Bottom Quarter Only must start below this height.
        public static let bottomQuarterLimit = 0.25

        public static let cornerSize = 0.1
        public static let tapMaxDuration = 0.3
        public static let tapMaxMovement = 0.025
        public static let doubleTapInterval = 0.4

        /// A fingertip's center rarely registers below about 6% even pressed against the rim, so
        /// the strip reaches past that.
        public static let mediaStripHeight = 0.12
        /// Fraction of the width.
        public static let mediaSwipeDistance = 0.14
        /// The swipe must cover its distance this soon after the finger starts moving: a flick,
        /// not pointing.
        public static let mediaSwipeMaxDuration = 0.2
        /// A finger may rest on the strip this long before it flicks.
        public static let mediaSwipeMaxRest = 0.5
        public static let mediaSwipeMaxVerticalDrift = 0.08

        /// Width divided by height of a MacBook trackpad, until the real one is known.
        public static let defaultAspectRatio = 1.6
    }

    public var settings: GestureSettings
    /// The trackpad's width divided by its height.
    public var aspectRatio: Double

    private var tracks: [Int: Track] = [:]
    private var slide: Slide?
    /// When the last corner tap ended, waiting for a second one.
    private var lastCornerTapEnd: TimeInterval?

    public init(settings: GestureSettings = GestureSettings(), aspectRatio: Double = Tuning.defaultAspectRatio) {
        self.settings = settings
        self.aspectRatio = aspectRatio
    }

    /// Process one frame and return what should happen, in order.
    ///
    /// - Parameter buttonHeld: The trackpad is pressed down. Touches during a click or drag never
    ///   become gestures.
    public mutating func process(_ frame: TouchFrame, modifiers: Modifiers, buttonHeld: Bool = false) -> [EdgeAction] {
        var actions: [EdgeAction] = []
        let now = frame.timestamp
        let liveIDs = Set(frame.touches.map(\.id))

        for id in tracks.keys.sorted() where !liveIDs.contains(id) {
            if let track = tracks.removeValue(forKey: id) {
                actions += finish(track, at: now)
            }
        }

        for touch in frame.touches {
            let point = Point(x: touch.x, y: touch.y)
            if var track = tracks[touch.id] {
                track.move(to: point, at: now, aspectRatio: aspectRatio)
                tracks[touch.id] = track
            } else {
                actions += land(touch.id, at: point, time: now)
            }
        }

        for id in tracks.keys.sorted() {
            guard var track = tracks[id] else { continue }
            if let current = slide, current.touchID == id {
                if otherFingerMoved(since: current.othersAtStart, besides: id) {
                    // A finger joined in and moves along: this is a two-finger gesture after all.
                    slide = nil
                    track.canSlide = false
                    tracks[id] = track
                    actions.append(.slideEnded)
                } else {
                    actions += steps(for: track, modifiers: modifiers)
                }
                continue
            }
            if buttonHeld {
                track.canSlide = false
                track.canSwipe = false
                track.pressed = true
            }
            actions += evaluate(&track, at: now, modifiers: modifiers)
            tracks[id] = track
        }
        return actions
    }

    /// Forget every finger, for example after the trackpad restarts.
    public mutating func reset() -> [EdgeAction] {
        tracks.removeAll()
        lastCornerTapEnd = nil
        guard slide != nil else { return [] }
        slide = nil
        return [.slideEnded]
    }

    // MARK: - Deciding what a finger does

    private mutating func land(_ id: Int, at point: Point, time: TimeInterval) -> [EdgeAction] {
        var track = Track(id: id, start: point, startTime: time, zones: zones(at: point))
        for other in tracks.values {
            track.othersAtLanding[other.id] = other.current
            // Fingers landing together make a multi-finger tap or click, not a corner tap.
            if time - other.startTime < Tuning.tapMaxDuration {
                track.hadCompany = true
            }
            tracks[other.id]?.hadCompany = true
        }
        tracks[id] = track
        return track.canSlide && slide == nil ? [.slideArmed] : []
    }

    private mutating func evaluate(_ track: inout Track, at now: TimeInterval, modifiers: Modifiers) -> [EdgeAction] {
        if otherFingerMoved(since: track.othersAtLanding, besides: track.id) {
            track.canSlide = false
            track.canSwipe = false
            track.hadCompany = true
            return []
        }
        guard track.canSlide || track.canSwipe else { return [] }
        let dx = (track.current.x - track.start.x) * aspectRatio
        let dy = track.current.y - track.start.y

        if track.canSlide, abs(dx) > Tuning.slideMaxHorizontalDrift {
            track.canSlide = false
        }
        if track.canSwipe {
            let tooSlow = if let movedAt = track.movedAt {
                now - movedAt > Tuning.mediaSwipeMaxDuration
            } else {
                now - track.startTime > Tuning.mediaSwipeMaxRest
            }
            if tooSlow || abs(dy) > Tuning.mediaSwipeMaxVerticalDrift {
                track.canSwipe = false
            }
        }

        // With a resting finger nearby, wait longer: a second finger moving with this one would
        // have shown itself by then, which rules out a two-finger scroll that started on an edge.
        let activation = Tuning.slideActivationDistance * (tracks.count > 1 ? Tuning.crowdedActivationScale : 1)
        if track.canSlide, slide == nil, let side = track.zones.side,
           now - track.startTime >= Tuning.slideMinimumAge,
           abs(dy) >= activation, abs(dy) >= abs(dx) * Tuning.slideDirectionRatio {
            track.canSlide = false
            // Without the required key, this touch is ordinary pointing for the rest of its life.
            guard !settings.requireModifier || !modifiers.isDisjoint(with: [.function, .option]) else { return [] }
            track.canSwipe = false
            let control = control(for: side)
            slide = Slide(touchID: track.id, control: control, anchorY: track.start.y, othersAtStart: positions(besides: track.id))
            return [.slideBegan(control)] + steps(for: track, modifiers: modifiers)
        }

        if track.canSwipe, abs(track.current.x - track.start.x) >= Tuning.mediaSwipeDistance, abs(dx) >= abs(dy) * 2 {
            track.canSlide = false
            track.canSwipe = false
            return [dx > 0 ? .nextTrack : .previousTrack]
        }
        return []
    }

    /// Whether a finger other than `id` has moved from where it was at some moment, given as the
    /// positions back then. Fingers that landed later are measured from where they landed. A thumb
    /// that settled before that moment and now rests does not count.
    private func otherFingerMoved(since reference: [Int: Point], besides id: Int) -> Bool {
        tracks.values.contains { other in
            guard other.id != id else { return false }
            let origin = reference[other.id] ?? other.start
            return other.current.distance(to: origin, aspectRatio: aspectRatio) > Tuning.restingTolerance
        }
    }

    private func positions(besides id: Int) -> [Int: Point] {
        tracks.values.reduce(into: [:]) { result, other in
            if other.id != id { result[other.id] = other.current }
        }
    }

    private mutating func steps(for track: Track, modifiers: Modifiers) -> [EdgeAction] {
        guard var current = slide else { return [] }
        let fine = settings.fineControl && modifiers.isSuperset(of: [.shift, .option])
        let distance = Tuning.baseStepDistance / settings.sensitivity * (fine ? Tuning.fineStepScale : 1)
        // The nudge keeps travel of exactly n steps from landing on n - 1 through rounding error.
        let travel = (track.current.y - current.anchorY) / distance
        let count = Int(travel + (travel < 0 ? -1e-9 : 1e-9))
        guard count != 0 else { return [] }
        current.anchorY += Double(count) * distance
        slide = current
        let direction: StepDirection = count > 0 ? .up : .down
        return Array(repeating: .step(current.control, direction, fine: fine), count: abs(count))
    }

    private mutating func finish(_ track: Track, at now: TimeInterval) -> [EdgeAction] {
        if slide?.touchID == track.id {
            slide = nil
            return [.slideEnded]
        }
        let isTap = !track.hadCompany && !track.pressed
            && now - track.startTime <= Tuning.tapMaxDuration
            && track.maxDistance <= Tuning.tapMaxMovement
        guard isTap else { return [] }

        if track.zones.corner {
            if let last = lastCornerTapEnd, track.startTime - last <= Tuning.doubleTapInterval {
                lastCornerTapEnd = nil
                return [.toggleMute]
            }
            lastCornerTapEnd = now
            return []
        }
        if track.zones.strip, settings.tapToPlay {
            return [.playPause]
        }
        return []
    }

    // MARK: - Geometry

    private func zones(at point: Point) -> Zones {
        var side: Side?
        if !settings.bottomQuarterOnly || point.y <= Tuning.bottomQuarterLimit {
            if point.x <= settings.edgeWidth {
                side = .left
            } else if point.x >= 1 - settings.edgeWidth {
                side = .right
            }
        }
        let corner = settings.quickMute
            && point.x >= 1 - Tuning.cornerSize && point.y >= 1 - Tuning.cornerSize
        let strip = settings.mediaStrip && point.y <= Tuning.mediaStripHeight
        return Zones(side: side, corner: corner, strip: strip)
    }

    private func control(for side: Side) -> EdgeControl {
        switch (side, settings.swapSides) {
        case (.left, false), (.right, true): .brightness
        case (.right, false), (.left, true): .volume
        }
    }
}

// MARK: - Finger state

private struct Point: Sendable {
    var x: Double
    var y: Double

    /// Physical distance, in trackpad heights.
    func distance(to other: Point, aspectRatio: Double) -> Double {
        hypot((x - other.x) * aspectRatio, y - other.y)
    }
}

private enum Side: Sendable {
    case left
    case right
}

/// Where a finger first landed.
private struct Zones: Sendable {
    var side: Side?
    var corner: Bool
    var strip: Bool
}

private struct Track: Sendable {
    let id: Int
    let start: Point
    let startTime: TimeInterval
    let zones: Zones
    var current: Point
    /// Farthest the finger has been from where it landed, in trackpad heights.
    var maxDistance = 0.0
    /// When the finger first moved farther than a tap allows.
    var movedAt: TimeInterval?
    /// Where the other fingers were when this one landed.
    var othersAtLanding: [Int: Point] = [:]
    /// Another finger landed with this one or moved during its life.
    var hadCompany = false
    /// The trackpad was pressed down during this finger's life.
    var pressed = false
    /// Can still become a slide.
    var canSlide: Bool
    /// Can still become a media swipe.
    var canSwipe: Bool

    init(id: Int, start: Point, startTime: TimeInterval, zones: Zones) {
        self.id = id
        self.start = start
        self.startTime = startTime
        self.zones = zones
        self.current = start
        self.canSlide = zones.side != nil
        self.canSwipe = zones.strip
    }

    mutating func move(to point: Point, at time: TimeInterval, aspectRatio: Double) {
        current = point
        maxDistance = max(maxDistance, point.distance(to: start, aspectRatio: aspectRatio))
        if movedAt == nil, maxDistance > EdgeGestureEngine.Tuning.tapMaxMovement {
            movedAt = time
        }
    }
}

private struct Slide: Sendable {
    let touchID: Int
    let control: EdgeControl
    /// Height at which the last step fired.
    var anchorY: Double
    /// Where the other fingers were when the slide began.
    let othersAtStart: [Int: Point]
}
