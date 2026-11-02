import AppKit
import SwiftUI

/// Reports when the window hosting this view is shown or hidden. The menu bar window is reused
/// between openings, so `onAppear` alone cannot tell.
struct WindowVisibilityObserver: NSViewRepresentable {
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> ObservingView {
        ObservingView(onChange: onChange)
    }

    func updateNSView(_ view: ObservingView, context: Context) {
        view.onChange = onChange
    }

    final class ObservingView: NSView {
        var onChange: (Bool) -> Void
        private var isVisible = false
        private var observer: NSObjectProtocol?

        init(onChange: @escaping (Bool) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
            observer = nil
            guard let window else { return }
            observer = NotificationCenter.default.addObserver(
                forName: NSWindow.didChangeOcclusionStateNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.update() }
            }
            update()
        }

        private func update() {
            let visible = window?.occlusionState.contains(.visible) ?? false
            guard visible != isVisible else { return }
            isVisible = visible
            onChange(visible)
        }
    }
}
