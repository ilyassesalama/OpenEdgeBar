import EdgeBarCore
import EdgeBarSystem
import SwiftUI

/// The window that drops down from the menu bar icon.
public struct MenuView: View {
    @Bindable var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        ZStack {
            switch model.page {
            case .main:
                MainPage(model: model)
                    .transition(pageTransition(from: .leading))
            case .settings:
                SettingsPage(model: model)
                    .transition(pageTransition(from: .trailing))
            }
        }
        .animation(.snappy(duration: 0.28), value: model.page)
        .frame(width: MenuMetrics.width)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func pageTransition(from edge: Edge) -> AnyTransition {
        reduceMotion ? .opacity : .move(edge: edge).combined(with: .opacity)
    }
}

// MARK: - Main page

struct MainPage: View {
    let model: AppModel
    @Bindable private var settings: AppSettings

    init(model: AppModel) {
        self.model = model
        settings = model.settings
    }

    var body: some View {
        VStack(spacing: 0) {
            MenuHeader(title: "OpenEdgeBar", status: model.status, openTour: model.openTour)
                .padding(.bottom, MenuMetrics.sectionGap)

            LevelsCard(
                levels: model.levels,
                swapSides: settings.gesture.swapSides,
                setBrightness: model.setBrightness,
                setVolume: model.setVolume
            )
            .padding(.bottom, MenuMetrics.sectionGap)

            VStack(spacing: MenuMetrics.rowSpacing) {
                OptionRow(
                    symbol: "hand.tap.fill",
                    title: "Haptic Feedback",
                    subtitle: "Clicks as you slide",
                    isActive: settings.haptics != .off
                ) {
                    Picker("Haptic Feedback", selection: $settings.haptics) {
                        ForEach(HapticStrength.allCases, id: \.self) { strength in
                            Text(strength.title).tag(strength)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }
                ToggleRow(
                    symbol: "speaker.slash.fill",
                    title: "Quick Mute",
                    subtitle: "Double-tap the top-right corner",
                    isOn: $settings.gesture.quickMute
                )
                ToggleRow(
                    symbol: "forward.fill",
                    title: "Media Strip",
                    subtitle: "Swipe the bottom edge to skip",
                    isOn: $settings.gesture.mediaStrip
                )
            }

            MenuDivider()

            VStack(spacing: MenuMetrics.sectionGap) {
                SliderRow(
                    symbol: "gauge.with.dots.needle.67percent",
                    title: "Sensitivity",
                    value: $settings.gesture.sensitivity,
                    range: GestureSettings.sensitivityRange,
                    step: GestureSettings.sensitivityStep,
                    valueText: { "\($0.formatted(.number.precision(.fractionLength(0...2))))×" }
                )
                SliderRow(
                    symbol: "arrow.left.and.right",
                    title: "Edge Width",
                    value: $settings.gesture.edgeWidth,
                    range: GestureSettings.edgeWidthRange,
                    step: GestureSettings.edgeWidthStep,
                    valueText: { "\(Int(($0 * 100).rounded()))%" }
                )
            }

            MenuFooter {
                FooterButton(symbol: "gearshape", title: "Settings", help: "Settings") {
                    model.page = .settings
                }
                Spacer()
                MoreMenu(model: model)
                FooterButton(symbol: "power", help: "Quit OpenEdgeBar", action: model.quit)
            }
        }
        .menuPagePadding()
    }
}

// MARK: - Settings page

struct SettingsPage: View {
    let model: AppModel
    @Bindable private var settings: AppSettings

    init(model: AppModel) {
        self.model = model
        settings = model.settings
    }

    private var gesture: GestureSettings { settings.gesture }

    var body: some View {
        VStack(spacing: 0) {
            MenuHeader(title: "Settings", status: nil, openTour: {})
                .padding(.bottom, MenuMetrics.sectionGap)

            MenuSection(title: "Edge Gestures") {
                ToggleRow(
                    symbol: "arrow.left.arrow.right",
                    title: "Swap Sides",
                    subtitle: gesture.swapSides ? "Left: Volume · Right: Brightness" : "Left: Brightness · Right: Volume",
                    isOn: $settings.gesture.swapSides
                )
                ToggleRow(
                    symbol: "rectangle.bottomhalf.filled",
                    title: "Bottom Quarter Only",
                    subtitle: "Slides start in the lower 25%",
                    isOn: $settings.gesture.bottomQuarterOnly
                )
                ToggleRow(
                    symbol: "option",
                    title: "Require Fn or ⌥",
                    subtitle: "Only slide while holding a modifier",
                    isOn: $settings.gesture.requireModifier
                )
                ToggleRow(
                    symbol: "playpause.fill",
                    title: "Tap to Play or Pause",
                    subtitle: gesture.mediaStrip ? "Clicks near the edge can trigger it" : "Needs the Media Strip",
                    isOn: $settings.gesture.tapToPlay
                )
                .disabled(!gesture.mediaStrip)
            }

            MenuDivider()

            MenuSection(title: "While Sliding") {
                ToggleRow(
                    symbol: "cursorarrow",
                    title: "Freeze Cursor",
                    subtitle: "Pointer stays put while sliding",
                    isOn: $settings.freezeCursor
                )
                ToggleRow(
                    symbol: "dial.low.fill",
                    title: "Fine Control",
                    subtitle: "Hold ⇧⌥ for quarter steps",
                    isOn: $settings.gesture.fineControl
                )
            }

            MenuDivider()

            MenuSection(title: "General") {
                OptionRow(symbol: "circle.lefthalf.filled", title: "Appearance") {
                    Picker("Appearance", selection: $settings.appearance) {
                        Text("Auto").tag(Appearance.system)
                        Text("Light").tag(Appearance.light)
                        Text("Dark").tag(Appearance.dark)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .controlSize(.small)
                    .fixedSize()
                }
                ToggleRow(
                    symbol: "power",
                    title: "Open at Login",
                    isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) })
                )
            }

            MenuFooter {
                FooterButton(symbol: "chevron.left", title: "Back", help: "Back") {
                    model.page = .main
                }
                Spacer()
                MoreMenu(model: model)
                FooterButton(symbol: "power", help: "Quit OpenEdgeBar", action: model.quit)
            }
        }
        .menuPagePadding()
    }
}

// MARK: - Shared pieces

extension View {
    /// The space between a menu page and the window edge. The bottom is tighter because the
    /// footer buttons carry their own space around their glyphs.
    func menuPagePadding() -> some View {
        padding(.horizontal, MenuMetrics.inset)
            .padding(.top, MenuMetrics.inset)
            .padding(.bottom, 8)
    }
}

struct MenuDivider: View {
    var body: some View {
        Divider().padding(.vertical, MenuMetrics.sectionGap)
    }
}

/// The bottom bar: a divider, then buttons whose glyphs line up with the rows above.
struct MenuFooter<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.top, MenuMetrics.sectionGap)
                .padding(.bottom, 8)
            HStack(spacing: 2, content: content)
                .padding(.horizontal, -MenuMetrics.footerButtonPadding)
        }
    }
}

struct MenuHeader: View {
    let title: String
    let status: EdgeStatus?
    let openTour: () -> Void

    var body: some View {
        // The icon fills the icon column, so the title starts where every row title does.
        HStack(spacing: MenuMetrics.iconGap) {
            AppIconImage()
                .frame(width: MenuMetrics.iconSize, height: MenuMetrics.iconSize)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let status {
                StatusBadge(status: status, action: openTour)
            }
        }
    }
}

struct StatusBadge: View {
    let status: EdgeStatus
    let action: () -> Void

    var body: some View {
        // Only a missing permission is something the welcome tour can fix.
        if status == .needsAccessibility {
            Button(action: action) {
                HStack(spacing: 3) {
                    label
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the welcome tour")
        } else {
            label
        }
    }

    private var label: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .help(help)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Status: \(text)")
    }

    private var color: Color {
        switch status {
        case .ready: .green
        case .needsAccessibility: .orange
        case .noTrackpad: .gray
        }
    }

    private var text: String {
        switch status {
        case .ready: "Ready"
        case .needsAccessibility: "Needs Access"
        case .noTrackpad: "No Trackpad"
        }
    }

    private var help: String {
        switch status {
        case .ready: "Edges are working"
        case .needsAccessibility: "Allow OpenEdgeBar to send brightness and volume keys"
        case .noTrackpad: "Connect a trackpad to use edge gestures"
        }
    }
}

struct MoreMenu: View {
    let model: AppModel

    var body: some View {
        Menu {
            Button("Welcome Tour…", action: model.openTour)
            Divider()
            Link("OpenEdgeBar on GitHub", destination: URL(string: "https://github.com/ilyassesalama/OpenEdgeBar")!)
        } label: {
            FooterLabel(symbol: "ellipsis.circle")
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("More")
        .accessibilityLabel("More")
    }
}
