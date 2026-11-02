import AppKit
import EdgeBarSystem
import EdgeBarUI
import SwiftUI

/// The welcome tour's window.
@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    let model: OnboardingModel
    private let window: NSWindow
    /// The system prompt only ever appears once, and it adds the app to the Accessibility list.
    /// After that, the button goes straight to System Settings.
    private var hasRequestedPermission = false

    init(settings: AppSettings, controller: EdgeController, levelControl: SystemLevels) {
        var requestPermission: () -> Void = {}
        let model = OnboardingModel(
            settings: settings,
            status: controller.status,
            levelControl: levelControl,
            loginItem: LoginItem(),
            effects: OnboardingModel.Effects(
                playHaptic: { controller.previewHaptic($0) },
                pressMute: { controller.press(.mute) },
                requestPermission: { requestPermission() }
            )
        )
        self.model = model
        window = TourWindow.make(OnboardingView(model: model))
        super.init()
        requestPermission = { [weak self] in self?.requestPermission() }
        window.delegate = self
    }

    func show() {
        model.startLiveLevels()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        // A menu bar app launched in the background cannot take focus; still bring the window up.
        window.orderFrontRegardless()
        // No button starts out focused, so Space cannot press one without its ring showing.
        window.makeFirstResponder(nil)
    }

    /// Brings the tour back in front, for example after granting access in System Settings.
    func bringToFront() {
        show()
    }

    func close() {
        model.stopLiveLevels()
        window.delegate = nil
        window.close()
    }

    /// The red close button skips the tour.
    func windowWillClose(_ notification: Notification) {
        model.skip()
    }

    private func requestPermission() {
        if hasRequestedPermission {
            KeyPermission.openSettings()
        } else {
            hasRequestedPermission = true
            KeyPermission.request()
        }
    }
}
