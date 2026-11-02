import AppKit
import SwiftUI

/// The tour's window: a standard window with only the close button, like the system's own setup
/// windows. It keeps the plain window background; Liquid Glass sits on the controls above it.
@MainActor
public enum TourWindow {
    public static let size = CGSize(width: 760, height: 640)

    public static func make(_ content: some View) -> NSWindow {
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to OpenEdgeBar"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        let host = NSHostingView(rootView: content)
        host.sizingOptions = []
        window.contentView = host
        window.setContentSize(size)
        window.center()
        return window
    }
}
