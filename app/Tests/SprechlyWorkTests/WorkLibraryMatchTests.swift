import Foundation
import SoundcoreWorkKit
import SwiftData
import Testing

@testable import SprechlyWork

/// Eine importierte Geräte-Aufnahme muss auch nach einem App-Start als
/// importiert erkannt werden – über die gespeicherte `file_id`, und für
/// ältere Importe über Zeitpunkt und Dauer.
@Suite("Work-Gerät: Zuordnung zur Bibliothek")
@MainActor
struct WorkLibraryMatchTests {
    /// 2026-10-14 13:46:02 UTC, wie das Gerät sie als `file_id` führt.
    private let fileID: UInt32 = 0x6AEE_C34A

    private func deviceRecording(
        _ fileID: UInt32, milliseconds: UInt32 = 45_000
    ) -> D3200Recording {
        D3200Recording(fileID: fileID, durationMilliseconds: milliseconds)
    }

    private func imported(
        from recording: D3200Recording, fileID: Int?
    ) -> Recording {
        Recording(
            title: "Work",
            fileName: "w.m4a",
            duration: recording.duration,
            createdAt: recording.recordedAt,
            workFileID: fileID
        )
    }

    // MARK: - Zuordnung

    @Test("Gespeicherte file_id zählt")
    func matchesByStoredFileID() {
        let device = deviceRecording(fileID)
        let library = [imported(from: device, fileID: Int(fileID))]

        #expect(WorkDeviceViewModel.libraryMatch(for: device, in: library) != nil)
    }

    @Test("Eine andere file_id zählt nicht")
    func doesNotMatchAnotherFileID() {
        let device = deviceRecording(fileID)
        // Gleiche Dauer, aber eine Stunde früher aufgenommen.
        let library = [imported(from: deviceRecording(fileID - 3600), fileID: Int(fileID) - 3600)]

        #expect(WorkDeviceViewModel.libraryMatch(for: device, in: library) == nil)
    }

    @Test("Älterer Import ohne file_id wird über Zeitpunkt und Dauer erkannt")
    func matchesLegacyImportByTimeAndDuration() {
        let device = deviceRecording(fileID)
        let library = [imported(from: device, fileID: nil)]

        #expect(WorkDeviceViewModel.libraryMatch(for: device, in: library) != nil)
    }

    @Test("Gleicher Zeitpunkt, andere Dauer – keine Zuordnung")
    func legacyMatchNeedsTheDuration() {
        let device = deviceRecording(fileID, milliseconds: 45_000)
        let library = [
            Recording(
                title: "Sprachnotiz",
                fileName: "a.m4a",
                duration: 300,
                createdAt: device.recordedAt
            )
        ]

        #expect(WorkDeviceViewModel.libraryMatch(for: device, in: library) == nil)
    }

    @Test("Eine Aufnahme im Papierkorb gilt als nicht importiert")
    func trashedRecordingDoesNotCount() {
        let device = deviceRecording(fileID)
        let recording = imported(from: device, fileID: Int(fileID))
        recording.moveToTrash()

        #expect(WorkDeviceViewModel.libraryMatch(for: device, in: [recording]) == nil)
    }

    // MARK: - Listenzustand

    @Test("Bibliothekstreffer markiert den Eintrag als importiert")
    func libraryMatchMarksAsImported() {
        let id = UUID()
        let state = WorkDeviceViewModel.importState(previous: nil, libraryMatch: id)

        #expect(state == .imported(recordingID: id))
    }

    @Test("Ohne Treffer bleibt der Eintrag importierbar")
    func withoutMatchItStaysImportable() {
        #expect(WorkDeviceViewModel.importState(previous: nil, libraryMatch: nil) == .notImported)
        #expect(
            WorkDeviceViewModel.importState(previous: .imported(recordingID: UUID()), libraryMatch: nil)
                == .notImported
        )
    }

    /// Ein Neuladen während des Downloads darf den Fortschritt nicht
    /// überschreiben, und ein Fehler soll stehen bleiben.
    @Test("Laufender und gescheiterter Import haben Vorrang")
    func runningImportKeepsItsState() {
        #expect(
            WorkDeviceViewModel.importState(previous: .downloading(progress: 0.4), libraryMatch: nil)
                == .downloading(progress: 0.4)
        )
        #expect(
            WorkDeviceViewModel.importState(previous: .converting, libraryMatch: UUID())
                == .converting
        )
        #expect(
            WorkDeviceViewModel.importState(previous: .failed("kaputt"), libraryMatch: nil)
                == .failed("kaputt")
        )
    }

    // MARK: - Nachtragen

    @Test("Nachgetragene file_id übersteht einen Fetch")
    func backfilledFileIDPersists() throws {
        let container = try ModelContainer(
            for: Recording.self, TranscriptSegment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let device = deviceRecording(fileID)
        context.insert(imported(from: device, fileID: nil))
        try context.save()

        let library = try context.fetch(FetchDescriptor<Recording>())
        let match = try #require(WorkDeviceViewModel.libraryMatch(for: device, in: library))
        match.workFileID = Int(device.fileID)
        try context.save()

        let danach = try context.fetch(FetchDescriptor<Recording>())
        #expect(danach.first?.workFileID == Int(fileID))
        // Danach greift der direkte Weg über die file_id.
        #expect(WorkDeviceViewModel.libraryMatch(for: device, in: danach)?.id == match.id)
    }
}
