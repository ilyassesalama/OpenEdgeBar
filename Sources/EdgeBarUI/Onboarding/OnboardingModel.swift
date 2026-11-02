import EdgeBarCore
import EdgeBarSystem
import Foundation
import Observation

/// The first-run tour: welcome, permission, a hands-on practice with live touches, a few
/// choices, and a finale.
@MainActor
@Observable
public final class OnboardingModel {
    public enum Act: Int, CaseIterable, Sendable {
        case welcome
        case permission
        case practice
        case personalize
        case finale
    }

    public enum Challenge: CaseIterable, Sendable {
        case volume
        case brightness
        case mute
        /// A bonus: skipping a track needs something playing.
        case skip
    }

    /// What the tour does to the Mac, supplied by the app.
    public struct Effects {
        public var playHaptic: (HapticStrength) -> Void
        /// Presses the mute key, to undo a mute left over from practice.
        public var pressMute: () -> Void
        public var requestPermission: () -> Void

        public init(
            playHaptic: @escaping (HapticStrength) -> Void,
            pressMute: @escaping () -> Void,
            requestPermission: @escaping () -> Void
        ) {
            self.playHaptic = playHaptic
            self.pressMute = pressMute
            self.requestPermission = requestPermission
        }
    }

    /// Steps of each control that count as having slid an edge.
    static let stepsToComplete = 2

    public let settings: AppSettings
    public private(set) var act: Act = .welcome
    public private(set) var completed: Set<Challenge> = []
    /// The fingers on the trackpad right now.
    public private(set) var fingers: [Touch] = []
    public private(set) var levels: Levels
    /// Access was just granted during the permission act; shown before moving on.
    public private(set) var justGranted = false
    public private(set) var launchAtLogin: Bool
    /// Decided when leaving the welcome act, so the progress dots stay put afterwards.
    private var includesPermission: Bool

    public var status: EdgeStatus {
        didSet { statusChanged(from: oldValue) }
    }

    /// Called when the tour ends, finished or skipped.
    @ObservationIgnored public var onFinish: () -> Void = {}
    /// How long "You're in" shows before the practice starts.
    private static let celebrationDelay: Duration = .seconds(1.4)

    @ObservationIgnored private let effects: Effects
    @ObservationIgnored private let levelControl: SystemLevels
    @ObservationIgnored private let loginItem: LoginItem
    @ObservationIgnored private var steps: [EdgeControl: Int] = [:]
    @ObservationIgnored private var muteToggles = 0
    @ObservationIgnored private var levelTimer: Timer?

    /// How often the live levels are read while the tour is open.
    static let levelRefreshInterval: TimeInterval = 1.0 / 15

    public init(
        settings: AppSettings,
        status: EdgeStatus,
        levelControl: SystemLevels,
        loginItem: LoginItem,
        effects: Effects
    ) {
        self.settings = settings
        self.status = status
        self.levelControl = levelControl
        self.loginItem = loginItem
        self.effects = effects
        levels = levelControl.read()
        launchAtLogin = loginItem.isEnabled
        includesPermission = status == .needsAccessibility
    }

    // MARK: - Moving through the tour

    /// The acts this tour will show. The permission act is left out when access was already granted.
    public var acts: [Act] {
        Act.allCases.filter { $0 != .permission || includesPermission }
    }

    public var challenges: [Challenge] {
        settings.gesture.mediaStrip ? Challenge.allCases : [.volume, .brightness, .mute]
    }

    /// The challenge to show hints for: the first one not yet done.
    public var currentChallenge: Challenge? {
        challenges.first { !completed.contains($0) }
    }

    /// Volume, brightness and mute are done; skipping a track is a bonus.
    public var practiceComplete: Bool {
        completed.isSuperset(of: [.volume, .brightness, .mute])
    }

    public func next() {
        switch act {
        case .welcome:
            includesPermission = status == .needsAccessibility
            show(includesPermission ? .permission : .practice)
        case .permission:
            show(.practice)
        case .practice:
            undoPracticeMute()
            show(.personalize)
        case .personalize:
            show(.finale)
            celebrate()
        case .finale:
            onFinish()
        }
    }

    /// Ends the tour from anywhere.
    public func skip() {
        undoPracticeMute()
        onFinish()
    }

    private func show(_ next: Act) {
        act = next
    }

    // MARK: - Live levels

    /// Keeps the meters and numbers on the real levels while the tour is open, whatever changes
    /// them: an edge slide, the keyboard keys, or another app. A key press takes effect a moment
    /// after it is sent, so reading right after a step would always lag one step behind.
    public func startLiveLevels() {
        refreshLevels()
        levelTimer?.invalidate()
        let timer = Timer(timeInterval: Self.levelRefreshInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshLevels() }
        }
        RunLoop.main.add(timer, forMode: .common)
        levelTimer = timer
    }

    public func stopLiveLevels() {
        levelTimer?.invalidate()
        levelTimer = nil
    }

    private func refreshLevels() {
        let latest = levelControl.read()
        if latest != levels {
            levels = latest
        }
    }

    // MARK: - Permission

    public func requestPermission() {
        effects.requestPermission()
    }

    private func statusChanged(from old: EdgeStatus) {
        guard old == .needsAccessibility, status != .needsAccessibility, act == .permission else { return }
        justGranted = true
        effects.playHaptic(.medium)
        let delay = Self.celebrationDelay
        Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, self.act == .permission else { return }
            self.show(.practice)
        }
    }

    // MARK: - Live input

    /// Shows the fingers from one trackpad frame.
    public func show(_ frame: TouchFrame) {
        guard act == .practice || act == .welcome else { return }
        if frame.touches != fingers {
            fingers = frame.touches
        }
    }

    /// Ticks off practice challenges as the real gestures happen.
    public func handle(_ action: EdgeAction) {
        guard act == .practice else { return }
        switch action {
        case let .step(control, _, _):
            steps[control, default: 0] += 1
            if steps[control, default: 0] >= Self.stepsToComplete {
                complete(control == .volume ? .volume : .brightness)
            }
        case .toggleMute:
            muteToggles += 1
            complete(.mute)
        case .nextTrack, .previousTrack:
            complete(.skip)
        case .slideArmed, .slideBegan, .slideEnded, .playPause:
            break
        }
    }

    private func complete(_ challenge: Challenge) {
        guard challenges.contains(challenge), completed.insert(challenge).inserted else { return }
        effects.playHaptic(settings.haptics == .off ? .medium : settings.haptics)
    }

    /// An odd number of mutes leaves the sound off; turn it back on.
    private func undoPracticeMute() {
        if muteToggles % 2 == 1 {
            effects.pressMute()
        }
        muteToggles = 0
    }

    // MARK: - Choices

    /// Picks a haptic strength and plays it, so it can be felt right away.
    public func chooseHaptics(_ strength: HapticStrength) {
        settings.haptics = strength
        effects.playHaptic(strength)
    }

    public func chooseVolumeOnRight(_ onRight: Bool) {
        settings.gesture.swapSides = !onRight
    }

    public func setLaunchAtLogin(_ enabled: Bool) {
        loginItem.setEnabled(enabled)
        launchAtLogin = loginItem.isEnabled
    }

    // MARK: - Finale

    private func celebrate() {
        let strength = settings.haptics == .off ? HapticStrength.medium : settings.haptics
        Task { [weak self] in
            for delay in [0, 140, 140, 260] {
                try? await Task.sleep(for: .milliseconds(delay))
                self?.effects.playHaptic(strength)
            }
        }
    }
}
