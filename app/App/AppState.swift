import Observation

/// App-wide observable state, provided through the SwiftUI environment.
@MainActor
@Observable
final class AppState {
    /// Single source of truth for in-app purchase entitlements.
    let store: StoreManager

    /// App-wide CloudKit sync status for the iCloud settings.
    let syncMonitor = CloudSyncMonitor()

    /// Decides when to ask for an App Store rating (after positive moments).
    let rating = RatingPromptController()

    /// Navigation path for the root `NavigationStack`.
    var path: [AppRoute] = []

    init(store: StoreManager) {
        self.store = store
    }
}
