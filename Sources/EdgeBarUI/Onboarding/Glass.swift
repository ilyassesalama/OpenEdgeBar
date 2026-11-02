import SwiftUI

// Liquid Glass on macOS 26 and later. Earlier versions get the frosted material of their own
// era in the same shape and tint, so the layout and colors stay the same.

extension View {
    /// Liquid Glass behind this view, in `shape`.
    @ViewBuilder
    func liquidGlass(tint: Color? = nil, interactive: Bool = false, in shape: some Shape) -> some View {
        if #available(macOS 26, *) {
            glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
        } else {
            background {
                ZStack {
                    shape.fill(.regularMaterial)
                    if let tint {
                        shape.fill(tint)
                    }
                    shape.stroke(.white.opacity(0.18), lineWidth: 1)
                }
            }
        }
    }

    /// The glass button style, or the bordered style of its era.
    @ViewBuilder
    func glassButtonStyle(prominent: Bool = false) -> some View {
        if #available(macOS 26, *) {
            if prominent {
                buttonStyle(.glassProminent)
            } else {
                buttonStyle(.glass)
            }
        } else {
            if prominent {
                buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
            } else {
                buttonStyle(.bordered).buttonBorderShape(.capsule)
            }
        }
    }

    /// The symbol turns while `isActive`. Before macOS 15, which added the effect, it pulses.
    @ViewBuilder
    func rotatingSymbol(isActive: Bool) -> some View {
        if #available(macOS 15, *) {
            symbolEffect(.rotate, isActive: isActive)
        } else {
            symbolEffect(.pulse, isActive: isActive)
        }
    }
}

/// Lets nearby glass shapes blend and morph together. Before macOS 26 it only groups them.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}
