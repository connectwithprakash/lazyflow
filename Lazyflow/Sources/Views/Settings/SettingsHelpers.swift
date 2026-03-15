import SwiftUI
import LazyflowCore

// MARK: - Appearance Mode

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Shared Utilities

/// Formats an hour integer (e.g. 9) into a localized time string (e.g. "9:00 AM").
func formatHour(_ hour: Int) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:00 a"
    var components = DateComponents()
    components.hour = hour
    if let date = Calendar.current.date(from: components) {
        return formatter.string(from: date)
    }
    return "\(hour):00"
}

/// App version string from bundle info (e.g. "1.8 (42)").
var appVersion: String {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    return "\(version) (\(build))"
}

// MARK: - Settings Form Width

struct SettingsFormWidth: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: horizontalSizeClass == .regular ? 700 : .infinity)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    func settingsFormWidth() -> some View {
        modifier(SettingsFormWidth())
    }
}
