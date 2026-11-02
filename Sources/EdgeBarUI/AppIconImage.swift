import AppKit
import SwiftUI

/// The app's own icon, as macOS draws it: Liquid Glass on macOS 26 and later, the flat
/// version before that. Comes from App/AppIcon.icon, so the menu and the tour always match it.
public struct AppIconImage: View {
    public init() {}

    public var body: some View {
        Image(nsImage: NSApplication.shared.applicationIconImage)
            .resizable()
            .aspectRatio(1, contentMode: .fit)
            .accessibilityHidden(true)
    }
}
