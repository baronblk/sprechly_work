import Foundation

/// Scoring for the transcription benchmark.
///
/// The normalisation is deliberately narrow: case, whitespace and trivial
/// punctuation only. It must never rewrite the very terms under test, and there
/// is no per-case special handling — otherwise the comparison measures the
/// scorer rather than the recogniser.
enum BenchmarkMetrics {
    /// Lowercases, strips punctuation that carries no meaning here, collapses
    /// whitespace. Decimal commas and dotted numbers survive, because
    /// "9,99" vs "999" is a real error and must stay visible.
    static func normalize(_ text: String) -> String {
        let lowered = text.lowercased()
        var out = ""
        out.reserveCapacity(lowered.count)
        for char in lowered {
            if char.isLetter || char.isNumber || char.isWhitespace {
                out.append(char)
            } else if char == "," || char == "." || char == ":" || char == "-" || char == "&" {
                // Kept: they distinguish 9,99 / 1.2.0 / 13:45 / Verkehrs-AG.
                out.append(char)
            } else {
                out.append(" ")
            }
        }
        return out.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// Token stream for word-level scoring. A trailing period on a sentence is
    /// dropped, an internal one (1.2.0) is not.
    static func tokens(_ text: String) -> [String] {
        normalize(text).split(separator: " ").map { token in
            var t = String(token)
            while let last = t.last, last == "." || last == "," || last == ":" {
                t.removeLast()
            }
            return t
        }.filter { !$0.isEmpty }
    }

    /// Levenshtein distance over any equatable sequence.
    static func editDistance<T: Equatable>(_ a: [T], _ b: [T]) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = Swift.min(current[j - 1] + 1, previous[j] + 1, previous[j - 1] + cost)
            }
            swap(&previous, &current)
        }
        return previous[b.count]
    }

    /// Word error rate: edit distance over tokens / reference tokens.
    static func wordErrorRate(reference: String, hypothesis: String) -> Double {
        let ref = tokens(reference)
        guard !ref.isEmpty else { return hypothesis.isEmpty ? 0 : 1 }
        return Double(editDistance(ref, tokens(hypothesis))) / Double(ref.count)
    }

    /// Character error rate over the normalised strings.
    static func characterErrorRate(reference: String, hypothesis: String) -> Double {
        let ref = Array(normalize(reference))
        guard !ref.isEmpty else { return hypothesis.isEmpty ? 0 : 1 }
        return Double(editDistance(ref, Array(normalize(hypothesis)))) / Double(ref.count)
    }

    /// Whether a target term appears in the transcript.
    ///
    /// Matching is on the normalised text and requires the term's own tokens to
    /// appear consecutively — "9,99" does not match "999", and "KI" does not
    /// match "kino". Multi-word terms ("4. Oktober 2026") are matched as a
    /// sequence. This is the whole point of the benchmark, so it stays strict.
    static func containsTerm(_ term: String, in transcript: String) -> Bool {
        let needle = tokens(term)
        guard !needle.isEmpty else { return false }
        let haystack = tokens(transcript)
        guard haystack.count >= needle.count else { return false }
        for start in 0...(haystack.count - needle.count) {
            if Array(haystack[start..<(start + needle.count)]) == needle { return true }
        }
        return false
    }

    // MARK: - Formatting vs. recognition (Phase 4)

    /// Strips *everything* that only carries shape: case, separators, spaces.
    ///
    /// `13.45`, `13:45` and `13 45` all collapse to `1345`; `Store Kit`,
    /// `storekit` and `StoreKit` all collapse to `storekit`. Two strings with
    /// the same skeleton contain the same letters and digits in the same order,
    /// so the recogniser heard the same thing and only wrote it differently.
    static func formattingSkeleton(_ text: String) -> String {
        normalize(text).filter { $0.isLetter || $0.isNumber }
    }

    /// Whether the term is present apart from its formatting.
    ///
    /// Compares against **token-aligned windows** rather than searching the
    /// whole collapsed transcript: an unanchored substring search would let
    /// "KI" match inside "Paketkiste" and inflate the formatting share at the
    /// expense of genuine recognition errors. Windows are bounded at six
    /// tokens, well above the longest corpus term spelled out letter by letter.
    static func containsTermIgnoringFormatting(_ term: String, in transcript: String) -> Bool {
        let needle = formattingSkeleton(term)
        guard !needle.isEmpty else { return false }
        let haystack = tokens(transcript)
        guard !haystack.isEmpty else { return false }
        let maxWindow = 6
        for start in haystack.indices {
            var joined = ""
            for end in start..<Swift.min(start + maxWindow, haystack.count) {
                joined += formattingSkeleton(haystack[end])
                if joined == needle { return true }
                if joined.count > needle.count { break }
            }
        }
        return false
    }

    /// How a single missed term failed.
    enum MissKind: String, Sendable {
        /// Right words, wrong shape — a formatter can fix this.
        case formatting
        /// Genuinely misheard — out of a formatter's reach.
        case recognition
    }

    static func missKind(_ term: String, in transcript: String) -> MissKind {
        containsTermIgnoringFormatting(term, in: transcript) ? .formatting : .recognition
    }

    /// Terms that turned from a hit into a miss between two runs.
    ///
    /// This is the **False Correction Count**: the one figure that must stay at
    /// zero. A formatter that raises accuracy while breaking text that was
    /// already correct is a regression, however good its average looks.
    static func falseCorrections(
        before: RunSummary,
        after: RunSummary
    ) -> [(caseID: String, term: String)] {
        var result: [(caseID: String, term: String)] = []
        for old in before.scores {
            guard let new = after.scores.first(where: { $0.id == old.id }) else { continue }
            for term in old.hitTerms where !new.hitTerms.contains(term) {
                result.append((old.id, term))
            }
        }
        return result
    }

    /// Result of scoring one case in one run.
    struct CaseScore: Sendable {
        let id: String
        let category: BenchmarkCase.Category
        let transcript: String
        let wer: Double
        let cer: Double
        let hitTerms: [String]
        let missedTerms: [String]
        /// Terms offered via context but never spoken that nonetheless appeared.
        let falsePositives: [String]
        /// Missed terms the recogniser heard but shaped wrongly.
        let formattingMisses: [String]
        /// Missed terms the recogniser genuinely got wrong.
        let recognitionMisses: [String]
        let duration: TimeInterval

        var targetTotal: Int { hitTerms.count + missedTerms.count }

        /// Share of the terms the recogniser *heard* that also carry the right
        /// shape. Recognition errors are excluded on purpose — they are not
        /// something formatting can influence, and leaving them in would hide
        /// the effect under a constant.
        var formattingAccuracy: Double {
            let heard = hitTerms.count + formattingMisses.count
            return heard == 0 ? 1 : Double(hitTerms.count) / Double(heard)
        }
    }

    static func score(
        _ testCase: BenchmarkCase,
        transcript: String,
        duration: TimeInterval
    ) -> CaseScore {
        let hits = testCase.targetTerms.filter { containsTerm($0, in: transcript) }
        let missed = testCase.targetTerms.filter { !containsTerm($0, in: transcript) }
        let invented = testCase.absentTerms.filter { containsTerm($0, in: transcript) }
        let formatting = missed.filter { missKind($0, in: transcript) == .formatting }
        let recognition = missed.filter { missKind($0, in: transcript) == .recognition }
        return CaseScore(
            id: testCase.id,
            category: testCase.category,
            transcript: transcript,
            wer: wordErrorRate(reference: testCase.reference, hypothesis: transcript),
            cer: characterErrorRate(reference: testCase.reference, hypothesis: transcript),
            hitTerms: hits,
            missedTerms: missed,
            falsePositives: invented,
            formattingMisses: formatting,
            recognitionMisses: recognition,
            duration: duration
        )
    }

    /// Aggregate over a run.
    struct RunSummary: Sendable {
        let label: String
        let scores: [CaseScore]

        var meanWER: Double { scores.isEmpty ? 0 : scores.map(\.wer).reduce(0, +) / Double(scores.count) }
        var meanCER: Double { scores.isEmpty ? 0 : scores.map(\.cer).reduce(0, +) / Double(scores.count) }
        var termsHit: Int { scores.map(\.hitTerms.count).reduce(0, +) }
        var termsTotal: Int { scores.map(\.targetTotal).reduce(0, +) }
        var termRecall: Double { termsTotal == 0 ? 0 : Double(termsHit) / Double(termsTotal) }
        var falsePositives: [(String, String)] {
            scores.flatMap { score in score.falsePositives.map { (score.id, $0) } }
        }
        var totalDuration: TimeInterval { scores.map(\.duration).reduce(0, +) }

        var formattingMisses: Int { scores.map(\.formattingMisses.count).reduce(0, +) }
        var recognitionMisses: Int { scores.map(\.recognitionMisses.count).reduce(0, +) }

        /// **Formatting Accuracy** over the whole run — pooled, not a mean of
        /// per-case rates, so a case with one target term does not weigh as
        /// much as one with six.
        var formattingAccuracy: Double {
            let heard = termsHit + formattingMisses
            return heard == 0 ? 1 : Double(termsHit) / Double(heard)
        }
    }
}
