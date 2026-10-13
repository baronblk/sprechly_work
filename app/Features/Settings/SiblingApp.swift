import Foundation

/// Links to the developer's other apps, shown as a quiet entry in Settings.
///
/// **WhisperScribe Pro (macOS)** is the sibling product for people who would
/// rather transcribe on a Mac. The id comes from the App Store Connect release
/// mail for version 1.3.1+14 (2026-06-16); the app is currently not listed in
/// the visible ASC app overview, which is unexplained but is no reason to
/// substitute a different id.
enum SiblingApp {
    /// WhisperScribe Pro for macOS.
    static let whisperScribeProID = "6761129645"

    /// Mac App Store link for WhisperScribe Pro.
    static var whisperScribeProURL: URL? {
        URL(string: "https://apps.apple.com/app/whisperscribe-pro/id\(whisperScribeProID)")
    }
}
