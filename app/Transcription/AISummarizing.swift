import Foundation

/// Why the on-device language model cannot be used right now. Mirrors
/// `SystemLanguageModel.Availability` so the UI can show a precise hint without
/// importing FoundationModels.
enum AIAvailability: Equatable, Sendable {
    case available
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case unknown
}

/// Errors surfaced by the AI summary layer. No crashes — every failure maps to a
/// defined, user-presentable case.
enum AISummaryError: Error, LocalizedError, Equatable {
    case unavailable(AIAvailability)
    case emptyTranscript
    /// Apple's on-device safety filter flagged the input or output. Triggers
    /// false positives on medical/sensitive topics — nothing we can override.
    case contentFlagged
    case tooLong
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(.deviceNotEligible):
            return String(localized: "Dieses Gerät unterstützt die KI-Funktionen nicht.")
        case .unavailable(.appleIntelligenceNotEnabled):
            return String(localized: "Aktiviere Apple Intelligence in den Einstellungen, um die KI-Zusammenfassung zu nutzen.")
        case .unavailable(.modelNotReady):
            return String(localized: "Das KI-Modell wird noch vorbereitet. Bitte versuche es später erneut.")
        case .unavailable:
            return String(localized: "Die KI-Funktionen sind derzeit nicht verfügbar.")
        case .emptyTranscript:
            return String(localized: "Es gibt keinen Transkript-Text zum Zusammenfassen.")
        case .contentFlagged:
            return String(localized: "Apples KI-Sicherheitsfilter hat diesen Inhalt abgelehnt. Bei medizinischen oder sensiblen Themen passiert das leider manchmal. Transkript und Export funktionieren weiterhin.")
        case .tooLong:
            return String(localized: "Der Text ist zu lang für die KI-Verarbeitung.")
        case .generationFailed(let message):
            return message
        }
    }
}

/// Generates AI insights from a transcript. Behind a protocol so the view model
/// is testable without the real on-device model (which runs only on device).
protocol AISummarizing: Sendable {
    func availability() async -> AIAvailability
    func summarize(transcript: String, style: SummaryStyle) async throws -> RecordingInsights
    /// Translates `text` into `language` (a localized language name).
    func translate(_ text: String, to language: String) async throws -> String
}
