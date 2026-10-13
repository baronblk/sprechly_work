import Foundation
import Speech
import Testing
#if !targetEnvironment(simulator)
import UIKit
#endif
@testable import SprechlyWork

/// Phase 4: does deterministic post-formatting improve the shipping transcript?
///
/// Reads the **frozen fixtures**, so the raw run doubles as the re-frozen
/// `SpeechTranscriber` baseline and every later run is comparable to it. The
/// audio, the corpus, the normalisation and the engine are all held constant;
/// the only variable is whether `TranscriptSemanticFormatter` ran, and with
/// which rules.
///
/// Device only — the Speech stack does not exist in the simulator.
@Suite(.serialized)
struct SemanticFormattingBenchmark {
    @Test func formattingEffectOnGermanFixtures() async throws {
        try await measure(language: "de", locale: Locale(identifier: "de-DE"),
                          cases: BenchmarkCorpus.german)
    }

    /// The regression guard for the rules: everything here was built and
    /// measured on German, and English must not pay for it.
    @Test func formattingEffectOnEnglishFixtures() async throws {
        try await measure(language: "en", locale: Locale(identifier: "en-US"),
                          cases: BenchmarkCorpus.english)
    }

    private func measure(language: String, locale: Locale, cases: [BenchmarkCase]) async throws {
        guard await BenchmarkSpeech.isAvailable(for: locale) else {
            print("FORMAT-\(language) SKIPPED: Speech stack unavailable")
            return
        }

        let engine = CurrentSpeechTranscriber()
        print("FORMAT-\(language) ENV device=\(deviceDescription()) locale=\(locale.identifier) " +
              "cases=\(cases.count) source=frozen-fixtures")

        // One transcription pass. Every variant scores the *same* raw text, so
        // no recognition noise can leak into the before/after comparison.
        var raw: [String: String] = [:]
        for testCase in cases {
            guard let url = BenchmarkSpeech.fixtureURL(for: testCase.id) else {
                print("FORMAT-\(language) MISSING FIXTURE \(testCase.id)")
                continue
            }
            let start = Date()
            let text = try await engine.transcribe(url: url, locale: testCase.locale)
            raw[testCase.id] = text
            print("FORMAT-\(language) RAW \(testCase.id) t=\(fmt(Date().timeIntervalSince(start)))s TEXT: \(text)")
        }

        // Marker audit: report every backslash sequence the recogniser emitted,
        // so a rule is only ever written against a marker actually observed.
        var markerCounts: [String: Int] = [:]
        for testCase in cases {
            guard let text = raw[testCase.id] else { continue }
            let sequences = TranscriptSemanticFormatter.backslashSequences(in: text)
            guard !sequences.isEmpty else { continue }
            print("FORMAT-\(language) MARKUP \(testCase.id) found=\(sequences.joined(separator: " "))")
            for sequence in sequences { markerCounts[sequence, default: 0] += 1 }
        }
        let auditLine = markerCounts.isEmpty
            ? "none"
            : markerCounts.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        print("FORMAT-\(language) MARKUP AUDIT \(auditLine)")

        let variants: [(label: String, rules: TranscriptSemanticFormatter.Rules?)] = [
            ("BEFORE", nil),
            ("AFTER-ALL", .all),
            ("RULE-TIMES", .clockTimes),
            ("RULE-VERSIONS", .versionNumbers),
            ("RULE-ACRONYMS", .spelledAcronyms),
            ("RULE-COMPOUNDS", .knownCompounds),
            ("RULE-MARKUP", .spelledLetterMarkup),
            ("RULE-MARKUP-ACRONYMS", [.spelledLetterMarkup, .spelledAcronyms]),
            ("RULE-CASING", .canonicalSpellings)
        ]

        var summaries: [String: BenchmarkMetrics.RunSummary] = [:]
        for variant in variants {
            var scores: [BenchmarkMetrics.CaseScore] = []
            for testCase in cases {
                guard let text = raw[testCase.id] else { continue }
                let processed: String
                if let rules = variant.rules {
                    let formatter = TranscriptSemanticFormatter(locale: testCase.locale, rules: rules)
                    processed = formatter.format(text)
                } else {
                    processed = text
                }
                let score = BenchmarkMetrics.score(testCase, transcript: processed, duration: 0)
                scores.append(score)
                if variant.label == "BEFORE" || variant.label == "AFTER-ALL" {
                    print("FORMAT-\(language) \(variant.label) \(testCase.id) wer=\(fmt(score.wer)) cer=\(fmt(score.cer)) " +
                          "hits=\(score.hitTerms.count)/\(score.targetTotal) " +
                          "fmt-miss=\(score.formattingMisses.joined(separator: "|")) " +
                          "rec-miss=\(score.recognitionMisses.joined(separator: "|")) " +
                          "fmt-acc=\(fmt(score.formattingAccuracy))")
                    if variant.label == "AFTER-ALL", processed != text {
                        print("FORMAT-\(language) CHANGED \(testCase.id) FROM: \(text)")
                        print("FORMAT-\(language) CHANGED \(testCase.id)   TO: \(processed)")
                    }
                }
            }
            let summary = BenchmarkMetrics.RunSummary(label: variant.label, scores: scores)
            summaries[variant.label] = summary
            print("FORMAT-\(language) SUMMARY \(variant.label) wer=\(fmt(summary.meanWER)) cer=\(fmt(summary.meanCER)) " +
                  "terms=\(summary.termsHit)/\(summary.termsTotal) recall=\(fmt(summary.termRecall)) " +
                  "fmt-acc=\(fmt(summary.formattingAccuracy)) " +
                  "fmt-miss=\(summary.formattingMisses) rec-miss=\(summary.recognitionMisses) " +
                  "fp=\(summary.falsePositives.count)")
        }

        guard let before = summaries["BEFORE"] else {
            Issue.record("no baseline run for \(language)")
            return
        }

        // Per-category breakdown of the baseline, for the error taxonomy.
        for category in BenchmarkCase.Category.allCases {
            let subset = before.scores.filter { $0.category == category }
            guard !subset.isEmpty else { continue }
            let hit = subset.map(\.hitTerms.count).reduce(0, +)
            let total = subset.map(\.targetTotal).reduce(0, +)
            let fmtMiss = subset.map(\.formattingMisses.count).reduce(0, +)
            let recMiss = subset.map(\.recognitionMisses.count).reduce(0, +)
            print("FORMAT-\(language) CATEGORY \(category.rawValue) terms=\(hit)/\(total) " +
                  "fmt-miss=\(fmtMiss) rec-miss=\(recMiss)")
        }

        // Per-rule attribution and, above all, false corrections.
        for variant in variants where variant.label != "BEFORE" {
            guard let after = summaries[variant.label] else { continue }
            let regressions = BenchmarkMetrics.falseCorrections(before: before, after: after)
            print("FORMAT-\(language) DELTA \(variant.label) wer=\(fmt(after.meanWER - before.meanWER)) " +
                  "cer=\(fmt(after.meanCER - before.meanCER)) " +
                  "terms=\(after.termsHit)-vs-\(before.termsHit) " +
                  "fmt-acc=\(fmt(after.formattingAccuracy - before.formattingAccuracy)) " +
                  "false-corrections=\(regressions.count)")
            for regression in regressions {
                print("FORMAT-\(language) FALSE-CORRECTION \(variant.label) \(regression.caseID) \(regression.term)")
            }
            // Which terms the rule actually recovered.
            for old in before.scores {
                guard let new = after.scores.first(where: { $0.id == old.id }) else { continue }
                for term in new.hitTerms where !old.hitTerms.contains(term) {
                    print("FORMAT-\(language) RECOVERED \(variant.label) \(old.id) \(term)")
                }
            }
        }

        // The decision criterion, asserted rather than only printed: the
        // formatter must not destroy text the recogniser already had right.
        if let after = summaries["AFTER-ALL"] {
            let regressions = BenchmarkMetrics.falseCorrections(before: before, after: after)
            #expect(regressions.isEmpty,
                    "\(language) false corrections: \(regressions.map(\.term).joined(separator: ", "))")
            #expect(after.meanWER <= before.meanWER)
            #expect(after.falsePositives.count == before.falsePositives.count)
        }
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
