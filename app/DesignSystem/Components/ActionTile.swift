import SwiftUI

/// A labeled, tappable tile (icon over text) for surfacing primary actions
/// directly instead of hiding them behind an overflow menu.
struct ActionTile: View {
    let systemName: String
    let title: LocalizedStringKey
    var tint: Color = Theme.Colors.accent
    var premium: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Spacing.xs) {
                Image(systemName: systemName)
                    .font(.title3)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            .foregroundStyle(tint)
            .overlay(alignment: .topTrailing) {
                if premium {
                    PremiumCrown().padding(Theme.Spacing.sm)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityValue(premium ? Text("Premium") : Text(verbatim: ""))
    }
}
