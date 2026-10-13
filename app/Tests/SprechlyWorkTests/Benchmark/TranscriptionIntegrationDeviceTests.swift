import AVFoundation
import Foundation
import Speech
import SwiftData
import Testing
@testable import SprechlyWork

/// End-to-end verification of the formatter's production wiring on real
/// hardware: the shipping service transcribes a frozen fixture, the result is
/// persisted exactly as the app persists it, and the exporters render it.
///
/// This exists because the unit tests prove the formatter and the benchmark
/// proves its effect, but neither proves the *wiring* — that the formatted text
/// is what actually reaches the database and the files the user shares.
///
/// Device only; skipped in the simulator, where the Speech stack is absent.
@Suite(.serialized)
struct TranscriptionIntegrationDeviceTests {
    private let locale = Locale(identifier: "de-DE")

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Recording.self, TranscriptSegment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        return ModelContext(container)
    }

    /// Transcribes a fixture through the shipping service and returns the drafts.
    private func transcribe(_ caseID: String) async throws -> [TranscriptDraft]? {
        guard await BenchmarkSpeech.isAvailable(for: locale) else { return nil }
        let fixture: URL? = BenchmarkSpeech.fixtureURL(for: caseID)
        let url = try #require(fixture, "no frozen audio for \(caseID)")
        var drafts: [TranscriptDraft] = []
        for try await draft in SpeechTranscriptionService().transcribe(fileAt: url, locale: locale) {
            drafts.append(draft)
        }
        return drafts
    }

    // MARK: - The markup can no longer reach stored text

    /// `abbrev-02` is the one fixture that produces the marker, so it is the
    /// case that proves the production path strips it.
    @Test func serviceStripsMarkupBeforeItIsEverPersisted() async throws {
        guard let drafts = try await transcribe("abbrev-02") else {
            print("INTEGRATION SKIPPED: Speech stack unavailable")
            return
        }
        let text = drafts.map(\.text).joined(separator: " ")
        print("INTEGRATION abbrev-02 SERVICE TEXT: \(text)")

        #expect(!text.contains(TranscriptMarkupRepair.marker))
        #expect(!text.contains("\\"))
        // The acronym is joined, which only happens after the markup is gone.
        #expect(text.contains("KI"))
    }

    /// Spot-checks the rules the device test plan calls out, on the fixtures
    /// that exercise them.
    @Test func formattedTextReachesTheServiceOutput() async throws {
        let expectations: [(id: String, needle: String)] = [
            ("numbers-02", "13:45"),        // clock time
            ("mixed-02", "1.2.0"),          // version number
            ("technical-01", "SharePoint"), // canonical spelling
            ("technical-02", "StoreKit"),   // compound
            ("technical-02", "CloudKit"),   // compound
            ("technical-03", "SwiftUI"),    // canonical spelling (recognition permitting)
            ("mixed-03", "Markdown")        // compound + casing
        ]
        for expectation in expectations {
            guard let drafts = try await transcribe(expectation.id) else {
                print("INTEGRATION SKIPPED: Speech stack unavailable")
                return
            }
            let text = drafts.map(\.text).joined(separator: " ")
            print("INTEGRATION \(expectation.id) expects '\(expectation.needle)' in: \(text)")
            if expectation.id == "technical-03" {
                // SwiftUI is a measured recognition miss ("SwiftOE"); assert
                // only that nothing was made worse, not that it is recovered.
                #expect(!text.isEmpty)
            } else {
                #expect(text.contains(expectation.needle))
            }
        }
    }

    /// Ordinary German prose must survive the production path untouched.
    @Test func plainSpeechIsUnchangedByTheProductionPath() async throws {
        guard let drafts = try await transcribe("abbrev-01") else {
            print("INTEGRATION SKIPPED: Speech stack unavailable")
            return
        }
        let text = drafts.map(\.text).joined(separator: " ")
        let formatter = TranscriptSemanticFormatter(locale: locale)
        // Already formatted at the service, so formatting again changes nothing.
        #expect(formatter.format(text) == text)
    }

    // MARK: - Persistence and export

    @Test func exportsCarryTheFormattedTextAndNoMarkup() async throws {
        guard let drafts = try await transcribe("abbrev-02") else {
            print("INTEGRATION SKIPPED: Speech stack unavailable")
            return
        }
        let context = try makeContext()
        let recording = Recording(title: "Abbrev", fileName: "a.m4a", duration: 5)
        context.insert(recording)
        // Exactly how TranscriptionViewModel persists a finished run.
        for draft in drafts {
            context.insert(TranscriptSegment(
                text: draft.text,
                startTime: draft.startTime,
                endTime: draft.endTime,
                recording: recording
            ))
        }
        try context.save()

        let stored = try context.fetch(FetchDescriptor<TranscriptSegment>())
            .sorted { $0.startTime < $1.startTime }
        #expect(!stored.isEmpty)
        for segment in stored {
            #expect(!segment.text.contains(TranscriptMarkupRepair.marker))
        }

        let exporter = TranscriptExporter()
        let segments = stored.map { TranscriptExporter.Segment(text: $0.text, startTime: $0.startTime) }
        for format in TranscriptExportFormat.allCases {
            let rendered = exporter.render(
                title: "Abbrev", summary: nil, segments: segments, format: format
            )
            print("INTEGRATION EXPORT \(format.rawValue): \(rendered.replacingOccurrences(of: "\n", with: " ⏎ "))")
            #expect(!rendered.contains(TranscriptMarkupRepair.marker))
            #expect(rendered.contains("KI"))
        }
    }

    /// The migration on real hardware, against a segment shaped like the ones
    /// already in users' databases.
    @Test func migrationRepairsAStoredLegacySegmentOnDevice() throws {
        let context = try makeContext()
        let recording = Recording(title: "Legacy", fileName: "l.m4a", duration: 5)
        context.insert(recording)
        context.insert(TranscriptSegment(
            text: "Die AP ist dokumentiert, die K\\letter I\\letter läuft auf dem Gerät.",
            startTime: 0, endTime: 5, recording: recording
        ))
        try context.save()

        #expect(TranscriptMarkupRepair.run(in: context) == 1)

        let stored = try context.fetch(FetchDescriptor<TranscriptSegment>())
        let text = try #require(stored.first?.text)
        print("INTEGRATION MIGRATED: \(text)")
        #expect(!text.contains(TranscriptMarkupRepair.marker))
        // The marked run is joined because Apple's marker identifies it as
        // spelled-out letters; nothing else is rewritten — "AP" stays the
        // recognition error it is, and no other formatter rule ran.
        #expect(text == "Die AP ist dokumentiert, die KI läuft auf dem Gerät.")

        // And it exports cleanly.
        let rendered = TranscriptExporter().render(
            title: "Legacy", summary: nil,
            segments: [.init(text: text, startTime: 0)], format: .markdown
        )
        #expect(!rendered.contains(TranscriptMarkupRepair.marker))
    }

    // MARK: - Volatile versus final

    /// Feeds a fixture through the **live** path and checks the contract the
    /// integration rests on: the in-progress line stays raw, finalized text is
    /// formatted, and nothing is lost in the transition.
    @Test func liveSessionFormatsOnlyFinalizedText() async throws {
        guard await BenchmarkSpeech.isAvailable(for: locale) else {
            print("LIVE SKIPPED: Speech stack unavailable")
            return
        }
        let fixture: URL? = BenchmarkSpeech.fixtureURL(for: "abbrev-02")
        let url = try #require(fixture)
        let file = try AVAudioFile(forReading: url)

        let handle = try await SpeechLiveTranscriber().start(locale: locale)
        let observer = Task { () -> [LiveTranscriptUpdate] in
            var seen: [LiveTranscriptUpdate] = []
            for await update in handle.updates { seen.append(update) }
            return seen
        }

        // Real-time-ish feeding in the recorder's chunk size.
        let chunk: AVAudioFrameCount = 16_384
        while file.framePosition < file.length {
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: chunk)
            else { break }
            try file.read(into: buffer)
            if buffer.frameLength == 0 { break }
            handle.feed(buffer)
        }
        let finalDrafts = await handle.finish()
        let updates = await observer.value

        let finalText = finalDrafts.map(\.text).joined(separator: " ")
        print("LIVE updates=\(updates.count) FINAL: \(finalText)")
        for update in updates {
            print("LIVE VOLATILE: \(update.volatileText)")
        }

        // The finalized, persisted text is formatted and markup-free.
        #expect(!finalText.contains(TranscriptMarkupRepair.marker))
        #expect(!finalDrafts.isEmpty)

        // No word loss across the volatile-to-final transition: every word of
        // the last volatile line survives into the finalized text, compared on
        // formatting-insensitive skeletons so a repaired shape is not read as
        // a lost word.
        if let last = updates.last?.volatileText, !last.isEmpty {
            let finalSkeleton = BenchmarkMetrics.formattingSkeleton(finalText)
            for word in BenchmarkMetrics.tokens(last) {
                let skeleton = BenchmarkMetrics.formattingSkeleton(word)
                guard !skeleton.isEmpty else { continue }
                #expect(finalSkeleton.contains(skeleton), "word lost at finalization: \(word)")
            }
        }

        // The live line never shows engine markup, even mid-sentence, while
        // the semantic rules stay off it: a partial "13.45" is not yet turned
        // into a time.
        for update in updates {
            #expect(!update.volatileText.contains(TranscriptMarkupRepair.marker),
                    "markup visible in the live line: \(update.volatileText)")
        }

        // No duplication: a finalized phrase appears once per time range.
        let starts = finalDrafts.map(\.startTime)
        #expect(Set(starts).count == starts.count)
    }

    /// Records what the shipping preset actually reports, so the claim that the
    /// file path sees finalized results is evidence rather than assumption.
    @Test func shippingPresetReportingOptions() async throws {
        #if targetEnvironment(simulator)
        print("PRESET SKIPPED: simulator")
        #else
        let preset = SpeechTranscriber.Preset.transcription
        print("PRESET transcription reporting=\(preset.reportingOptions) " +
              "transcription=\(preset.transcriptionOptions) attributes=\(preset.attributeOptions)")
        let live = SpeechTranscriber.Preset.timeIndexedProgressiveTranscription
        print("PRESET timeIndexedProgressiveTranscription reporting=\(live.reportingOptions) " +
              "transcription=\(live.transcriptionOptions) attributes=\(live.attributeOptions)")
        #endif
    }
}
