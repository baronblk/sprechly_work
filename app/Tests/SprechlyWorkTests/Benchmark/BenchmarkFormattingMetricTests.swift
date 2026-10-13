import Foundation
import Testing
@testable import VoxStudio

/// The Phase-4 metrics decide whether the formatter ships, so their definitions
/// are tested rather than assumed.
struct BenchmarkFormattingMetricTests {
    // MARK: - Skeleton

    @Test func skeletonCollapsesShapeOnly() {
        #expect(BenchmarkMetrics.formattingSkeleton("13:45") == "1345")
        #expect(BenchmarkMetrics.formattingSkeleton("13.45") == "1345")
        #expect(BenchmarkMetrics.formattingSkeleton("Store Kit") == "storekit")
        #expect(BenchmarkMetrics.formattingSkeleton("StoreKit") == "storekit")
        #expect(BenchmarkMetrics.formattingSkeleton("Verkehrs-AG") == "verkehrsag")
    }

    @Test func skeletonKeepsDifferentContentDifferent() {
        // Known limitation, stated rather than hidden: the skeleton drops the
        // decimal comma, so "9,99" and "999" collapse to the same value and a
        // real mishearing of a price would be scored as a formatting slip. No
        // corpus target has that shape, and the classification only ever
        // reassigns a term between two miss buckets — it can never turn a miss
        // into a hit. Mishearings of *words* stay distinct, which is what the
        // classification relies on:
        #expect(BenchmarkMetrics.formattingSkeleton("Docker")
                != BenchmarkMetrics.formattingSkeleton("Doktor"))
        #expect(BenchmarkMetrics.formattingSkeleton("René")
                != BenchmarkMetrics.formattingSkeleton("Rrene"))
    }

    // MARK: - Miss classification

    @Test func classifiesWrongShapeAsFormatting() {
        #expect(BenchmarkMetrics.missKind("13:45", in: "Treffen um 13.45 Uhr") == .formatting)
        #expect(BenchmarkMetrics.missKind("StoreKit", in: "Kauf über Store Kit") == .formatting)
        #expect(BenchmarkMetrics.missKind("KI", in: "Die K I läuft") == .formatting)
        #expect(BenchmarkMetrics.missKind("1.2.0", in: "Version 1. 2.0 kommt") == .formatting)
    }

    @Test func classifiesMisheardWordsAsRecognition() {
        #expect(BenchmarkMetrics.missKind("Docker", in: "Der Doktor startet") == .recognition)
        #expect(BenchmarkMetrics.missKind("René", in: "Rrene arbeitet dort") == .recognition)
        #expect(BenchmarkMetrics.missKind("SwiftUI", in: "Geschrieben in Swift") == .recognition)
    }

    @Test func doesNotMatchShortTermsInsideLongerWords() {
        // The decisive case for the window anchoring: an unanchored search
        // would find "ki" inside "Paketkiste" and misreport a mishearing as a
        // mere formatting slip.
        #expect(BenchmarkMetrics.missKind("KI", in: "Die Paketkiste steht da") == .recognition)
        #expect(BenchmarkMetrics.missKind("AG", in: "Die Tagung beginnt") == .recognition)
    }

    // MARK: - Formatting accuracy

    @Test func formattingAccuracyIgnoresRecognitionErrors() {
        let testCase = BenchmarkCase(
            id: "t", category: .mixed,
            reference: "Um 13:45 Uhr über StoreKit mit Docker.",
            targetTerms: ["13:45", "StoreKit", "Docker"]
        )
        // Two heard-but-misshapen, one genuinely misheard.
        let score = BenchmarkMetrics.score(
            testCase, transcript: "Um 13.45 Uhr über Store Kit mit Doktor.", duration: 0
        )
        #expect(score.hitTerms.isEmpty)
        #expect(score.formattingMisses.count == 2)
        #expect(score.recognitionMisses == ["Docker"])
        // 0 of 2 heard terms correctly shaped — the mishearing is not counted.
        #expect(score.formattingAccuracy == 0)
    }

    @Test func formattingAccuracyIsOneWhenShapeIsRight() {
        let testCase = BenchmarkCase(
            id: "t", category: .mixed,
            reference: "Um 13:45 Uhr mit Docker.",
            targetTerms: ["13:45", "Docker"]
        )
        let score = BenchmarkMetrics.score(
            testCase, transcript: "Um 13:45 Uhr mit Doktor.", duration: 0
        )
        #expect(score.hitTerms == ["13:45"])
        #expect(score.recognitionMisses == ["Docker"])
        #expect(score.formattingAccuracy == 1)
    }

    @Test func formattingAccuracyIsPooledAcrossCases() {
        let one = BenchmarkCase(id: "a", category: .mixed, reference: "A 13:45", targetTerms: ["13:45"])
        let many = BenchmarkCase(
            id: "b", category: .mixed,
            reference: "StoreKit CloudKit SwiftUI",
            targetTerms: ["StoreKit", "CloudKit", "SwiftUI"]
        )
        let summary = BenchmarkMetrics.RunSummary(label: "X", scores: [
            BenchmarkMetrics.score(one, transcript: "A 13:45", duration: 0),
            BenchmarkMetrics.score(many, transcript: "Store Kit Cloud Kit Swift UI", duration: 0)
        ])
        // 1 hit, 3 formatting misses — pooled, not (1.0 + 0.0) / 2.
        #expect(summary.termsHit == 1)
        #expect(summary.formattingMisses == 3)
        #expect(abs(summary.formattingAccuracy - 0.25) < 0.0001)
    }

    // MARK: - False corrections

    @Test func falseCorrectionsCountHitsLostBetweenRuns() {
        let testCase = BenchmarkCase(
            id: "a", category: .mixed, reference: "Markdown und 13:45",
            targetTerms: ["Markdown", "13:45"]
        )
        let before = BenchmarkMetrics.RunSummary(label: "BEFORE", scores: [
            BenchmarkMetrics.score(testCase, transcript: "Markdown und 13.45", duration: 0)
        ])
        // A formatter that fixed the time but broke the word it already had.
        let after = BenchmarkMetrics.RunSummary(label: "AFTER", scores: [
            BenchmarkMetrics.score(testCase, transcript: "Mark down und 13:45", duration: 0)
        ])
        let regressions = BenchmarkMetrics.falseCorrections(before: before, after: after)
        #expect(regressions.count == 1)
        #expect(regressions.first?.term == "Markdown")
    }

    @Test func noFalseCorrectionsWhenOnlyMissesImprove() {
        let testCase = BenchmarkCase(
            id: "a", category: .mixed, reference: "Markdown und 13:45",
            targetTerms: ["Markdown", "13:45"]
        )
        let before = BenchmarkMetrics.RunSummary(label: "BEFORE", scores: [
            BenchmarkMetrics.score(testCase, transcript: "Markdown und 13.45", duration: 0)
        ])
        let after = BenchmarkMetrics.RunSummary(label: "AFTER", scores: [
            BenchmarkMetrics.score(testCase, transcript: "Markdown und 13:45", duration: 0)
        ])
        #expect(BenchmarkMetrics.falseCorrections(before: before, after: after).isEmpty)
    }
}
