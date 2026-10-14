import AVFoundation
import Foundation
import NaturalLanguage
import Speech
import Testing
@testable import SprechlyWork

/// Lässt sich die gesprochene Sprache einer Aufnahme automatisch bestimmen?
///
/// Der naheliegende Weg — transkribieren und den Text von `NLLanguageRecognizer`
/// einschätzen lassen — trägt einen Denkfehler: Ein deutsches Modell erzeugt aus
/// englischer Sprache deutsch *aussehende* Wörter. Der Erkenner bekäme also
/// kaum die gesprochene, sondern die Modellsprache zu sehen und würde die
/// falsche Wahl bestätigen.
///
/// Gemessen werden deshalb zwei Regeln, die ohne diese Annahme arbeiten. Beide
/// transkribieren dieselbe Datei mit **jeder** Kandidatensprache und
/// entscheiden danach:
///
/// - **A Selbstkonsistenz** — welches Ergebnis hält der Spracherkenner für
///   seine eigene Sprache? Das richtige Modell sollte Text liefern, der sich
///   selbst bestätigt, das falsche Kauderwelsch, das es nicht tut.
/// - **B Modellkonfidenz** — welcher Lauf hat die höhere mittlere
///   `transcriptionConfidence`? Das ist die Einschätzung des Modells selbst.
///
/// Ergebnis ist ein Messprotokoll, kein Pass/Fail: erst die Trefferquote der
/// Regeln entscheidet, ob eine automatische Erkennung in die App gehört.
///
/// Gerät only — der Speech-Stack läuft nicht im Simulator.
@Suite(.serialized)
struct LanguageDetectionBenchmark {
    /// Die Kandidaten, zwischen denen entschieden wird. Beide Modelle müssen
    /// installiert sein, sonst sagt der Lauf nichts aus.
    private let candidates = [Locale(identifier: "de-DE"), Locale(identifier: "en-US")]

    /// Eine Transkription derselben Datei in einer Kandidatensprache.
    struct Probe: Sendable {
        let locale: Locale
        let text: String
        /// Längengewichteter Mittelwert über die Konfidenzen der Runs.
        let meanConfidence: Double
        /// Was `NLLanguageRecognizer` im erzeugten Text sieht.
        let detectedLanguage: String?
        let detectionConfidence: Double

        /// Ob der erzeugte Text sich selbst als die Sprache ausweist, in der er
        /// transkribiert wurde.
        var isSelfConsistent: Bool {
            detectedLanguage != nil && detectedLanguage == locale.language.languageCode?.identifier
        }
    }

    // MARK: - Regeln

    /// A: unter den selbstkonsistenten Läufen der mit der höchsten
    /// Erkennungskonfidenz. Ist keiner selbstkonsistent, bleibt die Regel
    /// unentschieden — das ist ehrlicher als zu raten.
    static func pickBySelfConsistency(_ probes: [Probe]) -> Locale? {
        probes
            .filter(\.isSelfConsistent)
            .max { $0.detectionConfidence < $1.detectionConfidence }?
            .locale
    }

    /// B: der Lauf mit der höheren mittleren Modellkonfidenz.
    static func pickByConfidence(_ probes: [Probe]) -> Locale? {
        probes.max { $0.meanConfidence < $1.meanConfidence }?.locale
    }

    // MARK: - Messung

    @Test func detectSpokenLanguage() async throws {
        for candidate in candidates {
            guard await BenchmarkSpeech.isAvailable(for: candidate) else {
                print("LANGDETECT SKIPPED: \(candidate.identifier) nicht verfügbar")
                return
            }
        }

        var selfConsistencyHits = 0
        var confidenceHits = 0
        var undecided = 0
        var measured = 0

        for testCase in BenchmarkCorpus.all {
            guard let url = BenchmarkSpeech.fixtureURL(for: testCase.id) else {
                print("LANGDETECT \(testCase.id): keine Fixture")
                continue
            }
            let truth = testCase.locale.language.languageCode?.identifier

            var probes: [Probe] = []
            for candidate in candidates {
                probes.append(try await Self.probe(url: url, locale: candidate))
            }
            measured += 1

            let byConsistency = Self.pickBySelfConsistency(probes)
            let byConfidence = Self.pickByConfidence(probes)
            if byConsistency == nil { undecided += 1 }
            if byConsistency?.language.languageCode?.identifier == truth { selfConsistencyHits += 1 }
            if byConfidence?.language.languageCode?.identifier == truth { confidenceHits += 1 }

            print("LANGDETECT \(testCase.id) gesprochen=\(truth ?? "?") "
                + "A=\(byConsistency?.identifier ?? "unentschieden") "
                + "B=\(byConfidence?.identifier ?? "-")")
            for probe in probes {
                print(String(
                    format: "  %@ konfidenz=%.3f erkannt=%@ (%.3f) selbstkonsistent=%@ text=%@",
                    probe.locale.identifier,
                    probe.meanConfidence,
                    probe.detectedLanguage ?? "-",
                    probe.detectionConfidence,
                    probe.isSelfConsistent ? "ja" : "nein",
                    probe.text.prefix(90).description
                ))
            }
        }

        guard measured > 0 else {
            print("LANGDETECT SKIPPED: keine Fälle gemessen")
            return
        }
        print("LANGDETECT SUMME Fälle=\(measured) "
            + "A-Treffer=\(selfConsistencyHits) (unentschieden=\(undecided)) "
            + "B-Treffer=\(confidenceHits)")
    }

    /// Transkribiert `url` in `locale` und bewertet das Ergebnis.
    ///
    /// Der Zuführungsweg ist derselbe wie in `SpeechTranscriptionService`, nur
    /// die Konfidenz-Attribute kommen hinzu — sonst würde der Messaufbau selbst
    /// zur Variablen.
    static func probe(url: URL, locale: Locale) async throws -> Probe {
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: [.transcriptionConfidence]
        )
        let analyzer = SpeechAnalyzer(modules: [transcriber])

        let collecting = Task { () -> (String, Double) in
            var parts: [String] = []
            var weighted = 0.0
            var characters = 0
            for try await result in transcriber.results {
                let text = String(result.text.characters)
                guard !text.isEmpty else { continue }
                parts.append(text)
                for run in result.text.runs {
                    guard let confidence = run.transcriptionConfidence else { continue }
                    let length = result.text[run.range].characters.count
                    weighted += confidence * Double(length)
                    characters += length
                }
            }
            let mean = characters > 0 ? weighted / Double(characters) : 0
            return (parts.joined(separator: " "), mean)
        }

        let file = try AVAudioFile(forReading: url)
        let analysisFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        try await analyzer.start(inputSequence: stream)
        try BenchmarkFeeder.feed(file: file, to: continuation, analysisFormat: analysisFormat)
        continuation.finish()
        try await analyzer.finalizeAndFinishThroughEndOfInput()
        let (text, meanConfidence) = try await collecting.value

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let hypotheses = recognizer.languageHypotheses(withMaximum: 1)
        let best = hypotheses.max { $0.value < $1.value }

        return Probe(
            locale: locale,
            text: text,
            meanConfidence: meanConfidence,
            detectedLanguage: best?.key.rawValue,
            detectionConfidence: best?.value ?? 0
        )
    }
}
