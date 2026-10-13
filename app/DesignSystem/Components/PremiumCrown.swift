import SwiftUI

/// A small gold crown marking a premium (purchase-required) feature. Features
/// stay visible and inviting — tapping a locked one opens the paywall rather
/// than being hidden.
struct PremiumCrown: View {
    var body: some View {
        Image(systemName: "crown.fill")
            .font(.caption2)
            .foregroundStyle(Theme.Colors.premium)
            .accessibilityLabel(Text("Premium"))
    }
}
