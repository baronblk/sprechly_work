import AVFoundation
import Foundation
import Testing
@testable import SprechlyWork

/// Die Entscheidungsregel der Spracherkennung. Läuft ohne Speech-Stack, weil
/// nur der erzeugte Text bewertet wird — die Messung am Gerät steckt in
/// `Benchmark/LanguageDetectionBenchmark.swift`.
@Suite("Spracherkennung")
struct LanguageDetectionTests {
    private let de = Locale(identifier: "de-DE")
    private let en = Locale(identifier: "en-US")

    // MARK: - Kandidaten

    @Test("Je Sprache ein Kandidat, Gerätesprache zuerst")
    func candidatesAreOnePerLanguageInPreferenceOrder() {
        let installed = [Locale(identifier: "de-AT"), de, en, Locale(identifier: "en-GB")]
        let candidates = LanguageDetection.candidates(installed: installed, preferred: ["en-GB", "de-DE"])

        #expect(candidates.count == 2)
        #expect(candidates[0].language.languageCode?.identifier == "en")
        #expect(candidates[1].language.languageCode?.identifier == "de")
    }

    @Test("Mehr Sprachen als die Obergrenze werden abgeschnitten")
    func candidatesAreCapped() {
        let installed = ["de-DE", "en-US", "fr-FR", "es-ES", "it-IT"].map { Locale(identifier: $0) }
        let candidates = LanguageDetection.candidates(installed: installed, preferred: ["de-DE"], limit: 3)

        #expect(candidates.count == 3)
        #expect(candidates.first?.identifier == "de-DE")
    }

    @Test("Eine einzige Sprache lässt nichts zu entscheiden")
    func singleLanguageLeavesNothingToDecide() {
        let installed = [de, Locale(identifier: "de-AT"), Locale(identifier: "de-CH")]
        #expect(LanguageDetection.candidates(installed: installed, preferred: ["de-DE"]).count == 1)
    }

    // MARK: - Regel

    /// Der Kern: das falsche Modell erzeugt Kauderwelsch, das sich nicht als
    /// seine eigene Sprache ausweist. Beide Texte sind echte Ausgaben aus dem
    /// Gerätelauf (`names-01`).
    @Test("Selbstkonsistenz wählt die gesprochene Sprache")
    func selfConsistencyPicksTheSpokenLanguage() {
        let picked = LanguageDetection.pick(from: [
            .init(locale: de, text: "René arbeitet bei der Chemnitzer Verkehrs AG und wohnt in Chemnitz."),
            .init(locale: en, text: "Renee are bited by der kemnitza fakirs agi und voned in kemnitz.")
        ])

        #expect(picked == de)
    }

    @Test("Umgekehrt genauso")
    func alsoTheOtherWayRound() {
        let picked = LanguageDetection.pick(from: [
            .init(locale: de, text: "The Dogs are in sareointan the container runs in Docker today."),
            .init(locale: en, text: "The docs are in SharePoint and the container runs in Docker today.")
        ])

        #expect(picked == en)
    }

    @Test("Zu kurze Proben werden nicht bewertet")
    func shortProbesAreIgnored() {
        #expect(LanguageDetection.pick(from: [.init(locale: de, text: "Ja."), .init(locale: en, text: "Yes.")]) == nil)
    }

    @Test("Ohne selbstkonsistente Probe bleibt es unentschieden")
    func noSelfConsistentProbeMeansUndecided() {
        // Deutscher Text, aber nur das englische Modell hat ihn geliefert.
        let picked = LanguageDetection.pick(from: [
            .init(locale: en, text: "Der Vertrag läuft noch bis zum vierten Oktober dieses Jahres.")
        ])

        #expect(picked == nil)
    }

    @Test("Leere Probenliste ist unentschieden")
    func emptyProbesAreUndecided() {
        #expect(LanguageDetection.pick(from: []) == nil)
    }

    // MARK: - Spracherkennung selbst

    @Test("Dominante Sprache wird samt Konfidenz gemeldet")
    func dominantLanguageIsReported() throws {
        let german = try #require(
            LanguageDetection.dominantLanguage(of: "Der Vertrag läuft noch bis zum vierten Oktober.")
        )
        #expect(german.code == "de")
        #expect(german.confidence > 0.5)
    }
}

/// Wie viel Audio eine Sprachprobe liest. Die Begrenzung ist der Grund, warum
/// kein Analyzer offen bleibt (siehe `SpeechTranscriptionService`).
@Suite("Sprachprobe: Lesegrenze")
struct ProbeFrameLimitTests {
    private let sampleRate = 48_000.0

    @Test("Ohne Grenze wird die ganze Datei gelesen")
    func noLimitReadsEverything() {
        let length = AVAudioFramePosition(600 * sampleRate)  // 10 min
        #expect(
            SpeechTranscriptionService.frameLimit(
                fileLength: length, sampleRate: sampleRate, seconds: nil
            ) == length
        )
    }

    @Test("Aus zehn Minuten werden 25 Sekunden")
    func limitCutsALongFile() {
        let length = AVAudioFramePosition(600 * sampleRate)
        let limit = SpeechTranscriptionService.frameLimit(
            fileLength: length, sampleRate: sampleRate, seconds: 25
        )
        #expect(limit == AVAudioFramePosition(25 * sampleRate))
        #expect(Double(limit) / sampleRate == 25)
    }

    @Test("Eine kürzere Datei bleibt kürzer")
    func limitNeverExceedsTheFile() {
        let length = AVAudioFramePosition(5 * sampleRate)
        #expect(
            SpeechTranscriptionService.frameLimit(
                fileLength: length, sampleRate: sampleRate, seconds: 25
            ) == length
        )
    }

    @Test("Unsinnige Werte lesen lieber alles als nichts")
    func degenerateValuesFallBackToTheWholeFile() {
        let length = AVAudioFramePosition(5 * sampleRate)
        #expect(SpeechTranscriptionService.frameLimit(fileLength: length, sampleRate: sampleRate, seconds: 0) == length)
        #expect(SpeechTranscriptionService.frameLimit(fileLength: length, sampleRate: 0, seconds: 25) == length)
    }
}
