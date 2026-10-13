import AVFoundation
import Foundation
import Speech
import Testing
#if !targetEnvironment(simulator)
import UIKit
#endif
@testable import VoxStudio

/// A/B benchmark for `AnalysisContext.contextualStrings` against the pipeline
/// the app actually ships.
///
/// Run on a device:
/// ```
/// xcodebuild test -project VoxStudio.xcodeproj -scheme VoxStudio \
///   -destination 'platform=iOS,id=<device-udid>' \
///   -only-testing:VoxStudioTests/TranscriptionContextBenchmark
/// ```
/// In the simulator every test reports "skipped": the Speech stack is
/// device-only, so a run there would measure nothing. CI stays green.
///
/// The only variable between the two runs is the context. Nothing else about
/// the pipeline changes.
@Suite(.serialized)
struct TranscriptionContextBenchmark {
    private let locale = Locale(identifier: "de-DE")
    private let service = SpeechTranscriptionService()

    // MARK: - Harness

    private func transcribe(
        url: URL,
        contextualStrings: [String]
    ) async throws -> (text: String, duration: TimeInterval) {
        let start = Date()
        var parts: [String] = []
        for try await draft in service.transcribe(
            fileAt: url, locale: locale, contextualStrings: contextualStrings
        ) {
            parts.append(draft.text)
        }
        return (parts.joined(separator: " "), Date().timeIntervalSince(start))
    }

    /// The frozen fixtures, so this run stays comparable to every other one.
    ///
    /// Previously synthesized per run, which is why the Phase-2 and Phase-3
    /// figures for the same transcriber disagreed.
    private func corpusAudio(_ cases: [BenchmarkCase]) throws -> [String: URL] {
        var urls: [String: URL] = [:]
        for testCase in cases {
            let fixture: URL? = BenchmarkSpeech.fixtureURL(for: testCase.id)
            urls[testCase.id] = try #require(fixture, "no frozen audio for case \(testCase.id)")
        }
        return urls
    }

    private func run(
        _ cases: [BenchmarkCase],
        urls: [String: URL],
        label: String,
        context: (BenchmarkCase) -> [String]
    ) async throws -> BenchmarkMetrics.RunSummary {
        var scores: [BenchmarkMetrics.CaseScore] = []
        for testCase in cases {
            guard let url = urls[testCase.id] else { continue }
            let result = try await transcribe(url: url, contextualStrings: context(testCase))
            let score = BenchmarkMetrics.score(testCase, transcript: result.text, duration: result.duration)
            scores.append(score)
            print("BENCH \(label) \(testCase.id) wer=\(fmt(score.wer)) cer=\(fmt(score.cer)) " +
                  "hits=\(score.hitTerms.count)/\(score.targetTotal) " +
                  "missed=\(score.missedTerms.joined(separator: "|")) " +
                  "fp=\(score.falsePositives.joined(separator: "|")) " +
                  "t=\(fmt(score.duration))s")
            print("BENCH \(label) \(testCase.id) TEXT: \(score.transcript)")
        }
        return BenchmarkMetrics.RunSummary(label: label, scores: scores)
    }

    private func fmt(_ value: Double) -> String { String(format: "%.3f", value) }

    private func report(_ summary: BenchmarkMetrics.RunSummary) {
        print("BENCH SUMMARY \(summary.label) " +
              "wer=\(fmt(summary.meanWER)) cer=\(fmt(summary.meanCER)) " +
              "terms=\(summary.termsHit)/\(summary.termsTotal) " +
              "recall=\(fmt(summary.termRecall)) " +
              "fp=\(summary.falsePositives.count) " +
              "time=\(fmt(summary.totalDuration))s")
        for category in BenchmarkCase.Category.allCases {
            let subset = summary.scores.filter { $0.category == category }
            guard !subset.isEmpty else { continue }
            let hit = subset.map(\.hitTerms.count).reduce(0, +)
            let total = subset.map(\.targetTotal).reduce(0, +)
            let wer = subset.map(\.wer).reduce(0, +) / Double(subset.count)
            print("BENCH CATEGORY \(summary.label) \(category.rawValue) " +
                  "terms=\(hit)/\(total) wer=\(fmt(wer))")
        }
    }

    // MARK: - Experiment

    @Test func baselineVersusContext() async throws {
        guard await BenchmarkSpeech.isAvailable(for: locale) else {
            print("BENCH SKIPPED: Speech stack unavailable (simulator, or de-DE model not installed)")
            return
        }

        let cases = BenchmarkCorpus.german

        print("BENCH ENV device=\(await deviceDescription()) locale=\(locale.identifier) cases=\(cases.count)")
        let urls = try corpusAudio(cases)
        #expect(urls.count == cases.count, "Nicht alle Fälle konnten synthetisiert werden")

        // A — the shipping pipeline, no context at all.
        let baseline = try await run(cases, urls: urls, label: "BASELINE") { _ in [] }
        report(baseline)

        // B — identical audio, identical pipeline, plus contextual strings.
        // Each case also offers decoy terms that are never spoken.
        let contextRun = try await run(cases, urls: urls, label: "CONTEXT") { testCase in
            testCase.contextualStrings + testCase.absentTerms
        }
        report(contextRun)

        print("BENCH DELTA " +
              "wer=\(fmt(contextRun.meanWER - baseline.meanWER)) " +
              "cer=\(fmt(contextRun.meanCER - baseline.meanCER)) " +
              "recall=\(fmt(contextRun.termRecall - baseline.termRecall)) " +
              "terms=\(contextRun.termsHit)-vs-\(baseline.termsHit) " +
              "fp=\(contextRun.falsePositives.count)-vs-\(baseline.falsePositives.count)")

        // Per-term comparison for the write-up.
        for testCase in cases {
            guard let b = baseline.scores.first(where: { $0.id == testCase.id }),
                  let c = contextRun.scores.first(where: { $0.id == testCase.id }) else { continue }
            for term in testCase.targetTerms {
                let before = b.hitTerms.contains(term)
                let after = c.hitTerms.contains(term)
                guard before != after else { continue }
                print("BENCH TERM \(testCase.id) \(term): \(before ? "hit" : "miss") -> \(after ? "hit" : "miss")")
            }
        }

        // The benchmark reports; it does not fail the build on a quality figure.
        #expect(baseline.scores.count == cases.count)
        #expect(contextRun.scores.count == cases.count)
    }

    /// Scaling probe — only meaningful once the basic effect is known.
    @Test func contextSizeScaling() async throws {
        guard await BenchmarkSpeech.isAvailable(for: locale) else {
            print("BENCH SKIPPED: Speech stack unavailable")
            return
        }
        // One representative mixed case carries several term types at once.
        guard let testCase = BenchmarkCorpus.german.first(where: { $0.id == "mixed-01" }) else { return }

        let urls = try corpusAudio([testCase])
        guard let url = urls[testCase.id] else { return }

        // Filler terms are plausible but unrelated, so growth is realistic.
        let filler = (1...100).map { "Begriff\($0)" }
        for size in [0, 10, 50, 100] {
            let context = size == 0 ? [] : testCase.contextualStrings + Array(filler.prefix(size))
            let result = try await transcribe(url: url, contextualStrings: context)
            let score = BenchmarkMetrics.score(testCase, transcript: result.text, duration: result.duration)
            print("BENCH SCALE size=\(context.count) " +
                  "terms=\(score.hitTerms.count)/\(score.targetTotal) " +
                  "wer=\(fmt(score.wer)) t=\(fmt(score.duration))s " +
                  "fp=\(score.falsePositives.joined(separator: "|"))")
        }
    }

    private func deviceDescription() async -> String {
        #if targetEnvironment(simulator)
        return "simulator"
        #else
        return await MainActor.run {
            let device = UIDevice.current
            return "\(device.model) iOS \(device.systemVersion)"
        }
        #endif
    }
}
