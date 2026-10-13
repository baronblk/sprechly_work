import SwiftUI

extension EntitlementProviding {
    /// Reusable gate for view models and services. Runs `action` when the
    /// entitlement is unlocked, otherwise invokes `onLocked` (e.g. present the
    /// paywall). The authoritative check lives here, not only in the UI — Phase 3
    /// attaches this to every AI entry point.
    func gate(
        _ entitlement: Entitlement,
        onLocked: () -> Void,
        action: () -> Void
    ) {
        if isUnlocked(entitlement) {
            action()
        } else {
            onLocked()
        }
    }
}

extension View {
    /// Declarative UI convenience: when the entitlement is locked, taps are
    /// routed to `onLocked` instead of activating the wrapped content. This is UI
    /// sugar only — business-critical gating must use `gate(_:onLocked:action:)`
    /// in the view model/service layer.
    func requiresEntitlement(
        _ entitlement: Entitlement,
        using provider: some EntitlementProviding,
        onLocked: @escaping () -> Void
    ) -> some View {
        modifier(
            RequiresEntitlementModifier(
                isUnlocked: provider.isUnlocked(entitlement),
                onLocked: onLocked
            )
        )
    }
}

private struct RequiresEntitlementModifier: ViewModifier {
    let isUnlocked: Bool
    let onLocked: () -> Void

    func body(content: Content) -> some View {
        content
            .allowsHitTesting(isUnlocked)
            .overlay {
                if !isUnlocked {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture(perform: onLocked)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel(Text("Gesperrt"))
                        .accessibilityHint(Text("Erfordert den VoxStudio-KI-Kauf"))
                }
            }
    }
}
