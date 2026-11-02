import EdgeBarSystem
import EdgeBarUI
import SwiftUI

@main
struct OpenEdgeBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            TrackedMenuView(model: appDelegate.model, controller: appDelegate.controller)
        } label: {
            Image(nsImage: MenuBarIcon.image)
        }
        .menuBarExtraStyle(.window)
    }
}

/// The menu, refreshing live levels and status only while its window is on screen.
struct TrackedMenuView: View {
    let model: AppModel
    let controller: EdgeController

    var body: some View {
        MenuView(model: model)
            // Keys still work; the rings that keyboard navigation draws are left out.
            .focusEffectDisabled()
            .background(WindowVisibilityObserver { visible in
                if visible {
                    model.menuDidOpen()
                    controller.refreshStatus()
                } else {
                    model.menuDidClose()
                }
            })
    }
}
