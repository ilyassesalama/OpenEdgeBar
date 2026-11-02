import EdgeBarCore
import EdgeBarSystem
import Foundation
import Observation

/// Everything the menu shows and can change.
@MainActor
@Observable
public final class AppModel {
    public enum Page: Sendable {
        case main
        case settings
    }

    public let settings: AppSettings
    public var status: EdgeStatus = .ready
    public var page: Page = .main
    public private(set) var levels = Levels(brightness: nil, volume: nil, isMuted: false)
    public private(set) var launchAtLogin: Bool

    /// Opens the welcome tour.
    @ObservationIgnored public var openTour: () -> Void = {}
    @ObservationIgnored public var quit: () -> Void = {}

    @ObservationIgnored private let levelControl: SystemLevels
    @ObservationIgnored private let loginItem: LoginItem
    @ObservationIgnored private var levelTimer: Timer?

    public init(settings: AppSettings, levelControl: SystemLevels, loginItem: LoginItem) {
        self.settings = settings
        self.levelControl = levelControl
        self.loginItem = loginItem
        launchAtLogin = loginItem.isEnabled
        levels = levelControl.read()
    }

    // MARK: - Live levels

    /// Keeps the levels fresh while the menu is open. Nothing runs while it is closed.
    public func menuDidOpen() {
        refreshLevels()
        launchAtLogin = loginItem.isEnabled
        levelTimer?.invalidate()
        let timer = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshLevels() }
        }
        RunLoop.main.add(timer, forMode: .common)
        levelTimer = timer
    }

    public func menuDidClose() {
        levelTimer?.invalidate()
        levelTimer = nil
        page = .main
    }

    public func refreshLevels() {
        let latest = levelControl.read()
        if latest != levels {
            levels = latest
        }
    }

    public func setBrightness(_ value: Double) {
        let clamped = min(max(value, 0), 1)
        levelControl.setBrightness(clamped)
        levels.brightness = clamped
    }

    public func setVolume(_ value: Double) {
        let clamped = min(max(value, 0), 1)
        levelControl.setVolume(clamped)
        levels.volume = clamped
    }

    // MARK: - Login item

    public func setLaunchAtLogin(_ enabled: Bool) {
        loginItem.setEnabled(enabled)
        launchAtLogin = loginItem.isEnabled
    }
}
