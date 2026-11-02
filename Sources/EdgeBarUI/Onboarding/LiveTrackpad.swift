import EdgeBarCore
import EdgeBarSystem
import SwiftUI

/// The tour's picture of the trackpad, as a shallow recess in the window. The brightness and
/// volume columns are tinted Liquid Glass standing at the real levels, and each real finger is a
/// glass bead.
/// While no finger is down, a faint bead acts out the current challenge.
struct LiveTrackpad: View {
    let fingers: [Touch]
    let levels: Levels
    let gesture: GestureSettings
    var hint: OnboardingModel.Challenge?
    /// Shows the percentages and the mute and skip marks.
    var showsDetails = true

    static let size = CGSize(width: 500, height: 312)
    private static let columnWidth: CGFloat = 30
    private static let inset = EdgeInsets(top: 44, leading: 22, bottom: 44, trailing: 22)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GlassGroup(spacing: 18) {
            ZStack(alignment: .topLeading) {
                well

                column(.brightness)
                column(.volume)

                if showsDetails {
                    details
                }

                ForEach(fingers, id: \.id) { finger in
                    Circle()
                        .fill(.clear)
                        .frame(width: 46, height: 46)
                        .liquidGlass(tint: tint(for: finger).opacity(0.35), interactive: true, in: .circle)
                        .position(position(for: finger))
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                }
            }
            .frame(width: Self.size.width, height: Self.size.height)
        }
        .overlay {
            ZStack(alignment: .topLeading) {
                glyph(.brightness)
                glyph(.volume)

                // Out here, its every frame redraws only itself, not the glass.
                if fingers.isEmpty, let hint {
                    GhostBead(hint: hint, volumeOnRight: !gesture.swapSides)
                }
            }
            .frame(width: Self.size.width, height: Self.size.height)
            .allowsHitTesting(false)
        }
        .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.8), value: fingers)
        .accessibilityElement()
        .accessibilityLabel("Your trackpad")
        .accessibilityValue(fingers.isEmpty ? "No fingers" : "\(fingers.count) finger\(fingers.count == 1 ? "" : "s") down")
    }

    /// A shallow recess in the glass, the size and shape of a trackpad.
    private var well: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(.primary.opacity(0.045))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
            )
            .frame(width: Self.size.width, height: Self.size.height)
    }

    private func isOnRight(_ control: EdgeControl) -> Bool {
        (control == .volume) != gesture.swapSides
    }

    private static func columnCenter(onRight: Bool) -> CGFloat {
        onRight ? size.width - inset.trailing - columnWidth / 2 : inset.leading + columnWidth / 2
    }

    private func level(of control: EdgeControl) -> Double {
        control == .volume ? (levels.isMuted ? 0 : levels.volume ?? 0) : levels.brightness ?? 0
    }

    private func column(_ control: EdgeControl) -> some View {
        let isVolume = control == .volume
        let onRight = isOnRight(control)
        let height = Self.size.height - Self.inset.top - Self.inset.bottom
        let fill = max(height * level(of: control), Self.columnWidth)
        let color: Color = isVolume ? .blue : .orange
        return ZStack(alignment: .bottom) {
            Capsule()
                .fill(.primary.opacity(0.06))
            Capsule()
                .fill(.clear)
                .frame(height: fill)
                .liquidGlass(tint: color.opacity(0.75), in: .capsule)
        }
        .frame(width: Self.columnWidth, height: height)
        .position(x: Self.columnCenter(onRight: onRight), y: Self.inset.top + height / 2)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: fill)
    }

    /// The symbol at the foot of a column. Drawn outside the glass container, which would
    /// otherwise lay the glass over it.
    private func glyph(_ control: EdgeControl) -> some View {
        let isVolume = control == .volume
        return Image(systemName: isVolume ? (levels.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill") : "sun.max.fill")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .position(x: Self.columnCenter(onRight: isOnRight(control)), y: Self.size.height - Self.inset.bottom - Self.columnWidth / 2)
    }

    private var details: some View {
        ZStack(alignment: .topLeading) {
            value(.brightness)
            value(.volume)

            if gesture.quickMute {
                HStack(spacing: 5) {
                    Image(systemName: levels.isMuted ? "speaker.slash.fill" : "speaker.slash")
                    Text("Double-tap this corner to mute")
                    Image(systemName: "arrow.up.right")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(hint == .mute || levels.isMuted ? Color.accentColor : .secondary)
                .fixedSize()
                // Ends clear of the volume reading, which says "Muted" at its widest.
                .frame(width: Self.size.width - 100, alignment: .trailing)
                .position(x: (Self.size.width - 100) / 2, y: 22)
            }

            if gesture.mediaStrip {
                Label("Flick to skip", systemImage: "forward")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(hint == .skip ? Color.accentColor : .secondary)
                    .position(x: Self.size.width / 2, y: Self.size.height - 20)
            }
        }
        .allowsHitTesting(false)
    }

    private func value(_ control: EdgeControl) -> some View {
        let isVolume = control == .volume
        let onRight = isOnRight(control)
        let percent = Int((level(of: control) * 100).rounded())
        return Text(isVolume && levels.isMuted ? "Muted" : "\(percent)%")
            .font(.callout.weight(.semibold).monospacedDigit())
            .foregroundStyle(.primary)
            .contentTransition(.numericText(value: Double(percent)))
            .animation(.snappy(duration: 0.25), value: percent)
            .position(x: Self.columnCenter(onRight: onRight), y: 22)
            .accessibilityLabel(isVolume ? "Volume" : "Brightness")
            .accessibilityValue(isVolume && levels.isMuted ? "Muted" : "\(percent) percent")
    }

    /// Fingers on an edge ride their column; elsewhere they sit where they touch.
    private func position(for finger: Touch) -> CGPoint {
        let y = min(max((1 - finger.y) * Self.size.height, 23), Self.size.height - 23)
        if finger.x <= gesture.edgeWidth { return CGPoint(x: Self.columnCenter(onRight: false), y: y) }
        if finger.x >= 1 - gesture.edgeWidth { return CGPoint(x: Self.columnCenter(onRight: true), y: y) }
        return CGPoint(x: min(max(finger.x * Self.size.width, 23), Self.size.width - 23), y: y)
    }

    private func tint(for finger: Touch) -> Color {
        let onLeft = finger.x <= gesture.edgeWidth
        let onRight = finger.x >= 1 - gesture.edgeWidth
        guard onLeft || onRight else { return .white }
        return (onRight != gesture.swapSides) ? .blue : .orange
    }

    fileprivate static func columnFraction(onRight: Bool) -> Double {
        columnCenter(onRight: onRight) / size.width
    }
}

/// A faint bead acting out a challenge, on a loop.
private struct GhostBead: View {
    let hint: OnboardingModel.Challenge
    let volumeOnRight: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let cycle = 2.4
            let phase = reduceMotion ? 0.55 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle) / cycle
            let pose = pose(at: phase)
            Circle()
                .strokeBorder(.secondary.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .background(Circle().fill(.primary.opacity(0.05)))
                .frame(width: 40, height: 40)
                .scaleEffect(pose.scale)
                .opacity(pose.opacity)
                .position(x: pose.x * LiveTrackpad.size.width, y: (1 - pose.y) * LiveTrackpad.size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func pose(at phase: Double) -> (x: Double, y: Double, opacity: Double, scale: Double) {
        let eased = ease(min(max((phase - 0.15) / 0.55, 0), 1))
        let fade = phase < 0.1 ? phase / 0.1 : phase > 0.82 ? max(0, (1 - phase) / 0.18) : 1
        switch hint {
        case .volume, .brightness:
            let onRight = (hint == .volume) == volumeOnRight
            return (LiveTrackpad.columnFraction(onRight: onRight), 0.25 + 0.5 * eased, fade, 1)
        case .mute:
            let tap = phase.truncatingRemainder(dividingBy: 0.5) / 0.5
            let pressed = phase < 0.6 && tap < 0.35
            return (0.9, 0.86, phase < 0.6 ? 1 : max(0, (1 - phase) / 0.4), pressed ? 0.8 : 1)
        case .skip:
            return (0.3 + 0.4 * ease(min(max((phase - 0.2) / 0.3, 0), 1)), EdgeGestureEngine.Tuning.mediaStripHeight / 2, fade, 1)
        }
    }

    private func ease(_ value: Double) -> Double {
        value < 0.5 ? 2 * value * value : 1 - pow(-2 * value + 2, 2) / 2
    }
}
