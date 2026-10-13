import SwiftUI

/// A small pill (icon + text) for status markers like "Transkript" or "KI".
struct Badge: View {
    let systemName: String
    let title: LocalizedStringKey
    var tint: Color = Theme.Colors.accent

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: systemName)
            Text(title)
        }
        .font(Theme.Font.badge)
        .foregroundStyle(tint)
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 3)
        .background(Theme.Colors.accentSoft, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
    }
}
