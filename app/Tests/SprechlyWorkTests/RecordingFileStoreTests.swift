import Foundation
import Testing
@testable import VoxStudio

struct RecordingFileStoreTests {
    private func makeStore() throws -> (RecordingFileStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("voxstore-\(UUID().uuidString)")
        let docs = root.appendingPathComponent("Documents")
        let caches = root.appendingPathComponent("Caches")
        try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
        return (RecordingFileStore(documentsURL: docs, cachesURL: caches), root)
    }

    @Test func resolvesRelativeFileNameToDocuments() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = store.audioURL(forFileName: "clip.m4a")
        #expect(url == store.documentsURL.appendingPathComponent("clip.m4a"))
    }

    @Test func finalizeMovesTemporaryIntoDocuments() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let (tempURL, fileName) = store.makeRecordingTarget()
        try Data("audio".utf8).write(to: tempURL)

        try store.finalize(temporaryURL: tempURL, fileName: fileName)

        #expect(!FileManager.default.fileExists(atPath: tempURL.path))
        #expect(FileManager.default.fileExists(atPath: store.audioURL(forFileName: fileName).path))
    }

    @Test func deleteRemovesAudioAndSidecar() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let id = UUID()
        let fileName = "clip.m4a"
        try Data("audio".utf8).write(to: store.audioURL(forFileName: fileName))
        store.savePeaks([WaveformBucket(min: -1, max: 1, rms: 0.5)], forRecordingID: id)

        // Both exist before delete.
        #expect(FileManager.default.fileExists(atPath: store.audioURL(forFileName: fileName).path))
        #expect(FileManager.default.fileExists(atPath: store.sidecarURL(forRecordingID: id).path))

        store.delete(fileName: fileName, recordingID: id)

        // No orphans after delete.
        #expect(!FileManager.default.fileExists(atPath: store.audioURL(forFileName: fileName).path))
        #expect(!FileManager.default.fileExists(atPath: store.sidecarURL(forRecordingID: id).path))
    }

    @Test func peaksRoundTripThroughSidecar() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let id = UUID()
        let peaks = [
            WaveformBucket(min: -0.5, max: 0.5, rms: 0.4),
            WaveformBucket(min: -1, max: 1, rms: 0.7)
        ]
        store.savePeaks(peaks, forRecordingID: id)
        #expect(store.loadPeaks(forRecordingID: id) == peaks)
    }
}
