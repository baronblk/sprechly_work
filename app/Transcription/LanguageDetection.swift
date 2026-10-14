import Foundation
import NaturalLanguage

/// Erkennt die gesprochene Sprache einer Aufnahme, indem sie einen kurzen
/// Anfang in mehreren Sprachen probeweise transkribiert und die Ergebnisse
/// vergleicht.
///
/// **Warum nicht einfach den Text einschätzen lassen?** Ein deutsches Modell
/// erzeugt aus englischer Sprache deutsch *aussehende* Wörter — der
/// Spracherkenner würde die falsche Wahl bestätigen. Entschieden wird deshalb
/// über **Selbstkonsistenz**: Nur der Lauf, dessen Text sich selbst als die
/// Sprache ausweist, in der er transkribiert wurde, gilt; bei mehreren
/// entscheidet die Erkennungskonfidenz.
///
/// Am Gerät gemessen (30 Fälle, Deutsch und Englisch, `LanguageDetectionBenchmark`):
/// Selbstkonsistenz 30/30, die Modellkonfidenz allein nur 28/30. Gemessen wurde
/// mit synthetischer Sprache und zwei Kandidaten — für nah verwandte Sprachen
/// (etwa Deutsch/Niederländisch) liegt keine Messung vor.
enum LanguageDetection {
    /// Wie viel Audio die Probe liest. Länger kostet nur Zeit: die Sprache
    /// steht nach wenigen Sätzen fest.
    static let probeWindow: TimeInterval = 25

    /// Wie viele Sprachen höchstens probiert werden. Jeder Kandidat ist ein
    /// eigener Transkriptionslauf, deshalb eine harte Obergrenze.
    static let maximumCandidates = 3

    /// Kürzester Probetext, der eine Einschätzung wert ist. Zwei Wörter sagen
    /// über die Sprache nichts.
    static let minimumProbeCharacters = 25

    /// Eine probeweise Transkription.
    struct Probe: Sendable, Equatable {
        let locale: Locale
        let text: String

        init(locale: Locale, text: String) {
            self.locale = locale
            self.text = text
        }
    }

    /// Die Sprachen, die eine Probe wert sind: eine je Sprache (Regionen
    /// unterscheiden sich im Klang nicht genug, um sie so zu trennen), in der
    /// Reihenfolge der Gerätesprachen, dann der Rest.
    static func candidates(
        installed: [Locale],
        preferred: [String] = Locale.preferredLanguages,
        limit: Int = maximumCandidates
    ) -> [Locale] {
        var byLanguage: [String: Locale] = [:]
        var order: [String] = []

        func add(_ locale: Locale) {
            guard let code = locale.language.languageCode?.identifier else { return }
            if byLanguage[code] == nil {
                byLanguage[code] = locale
                order.append(code)
            }
        }

        // Gerätesprachen zuerst – die sind am wahrscheinlichsten.
        for language in preferred {
            let code = Locale(identifier: language).language.languageCode?.identifier
            if let match = installed.first(where: { $0.language.languageCode?.identifier == code }) {
                add(match)
            }
        }
        for locale in installed { add(locale) }

        return order.prefix(limit).compactMap { byLanguage[$0] }
    }

    /// Wählt die Sprache aus den Proben. `nil` heißt unentschieden — dann
    /// bleibt es bei der bisherigen Wahl, statt zu raten.
    static func pick(from probes: [Probe]) -> Locale? {
        probes
            .compactMap { probe -> (locale: Locale, confidence: Double)? in
                guard probe.text.count >= minimumProbeCharacters,
                      let own = probe.locale.language.languageCode?.identifier,
                      let dominant = dominantLanguage(of: probe.text),
                      dominant.code == own
                else { return nil }
                return (probe.locale, dominant.confidence)
            }
            .max { $0.confidence < $1.confidence }?
            .locale
    }

    /// Die wahrscheinlichste Sprache eines Textes samt Konfidenz.
    static func dominantLanguage(of text: String) -> (code: String, confidence: Double)? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let best = recognizer.languageHypotheses(withMaximum: 1).max(by: { $0.value < $1.value })
        else { return nil }
        return (best.key.rawValue, best.value)
    }
}
