import SwiftUI

/// Height of the app's own bottom tab bar, published by `RootView`.
///
/// The tab bar is a `safeAreaInset`, which SwiftUI propagates to most of the
/// hierarchy — but **not** into a `NavigationSplitView`'s detail column, where
/// content ends up scrolling underneath the bar and the last lines can never be
/// read. Screens hosted in that column read this value and pad themselves.
/// It is `0` wherever no tab bar is shown (iPad regular width uses the sidebar),
/// so applying it is always safe.
private struct TabBarHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var tabBarHeight: CGFloat {
        get { self[TabBarHeightKey.self] }
        set { self[TabBarHeightKey.self] = newValue }
    }
}
