import AppKit
import EdgeBarCore

/// Runs edge gestures: trackpad frames go through a gesture engine per trackpad, and the resulting
/// actions become key presses, haptic ticks and a frozen pointer.
@MainActor
public final class EdgeController {
    public var gestureSettings = GestureSettings() {
        didSet {
            for id in engines.keys {
                engines[id]?.settings = gestureSettings
            }
        }
    }
    public var hapticStrength: HapticStrength = .medium
    public var freezeCursor = true {
        didSet {
            if !freezeCursor { releaseCursor() }
        }
    }

    public private(set) var status: EdgeStatus = .noTrackpad {
        didSet {
            guard status != oldValue else { return }
            if status != .ready { endSlides() }
            onStatusChange?(status)
        }
    }
    public var onStatusChange: ((EdgeStatus) -> Void)?
    /// Called after every action, for example to refresh the menu or tick off a tour challenge.
    public var onAction: ((EdgeAction) -> Void)?
    /// Every frame from every trackpad, even before the permission is granted: reading touches
    /// needs none. The welcome tour uses it to show the fingers live.
    public var onTouches: ((TouchFrame) -> Void)?

    /// How long the pointer stays frozen after the last frame of a slide, if the lift never arrives.
    private static let watchdogDelay: Duration = .milliseconds(500)

    private let haptics = Haptics()
    private let cursor = CursorFreezer()
    private let monitor = TrackpadMonitor()
    private var trackpads: [ObjectIdentifier: Trackpad] = [:]
    private var engines: [ObjectIdentifier: EdgeGestureEngine] = [:]
    private var isCursorFrozen = false
    private var permissionTimer: Timer?
    private var watchdog: Task<Void, Never>?

    public init() {}

    public func start() {
        monitor.onFrame = { [weak self] frame in self?.handle(frame) }
        monitor.onTrackpadsChanged = { [weak self] trackpads in self?.trackpadsChanged(trackpads) }
        monitor.start()
        refreshStatus()
    }

    public func stop() {
        endSlides()
        monitor.stop()
        haptics.reset()
        permissionTimer?.invalidate()
        permissionTimer = nil
    }

    /// Re-checks the permission and trackpads. While the permission is missing, keeps checking
    /// every second so the app starts working the moment it is granted.
    public func refreshStatus() {
        let granted = KeyPermission.isGranted
        if !granted {
            status = .needsAccessibility
        } else if trackpads.isEmpty {
            status = .noTrackpad
        } else {
            status = .ready
        }

        if granted {
            permissionTimer?.invalidate()
            permissionTimer = nil
        } else if permissionTimer == nil {
            let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshStatus() }
            }
            RunLoop.main.add(timer, forMode: .common)
            permissionTimer = timer
        }
    }

    // MARK: - Frames

    /// Plays one haptic tick on the first trackpad, to preview a strength.
    public func previewHaptic(_ strength: HapticStrength) {
        guard let trackpad = trackpads.values.first else { return }
        haptics.tick(strength, on: trackpad.multitouchID)
    }

    public func press(_ key: MediaKey) {
        MediaKeyPoster.press(key, fine: false)
    }

    private func handle(_ frame: TrackpadFrame) {
        onTouches?(frame.frame)
        // Without the permission, key presses would do nothing; don't freeze the pointer for nothing.
        guard status == .ready, let trackpad = trackpads[frame.trackpad] else { return }
        var engine = engines[frame.trackpad]
            ?? EdgeGestureEngine(settings: gestureSettings, aspectRatio: trackpad.aspectRatio)
        let actions = engine.process(frame.frame, modifiers: .current, buttonHeld: NSEvent.pressedMouseButtons != 0)
        engines[frame.trackpad] = engine
        for action in actions {
            perform(action, on: trackpad)
        }
        if isCursorFrozen {
            armWatchdog()
        }
    }

    private func perform(_ action: EdgeAction, on trackpad: Trackpad) {
        switch action {
        case .slideArmed:
            // Catches a permission revoked while running, once per touch rather than per frame.
            refreshStatus()
            if freezeCursor { cursor.rememberPosition() }
        case .slideBegan:
            if freezeCursor {
                cursor.freeze()
                isCursorFrozen = true
            }
        case .slideEnded:
            releaseCursor()
        case .step, .toggleMute, .playPause, .nextTrack, .previousTrack:
            // Every gesture that does something confirms it under the finger.
            haptics.tick(hapticStrength, on: trackpad.multitouchID)
        }
        if let press = MediaKey.forAction(action) {
            MediaKeyPoster.press(press.key, fine: press.fine)
        }
        onAction?(action)
    }

    private func trackpadsChanged(_ trackpads: [Trackpad]) {
        endSlides()
        engines.removeAll()
        haptics.reset()
        self.trackpads = Dictionary(uniqueKeysWithValues: trackpads.map { ($0.id, $0) })
        refreshStatus()
    }

    /// Lifting a finger always sends a final empty frame, but if that frame never arrives (the
    /// trackpad vanished mid-slide), never leave the pointer stuck.
    private func armWatchdog() {
        watchdog?.cancel()
        watchdog = Task { [weak self] in
            try? await Task.sleep(for: Self.watchdogDelay)
            guard !Task.isCancelled else { return }
            self?.endSlides()
        }
    }

    private func endSlides() {
        watchdog?.cancel()
        watchdog = nil
        for id in engines.keys {
            _ = engines[id]?.reset()
        }
        releaseCursor()
    }

    private func releaseCursor() {
        cursor.release()
        isCursorFrozen = false
    }
}

extension Modifiers {
    /// The modifier keys held right now. Reading this needs no permission.
    @MainActor
    static var current: Modifiers {
        let flags = NSEvent.modifierFlags
        var modifiers: Modifiers = []
        if flags.contains(.function) { modifiers.insert(.function) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        return modifiers
    }
}
