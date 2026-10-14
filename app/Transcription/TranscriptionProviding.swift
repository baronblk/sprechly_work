import Foundation

/// Protocol seam so view models depend on an abstraction, not the concrete
/// Speech-framework service — enabling state-machine tests without hardware
/// (SpeechAnalyzer/SpeechTranscriber run only on a real device; see §12).
protocol TranscriptionProviding: Sendable {
    /// Current on-device asset state for a locale.
    func assetState(for locale: Locale) async -> TranscriptionAssetState

    /// Downloads/installs the language model for a locale, emitting state
    /// updates (`.downloading(progress:)` … `.installed`/`.failed`).
    func installAssets(for locale: Locale) -> AsyncStream<TranscriptionAssetState>

    /// Transcribes the audio file, streaming drafts with timestamps. Throws on
    /// failure/cancellation so the caller keeps existing segments and the trial.
    func transcribe(fileAt url: URL, locale: Locale) -> AsyncThrowingStream<TranscriptDraft, Error>

    /// Transkribiert nur die ersten `seconds` der Datei – für die
    /// Spracherkennung, die dieselbe Datei mehrfach probiert.
    func transcribePrefix(fileAt url: URL, locale: Locale, seconds: TimeInterval) async throws -> String

    /// All locales the on-device transcriber supports (for the language picker).
    func supportedLocales() async -> [Locale]

    /// Locales whose model is already installed on this device.
    func installedLocales() async -> [Locale]
}

extension TranscriptionProviding {
    func supportedLocales() async -> [Locale] { TranscriptionLocale.supported }
    func installedLocales() async -> [Locale] { [] }

    /// Rückfallweg für Testdoubles: liest den regulären Strom nur bis zum
    /// Fenster. Die echte Implementierung liest stattdessen nur so viel Audio,
    /// damit kein Analyzer offen bleibt.
    func transcribePrefix(fileAt url: URL, locale: Locale, seconds: TimeInterval) async throws -> String {
        var parts: [String] = []
        for try await draft in transcribe(fileAt: url, locale: locale) {
            parts.append(draft.text)
            if draft.endTime >= seconds { break }
        }
        return parts.joined(separator: " ")
    }
}
