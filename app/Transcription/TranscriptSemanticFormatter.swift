import Foundation

/// Repairs *presentation* errors in recognised text — never recognition errors.
///
/// Phase-3 measurement showed that a sizeable share of Sprechly's benchmark
/// misses are not mishearings but formatting: the words are right, the shape is
/// wrong (`13.45` for `13:45`, `Store Kit` for `StoreKit`, `A P I` for `API`).
/// Those are deterministic to fix; what the recogniser actually got wrong
/// (`Rrene` for `René`) is deliberately left alone.
///
/// **Design rule: leave a formatting error standing rather than alter correct
/// text.** Every rule below only fires on an unambiguous pattern, and each one
/// is covered by negative tests proving it leaves look-alikes untouched.
///
/// Pure, synchronous, locale-aware, no I/O and no dependency on Speech.
struct TranscriptSemanticFormatter: Sendable {
    /// Which repairs to apply. Separable so the benchmark can attribute impact.
    struct Rules: OptionSet, Sendable {
        let rawValue: Int
        static let spelledLetterMarkup = Rules(rawValue: 1 << 4)
        static let clockTimes = Rules(rawValue: 1 << 0)
        static let versionNumbers = Rules(rawValue: 1 << 1)
        static let spelledAcronyms = Rules(rawValue: 1 << 2)
        static let knownCompounds = Rules(rawValue: 1 << 3)
        static let canonicalSpellings = Rules(rawValue: 1 << 5)
        static let all: Rules = [
            .spelledLetterMarkup, .clockTimes, .versionNumbers,
            .spelledAcronyms, .knownCompounds, .canonicalSpellings
        ]
    }

    /// Whether a rule's behaviour depends on the transcript's language.
    enum LocaleScope: String, Sendable {
        /// Same behaviour in every language — product names, engine markup.
        case independent
        /// Keyed off the language; must be gated, never generalised.
        case specific
    }

    /// Every rule with its language dependence. `ruleScopeCoverage` asserts
    /// this stays complete, so a new rule cannot be added without classifying
    /// it.
    static let ruleScopes: [(rule: Rules, name: String, scope: LocaleScope)] = [
        (.spelledLetterMarkup, "spelledLetterMarkup", .independent),
        (.knownCompounds, "knownCompounds", .independent),
        (.canonicalSpellings, "canonicalSpellings", .independent),
        (.clockTimes, "clockTimes", .specific),
        (.versionNumbers, "versionNumbers", .specific),
        (.spelledAcronyms, "spelledAcronyms", .specific)
    ]

    let locale: Locale
    let rules: Rules

    init(locale: Locale = Locale(identifier: "de-DE"), rules: Rules = .all) {
        self.locale = locale
        self.rules = rules
    }

    func format(_ text: String) -> String {
        var out = text
        // Must run before the acronym rule: it is what exposes "K I" as a run.
        if rules.contains(.spelledLetterMarkup) { out = Self.stripSpelledLetterMarkup(out) }
        if rules.contains(.clockTimes) { out = Self.repairClockTimes(out, locale: locale) }
        if rules.contains(.versionNumbers) { out = Self.repairVersionNumbers(out) }
        if rules.contains(.spelledAcronyms) { out = Self.repairSpelledAcronyms(out) }
        if rules.contains(.knownCompounds) { out = Self.repairKnownCompounds(out) }
        // After the compound rule, so a freshly joined "StoreKit" is cased too.
        if rules.contains(.canonicalSpellings) { out = Self.repairCanonicalSpellings(out) }
        return out
    }

    // MARK: - Spelled-letter markup

    /// Removes the recogniser's own spelled-letter markup from the text.
    ///
    /// `SpeechTranscriber` marks a character it heard spelled out by appending
    /// a literal backslash token, so dictating "K I" yields the visible text
    /// `K\letter I\letter`. Verified byte for byte (`4b 5c 6c 65 74 74 65 72`)
    /// in the frozen-fixture run, not inferred from documentation.
    ///
    /// This is the one rule here that is not cosmetic: without it the markup
    /// reaches the saved transcript and every export of it.
    ///
    /// **Only the markers actually observed are stripped.** `\letter` is the
    /// single one this corpus produces; `SemanticFormattingBenchmark` reports
    /// every backslash sequence it sees, so a sibling marker shows up as
    /// evidence instead of being guessed at here. Everything else containing a
    /// backslash — a Windows path, an escape sequence a user dictated or
    /// pasted — is deliberately left untouched.
    static func stripSpelledLetterMarkup(_ text: String) -> String {
        guard text.contains("\\") else { return text }
        // The trailing boundary keeps "\letters" and "\letterbox" intact.
        guard let regex = try? NSRegularExpression(pattern: #"\\letter\b"#) else { return text }
        let stripped = regex.stringByReplacingMatches(
            in: text, range: NSRange(text.startIndex..., in: text), withTemplate: ""
        )
        guard stripped != text else { return text }
        // Removing the token can leave a doubled space behind.
        guard let spaces = try? NSRegularExpression(pattern: #"[ \t]{2,}"#) else { return stripped }
        return spaces.stringByReplacingMatches(
            in: stripped, range: NSRange(stripped.startIndex..., in: stripped), withTemplate: " "
        )
    }

    /// Every backslash sequence in the text, for the benchmark's marker audit.
    ///
    /// Reported rather than acted on: a marker only becomes a rule once it has
    /// been seen in a measured run.
    static func backslashSequences(in text: String) -> [String] {
        guard text.contains("\\"), let regex = try? NSRegularExpression(pattern: #"\\[^\s]*"#) else {
            return []
        }
        let nsText = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            .map { nsText.substring(with: $0.range) }
    }

    // MARK: - Clock times

    /// `13.45 Uhr` → `13:45 Uhr`.
    ///
    /// Requires **both** a valid 24-hour reading *and* an explicit time marker
    /// ("Uhr" / "o'clock") directly after it. Without that marker `12.50` is far
    /// more likely a price or a decimal, so it stays. This is why `Kapitel 3.2`,
    /// `Version 1.5` and `12,50` are untouched.
    /// Locale-specific. The marker word is the rule, so an unlisted language is
    /// **skipped** rather than served the German one: applying "Uhr" to French
    /// would be a rule generalised past its evidence.
    static let timeMarkers: [String: String] = ["de": "Uhr", "en": "o'clock"]

    static func repairClockTimes(_ text: String, locale: Locale) -> String {
        guard let language = locale.language.languageCode?.identifier,
              let marker = timeMarkers[language]
        else { return text }
        let pattern = #"\b([01]?\d|2[0-3])\.([0-5]\d)(?=\s+"# + NSRegularExpression.escapedPattern(for: marker) + #"\b)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        return regex.stringByReplacingMatches(
            in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "$1:$2"
        )
    }

    // MARK: - Version numbers

    /// `Version 1. 2.0` → `Version 1.2.0`.
    ///
    /// Only fires after an explicit context word (Version/Build/Release) and
    /// only when the result is a complete three-part version. A bare `1. 2.0`
    /// in running text is left alone, as is `Version 1.5` which is already
    /// well-formed.
    /// Locale-specific by way of its keyword list, which covers German and
    /// English — the two share these words, which is why one list serves both.
    /// A language that does not use them simply never matches.
    static func repairVersionNumbers(_ text: String) -> String {
        let keywords = ["Version", "version", "Build", "build", "Release", "release"]
        let keyword = keywords.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        // "1. 2.0" / "1 . 2 . 0" → the digits are right, the spacing is not.
        let pattern = #"\b("# + keyword + #")\s+(\d+)\s*\.\s*(\d+)\s*\.\s*(\d+)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        return regex.stringByReplacingMatches(
            in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "$1 $2.$3.$4"
        )
    }

    // MARK: - Spelled-out acronyms

    /// `A P I` → `API`, `V P N` → `VPN`.
    ///
    /// Joins a run of two to five isolated capitals. Bounded deliberately: two
    /// is the shortest meaningful acronym, and beyond five a run is more likely
    /// to be something else. German single-letter words are the real hazard —
    /// so a run is only joined when **every** element is a capital letter and
    /// none of them forms a word on its own in the guard list below.
    static func repairSpelledAcronyms(_ text: String) -> String {
        // Single uppercase letters that can stand as a word on their own in
        // German or English; a run of only these is left as is. Deliberately a
        // union rather than a per-language set: the guard only ever *prevents*
        // a change, so covering both languages is the conservative direction.
        let standalone: Set<String> = ["A", "I", "O", "U"]
        // Matches a run of *any* length so an over-long one can be rejected
        // wholesale. Capping it in the pattern instead would join the first
        // five letters of a seven-letter run — a false correction.
        let pattern = #"\b(?:[A-ZÄÖÜ]\s+)+[A-ZÄÖÜ]\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }

        let nsText = text as NSString
        var result = text
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        for match in matches.reversed() {
            let run = nsText.substring(with: match.range)
            let letters = run.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            guard letters.count >= 2, letters.count <= 5 else { continue }
            // A run that is only ambiguous single-letter words is not an acronym.
            guard !letters.allSatisfy({ standalone.contains($0) }) else { continue }
            let joined = letters.joined()
            guard let range = Range(match.range, in: result) else { continue }
            result.replaceSubrange(range, with: joined)
        }
        return result
    }

    // MARK: - Known compound product names

    /// `Store Kit` → `StoreKit`, `Share Point` → `SharePoint`.
    ///
    /// A short, explicit list of names this project actually tests. It is **not**
    /// a user vocabulary and not fuzzy matching: both halves must already be
    /// present and correctly spelled, only the split and the inner capital are
    /// repaired. An unknown word is never touched.
    static let knownCompounds: [(spoken: [String], formatted: String)] = [
        (["Store", "Kit"], "StoreKit"),
        (["Cloud", "Kit"], "CloudKit"),
        (["Share", "Point"], "SharePoint"),
        (["Swift", "UI"], "SwiftUI"),
        (["Speech", "Analyzer"], "SpeechAnalyzer"),
        (["Analysis", "Context"], "AnalysisContext"),
        (["Mark", "down"], "Markdown")
    ]

    /// Canonical spelling for names the recogniser writes as one word with the
    /// wrong inner capital (`Sharepoint`). A short, explicit, documented list —
    /// no fuzzy matching, no user vocabulary.
    ///
    /// Note for the record: the benchmark's term matching is case-insensitive,
    /// so this rule cannot move Formatting Accuracy. It is here for the text
    /// the user actually reads, and its effect is visible in the transcripts,
    /// not in the score.
    static let canonicalSpellings = ["StoreKit", "CloudKit", "SwiftUI", "SharePoint", "Markdown"]

    static func repairCanonicalSpellings(_ text: String) -> String {
        var result = text
        for canonical in canonicalSpellings {
            let pattern = #"\b"# + NSRegularExpression.escapedPattern(for: canonical) + #"\b"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            else { continue }
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: canonical
            )
        }
        return result
    }

    static func repairKnownCompounds(_ text: String) -> String {
        var result = text
        for entry in knownCompounds {
            guard let first = entry.spoken.first else { continue }
            // The leading word stays case-sensitive: "store kit" mid-sentence
            // is ordinary German and must not become a product name. The
            // following words are matched case-insensitively, because the
            // recogniser capitalises them inconsistently — it produced both
            // "Mark down" and "Mark Down" for the same word.
            var pattern = #"\b"# + NSRegularExpression.escapedPattern(for: first)
            for part in entry.spoken.dropFirst() {
                pattern += #"\s+(?i:"# + NSRegularExpression.escapedPattern(for: part) + #")"#
            }
            pattern += #"\b"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: entry.formatted
            )
        }
        return result
    }
}
