import Foundation
import SwiftData
import Testing
@testable import VoxStudio

/// The migration rewrites text the user already has, so its restraint matters
/// more than its reach: it must fix the marker bug and change nothing else.
@MainActor
struct TranscriptMarkupRepairTests {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Recording.self, TranscriptSegment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        return ModelContext(container)
    }

    private func insert(_ texts: [String], into context: ModelContext) throws -> Recording {
        let recording = Recording(title: "Test", fileName: "t.m4a", duration: 1)
        context.insert(recording)
        for (index, text) in texts.enumerated() {
            context.insert(TranscriptSegment(
                text: text,
                startTime: Double(index),
                endTime: Double(index) + 1,
                recording: recording
            ))
        }
        try context.save()
        return recording
    }

    private func texts(in context: ModelContext) throws -> [String] {
        try context.fetch(FetchDescriptor<TranscriptSegment>())
            .sorted { $0.startTime < $1.startTime }
            .map(\.text)
    }

    @Test func joinsMarkedLetterRuns() throws {
        let context = try makeContext()
        _ = try insert(["Die K\\letter I\\letter läuft lokal."], into: context)

        let repaired = TranscriptMarkupRepair.run(in: context)

        #expect(repaired == 1)
        #expect(try texts(in: context) == ["Die KI läuft lokal."])
    }

    @Test func joinsRunsOfAnyLength() {
        #expect(TranscriptMarkupRepair.repair("Die K\\letter I\\letter läuft.")
                == "Die KI läuft.")
        #expect(TranscriptMarkupRepair.repair("Zugriff per V\\letter P\\letter N\\letter.")
                == "Zugriff per VPN.")
        #expect(TranscriptMarkupRepair.repair("Das M\\letter D\\letter M\\letter verwaltet.")
                == "Das MDM verwaltet.")
    }

    @Test func leavesUnmarkedLetterSequencesAlone() {
        // The decisive boundary: the join follows Apple's marker, never a shape.
        // An unmarked letter sequence in old text is the user's text.
        #expect(TranscriptMarkupRepair.repair("Die K I bleibt so.") == "Die K I bleibt so.")
        #expect(TranscriptMarkupRepair.repair("A B C folgt.") == "A B C folgt.")
        #expect(TranscriptMarkupRepair.repair("Die A P I ist dokumentiert.")
                == "Die A P I ist dokumentiert.")
    }

    @Test func keepsALoneMarkedLetterAsThatLetter() {
        #expect(TranscriptMarkupRepair.repair("Das A\\letter Ende.") == "Das A Ende.")
        #expect(TranscriptMarkupRepair.repair("Das A\\letter  Ende.") == "Das A Ende.")
    }

    @Test func joinsOnlyTheMarkedPartOfAMixedSequence() {
        // Apple marked K but not I, so only K is resolved — the join does not
        // reach past the marker.
        #expect(TranscriptMarkupRepair.repair("Die K\\letter I bleibt.") == "Die K I bleibt.")
    }

    @Test func leavesSegmentsWithoutTheMarkerCharacterIdentical() throws {
        let context = try makeContext()
        // Deliberately full of things the formatter *would* change if it ran.
        let untouched = [
            "Das Treffen ist um 13.45 Uhr.",
            "Wir liefern Version 1. 2.0 aus.",
            "Der Kauf läuft über Store Kit.",
            "Die Doku liegt in Sharepoint.",
            "Der Export geht nach Mark Down.",
            "Die A P I ist dokumentiert.",
            "Das M D M verwaltet Geräte."
        ]
        _ = try insert(untouched, into: context)

        let repaired = TranscriptMarkupRepair.run(in: context)

        #expect(repaired == 0)
        #expect(try texts(in: context) == untouched)
    }

    @Test func appliesOnlyTheMarkerFixToAffectedSegments() throws {
        let context = try makeContext()
        // The decisive case: one segment carries the marker *and* every other
        // repairable pattern. Only the marker may go — the rest is the user's
        // existing text and must not be reformatted retroactively.
        _ = try insert(
            ["Um 13.45 Uhr per K\\letter I\\letter über Store Kit, Version 1. 2.0, in Sharepoint."],
            into: context
        )

        #expect(TranscriptMarkupRepair.run(in: context) == 1)
        #expect(try texts(in: context)
                == ["Um 13.45 Uhr per KI über Store Kit, Version 1. 2.0, in Sharepoint."])
    }

    @Test func leavesOrdinaryBackslashesAlone() throws {
        let context = try makeContext()
        let paths = [
            #"Der Pfad ist C:\Users\rene\Dokumente."#,
            #"Ein Zeilenumbruch ist \n im Code."#,
            #"Schreib \begin{document} an den Anfang."#,
            #"Die \letters sind gemeint."#,
            #"Im \letterbox lag Post."#
        ]
        _ = try insert(paths, into: context)

        #expect(TranscriptMarkupRepair.run(in: context) == 0)
        #expect(try texts(in: context) == paths)
    }

    @Test func isIdempotent() throws {
        let context = try makeContext()
        _ = try insert(["Die K\\letter I\\letter läuft.", "Ein normaler Satz."], into: context)

        #expect(TranscriptMarkupRepair.run(in: context) == 1)
        let afterFirst = try texts(in: context)
        #expect(afterFirst.first == "Die KI läuft.")
        // A second pass finds nothing, because the filter is the marker itself.
        #expect(TranscriptMarkupRepair.run(in: context) == 0)
        #expect(try texts(in: context) == afterFirst)
    }

    @Test func repairsOnlyTheAffectedSegmentsOfAMixedSet() throws {
        let context = try makeContext()
        _ = try insert([
            "Ein normaler Satz.",
            "Die K\\letter I\\letter läuft.",
            "Noch ein normaler Satz.",
            "Zugriff per V\\letter P\\letter N\\letter."
        ], into: context)

        #expect(TranscriptMarkupRepair.run(in: context) == 2)
        #expect(try texts(in: context) == [
            "Ein normaler Satz.",
            "Die KI läuft.",
            "Noch ein normaler Satz.",
            "Zugriff per VPN."
        ])
    }

    @Test func emptyStoreIsSafe() throws {
        let context = try makeContext()
        #expect(TranscriptMarkupRepair.run(in: context) == 0)
    }
}
