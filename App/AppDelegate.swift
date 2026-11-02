import AppKit
import EdgeBarCore
import EdgeBarSystem
import EdgeBarUI
import Observation
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    let controller = EdgeController()
    private(set) lazy var model = AppModel(
        settings: settings,
        levelControl: levelControl,
        loginItem: LoginItem()
    )
    private let levelControl = SystemLevels()
    private var onboarding: OnboardingWindowController?
    private var menuWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        quitOtherCopies()

        model.openTour = { [weak self] in self?.showOnboarding() }
        model.quit = { NSApp.terminate(nil) }

        controller.onStatusChange = { [weak self] status in
            guard let self else { return }
            model.status = status
            if let onboarding {
                let wasWaiting = onboarding.model.status == .needsAccessibility
                onboarding.model.status = status
                // Access was just granted in System Settings: come back to celebrate.
                if wasWaiting, status != .needsAccessibility {
                    onboarding.bringToFront()
                }
            }
        }
        controller.onAction = { [weak self] action in
            guard let self else { return }
            if case .step = action { model.refreshLevels() }
            if action == .toggleMute { model.refreshLevels() }
            onboarding?.model.handle(action)
        }

        applySettings()
        controller.start()
        model.status = controller.status

        if !settings.hasCompletedSetup || controller.status == .needsAccessibility {
            showOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.stop()
    }

    /// Opening the app again while it runs shows the menu in a window. The menu bar icon can be
    /// hidden behind the notch, and this keeps settings and Quit within reach.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showMenuWindow() }
        return false
    }

    /// Two copies would each press every key, so a double tap would mute and unmute. The newest
    /// launch wins: that is the one just built or just updated.
    private func quitOtherCopies() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let me = ProcessInfo.processInfo.processIdentifier
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) where app.processIdentifier != me {
            app.terminate()
        }
    }

    /// Pushes settings into the controller and appearance, now and on every change.
    private func applySettings() {
        withObservationTracking {
            controller.gestureSettings = settings.gesture
            controller.hapticStrength = settings.haptics
            controller.freezeCursor = settings.freezeCursor
            NSApp.appearance = switch settings.appearance {
            case .system: nil
            case .light: NSAppearance(named: .aqua)
            case .dark: NSAppearance(named: .darkAqua)
            }
        } onChange: { [weak self] in
            Task { @MainActor in self?.applySettings() }
        }
    }

    private func showOnboarding() {
        if let onboarding {
            onboarding.bringToFront()
            return
        }
        let tour = OnboardingWindowController(settings: settings, controller: controller, levelControl: levelControl)
        tour.model.onFinish = { [weak self] in
            guard let self else { return }
            settings.hasCompletedSetup = true
            controller.onTouches = nil
            onboarding?.close()
            onboarding = nil
        }
        controller.onTouches = { [weak tour] frame in tour?.model.show(frame) }
        onboarding = tour
        tour.show()
    }

    private func showMenuWindow() {
        if menuWindow == nil {
            let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "OpenEdgeBar"
            window.contentViewController = NSHostingController(rootView: TrackedMenuView(model: model, controller: controller))
            window.isReleasedWhenClosed = false
            window.center()
            menuWindow = window
        }
        NSApp.activate()
        menuWindow?.makeKeyAndOrderFront(nil)
        menuWindow?.orderFrontRegardless()
    }
}
