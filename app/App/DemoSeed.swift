#if DEBUG
import AVFoundation
import Foundation
import SwiftData

/// Seeds an isolated **in-memory** store with polished demo recordings for App
/// Store screenshots and local demos. Triggered by the `SEED_DEMO` launch
/// argument. Never touches the real on-disk store or iCloud (CloudKit is off on
/// the in-memory container), so it can't pollute the user's library.
enum DemoSeed {
    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("SEED_DEMO")
    }

    private struct Sample {
        let title: String
        let minutesAgo: Int
        let duration: TimeInterval
        let aiTitle: String?
        let summary: String?
        /// Optional stored translation. The transcript view restores a
        /// persisted translation on open, so seeding it shows the real card
        /// with real content — the same mechanism as the seeded transcript.
        var translation: String? = nil
        var translationLanguageCode: String? = nil
        let segments: [(text: String, start: TimeInterval, end: TimeInterval)]
    }

    static func populate(_ context: ModelContext) {
        let store = RecordingFileStore()
        for sample in samples {
            let fileName = "demo-\(UUID().uuidString).m4a"
            try? writeTone(to: store.audioURL(forFileName: fileName), seconds: sample.duration)
            let recording = Recording(
                title: sample.title,
                fileName: fileName,
                duration: sample.duration,
                createdAt: Date(timeIntervalSinceNow: -Double(sample.minutesAgo) * 60),
                aiTitle: sample.aiTitle,
                summary: sample.summary
            )
            // Set after construction: the initializer does not take these, and
            // widening it would be a change to production code for a demo-only
            // need.
            recording.translation = sample.translation
            recording.translationLanguageCode = sample.translationLanguageCode
            context.insert(recording)
            for segment in sample.segments {
                context.insert(TranscriptSegment(
                    text: segment.text,
                    startTime: segment.start,
                    endTime: segment.end,
                    recording: recording
                ))
            }
        }
        try? context.save()
    }

    /// A short amplitude-modulated tone so the waveform has a natural shape.
    private static func writeTone(to url: URL, seconds: TimeInterval) throws {
        let file = try AVAudioFile(forWriting: url, settings: RecordingSettings.encoderSettings)
        let format = file.processingFormat
        let sampleRate = Float(format.sampleRate)
        let total = AVAudioFrameCount(seconds * Double(sampleRate))
        let chunk: AVAudioFrameCount = 4_800
        var written: AVAudioFrameCount = 0
        var phase: Float = 0
        let twoPi = 2 * Float.pi
        while written < total {
            let count = min(chunk, total - written)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count),
                  let channel = buffer.floatChannelData?[0] else { break }
            buffer.frameLength = count
            for i in 0..<Int(count) {
                let t = Float(written + AVAudioFrameCount(i)) / sampleRate
                let envelope = 0.28 * (0.55 + 0.45 * sinf(twoPi * 0.4 * t))
                channel[i] = envelope * sinf(phase)
                phase += twoPi * 190 / sampleRate
                if phase > twoPi { phase -= twoPi }
            }
            try file.write(from: buffer)
            written += count
        }
    }

    /// Localized demo content so screenshots match the chosen language.
    private static var samples: [Sample] {
        (Locale.preferredLanguages.first ?? "de").hasPrefix("en") ? englishSamples : germanSamples
    }

    private static let englishSamples: [Sample] = [
        // Carries the hero shot: deliberately **without** an AI title or
        // summary, so the transcript view opens straight onto timestamps. With
        // a summary the AI block sits above the transcript — and the headline
        // promises writing along, not summarising. Long enough to fill the
        // screen without scrolling.
        Sample(
            title: "Project status – notes",
            minutesAgo: 0,
            duration: 93,
            aiTitle: nil,
            summary: nil,
            segments: [
                ("A quick project status so nothing gets lost.", 0, 5),
                ("The rework of the import feature has been done since yesterday.", 5, 12),
                ("Two test devices arrived, the third one comes next week.", 12, 19),
                ("Feedback from the beta round was positive throughout.", 19, 26),
                ("Still open is the decision on language selection for export.", 26, 33),
                ("I suggest we settle that in the next meeting directly.", 33, 40),
                ("I brought the documentation up to the current state.", 40, 47),
                ("One point we should not forget is accessibility.", 47, 54),
                ("For that I still need an hour with someone from design.", 54, 62),
                ("That is it for now, I will report back at the end of the week.", 62, 71),
                ("One more thing: Friday's meeting stands.", 71, 77),
                ("I will send the agenda round before it.", 77, 83),
                ("Please take a quick look beforehand.", 83, 88),
                ("That way we get through it faster.", 88, 93)
            ]
        ),
        Sample(
            title: "Team meeting – Sprint planning",
            minutesAgo: 12,
            duration: 64,
            aiTitle: "Sprint planning: focus on onboarding",
            summary: """
            **Key points:** The team prioritizes the new onboarding for the next \
            iteration. Design delivers the screens by Wednesday, engineering \
            starts right after.

            - Finish the onboarding flow by the end of the sprint
            - Open question: clarify the tracking opt-in
            - Next review on Friday
            """,
            translation: """
            Lass uns mit der Sprint-Planung starten. Oberste Priorität ist das neue Onboarding.
            Design kann die Screens bis Mittwoch liefern, dann übernimmt die Entwicklung.
            Eine offene Frage ist noch die Tracking-Freigabe, das klären wir bis Donnerstag.
            """,
            translationLanguageCode: "de",
            segments: [
                ("Let's start with sprint planning. Top priority is the new onboarding.", 0, 6),
                ("Design can deliver the screens by Wednesday, then engineering takes over.", 6, 13),
                ("One open question is the tracking opt-in; we'll clarify that by Thursday.", 13, 19),
                ("We should pull the library import into the same sprint.", 19, 26),
                ("Agreed, but only once the onboarding flow is in place.", 26, 32),
                ("The test devices are ordered; two of them arrive this week.", 32, 39),
                ("For translation we still need a decision on which languages ship.", 39, 46),
                ("Proposal: start with German and English, add more later.", 46, 53),
                ("Let's note that down and check it in the next review.", 53, 59),
                ("Great, let's do the review on Friday. Thanks everyone.", 59, 64)
            ]
        ),
        Sample(
            title: "Interview – Heat & health",
            minutesAgo: 95,
            duration: 31,
            aiTitle: "Interview: heat and health",
            summary: """
            A conversation with a physician about the effects of heat on the body \
            and how clinics and patients can prepare.
            """,
            segments: [
                ("Today I'm talking about heat and what it means for our health.", 0, 7),
                ("My guest is a physician and researcher focused on heat and health.", 7, 15),
                ("Which bodily functions are most affected on hot days?", 15, 22),
                ("It's wide-ranging — the body constantly tries to shed the heat.", 22, 31)
            ]
        ),
        Sample(
            title: "Podcast idea – note",
            minutesAgo: 240,
            duration: 11,
            aiTitle: nil,
            summary: nil,
            segments: [
                ("Idea for the next episode: record short interviews on the go.", 0, 6),
                ("Then transcribe automatically and have the key points summarized.", 6, 11)
            ]
        ),
        Sample(
            title: "Voice note – shopping list",
            minutesAgo: 1_440,
            duration: 7,
            aiTitle: nil,
            summary: nil,
            segments: []
        )
    ]

    private static let germanSamples: [Sample] = [
        // Trägt das Hero-Motiv: bewusst **ohne** KI-Titel und Zusammenfassung,
        // damit die Transkriptansicht in natürlicher Startposition direkt mit
        // Zeitstempeln beginnt. Mit Zusammenfassung stünde der KI-Block über
        // dem Transkript — und die Headline verspricht das Mitschreiben, nicht
        // das Zusammenfassen. Lang genug, dass der Bildschirm ohne Scrollen
        // gefüllt ist.
        Sample(
            title: "Projektstand – Notizen",
            minutesAgo: 0,
            duration: 93,
            aiTitle: nil,
            summary: nil,
            segments: [
                ("Kurzer Projektstand, damit nichts verloren geht.", 0, 5),
                ("Die Umstellung der Importfunktion ist seit gestern fertig.", 5, 12),
                ("Zwei Testgeräte sind angekommen, das dritte kommt nächste Woche.", 12, 19),
                ("Die Rückmeldungen aus dem Betatest waren durchweg positiv.", 19, 26),
                ("Offen ist noch die Entscheidung zur Sprachauswahl beim Export.", 26, 33),
                ("Ich schlage vor, wir klären das direkt im nächsten Termin.", 33, 40),
                ("Die Dokumentation habe ich auf den aktuellen Stand gebracht.", 40, 47),
                ("Einen Punkt sollten wir nicht vergessen: die Barrierefreiheit.", 47, 54),
                ("Dafür brauche ich noch eine Stunde mit jemandem aus dem Design.", 54, 62),
                ("Das war es fürs Erste, ich melde mich Ende der Woche wieder.", 62, 71),
                ("Nachtrag: der Termin am Freitag bleibt.", 71, 77),
                ("Die Agenda schicke ich vorher herum.", 77, 83),
                ("Bitte vorher kurz reinschauen.", 83, 88),
                ("Dann sind wir schneller durch.", 88, 93)
            ]
        ),
        Sample(
            title: "Teammeeting – Sprint-Planung",
            minutesAgo: 12,
            duration: 64,
            aiTitle: "Sprint-Planung: Fokus Onboarding",
            summary: """
            **Kernpunkte:** Das Team priorisiert das neue Onboarding für die \
            nächste Iteration. Design liefert die Screens bis Mittwoch, \
            Entwicklung startet danach.

            - Onboarding-Flow bis Sprint-Ende fertigstellen
            - Offene Frage: Tracking-Freigabe noch klären
            - Nächstes Review am Freitag
            """,
            translation: """
            Let's start with sprint planning. Top priority is the new onboarding.
            Design can deliver the screens by Wednesday, then engineering takes over.
            One open question is the tracking opt-in; we'll clarify that by Thursday.
            """,
            translationLanguageCode: "en",
            segments: [
                ("Lass uns mit der Sprint-Planung starten. Oberste Priorität ist das neue Onboarding.", 0, 6),
                ("Design kann die Screens bis Mittwoch liefern, dann übernimmt die Entwicklung.", 6, 13),
                ("Eine offene Frage ist noch die Tracking-Freigabe, das klären wir bis Donnerstag.", 13, 19),
                ("Wir sollten den Import aus der Mediathek im selben Sprint mitnehmen.", 19, 26),
                ("Einverstanden, aber nur wenn der Onboarding-Flow vorher steht.", 26, 32),
                ("Die Testgeräte sind bestellt, zwei davon kommen schon diese Woche an.", 32, 39),
                ("Für die Übersetzung brauchen wir noch eine Entscheidung zu den Sprachen.", 39, 46),
                ("Vorschlag: wir starten mit Deutsch und Englisch und ergänzen später.", 46, 53),
                ("Dann halten wir das so fest und prüfen es im nächsten Review.", 53, 59),
                ("Gut, dann machen wir das Review am Freitag. Danke euch.", 59, 64)
            ]
        ),
        Sample(
            title: "Interview – Hitze & Gesundheit",
            minutesAgo: 95,
            duration: 31,
            aiTitle: "Interview: Hitze und Gesundheit",
            summary: """
            Gespräch mit einer Ärztin über die Auswirkungen von Hitze auf den \
            Körper und wie sich Kliniken und Patienten vorbereiten können.
            """,
            segments: [
                ("Heute spreche ich über Hitze und was sie für unsere Gesundheit bedeutet.", 0, 7),
                ("Mein Gast ist Ärztin und Forscherin mit dem Schwerpunkt Hitze und Gesundheit.", 7, 15),
                ("Auf welche Körperfunktionen wirken sich heiße Tage besonders aus?", 15, 22),
                ("Das ist vielfältig – der Körper versucht ständig, die Hitze abzugeben.", 22, 31)
            ]
        ),
        Sample(
            title: "Podcast-Idee – Notiz",
            minutesAgo: 240,
            duration: 11,
            aiTitle: nil,
            summary: nil,
            segments: [
                ("Idee für die nächste Folge: kurze Interviews direkt unterwegs aufnehmen.", 0, 6),
                ("Danach automatisch transkribieren und die Kernpunkte zusammenfassen lassen.", 6, 11)
            ]
        ),
        Sample(
            title: "Sprachnotiz – Einkaufsliste",
            minutesAgo: 1_440,
            duration: 7,
            aiTitle: nil,
            summary: nil,
            segments: []
        )
    ]
}
#endif
