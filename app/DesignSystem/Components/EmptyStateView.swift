import SwiftUI

/// A warm, branded empty/placeholder state: a gold glyph in a soft disc, a
/// title, an optional message, and an optional primary action. Replaces bare
/// `ContentUnavailableView` so empty screens match the app's premium feel.
struct EmptyStateView: View {
    let systemName: String
    let title: LocalizedStringKey
    var message: LocalizedStringKey?
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.accentSoft)
                    .frame(width: 96, height: 96)
                Image(systemName: systemName)
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(Theme.Colors.accent)
            }
            .accessibilityHidden(true)

            VStack(spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(Theme.Font.screenTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                if let message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.md)
                }
            }

            if let actionTitle, let action {
                Button {
                    Haptics.impact(.light)
                    action()
                } label: {
                    Text(actionTitle).frame(maxWidth: 280)
                }
                .buttonStyle(.goldProminent)
                .controlSize(.large)
                .padding(.top, Theme.Spacing.xs)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
