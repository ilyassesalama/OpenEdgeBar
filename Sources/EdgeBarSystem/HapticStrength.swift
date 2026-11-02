public enum HapticStrength: String, CaseIterable, Sendable {
    case off
    case light
    case medium
    case strong

    public var title: String {
        switch self {
        case .off: "Off"
        case .light: "Light"
        case .medium: "Medium"
        case .strong: "Strong"
        }
    }
}
