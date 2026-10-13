import Foundation

/// Structured, user-facing errors for the monetization layer.
enum StoreError: Error, LocalizedError, Equatable {
    case productUnavailable(String)
    case failedVerification
    case syncFailed

    var errorDescription: String? {
        switch self {
        case .productUnavailable(let id):
            return String(localized: "Das Produkt „\(id)“ ist derzeit nicht verfügbar.")
        case .failedVerification:
            return String(localized: "Der Kauf konnte nicht verifiziert werden.")
        case .syncFailed:
            return String(localized: "Käufe konnten nicht mit dem App Store synchronisiert werden.")
        }
    }
}
