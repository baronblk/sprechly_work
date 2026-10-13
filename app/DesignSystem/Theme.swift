import SwiftUI

/// Semantic design tokens. Dark-first; values are intentionally referenced
/// through semantic names so a light theme can be added later without touching
/// call sites.
enum Theme {
    enum Colors {
        // Warm, gold-on-dark palette matching the vintage-microphone icon.
        static let background = Color(red: 0.07, green: 0.06, blue: 0.05)
        static let surface = Color(red: 0.12, green: 0.11, blue: 0.09)
        static let surfaceElevated = Color(red: 0.18, green: 0.16, blue: 0.12)
        static let accent = Color(red: 0.89, green: 0.70, blue: 0.33)
        /// Tinted fill for badges and soft accents.
        static let accentSoft = Color(red: 0.89, green: 0.70, blue: 0.33).opacity(0.18)
        static let textPrimary = Color.white
        static let textSecondary = Color.white.opacity(0.65)
        static let destructive = Color(red: 1.0, green: 0.36, blue: 0.30)
        static let success = Color(red: 0.40, green: 0.78, blue: 0.45)
        /// Brighter gold marking premium (purchase-required) features.
        static let premium = Color(red: 1.0, green: 0.82, blue: 0.38)
        /// High-contrast label color for filled accent (gold) buttons.
        static let onAccent = Color(red: 0.12, green: 0.09, blue: 0.04)
    }

    /// Semantic fonts. Rounded design throughout for a cohesive, premium feel
    /// (matches the recording timer). All map to system text styles, so Dynamic
    /// Type keeps working.
    enum Font {
        static let screenTitle = SwiftUI.Font.system(.title2, design: .rounded).weight(.semibold)
        static let rowTitle = SwiftUI.Font.system(.headline, design: .rounded)
        static let cardTitle = SwiftUI.Font.system(.headline, design: .rounded)
        static let badge = SwiftUI.Font.system(.caption2, design: .rounded).weight(.semibold)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 20
    }
}

extension View {
    /// Wraps content in an elevated, rounded surface — the standard card look.
    func cardSurface(padding: CGFloat = Theme.Spacing.md) -> some View {
        self
            .padding(padding)
            .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
    }
}
