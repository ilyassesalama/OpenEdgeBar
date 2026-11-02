import EdgeBarSystem
import SwiftUI

/// Brightness and volume, each shown on the side of the card that matches its trackpad edge.
/// Drag up or down on either half to change it, just like sliding the edge.
struct LevelsCard: View {
    let levels: Levels
    let swapSides: Bool
    let setBrightness: (Double) -> Void
    let setVolume: (Double) -> Void

    var body: some View {
        HStack(spacing: 0) {
            if swapSides {
                volume(edge: .leading)
                brightness(edge: .trailing)
            } else {
                brightness(edge: .leading)
                volume(edge: .trailing)
            }
        }
        .frame(height: 96)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.quinary))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
        .animation(.snappy(duration: 0.25), value: swapSides)
    }

    private func brightness(edge: HorizontalEdge) -> some View {
        LevelGauge(
            title: "Brightness",
            symbol: "sun.max.fill",
            tint: Palette.brightness,
            value: levels.brightness,
            unavailableText: "Built-in only",
            isMuted: false,
            edge: edge,
            set: setBrightness
        )
    }

    private func volume(edge: HorizontalEdge) -> some View {
        LevelGauge(
            title: "Volume",
            symbol: levels.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
            tint: Palette.volume,
            value: levels.volume,
            unavailableText: "Fixed",
            isMuted: levels.isMuted,
            edge: edge,
            set: setVolume
        )
    }
}

private struct LevelGauge: View {
    let title: String
    let symbol: String
    let tint: Color
    let value: Double?
    let unavailableText: String
    let isMuted: Bool
    let edge: HorizontalEdge
    let set: (Double) -> Void

    /// Value when the current drag began.
    @State private var dragStart: Double?

    /// Points of vertical drag for the full range.
    private let dragRange: CGFloat = 160

    var body: some View {
        HStack(spacing: 12) {
            if edge == .leading { bar }
            readout
                .frame(maxWidth: .infinity, alignment: edge == .leading ? .leading : .trailing)
            if edge == .trailing { bar }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .contentShape(Rectangle())
        .gesture(drag, including: value == nil ? .none : .all)
        .focusable(value != nil)
        .onKeyPress(keys: [.upArrow, .rightArrow]) { _ in
            nudge(by: 1)
            return .handled
        }
        .onKeyPress(keys: [.downArrow, .leftArrow]) { _ in
            nudge(by: -1)
            return .handled
        }
        .accessibilityElement()
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValue)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: nudge(by: 1)
            case .decrement: nudge(by: -1)
            @unknown default: break
            }
        }
    }

    /// One keyboard-key step: a sixteenth, like the brightness and volume keys.
    private func nudge(by steps: Double) {
        guard let value else { return }
        set(value + steps / 16)
    }

    private var bar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(isMuted ? AnyShapeStyle(.tertiary) : AnyShapeStyle(tint))
                    .frame(height: geometry.size.height * (value ?? 0))
            }
        }
        .frame(width: 4)
        .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.9), value: value)
    }

    private var readout: some View {
        VStack(alignment: edge == .leading ? .leading : .trailing, spacing: 2) {
            HStack(spacing: 5) {
                if edge == .leading { icon }
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                if edge == .trailing { icon }
            }
            if let value {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(Int((value * 100).rounded()))")
                        .font(.system(size: 34, weight: .regular).monospacedDigit())
                        .contentTransition(.numericText(value: value))
                    Text("%")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                .opacity(isMuted ? 0.4 : 1)
                .animation(.snappy(duration: 0.2), value: value)
            } else {
                Text(unavailableText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .frame(height: 41)
            }
        }
    }

    private var icon: some View {
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(isMuted ? AnyShapeStyle(.secondary) : AnyShapeStyle(tint))
            .contentTransition(.symbolEffect(.replace))
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { gesture in
                guard let value else { return }
                let start = dragStart ?? value
                dragStart = start
                set(start - gesture.translation.height / dragRange)
            }
            .onEnded { _ in dragStart = nil }
    }

    private var accessibilityValue: String {
        guard let value else { return unavailableText }
        let percent = "\(Int((value * 100).rounded())) percent"
        return isMuted ? "Muted, \(percent)" : percent
    }
}
