import Foundation

/// Type-safe navigation destinations for the app's `NavigationStack`.
enum AppRoute: Hashable {
    case library
    case editor(recordingID: UUID)
    case settings
}
