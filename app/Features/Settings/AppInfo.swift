import Foundation

/// App metadata read from the bundle. The formatting is split into a pure
/// function so it can be unit-tested without a bundle.
enum AppInfo {
    static var displayName: String {
        (Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String)
            ?? (Bundle.main.infoDictionary?["CFBundleName"] as? String)
            ?? "Sprechly"
    }

    static var versionString: String {
        format(
            short: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            build: Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        )
    }

    /// This app's Apple ID (see `STORE_LISTING.md`). Used to build store links.
    static let appStoreID = "6782676748"

    /// Deep link that opens the App Store page with the review sheet already up.
    static var reviewURL: URL? { storeURL(action: "write-review") }

    /// Builds an App Store URL for this app; `action` is appended as a query
    /// item when given (`write-review` opens the rating sheet directly).
    static func storeURL(action: String? = nil) -> URL? {
        var components = URLComponents(string: "https://apps.apple.com/app/id\(appStoreID)")
        if let action {
            components?.queryItems = [URLQueryItem(name: "action", value: action)]
        }
        return components?.url
    }

    /// Renders a `1.2.3 (45)` version string, gracefully handling missing parts.
    static func format(short: String?, build: String?) -> String {
        let version = short.flatMap { $0.isEmpty ? nil : $0 } ?? "—"
        guard let build, !build.isEmpty else { return version }
        return "\(version) (\(build))"
    }
}
