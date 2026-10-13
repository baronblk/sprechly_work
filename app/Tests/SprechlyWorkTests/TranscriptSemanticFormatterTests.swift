import Foundation
import Testing
@testable import SprechlyWork

/// The formatter's value depends entirely on it *not* touching correct text.
/// Every rule therefore gets its negative cases first.
struct TranscriptSemanticFormatterTests {
    private let formatter = TranscriptSemanticFormatter()

    // MARK: - Spelled-letter markup

    @Test func stripsTheObservedSpelledLetterMarker() {
        // Exactly what the frozen fixture produces, bytes verified.
        #expect(formatter.format("Die AP ist dokumentiert, die K\\letter I\\letter läuft.")
                == "Die AP ist dokumentiert, die KI läuft.")
        #expect(TranscriptSemanticFormatter.stripSpelledLetterMarkup("K\\letter I\\letter")
                == "K I")
    }

    @Test func collapsesTheSpaceTheMarkerLeavesBehind() {
        #expect(TranscriptSemanticFormatter.stripSpelledLetterMarkup("das A\\letter  Ende")
                == "das A Ende")
    }

    @Test func leavesOrdinaryBackslashesAlone() {
        // The decisive negative cases: a dictated or pasted backslash is the
        // user's text, not markup, and must survive untouched.
        #expect(formatter.format(#"Der Pfad ist C:\Users\rene\Dokumente."#)
                == #"Der Pfad ist C:\Users\rene\Dokumente."#)
        #expect(formatter.format(#"Ein Zeilenumbruch ist \n im Code."#)
                == #"Ein Zeilenumbruch ist \n im Code."#)
        #expect(formatter.format(#"Schreib \begin{document} an den Anfang."#)
                == #"Schreib \begin{document} an den Anfang."#)
    }

    @Test func leavesLookalikeMarkerWordsAlone() {
        // Only the exact token is markup — the boundary guards the rest.
        #expect(formatter.format(#"Die \letters sind gemeint."#) == #"Die \letters sind gemeint."#)
        #expect(formatter.format(#"Im \letterbox lag Post."#) == #"Im \letterbox lag Post."#)
    }

    @Test func textWithoutBackslashIsReturnedUnchanged() {
        let plain = "Ein ganz gewöhnlicher Satz ohne Markup."
        #expect(TranscriptSemanticFormatter.stripSpelledLetterMarkup(plain) == plain)
    }

    @Test func reportsBackslashSequencesForTheMarkerAudit() {
        #expect(TranscriptSemanticFormatter.backslashSequences(in: "K\\letter I\\letter")
                == [#"\letter"#, #"\letter"#])
        #expect(TranscriptSemanticFormatter.backslashSequences(in: "kein Markup hier").isEmpty)
        #expect(TranscriptSemanticFormatter.backslashSequences(in: #"C:\Users"#) == [#"\Users"#])
    }

    // MARK: - Canonical spellings

    @Test func appliesCanonicalSpellingToKnownNames() {
        #expect(formatter.format("Die Doku liegt in Sharepoint.") == "Die Doku liegt in SharePoint.")
        #expect(formatter.format("Der Kauf läuft über Storekit.") == "Der Kauf läuft über StoreKit.")
        #expect(formatter.format("Export nach markdown.") == "Export nach Markdown.")
        #expect(formatter.format("Gebaut mit Swiftui.") == "Gebaut mit SwiftUI.")
    }

    @Test func canonicalSpellingLeavesUnlistedNamesAlone() {
        // No fuzzy matching: a name not on the documented list keeps its shape.
        #expect(formatter.format("Wir nutzen Powerpoint.") == "Wir nutzen Powerpoint.")
        #expect(formatter.format("Das lief über Teamviewer.") == "Das lief über Teamviewer.")
    }

    @Test func canonicalSpellingDoesNotTouchPartialWords() {
        #expect(formatter.format("Die Sharepointer kamen.") == "Die Sharepointer kamen.")
    }

    @Test func canonicalSpellingSurvivesHyphenation() {
        #expect(formatter.format("Der markdown-Export läuft.") == "Der Markdown-Export läuft.")
    }

    // MARK: - Clock times

    @Test func repairsClockTimeBeforeTimeMarker() {
        #expect(formatter.format("Das Treffen ist um 13.45 Uhr.") == "Das Treffen ist um 13:45 Uhr.")
        #expect(formatter.format("Wir starten 9.05 Uhr.") == "Wir starten 9:05 Uhr.")
        #expect(formatter.format("Ende um 23.59 Uhr") == "Ende um 23:59 Uhr")
    }

    @Test func leavesNumbersWithoutATimeMarkerAlone() {
        // The decisive negative case: same shape, no "Uhr", so it stays.
        #expect(formatter.format("Kapitel 3.2 ist lang.") == "Kapitel 3.2 ist lang.")
        #expect(formatter.format("Version 1.5 kommt später.") == "Version 1.5 kommt später.")
        #expect(formatter.format("Das kostet 12.50 Dollar.") == "Das kostet 12.50 Dollar.")
        #expect(formatter.format("Der Wert ist 13.45 Prozent.") == "Der Wert ist 13.45 Prozent.")
    }

    @Test func leavesImpossibleClockReadingsAlone() {
        #expect(formatter.format("Der Wert 25.70 Uhr ergibt keine Zeit.")
                == "Der Wert 25.70 Uhr ergibt keine Zeit.")
        #expect(formatter.format("Bei 13.99 Uhr stimmt die Minute nicht.")
                == "Bei 13.99 Uhr stimmt die Minute nicht.")
    }

    @Test func leavesAlreadyCorrectTimesAlone() {
        #expect(formatter.format("Um 13:45 Uhr geht es los.") == "Um 13:45 Uhr geht es los.")
    }

    @Test func clockRuleIsLocaleAware() {
        let english = TranscriptSemanticFormatter(locale: Locale(identifier: "en-US"))
        #expect(english.format("We meet at 13.45 o'clock.") == "We meet at 13:45 o'clock.")
        // "Uhr" is not the marker in English, so nothing happens.
        #expect(english.format("The value 13.45 Uhr") == "The value 13.45 Uhr")
    }

    // MARK: - Version numbers

    @Test func repairsSplitVersionAfterKeyword() {
        #expect(formatter.format("Wir liefern Version 1. 2.0 aus.") == "Wir liefern Version 1.2.0 aus.")
        #expect(formatter.format("Build 2 . 1 . 3 ist fertig.") == "Build 2.1.3 ist fertig.")
    }

    @Test func leavesVersionsWithoutKeywordAlone() {
        // Without the context word this could be anything — sentence boundary
        // followed by a decimal, for instance.
        #expect(formatter.format("Der Wert 1. 2.0 steht dort.") == "Der Wert 1. 2.0 steht dort.")
    }

    @Test func leavesWellFormedVersionsAlone() {
        #expect(formatter.format("Version 1.2.0 ist live.") == "Version 1.2.0 ist live.")
        #expect(formatter.format("Version 1.5 reicht.") == "Version 1.5 reicht.")
    }

    // MARK: - Spelled-out acronyms

    @Test func joinsSpelledAcronyms() {
        #expect(formatter.format("Die A P I ist dokumentiert.") == "Die API ist dokumentiert.")
        #expect(formatter.format("Zugriff über V P N.") == "Zugriff über VPN.")
        #expect(formatter.format("Die K I läuft lokal.") == "Die KI läuft lokal.")
        #expect(formatter.format("Das M D M verwaltet Geräte.") == "Das MDM verwaltet Geräte.")
    }

    @Test func leavesOrdinaryCapitalisedWordsAlone() {
        // Real words, not a spelled-out acronym.
        #expect(formatter.format("Anna Berta Clara kamen an.") == "Anna Berta Clara kamen an.")
        #expect(formatter.format("Der Export geht nach Markdown.") == "Der Export geht nach Markdown.")
    }

    @Test func leavesAmbiguousSingleLetterRunsAlone() {
        // "A I" is as plausibly two standalone words as an acronym.
        #expect(formatter.format("Das A I bleibt offen.") == "Das A I bleibt offen.")
    }

    @Test func doesNotJoinOverlyLongRuns() {
        let input = "A B C D E F G folgt."
        #expect(formatter.format(input) == input)
    }

    // MARK: - Known compounds

    @Test func joinsKnownProductCompounds() {
        #expect(formatter.format("Der Kauf läuft über Store Kit.") == "Der Kauf läuft über StoreKit.")
        #expect(formatter.format("Sync über Cloud Kit.") == "Sync über CloudKit.")
        #expect(formatter.format("Die Doku liegt in Share Point.") == "Die Doku liegt in SharePoint.")
        #expect(formatter.format("Geschrieben in Swift UI.") == "Geschrieben in SwiftUI.")
    }

    @Test func leavesLowercaseLookalikesAlone() {
        // The leading word stays case-sensitive, so ordinary German prose that
        // happens to contain these words is safe.
        #expect(formatter.format("Im store kit lag nichts.") == "Im store kit lag nichts.")
        #expect(formatter.format("Er musste den mark down nehmen.")
                == "Er musste den mark down nehmen.")
    }

    @Test func compoundRuleToleratesInconsistentCasingAfterTheFirstWord() {
        // The recogniser produced both "Mark down" and "Mark Down" for the
        // same word, so only the leading word may be case-sensitive.
        #expect(formatter.format("Der Export geht nach Mark Down.")
                == "Der Export geht nach Markdown.")
        #expect(formatter.format("Der Export geht nach Mark down.")
                == "Der Export geht nach Markdown.")
        #expect(formatter.format("Der Kauf läuft über Store kit.")
                == "Der Kauf läuft über StoreKit.")
    }

    @Test func leavesUnknownCompoundsAlone() {
        // No fuzzy matching: a name not on the list is never invented.
        #expect(formatter.format("Wir nutzen Power Point.") == "Wir nutzen Power Point.")
        #expect(formatter.format("Das Team nutzt Team Viewer.") == "Das Team nutzt Team Viewer.")
    }

    @Test func leavesAlreadyCorrectCompoundsAlone() {
        #expect(formatter.format("StoreKit und CloudKit sind fertig.") == "StoreKit und CloudKit sind fertig.")
    }

    // MARK: - Interaction and safety

    @Test func rulesCanBeAppliedSelectively() {
        let onlyTimes = TranscriptSemanticFormatter(rules: .clockTimes)
        let input = "Um 13.45 Uhr über Store Kit."
        #expect(onlyTimes.format(input) == "Um 13:45 Uhr über Store Kit.")
    }

    @Test func handlesSeveralRepairsInOneSentence() {
        let input = "René legt es bis 13.45 Uhr in Share Point ab, Version 1. 2.0, per A P I."
        #expect(formatter.format(input)
                == "René legt es bis 13:45 Uhr in SharePoint ab, Version 1.2.0, per API.")
    }

    @Test func leavesOrdinaryProseCompletelyUntouched() {
        // The property that matters most: normal speech must survive unchanged.
        let prose = """
        Lass uns mit der Sprint-Planung starten. Oberste Priorität ist das neue \
        Onboarding. Design kann die Screens bis Mittwoch liefern, dann übernimmt \
        die Entwicklung. Eine offene Frage ist noch die Tracking-Freigabe.
        """
        #expect(formatter.format(prose) == prose)
    }

    @Test func doesNotTouchRecognitionErrors() {
        // Explicitly out of scope — a misheard name stays misheard.
        #expect(formatter.format("Rrene arbeitet dort.") == "Rrene arbeitet dort.")
        #expect(formatter.format("Henning und Karl kamen.") == "Henning und Karl kamen.")
    }

    // MARK: - Idempotence

    /// The production path applies the formatter exactly once, but nothing in
    /// the type enforces that, and a retranscription or a re-export must not
    /// drift. Running it twice has to be indistinguishable from running it once.
    @Test func formattingIsIdempotent() {
        let inputs = [
            "Das Treffen ist um 13.45 Uhr.",
            "Wir liefern Version 1. 2.0 aus.",
            "Die AP ist dokumentiert, die K\\letter I\\letter läuft.",
            "Der Kauf läuft über Store Kit und Cloud Kit.",
            "Die Doku liegt in Sharepoint.",
            "Der Export geht nach Mark Down.",
            "René legt es bis 13.45 Uhr in Share Point ab, Version 1. 2.0, per A P I.",
            #"Der Pfad ist C:\Users\rene."#,
            "Ein ganz gewöhnlicher Satz ohne alles.",
            ""
        ]
        for input in inputs {
            let once = formatter.format(input)
            #expect(formatter.format(once) == once, "not idempotent for: \(input)")
        }
    }

    @Test func everyRuleIsIdempotentOnItsOwn() {
        let input = "Um 13.45 Uhr per K\\letter I\\letter über Store Kit, Version 1. 2.0, in Sharepoint."
        for entry in TranscriptSemanticFormatter.ruleScopes {
            let single = TranscriptSemanticFormatter(rules: entry.rule)
            let once = single.format(input)
            #expect(single.format(once) == once, "not idempotent: \(entry.name)")
        }
    }

    // MARK: - Locale scope

    @Test func everyShippedRuleIsClassifiedByLocaleScope() {
        // Guards against a rule being added without saying whether it is
        // language-dependent.
        let classified = TranscriptSemanticFormatter.ruleScopes
            .reduce(into: TranscriptSemanticFormatter.Rules()) { $0.insert($1.rule) }
        #expect(classified == TranscriptSemanticFormatter.Rules.all)
    }

    @Test func clockRuleIsSkippedForUnlistedLanguages() {
        // Locale-gated, not generalised: French gets no rule rather than the
        // German marker.
        let french = TranscriptSemanticFormatter(locale: Locale(identifier: "fr-FR"))
        #expect(french.format("Le rendez-vous est à 13.45 Uhr.") == "Le rendez-vous est à 13.45 Uhr.")
        #expect(french.format("Rendez-vous 13.45 o'clock.") == "Rendez-vous 13.45 o'clock.")
    }

    @Test func localeIndependentRulesApplyInEveryLanguage() {
        let english = TranscriptSemanticFormatter(locale: Locale(identifier: "en-US"))
        #expect(english.format("The purchase goes through Store Kit.")
                == "The purchase goes through StoreKit.")
        #expect(english.format("Exported to Sharepoint.") == "Exported to SharePoint.")
        // Markup stripping is language-independent, and the run joins because
        // no letter here is a word on its own.
        #expect(english.format("The V\\letter P\\letter N\\letter is up.")
                == "The VPN is up.")
    }

    @Test func englishAIIsDeliberatelyNotJoined() {
        // A documented en-US limitation, not an oversight: "A" and "I" are both
        // words on their own, so the ambiguity guard refuses the run. The
        // markup still goes — the user sees "A I", never "A\\letter I\\letter".
        // German "KI" joins because "K" is not a standalone word.
        let english = TranscriptSemanticFormatter(locale: Locale(identifier: "en-US"))
        #expect(english.format("The A\\letter I\\letter runs locally.")
                == "The A I runs locally.")
    }

    // MARK: - Cost

    /// The formatter runs once per finalized segment, including during live
    /// transcription, so its cost has to be negligible against a long
    /// recording. Six regex passes over a segment-sized string should be.
    @Test func formattingALongTranscriptIsCheap() {
        // A one-hour recording at roughly one segment per three seconds.
        let segment = "René legt die CVAG-Unterlagen bis 13.45 Uhr in Share Point ab, " +
                      "Version 1. 2.0 geht über Store Kit und Cloud Kit raus."
        let segments = Array(repeating: segment, count: 1200)

        let start = Date()
        for text in segments { _ = formatter.format(text) }
        let elapsed = Date().timeIntervalSince(start)

        print("PERF formatter 1200 segments in \(String(format: "%.3f", elapsed))s " +
              "(\(String(format: "%.3f", elapsed / 1200 * 1000))ms per segment)")
        // Deliberately loose: this guards against an accidental quadratic
        // rewrite, not against a few milliseconds of drift.
        #expect(elapsed < 2.0)
    }

    @Test func emptyAndWhitespaceInputAreSafe() {
        #expect(formatter.format("") == "")
        #expect(formatter.format("   ") == "   ")
    }
}
