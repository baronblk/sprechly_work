import Foundation
import Observation
import os

/// Decides *when* to ask for an App Store rating; the root view turns the
/// `pendingRequest` flag into StoreKit's `requestReview`. The ask is raised only
/// after a few **positive, completed** moments (a successful transcription or AI
/// result) and at most **once per app version**. Apple additionally throttles to
/// ~3 prompts per year, so this stays well within good taste. Decision logic is
/// kept here (pure, injectable) so it can be unit-tested without StoreKit.
@MainActor
@Observable
final class RatingPromptController {
    /// Raised when the criteria are met; the root view consumes it (calls
    /// `requestReview`) and resets it via `consume()`.
    private(set) var pendingRequest = false

    /// Positive moments required before an ask (per version).
    private let threshold: Int
    private let appVersion: String
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "de.gcng.sprechly.work", category: "Rating")

    private enum Key {
        static let delightCount = "rating.delightCount"
        static let lastPromptedVersion = "rating.lastPromptedVersion"
    }

    init(
        defaults: UserDefaults = .standard,
        appVersion: String = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0",
        threshold: Int = 3
    ) {
        self.defaults = defaults
        self.appVersion = appVersion
        self.threshold = threshold
    }

    /// Call after a positive, completed action (successful transcription / AI
    /// result). **Never** call after an error, a paywall, or mid-task. When the
    /// per-version threshold is reached, raises `pendingRequest`.
    func registerDelight() {
        // One ask per version: once prompted on this version, stay silent until
        // the next update.
        guard defaults.string(forKey: Key.lastPromptedVersion) != appVersion else { return }

        let count = defaults.integer(forKey: Key.delightCount) + 1
        defaults.set(count, forKey: Key.delightCount)
        guard count >= threshold else { return }

        // Mark this version as asked and reset the counter, so the next version
        // requires fresh engagement (no nagging right after an update).
        defaults.set(appVersion, forKey: Key.lastPromptedVersion)
        defaults.set(0, forKey: Key.delightCount)
        pendingRequest = true
        logger.info("Rating prompt eligible on version \(self.appVersion, privacy: .public)")
    }

    /// The root view calls this immediately after invoking `requestReview`.
    func consume() { pendingRequest = false }
}
