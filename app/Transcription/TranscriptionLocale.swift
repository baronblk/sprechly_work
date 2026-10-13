import Foundation

/// Supported transcription locales, **data-driven** (a list, not hardwired
/// branches) — adding a language later is one entry plus its asset download,
/// not a code change.
enum TranscriptionLocale {
    static let supported: [Locale] = [
        Locale(identifier: "de-DE"),
        Locale(identifier: "en-US")
    ]

    static func displayName(for locale: Locale) -> String {
        locale.localizedString(forIdentifier: locale.identifier)
            ?? locale.identifier
    }
}
