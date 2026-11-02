import EdgeBarCore
import EdgeBarSystem
import SwiftUI

/// The first-run tour, laid out like the system's own setup windows: a hero, a title, a line of
/// text, and a footer with Skip, the step dots and the main button. Everything is native: system
/// type and colors, Liquid Glass, and standard controls.
public struct OnboardingView: View {
    let model: OnboardingModel

    public init(model: OnboardingModel) {
        self.model = model
    }

    public var body: some View {
        VStack(spacing: 0) {
            ZStack {
                step
                    .id(model.act)
                    .transition(.blurReplace)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.smooth(duration: 0.45), value: model.act)

            Footer(model: model)
        }
        .padding(.horizontal, 40)
        .padding(.top, 48)
        .padding(.bottom, 28)
        .frame(width: TourWindow.size.width, height: TourWindow.size.height)
        // Return and Escape still work; the rings that keyboard navigation draws are left out.
        .focusEffectDisabled()
    }

    @ViewBuilder
    private var step: some View {
        switch model.act {
        case .welcome: WelcomeStep(model: model)
        case .permission: PermissionStep(model: model)
        case .practice: PracticeStep(model: model)
        case .personalize: PersonalizeStep(model: model)
        case .finale: FinaleStep(model: model)
        }
    }
}

/// A step: the hero, then a title and one line of text, then anything extra.
private struct StepLayout<Hero: View, Extra: View>: View {
    let title: String
    let detail: String
    @ViewBuilder var hero: () -> Hero
    @ViewBuilder var extra: () -> Extra

    var body: some View {
        VStack(spacing: 0) {
            hero()
                .frame(maxHeight: .infinity)
            Text(title)
                .font(.system(size: 26, weight: .bold))
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 22)
            Text(detail)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .padding(.top, 8)
            extra()
        }
    }
}

extension StepLayout where Extra == EmptyView {
    init(title: String, detail: String, @ViewBuilder hero: @escaping () -> Hero) {
        self.init(title: title, detail: detail, hero: hero) { EmptyView() }
    }
}

// MARK: - Footer

private struct Footer: View {
    let model: OnboardingModel

    private var granted: Bool { model.justGranted || model.status != .needsAccessibility }

    var body: some View {
        HStack {
            // A ZStack keeps its width with nothing in it, so the dots stay centered on the finale.
            ZStack {
                if model.act != .finale {
                    Button("Skip", action: model.skip)
                        .glassButtonStyle()
                        .keyboardShortcut(.cancelAction)
                }
            }
            .frame(width: 200, alignment: .leading)

            Spacer()
            StepDots(acts: model.acts, current: model.act)
            Spacer()

            primary
                .glassButtonStyle(prominent: true)
                .frame(width: 200, alignment: .trailing)
        }
        .controlSize(.extraLarge)
        .padding(.top, 24)
        .animation(.smooth(duration: 0.3), value: model.practiceComplete)
    }

    @ViewBuilder
    private var primary: some View {
        switch model.act {
        case .welcome, .personalize:
            Button("Continue", action: model.next)
                .keyboardShortcut(.defaultAction)
        case .permission:
            if granted {
                Button("Continue", action: model.next)
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Open Settings", action: model.requestPermission)
                    .keyboardShortcut(.defaultAction)
            }
        case .practice:
            if model.status == .needsAccessibility {
                Button("Allow Access", action: model.requestPermission)
            } else if model.practiceComplete {
                Button("Continue", action: model.next)
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Skip Practice", action: model.next)
                    .glassButtonStyle()
            }
        case .finale:
            Button("Done", action: model.next)
                .keyboardShortcut(.defaultAction)
        }
    }
}

private struct StepDots: View {
    let acts: [OnboardingModel.Act]
    let current: OnboardingModel.Act

    private var index: Int { acts.firstIndex(of: current) ?? 0 }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(acts.enumerated()), id: \.offset) { position, _ in
                Capsule()
                    .fill(Color.primary.opacity(position == index ? 0.85 : 0.2))
                    .frame(width: position == index ? 18 : 7, height: 7)
            }
        }
        .animation(.smooth, value: index)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(index + 1) of \(acts.count)")
    }
}

// MARK: - Welcome

private struct WelcomeStep: View {
    let model: OnboardingModel

    private var volumeSide: String { model.settings.gesture.swapSides ? "left" : "right" }
    private var brightnessSide: String { model.settings.gesture.swapSides ? "right" : "left" }

    var body: some View {
        StepLayout(
            title: "Your Trackpad Has Edges Now",
            detail: "Slide up the \(brightnessSide) side for brightness and the \(volumeSide) side for volume."
        ) {
            VStack(spacing: 16) {
                LiveTrackpad(fingers: model.fingers, levels: model.levels, gesture: model.settings.gesture, showsDetails: false)
                Label(
                    model.fingers.isEmpty ? "Rest a finger on your trackpad" : "That’s your finger. Now slide an edge.",
                    systemImage: model.fingers.isEmpty ? "hand.point.up.left" : "hand.point.up.left.fill"
                )
                .font(.callout.weight(.medium))
                .foregroundStyle(model.fingers.isEmpty ? .secondary : .primary)
                .contentTransition(.symbolEffect(.replace))
                .animation(.smooth, value: model.fingers.isEmpty)
            }
        }
    }
}

// MARK: - Permission

private struct PermissionStep: View {
    let model: OnboardingModel

    private var granted: Bool { model.justGranted || model.status != .needsAccessibility }

    var body: some View {
        StepLayout(
            title: granted ? "Access Allowed" : "Allow OpenEdgeBar to Press the Keys",
            detail: "OpenEdgeBar presses the same brightness and volume keys as your keyboard. macOS asks for your permission once."
        ) {
            VStack(spacing: 26) {
                // The icon image carries its own margin and shadow, as macOS draws it.
                AppIconImage()
                    .frame(width: 116, height: 116)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: granted ? "checkmark.circle.fill" : "lock.circle.fill")
                            .font(.system(size: 34))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, granted ? Color.green : Color.orange)
                            .contentTransition(.symbolEffect(.replace))
                    }
                SettingsRow(granted: granted)
            }
        } extra: {
            Group {
                if !granted {
                    Text("Already on? Remove OpenEdgeBar from the list with −, then add it again.")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 14)
                }
            }
        }
        .animation(.smooth, value: granted)
    }
}

/// OpenEdgeBar's row in Privacy & Security, with its switch showing whether access is on.
private struct SettingsRow: View {
    let granted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Privacy & Security › Accessibility")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            HStack(spacing: 12) {
                AppIconImage().frame(width: 30, height: 30)
                Text("OpenEdgeBar")
                    .font(.body.weight(.medium))
                Spacer()
                Toggle("OpenEdgeBar", isOn: .constant(granted))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.quaternary.opacity(0.6), in: .rect(cornerRadius: 12))
        }
        .frame(width: 400)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(granted ? "OpenEdgeBar is allowed in Accessibility settings" : "OpenEdgeBar is not allowed yet in Accessibility settings")
    }
}

// MARK: - Practice

private struct PracticeStep: View {
    let model: OnboardingModel

    private var volumeSide: String { model.settings.gesture.swapSides ? "left" : "right" }
    private var brightnessSide: String { model.settings.gesture.swapSides ? "right" : "left" }

    private var title: String {
        switch model.currentChallenge {
        case .volume: "Slide Up the \(volumeSide.capitalized) Edge"
        case .brightness: "Now the \(brightnessSide.capitalized) Edge"
        case .mute: "Double-Tap the Top-Right Corner"
        case .skip: "Flick Along the Bottom Edge"
        case nil: "That’s All There Is to It"
        }
    }

    private var detail: String {
        switch model.currentChallenge {
        case .volume:
            model.settings.gesture.requireModifier ? "Hold Fn or ⌥ while you slide. Volume follows your finger." : "Volume follows your finger."
        case .brightness: "Same move on the other side, for brightness."
        case .mute: "Two quick taps mute. Do it again to bring the sound back."
        case .skip: "With music playing, a quick flick skips the song. This one’s optional."
        case nil: "Every edge works. Just a couple of choices left."
        }
    }

    var body: some View {
        StepLayout(title: title, detail: detail) {
            LiveTrackpad(fingers: model.fingers, levels: model.levels, gesture: model.settings.gesture, hint: model.currentChallenge)
        } extra: {
            GlassGroup(spacing: 10) {
                HStack(spacing: 10) {
                    ForEach(model.challenges, id: \.self) { challenge in
                        ChallengeChip(challenge: challenge, isDone: model.completed.contains(challenge), isCurrent: challenge == model.currentChallenge)
                    }
                }
            }
            .padding(.top, 18)
        }
        .animation(.smooth, value: model.currentChallenge)
    }
}

private struct ChallengeChip: View {
    let challenge: OnboardingModel.Challenge
    let isDone: Bool
    let isCurrent: Bool

    private var label: String {
        switch challenge {
        case .volume: "Volume"
        case .brightness: "Brightness"
        case .mute: "Mute"
        case .skip: "Skip a Song"
        }
    }

    private var symbol: String {
        if isDone { return "checkmark.circle.fill" }
        if challenge == .skip { return "sparkle" }
        return isCurrent ? "circle.dotted" : "circle"
    }

    var body: some View {
        Label(label, systemImage: symbol)
            .font(.callout.weight(.medium))
            .foregroundStyle(isDone || isCurrent ? .primary : .secondary)
            .symbolRenderingMode(.hierarchical)
            .contentTransition(.symbolEffect(.replace))
            .rotatingSymbol(isActive: isCurrent && !isDone)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .liquidGlass(tint: isDone ? .accentColor.opacity(0.35) : nil, in: .capsule)
            .animation(.smooth, value: isDone)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(isDone ? "Done" : isCurrent ? "Next up" : "To do")
    }
}

// MARK: - Personalize

private struct PersonalizeStep: View {
    let model: OnboardingModel

    var body: some View {
        StepLayout(title: "Make It Yours", detail: "You can change these anytime from the menu bar.") {
            VStack(spacing: 0) {
                SettingRow(symbol: "hand.tap.fill", color: .orange, title: "Haptic feedback", caption: "Rest a finger on the trackpad to feel each one") {
                    GlassSegmentedPicker(
                        title: "Haptic feedback",
                        selection: Binding(get: { model.settings.haptics }, set: { model.chooseHaptics($0) }),
                        options: HapticStrength.allCases.map { ($0, $0.title) }
                    )
                }
                Divider().padding(.leading, 56)
                SettingRow(symbol: "arrow.left.arrow.right", color: .blue, title: "Volume side", caption: "Brightness takes the other edge") {
                    GlassSegmentedPicker(
                        title: "Volume side",
                        selection: Binding(get: { !model.settings.gesture.swapSides }, set: { model.chooseVolumeOnRight($0) }),
                        options: [(false, "Left"), (true, "Right")]
                    )
                }
                Divider().padding(.leading, 56)
                SettingRow(symbol: "power", color: .green, title: "Open at login", caption: "Ready whenever your Mac is") {
                    Toggle("Open at login", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }
            .padding(.vertical, 6)
            .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 16))
            .frame(width: 560)
        }
    }
}

/// A row like System Settings: a colored icon, a title and caption, and a control.
private struct SettingRow<Control: View>: View {
    let symbol: String
    let color: Color
    let title: String
    let caption: String
    @ViewBuilder var control: () -> Control

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(color.gradient, in: .rect(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.medium))
                Text(caption).font(.callout).foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            control()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

// MARK: - Finale

private struct FinaleStep: View {
    let model: OnboardingModel
    @State private var arrived = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        StepLayout(title: "You’re All Set", detail: "OpenEdgeBar lives in your menu bar. Slide an edge anytime.") {
            ZStack {
                LiveTrackpad(
                    fingers: [],
                    levels: arrived || reduceMotion ? Levels(brightness: 1, volume: 1, isMuted: false) : model.levels,
                    gesture: model.settings.gesture,
                    showsDetails: false
                )
                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 110, height: 110)
                    .liquidGlass(tint: .accentColor, in: .circle)
                    .scaleEffect(arrived || reduceMotion ? 1 : 0.3)
                    .opacity(arrived || reduceMotion ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.65).delay(0.25)) { arrived = true }
        }
    }
}
