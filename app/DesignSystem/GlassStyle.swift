import SwiftUI

extension View {
    /// Applies a Liquid Glass panel for floating overlay controls (iOS 26),
    /// falling back to a material on older systems. Use **after** layout
    /// modifiers, per the design rules.
    @ViewBuilder
    func glassPanel(cornerRadius: CGFloat = Theme.Radius.lg) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

/// A soft accent glow behind hero content for depth (dark-first).
struct DepthGlow: View {
    var color: Color = Theme.Colors.accent

    var body: some View {
        RadialGradient(
            colors: [color.opacity(0.28), color.opacity(0.06), .clear],
            center: .center,
            startRadius: 0,
            endRadius: 320
        )
        .blur(radius: 40)
        .allowsHitTesting(false)
    }
}
