import Foundation
import SwiftData
import Testing
@testable import SprechlyWork

/// The reconciler runs on every launch, foreground and remote change, so its
/// two directions (file → `audioData`, `audioData` → file) have to hold up over
/// a whole library, not just one row.
@MainActor
struct CloudAudioReconcilerTests {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Recording.self, TranscriptSegment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// Writes `count` bytes of audio-ish payload to the store's Documents dir.
    @discardableResult
    private func writeFile(_ store: RecordingFileStore, name: String, bytes: Int) throws -> URL {
        let url = store.audioURL(forFileName: name)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Data(repeating: 0xAB, count: bytes).write(to: url)
        return url
    }

    @Test func localFileIsLoadedIntoAudioDataForUpload() async throws {
        let container = try makeContainer()
        let store = RecordingFileStore()
        let name = "\(UUID().uuidString).m4a"
        try writeFile(store, name: name, bytes: 2_048)
        defer { store.delete(fileName: name, recordingID: UUID()) }

        let recording = Recording(title: "R", fileName: name, duration: 1)
        container.mainContext.insert(recording)
        try container.mainContext.save()

        await CloudAudioReconciler.reconcileNow(container: container)

        let fetched = try #require(
            try container.mainContext.fetch(FetchDescriptor<Recording>()).first
        )
        #expect(fetched.audioData?.count == 2_048)
    }

    @Test func syncedAudioDataIsWrittenBackToDisk() async throws {
        let container = try makeContainer()
        let store = RecordingFileStore()
        let name = "\(UUID().uuidString).m4a"
        let url = store.audioURL(forFileName: name)
        defer { store.delete(fileName: name, recordingID: UUID()) }
        #expect(!FileManager.default.fileExists(atPath: url.path))

        // Arrived from another device: blob present, no local file yet.
        let recording = Recording(title: "R", fileName: name, duration: 1)
        recording.audioData = Data(repeating: 0xCD, count: 1_024)
        container.mainContext.insert(recording)
        try container.mainContext.save()

        await CloudAudioReconciler.reconcileNow(container: container)

        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(try Data(contentsOf: url).count == 1_024)
    }

    @Test func everyRecordingIsReconciledNotJustTheFirst() async throws {
        let container = try makeContainer()
        let store = RecordingFileStore()
        var names: [String] = []
        for index in 0..<5 {
            let name = "\(UUID().uuidString).m4a"
            names.append(name)
            try writeFile(store, name: name, bytes: 512 + index)
            let recording = Recording(title: "R\(index)", fileName: name, duration: 1)
            container.mainContext.insert(recording)
        }
        try container.mainContext.save()
        defer { for name in names { store.delete(fileName: name, recordingID: UUID()) } }

        await CloudAudioReconciler.reconcileNow(container: container)

        let all = try container.mainContext.fetch(FetchDescriptor<Recording>())
        #expect(all.count == 5)
        // Per-recording saves must not stop the sweep partway through.
        #expect(all.allSatisfy { $0.audioData != nil })
    }

    @Test func recordingWithoutFileNameIsSkipped() async throws {
        let container = try makeContainer()
        let recording = Recording(title: "R", fileName: "", duration: 1)
        container.mainContext.insert(recording)
        try container.mainContext.save()

        await CloudAudioReconciler.reconcileNow(container: container)

        let fetched = try #require(
            try container.mainContext.fetch(FetchDescriptor<Recording>()).first
        )
        #expect(fetched.audioData == nil)
    }

    @Test func missingFileAndNoBlobIsLeftAlone() async throws {
        let container = try makeContainer()
        let recording = Recording(title: "R", fileName: "\(UUID().uuidString).m4a", duration: 1)
        container.mainContext.insert(recording)
        try container.mainContext.save()

        // Neither side has data — the sweep must not crash or invent content.
        await CloudAudioReconciler.reconcileNow(container: container)

        let fetched = try #require(
            try container.mainContext.fetch(FetchDescriptor<Recording>()).first
        )
        #expect(fetched.audioData == nil)
    }
}
