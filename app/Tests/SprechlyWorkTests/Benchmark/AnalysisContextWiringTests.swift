import Foundation
import Speech
import Testing
@testable import VoxStudio

/// Guards the benchmark's own setup.
///
/// The context run produced transcripts identical to the baseline down to the
/// character. That is only meaningful evidence about `contextualStrings` if the
/// context actually reached the analyzer — otherwise it would merely show that
/// the benchmark forgot to set it. These tests read the context back out and
/// also exercise the alternative wiring (handing it to the initializer rather
/// than calling `setContext`).
@Suite(.serialized)
struct AnalysisContextWiringTests {
    private let locale = Locale(identifier: "de-DE")
    private let terms = ["Proxmox", "CloudKit", "Chemnitzer Verkehrs-AG"]

    @Test func setContextIsRetainedByTheAnalyzer() async throws {
        guard await BenchmarkSpeech.isAvailable(for: locale) else {
            print("WIRING SKIPPED: Speech stack unavailable")
            return
        }
        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
        let analyzer = SpeechAnalyzer(modules: [transcriber])

        let before = await analyzer.context.contextualStrings[.general] ?? []
        let context = AnalysisContext()
        context.contextualStrings[.general] = terms
        try await analyzer.setContext(context)
        let after = await analyzer.context.contextualStrings[.general] ?? []

        print("WIRING setContext: before=\(before.count) after=\(after.count) values=\(after)")
        #expect(after == terms, "Der Analyzer hat die Kontextbegriffe nicht übernommen")
    }

    @Test func contextPassedThroughInitializerIsRetained() async throws {
        guard await BenchmarkSpeech.isAvailable(for: locale) else {
            print("WIRING SKIPPED: Speech stack unavailable")
            return
        }
        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
        let context = AnalysisContext()
        context.contextualStrings[.general] = terms

        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        defer { continuation.finish() }
        let analyzer = SpeechAnalyzer(
            inputSequence: stream,
            modules: [transcriber],
            options: nil,
            analysisContext: context
        )
        let read = await analyzer.context.contextualStrings[.general] ?? []
        print("WIRING initializer: count=\(read.count) values=\(read)")
        #expect(read == terms, "Der Initializer-Kontext kam nicht an")
    }
}
