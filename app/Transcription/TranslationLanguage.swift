import Foundation

/// A curated target language for transcript translation. The Translation
/// framework downloads the language pack on first use; everything stays
/// on-device.
struct TranslationLanguage: Identifiable, Hashable, Sendable {
    let code: String
    var id: String { code }
    var displayName: String {
        Locale.current.localizedString(forLanguageCode: code)?.capitalized ?? code.uppercased()
    }
    var language: Locale.Language { Locale.Language(identifier: code) }

    static let common: [TranslationLanguage] = [
        "en", "de", "fr", "es", "it", "pt", "nl", "pl", "tr", "ru", "uk", "zh", "ja", "ko", "ar"
    ].map { TranslationLanguage(code: $0) }
}
