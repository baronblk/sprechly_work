import SwiftUI

/// A circular icon button used across the transport controls.
struct CircleIconButton: View {
    let systemName: String
    var tint: Color = Theme.Colors.textPrimary
    var background: Color = Theme.Colors.surfaceElevated
    var diameter: CGFloat = 64
    var accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: diameter * 0.4, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(background))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel))
    }
}
