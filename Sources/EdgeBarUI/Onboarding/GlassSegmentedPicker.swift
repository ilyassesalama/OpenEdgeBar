import SwiftUI

/// A segmented control in Liquid Glass, matching the trackpad picture: the options sit in a
/// shallow recess and the selection is a tinted glass lens that slides between them.
struct GlassSegmentedPicker<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [(value: Value, label: String)]

    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.value) { option in
                segment(option.value, label: option.label)
            }
        }
        .padding(3)
        .fixedSize()
        .background(.primary.opacity(0.06), in: .capsule)
        .overlay(Capsule().strokeBorder(.primary.opacity(0.08), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    private func segment(_ value: Value, label: String) -> some View {
        let isSelected = value == selection
        return Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.72)) {
                selection = value
            }
        } label: {
            Text(label)
                .font(.body.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 14)
                .frame(height: 30)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(.clear)
                            .liquidGlass(tint: .accentColor, interactive: true, in: .capsule)
                            .matchedGeometryEffect(id: "selection", in: namespace)
                    }
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
