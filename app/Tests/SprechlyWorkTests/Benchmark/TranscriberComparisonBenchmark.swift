import AVFoundation
import Foundation
import Speech
import Testing
#if !targetEnvironment(simulator)
import UIKit
#endif
@testable import VoxStudio

/// Phase 3: `DictationTranscriber` against the `SpeechTranscriber` the app ships.
///
/// Reuses the Phase-2 corpus, audio synthesis, normalisation and metrics
/// unchanged, so the recorded baseline stays the reference. The only variable
/// between runs is the speech module.
///
/// Device only — see `TranscriptionContextBenchmark` for the rationale.
@Suite(.serialized)
struct TranscriberComparisonBenchmark {
    private let locale = Locale(identifier: "de-DE")

    /// Reports what the candidate actually offers on this OS, before measuring.
    @Test func dictationTranscriberCapabilities() async throws {
        #if targetEnvironment(simulator)
        print("CAPS SKIPPED: simulator")
        return
        #else
        let supported = await DictationTranscriber.supportedLocales
        let installed = await DictationTranscriber.installedLocales
        print("CAPS dictation supportedLocales=\(supported.count) installedLocales=\(installed.count)")
        print("CAPS dictation supported-de=\(supported.contains { $0.identifier.hasPrefix("de") })")
        print("CAPS dictation installed=\(installed.map(\.identifier).sorted().joined(separator: ","))")

        let speechSupported = await SpeechTranscriber.supportedLocales
        let speechInstalled = await SpeechTranscriber.installedLocales
        print("CAPS speech isAvailable=\(SpeechTranscriber.isAvailable) " +
              "supportedLocales=\(speechSupported.count) installedLocales=\(speechInstalled.count)")
        print("CAPS speech installed=\(speechInstalled.map(\.identifier).sorted().joined(separator: ","))")

        // What the presets actually switch on — the SDK does not document this.
        for (name, preset) in [
            ("phrase", DictationTranscriber.Preset.phrase),
            ("shortDictation", .shortDictation),
            ("progressiveShortDictation", .progressiveShortDictation),
            ("longDictation", .longDictation),
            ("progressiveLongDictation", .progressiveLongDictation),
            ("timeIndexedLongDictation", .timeIndexedLongDictation)
        ] {
            print("CAPS preset \(name): hints=\(preset.contentHints.count) " +
                  "transcription=\(preset.transcriptionOptions) " +
                  "reporting=\(preset.reportingOptions) " +
                  "attributes=\(preset.attributeOptions)")
        }
        #endif
    }

    @Test func compareEngines() async throws {
        guard await BenchmarkSpeech.isAvailable(for: locale) else {
            print("COMPARE SKIPPED: Speech stack unavailable")
            return
        }

        let cases = BenchmarkCorpus.german

        // Frozen fixtures: identical audio for every engine *and* across runs.
        var urls: [String: URL] = [:]
        for testCase in cases {
            let fixture: URL? = BenchmarkSpeech.fixtureURL(for: testCase.id)
            urls[testCase.id] = try #require(fixture, "no frozen audio for case \(testCase.id)")
        }
        print("COMPARE ENV device=\(deviceDescription()) locale=\(locale.identifier) " +
              "cases=\(cases.count) source=frozen-fixtures")

        let engines: [any BenchmarkEngine] = [
            CurrentSpeechTranscriber(),
            CandidateDictationTranscriber(),
            CandidateDictationTranscriber(label: "DICT-FARFIELD", preset: nil, contentHints: [.farField])
        ]

        var summaries: [String: BenchmarkMetrics.RunSummary] = [:]
        for engine in engines {
            var scores: [BenchmarkMetrics.CaseScore] = []
            for testCase in cases {
                guard let url = urls[testCase.id] else { continue }
                let start = Date()
                let text: String
                do {
                    text = try await engine.transcribe(url: url, locale: testCase.locale)
                } catch {
                    print("COMPARE \(engine.label) \(testCase.id) ERROR: \(error)")
                    continue
                }
                let score = BenchmarkMetrics.score(
                    testCase, transcript: text, duration: Date().timeIntervalSince(start)
                )
                scores.append(score)
                print("COMPARE \(engine.label) \(testCase.id) wer=\(fmt(score.wer)) cer=\(fmt(score.cer)) " +
                      "hits=\(score.hitTerms.count)/\(score.targetTotal) " +
                      "missed=\(score.missedTerms.joined(separator: "|")) " +
                      "fp=\(score.falsePositives.joined(separator: "|")) t=\(fmt(score.duration))s")
                print("COMPARE \(engine.label) \(testCase.id) TEXT: \(score.transcript)")
            }
            let summary = BenchmarkMetrics.RunSummary(label: engine.label, scores: scores)
            summaries[engine.label] = summary
            print("COMPARE SUMMARY \(engine.label) wer=\(fmt(summary.meanWER)) cer=\(fmt(summary.meanCER)) " +
                  "terms=\(summary.termsHit)/\(summary.termsTotal) recall=\(fmt(summary.termRecall)) " +
                  "fp=\(summary.falsePositives.count) time=\(fmt(summary.totalDuration))s cases=\(summary.scores.count)")
            for category in BenchmarkCase.Category.allCases {
                let subset = summary.scores.filter { $0.category == category }
                guard !subset.isEmpty else { continue }
                let hit = subset.map(\.hitTerms.count).reduce(0, +)
                let total = subset.map(\.targetTotal).reduce(0, +)
                let wer = subset.map(\.wer).reduce(0, +) / Double(subset.count)
                print("COMPARE CATEGORY \(engine.label) \(category.rawValue) terms=\(hit)/\(total) wer=\(fmt(wer))")
            }
        }

        // Per-term comparison against the shipping engine.
        if let base = summaries["SPEECH"] {
            for other in summaries.values where other.label != "SPEECH" {
                for testCase in cases {
                    guard let b = base.scores.first(where: { $0.id == testCase.id }),
                          let c = other.scores.first(where: { $0.id == testCase.id }) else { continue }
                    for term in testCase.targetTerms {
                        let hitBase = b.hitTerms.contains(term)
                        let hitOther = c.hitTerms.contains(term)
                        print("COMPARE TERM \(other.label) \(testCase.id) \(term): " +
                              "speech=\(hitBase ? "hit" : "miss") other=\(hitOther ? "hit" : "miss")")
                    }
                }
                print("COMPARE DELTA \(other.label) wer=\(fmt(other.meanWER - base.meanWER)) " +
                      "cer=\(fmt(other.meanCER - base.meanCER)) " +
                      "recall=\(fmt(other.termRecall - base.termRecall)) " +
                      "terms=\(other.termsHit)-vs-\(base.termsHit)")
            }
        }

        #expect(summaries["SPEECH"] != nil)
    }

    private func fmt(_ value: Double) -> String { String(format: "%.3f", value) }

    private func deviceDescription() -> String {
        #if targetEnvironment(simulator)
        return "simulator"
        #else
        return "\(UIDevice.current.model) iOS \(UIDevice.current.systemVersion)"
        #endif
    }
}
