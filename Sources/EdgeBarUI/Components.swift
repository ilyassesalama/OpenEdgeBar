import SwiftUI

enum Palette {
    static let accent = Color(red: 0.40, green: 0.29, blue: 0.95)
    static let brightness = Color.orange
    static let volume = Color.blue
}

/// The menu's spacing scale, so every page lines up the same way.
enum MenuMetrics {
    static let width: CGFloat = 320
    /// Between the window edge and the content.
    static let inset: CGFloat = 16
    /// Above and below each divider, and after the header and the levels card.
    static let sectionGap: CGFloat = 14
    /// Between rows in a group.
    static let rowSpacing: CGFloat = 12
    /// Width of the icon column. Titles start at `iconSize + iconGap` on every row.
    static let iconSize: CGFloat = 26
    static let iconGap: CGFloat = 10
    /// Footer buttons pad their hover highlight by this much; pulling the footer out by it lines
    /// the glyphs up with the rows.
    static let footerButtonPadding: CGFloat = 7
}

/// A settings row: round icon, title, optional subtitle, and a trailing control.
struct OptionRow<Accessory: View>: View {
    let symbol: String
    let title: String
    var subtitle: String?
    /// Fills the icon with the accent color, to show the option is on.
    var isActive = false
    @ViewBuilder var accessory: () -> Accessory

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: MenuMetrics.iconGap) {
                RowIcon(symbol: symbol, isActive: isActive)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 8)
            // The control stays its own element, so VoiceOver can operate it.
            accessory()
        }
        .opacity(isEnabled ? 1 : 0.45)
    }
}

extension OptionRow where Accessory == EmptyView {
    init(symbol: String, title: String, subtitle: String? = nil, isActive: Bool = false) {
        self.init(symbol: symbol, title: title, subtitle: subtitle, isActive: isActive) { EmptyView() }
    }
}

/// A row with a switch on the right.
struct ToggleRow: View {
    let symbol: String
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        OptionRow(symbol: symbol, title: title, subtitle: subtitle, isActive: isOn) {
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(Palette.accent)
                .accessibilityHint(subtitle ?? "")
        }
    }
}

struct RowIcon: View {
    let symbol: String
    var isActive = false

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isActive ? Color.white : Color.secondary)
            .frame(width: MenuMetrics.iconSize, height: MenuMetrics.iconSize)
            .background(Circle().fill(isActive ? AnyShapeStyle(Palette.accent) : AnyShapeStyle(.quaternary)))
            .animation(.easeOut(duration: 0.15), value: isActive)
            .accessibilityHidden(true)
    }
}

/// A titled group of rows. The title sits closer to its rows than the rows sit to each other,
/// so it reads as theirs.
struct MenuSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: MenuMetrics.rowSpacing, content: content)
        }
    }
}

/// A slider that snaps to evenly spaced stops, drawn with a dot at each stop.
struct SteppedSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let label: String
    let valueText: (Double) -> String

    private let trackHeight: CGFloat = 18
    private var stopCount: Int { Int(((range.upperBound - range.lowerBound) / step).rounded()) }
    private var fraction: Double { (value - range.lowerBound) / (range.upperBound - range.lowerBound) }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let knob = trackHeight - 4
            let usable = width - trackHeight
            let knobX = trackHeight / 2 + usable * fraction

            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                ForEach(0...stopCount, id: \.self) { index in
                    let x = trackHeight / 2 + usable * Double(index) / Double(stopCount)
                    if x > knobX + knob / 2 + 2 {
                        Circle()
                            .fill(.tertiary)
                            .frame(width: 3, height: 3)
                            .position(x: x, y: trackHeight / 2)
                    }
                }
                Capsule()
                    .fill(Palette.accent)
                    .frame(width: knobX + trackHeight / 2)
                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.25), radius: 1.5, y: 0.5)
                    .frame(width: knob, height: knob)
                    .position(x: knobX, y: trackHeight / 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let raw = (drag.location.x - trackHeight / 2) / usable
                        set(fraction: raw)
                    }
            )
            .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.9), value: value)
        }
        .frame(height: trackHeight)
        .focusable()
        .onKeyPress(keys: [.rightArrow, .upArrow]) { _ in
            set(value: value + step)
            return .handled
        }
        .onKeyPress(keys: [.leftArrow, .downArrow]) { _ in
            set(value: value - step)
            return .handled
        }
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue(valueText(value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: set(value: value + step)
            case .decrement: set(value: value - step)
            @unknown default: break
            }
        }
    }

    private func set(fraction: Double) {
        set(value: range.lowerBound + min(max(fraction, 0), 1) * (range.upperBound - range.lowerBound))
    }

    private func set(value newValue: Double) {
        let stops = ((newValue - range.lowerBound) / step).rounded()
        let snapped = min(max(range.lowerBound + stops * step, range.lowerBound), range.upperBound)
        if snapped != value {
            value = snapped
        }
    }
}

/// A labeled slider row: icon, title, current value, and the slider underneath.
struct SliderRow: View {
    let symbol: String
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let valueText: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: MenuMetrics.iconGap) {
                RowIcon(symbol: symbol)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Text(valueText(value))
                    .font(.system(size: 13).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.2), value: value)
            }
            SteppedSlider(value: $value, range: range, step: step, label: title, valueText: valueText)
                .padding(.leading, MenuMetrics.iconSize + MenuMetrics.iconGap)
        }
    }
}

/// A small borderless button for the footer.
struct FooterButton: View {
    let symbol: String
    var title: String?
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            FooterLabel(symbol: symbol, title: title)
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(title ?? help)
    }
}

/// What every footer control looks like: a gray icon, an optional title, and a hover highlight.
struct FooterLabel: View {
    let symbol: String
    var title: String?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 13))
            if let title {
                Text(title).font(.system(size: 13))
            }
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, MenuMetrics.footerButtonPadding)
        .frame(minWidth: 28, minHeight: 26)
        .background(RoundedRectangle(cornerRadius: 6).fill(isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear)))
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}
