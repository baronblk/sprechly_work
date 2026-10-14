import Foundation
import Observation
import SwiftData
import os

/// Drives the transcript screen: runs transcription (streaming live drafts) and
/// persists the result as `TranscriptSegment`s **atomically** (delete old +
/// insert new in one transaction; an aborted run keeps the old segments).
@MainActor
@Observable
final class TranscriptionViewModel {
    enum Phase: Equatable {
        /// `preview` = a locked run that transcribed only the first
        /// `previewLimit` seconds and deliberately persisted nothing.
        /// `detecting` = probing which language is spoken, before the real run.
        case idle, detecting, transcribing, done, preview, failed
    }

    /// How much of a recording a locked user may transcribe. The paywall argues
    /// with the user's own audio instead of a feature list, so the value is
    /// visible before the purchase — but the result is never persisted,
    /// exportable or usable for AI.
    static let previewLimit: TimeInterval = 30

    let recording: Recording
    private(set) var installedLocales: [Locale] = []
    var locale: Locale
    private(set) var liveDrafts: [TranscriptDraft] = []
    private(set) var phase: Phase = .idle
    /// Gesetzt, wenn die Spracherkennung die Sprache gewechselt hat – damit der
    /// Wechsel in der Ansicht sichtbar ist und nicht wie Zauberei wirkt.
    private(set) var detectedLocale: Locale?
    var errorMessage: String?
    var showPaywall = false

    /// Persisted segments, sorted; what the view shows when not transcribing.
    var segments: [TranscriptSegment] {
        recording.segmentList.sorted { $0.startTime < $1.startTime }
    }

    var hasInstalledLocale: Bool { !installedLocales.isEmpty }

    private let service: any TranscriptionProviding
    private let fileStore: RecordingFileStore
    private let logger = Logger(subsystem: "de.gcng.sprechly.work", category: "TranscriptionVM")
    private var modelContext: ModelContext?
    private var store: (any EntitlementProviding)?

    /// Whether transcription is unlocked (premium). Drives the crown marker.
    var isUnlocked: Bool { store?.isUnlocked(.ai) == true }

    init(
        recording: Recording,
        service: any TranscriptionProviding = SpeechTranscriptionService(),
        fileStore: RecordingFileStore = RecordingFileStore()
    ) {
        self.recording = recording
        self.service = service
        self.fileStore = fileStore
        self.locale = TranscriptionLocale.supported.first ?? Locale(identifier: "en-US")
    }

    func configure(modelContext: ModelContext, store: any EntitlementProviding) {
        self.modelContext = modelContext
        self.store = store
    }

    /// Loads which locales are actually installed (same source as the language
    /// model manager) and picks a sensible default.
    func loadInstalledLocales() async {
        let installed = await service.installedLocales()
            .sorted {
                TranscriptionLocale.displayName(for: $0)
                    .localizedCaseInsensitiveCompare(TranscriptionLocale.displayName(for: $1)) == .orderedAscending
            }
        installedLocales = installed
        if let preferred = Self.defaultLocale(
            installed: installed,
            remembered: recording.transcriptionLanguage
        ) {
            locale = preferred
        }
    }

    func transcribe() async {
        guard phase != .transcribing, phase != .detecting else { return }

        // Nur beim ersten Lauf: hat die Aufnahme schon eine Sprache, ist das
        // die des Nutzers und wird nicht hinterfragt.
        if recording.transcriptionLanguage == nil {
            await detectLanguage()
        }

        // Locked users get a preview of the first `previewLimit` seconds: the
        // result is shown but never persisted, so it cannot be exported, fed to
        // the AI layer or kept. Unlocked users transcribe the whole file.
        let isPreviewRun = !isUnlocked

        phase = .transcribing
        liveDrafts = []
        errorMessage = nil

        do {
            for try await draft in service.transcribe(fileAt: audioURL, locale: locale) {
                liveDrafts.append(draft)
                // Stop pulling from the stream once the preview window is full;
                // breaking terminates the underlying transcription task.
                if isPreviewRun, draft.endTime >= Self.previewLimit { break }
            }
            if isPreviewRun {
                phase = .preview
            } else {
                try persistAtomically(liveDrafts)
                phase = .done
            }
        } catch {
            logger.error("Transcription failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            phase = .failed
            liveDrafts = [] // old persisted segments remain untouched
        }
    }

    /// True while showing an unpurchased preview result.
    var isShowingPreview: Bool { phase == .preview && !liveDrafts.isEmpty }

    /// Whether the preview actually cut the recording short — drives the
    /// "there is more" message. A recording shorter than the window is shown in
    /// full (still unpersisted), which is the hook, not a leak.
    var isPreviewTruncated: Bool {
        guard isShowingPreview else { return false }
        return recording.duration > Self.previewLimit
    }

    /// The preview text, handed to the paywall so it can argue with the user's
    /// own words rather than a canned example.
    var previewText: String? {
        guard isShowingPreview else { return nil }
        let text = liveDrafts.map(\.text).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private var audioURL: URL { fileStore.audioURL(forFileName: recording.fileName) }

    /// Writes the transcript to a shareable file (TXT/Markdown) and returns its
    /// URL. Gated on `.ai` and on **persisted** segments, so a locked preview
    /// (which is never persisted) can not be exported. Nil when locked or empty.
    func exportFile(
        _ format: TranscriptExportFormat,
        translation: String? = nil,
        translationLanguage: String? = nil
    ) -> URL? {
        guard store?.isUnlocked(.ai) == true, !recording.segmentList.isEmpty else { return nil }
        let segments = recording.segmentList.map {
            TranscriptExporter.Segment(text: $0.text, startTime: $0.startTime)
        }
        let title = (recording.aiTitle?.isEmpty == false) ? recording.aiTitle! : recording.title
        do {
            return try TranscriptExporter().write(
                title: title,
                summary: recording.summary,
                translation: translation,
                translationLanguage: translationLanguage,
                date: recording.createdAt,
                duration: recording.duration,
                segments: segments,
                format: format,
                to: FileManager.default.temporaryDirectory
            )
        } catch {
            logger.error("Transcript export failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Probiert die aussichtsreichsten Sprachen auf dem Anfang der Aufnahme und
    /// übernimmt die Sprache, die sich selbst bestätigt (siehe
    /// `LanguageDetection`).
    ///
    /// Gibt es nur eine installierte Sprache, gibt es nichts zu entscheiden –
    /// dann wird nichts probiert. Schlägt eine Probe fehl, zählt sie einfach
    /// nicht mit; die Erkennung darf den Lauf nie verhindern.
    func detectLanguage() async {
        let candidates = LanguageDetection.candidates(installed: installedLocales)
        guard candidates.count > 1 else { return }

        phase = .detecting
        var probes: [LanguageDetection.Probe] = []
        for candidate in candidates {
            guard let text = await probeText(locale: candidate) else { continue }
            probes.append(LanguageDetection.Probe(locale: candidate, text: text))
        }

        guard let detected = LanguageDetection.pick(from: probes) else {
            logger.info("Spracherkennung unentschieden, bleibe bei \(self.locale.identifier, privacy: .public)")
            return
        }
        if detected != locale {
            logger.info("Sprache erkannt: \(detected.identifier, privacy: .public)")
            locale = detected
            detectedLocale = detected
        }
    }

    /// Transkribiert nur den Anfang der Aufnahme und gibt den Text zurück.
    ///
    /// Bewusst über `transcribePrefix` und nicht über einen abgebrochenen
    /// `transcribe`-Strom: Der Lauf muss fertig abgebaut sein, bevor die
    /// nächste Sprache probiert wird.
    private func probeText(locale: Locale) async -> String? {
        do {
            let text = try await service.transcribePrefix(
                fileAt: audioURL,
                locale: locale,
                seconds: LanguageDetection.probeWindow
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            logger.error("Sprachprobe \(locale.identifier, privacy: .public) fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Replaces all segments in one transaction; rolls back on failure so the
    /// recording is never left half old / half new.
    private func persistAtomically(_ drafts: [TranscriptDraft]) throws {
        guard let modelContext else { return }
        for old in recording.segmentList { modelContext.delete(old) }
        // Zur Transaktion gehört auch, in welcher Sprache die Segmente
        // entstanden sind – sonst rät der nächste Lauf wieder.
        recording.transcriptionLanguage = locale.identifier
        for draft in drafts {
            modelContext.insert(TranscriptSegment(
                text: draft.text, startTime: draft.startTime, endTime: draft.endTime, recording: recording
            ))
        }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    /// Picks the locale for this recording.
    ///
    /// A recording that was transcribed before keeps **its** language: re-running
    /// it must not silently switch to the device language, or a German transcript
    /// would come back as English on an English phone. An exact identifier wins;
    /// otherwise the same language in another region (remembered `de-DE`, only
    /// `de-AT` installed) still counts. Only without a remembered language do the
    /// device's preferred languages decide, then the first installed one.
    ///
    /// Uses `Locale.preferredLanguages` — the device's language settings — not
    /// `Locale.current`, which reflects the app's (currently en-only) localization.
    static func defaultLocale(
        installed: [Locale],
        preferred: [String] = Locale.preferredLanguages,
        remembered: String? = nil
    ) -> Locale? {
        if let remembered {
            if let exact = installed.first(where: { $0.identifier == remembered }) {
                return exact
            }
            let code = Locale(identifier: remembered).language.languageCode
            if let sameLanguage = installed.first(where: { $0.language.languageCode == code }) {
                return sameLanguage
            }
        }
        for language in preferred {
            let code = Locale(identifier: language).language.languageCode
            if let match = installed.first(where: { $0.language.languageCode == code }) {
                return match
            }
        }
        return installed.first
    }
}
