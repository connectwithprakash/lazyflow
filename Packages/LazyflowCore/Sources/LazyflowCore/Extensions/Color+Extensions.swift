import SwiftUI

extension Color {
    /// Initialize Color from hex string (e.g., "#218A8D" or "218A8D")
    public init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let length = hexSanitized.count

        switch length {
        case 6:
            self.init(
                red: Double((rgb & 0xFF0000) >> 16) / 255.0,
                green: Double((rgb & 0x00FF00) >> 8) / 255.0,
                blue: Double(rgb & 0x0000FF) / 255.0
            )
        case 8:
            self.init(
                red: Double((rgb & 0xFF000000) >> 24) / 255.0,
                green: Double((rgb & 0x00FF0000) >> 16) / 255.0,
                blue: Double((rgb & 0x0000FF00) >> 8) / 255.0,
                opacity: Double(rgb & 0x000000FF) / 255.0
            )
        default:
            return nil
        }
    }

    /// Convert Color to hex string
    public func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components else { return nil }

        let r = components[0]
        let g = components.count > 1 ? components[1] : r
        let b = components.count > 2 ? components[2] : r

        return String(format: "#%02X%02X%02X",
                      Int(r * 255),
                      Int(g * 255),
                      Int(b * 255))
    }
}

// MARK: - App Colors

extension Color {
    /// Lazyflow app color palette
    public struct Lazyflow {
        // Primary
        public static let accent = Color(hex: "#218A8D")!
        public static let accentLight = Color(hex: "#2BA5A8")!
        public static let accentDark = Color(hex: "#1A6F71")!

        // Backgrounds
        public static let backgroundLight = Color(hex: "#F5F5F5")!
        public static let backgroundDark = Color(hex: "#1F2121")!

        // Surfaces
        public static let surfaceLight = Color.white
        public static let surfaceDark = Color(hex: "#272A2A")!

        // Text
        public static let textPrimary = Color.primary
        public static let textSecondary = Color.secondary
        public static let textTertiary = Color(hex: "#5A6C71")!

        // Semantic
        public static let success = Color(hex: "#22C876")!
        public static let error = Color(hex: "#FF5459")!
        public static let warning = Color(hex: "#E68157")!
        public static let info = Color(hex: "#5A6C71")!

        // Priority colors
        public static let priorityUrgent = Color(hex: "#FF5459")!
        public static let priorityHigh = Color(hex: "#E68157")!
        public static let priorityMedium = Color(hex: "#FFB800")!
        public static let priorityLow = Color(hex: "#007AFF")!
        public static let priorityNone = Color(hex: "#5A6C71")!
    }
}

// MARK: - Adaptive Colors

#if os(iOS)
extension Color {
    /// Adaptive background color based on color scheme
    public static var adaptiveBackground: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(Color.Lazyflow.backgroundDark)
                : UIColor(Color.Lazyflow.backgroundLight)
        })
    }

    /// Adaptive surface color based on color scheme
    public static var adaptiveSurface: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(Color.Lazyflow.surfaceDark)
                : UIColor(Color.Lazyflow.surfaceLight)
        })
    }
}
#else
extension Color {
    public static var adaptiveBackground: Color {
        Color.Lazyflow.backgroundLight
    }

    public static var adaptiveSurface: Color {
        Color.Lazyflow.surfaceLight
    }
}
#endif
