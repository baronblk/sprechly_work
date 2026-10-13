import SwiftUI

/// Prominent call-to-action: a gold fill with dark, high-contrast text. Replaces
/// `.borderedProminent` so the warm gold accent stays readable.
struct GoldProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Theme.Colors.onAccent)
            .padding(.vertical, Theme.Spacing.md)
            .padding(.horizontal, Theme.Spacing.lg)
            .background(Theme.Colors.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

extension ButtonStyle where Self == GoldProminentButtonStyle {
    static var goldProminent: GoldProminentButtonStyle { GoldProminentButtonStyle() }
}
