import Foundation
import Observation
import SwiftData
import os

/// Drives the AI post-processing card on the transcript screen: generates a
/// title + summary from the transcript via Foundation Models and persists them
/// on the `Recording`. Gated on the `.ai` entitlement (unlock-only, no trial);
/// re-generating an already-summarized recording is free.
@MainActor
@Observable
final class AISummaryViewModel {
    enum Phase: Equatable {
        case idle, generating, done, failed
    }

    let recording: Recording
    private(set) var phase: Phase = .idle
    private(set) var availability: AIAvailability = .available
    var style: SummaryStyle = .summary
    var errorMessage: String?
    var showPaywall = false

    // Translation — persisted on the recording (restored on open).
    private(set) var isTranslating = false
    private(set) var translatedText: String?
    private(set) var translationLanguage: TranslationLanguage?

    private let service: any AISummarizing
    private let logger = Logger(subsystem: "de.gcng.sprechly.work", category: "AISummaryVM")
    private var modelContext: ModelContext?
    private var store: (any EntitlementProviding)?

    var isUnlocked: Bool { store?.isUnlocked(.ai) == true }
    var hasSummary: Bool { recording.summary?.isEmpty == false }
    var canApplyTitle: Bool {
        guard let aiTitle = recording.aiTitle, !aiTitle.isEmpty else { return false }
        return aiTitle != recording.title
    }
    var hasTranscript: Bool { !recording.segmentList.isEmpty }

    init(
        recording: Recording,
        service: any AISummarizing = AISummaryService()
    ) {
        self.recording = recording
        self.service = service
        // Restore a previously saved translation.
        translatedText = recording.translation
        translationLanguage = recording.translationLanguageCode.map { TranslationLanguage(code: $0) }
    }

    func configure(modelContext: ModelContext, store: any EntitlementProviding) {
        self.modelContext = modelContext
        self.store = store
    }

    func refreshAvailability() async {
        availability = await service.availability()
    }

    /// Concatenated transcript text, in time order.
    private var transcriptText: String {
        recording.segmentList
            .sorted { $0.startTime < $1.startTime }
            .map(\.text)
            .joined(separator: " ")
    }

    func generate() async {
        guard phase != .generating else { return }

        // Gate: unlock-only. Re-generating an existing summary is free.
        if recording.summary == nil && store?.isUnlocked(.ai) != true {
            showPaywall = true
            return
        }

        phase = .generating
        errorMessage = nil
        do {
            let insights = try await service.summarize(transcript: transcriptText, style: style)
            recording.aiTitle = insights.title
            recording.summary = insights.summary
            try modelContext?.save()
            phase = .done
        } catch {
            logger.error("Summary failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            phase = .failed
        }
    }

    /// Translates the transcript into `language` (premium, unlock-only).
    func translate(transcript: String, to language: TranslationLanguage) async {
        guard !isTranslating else { return }
        guard isUnlocked else { showPaywall = true; return }

        translationLanguage = language
        translatedText = nil
        isTranslating = true
        do {
            let result = try await service.translate(transcript, to: language.displayName)
            translatedText = result
            recording.translation = result
            recording.translationLanguageCode = language.code
            try modelContext?.save()
        } catch {
            logger.error("Translate failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
        isTranslating = false
    }

    /// Applies the AI-suggested title as the recording's user-facing title.
    func applyTitle() {
        guard let aiTitle = recording.aiTitle, !aiTitle.isEmpty else { return }
        recording.title = aiTitle
        do {
            try modelContext?.save()
        } catch {
            logger.error("Apply title failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }
}
