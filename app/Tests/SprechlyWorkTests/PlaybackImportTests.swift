import AVFoundation
import Foundation
import SwiftData
import Testing
@testable import SprechlyWork

/// Reproduces the reported bug: an imported recording (CAF → m4a via the export
/// service) must be openable by the playback engine (`AVAudioPlayer`), exactly
/// like a normal recording.
@MainActor
struct PlaybackImportTests {
    @Test func exportedM4APlaysBack() async throws {
        let caf = AudioTestSupport.tempURL("caf")
        try AudioTestSupport.writeSine(to: caf, amplitude: 0.5, seconds: 1.5, sampleRate: 48_000)
        defer { try? FileManager.default.removeItem(at: caf) }

        let m4a = AudioTestSupport.tempURL("m4a")
        defer { try? FileManager.default.removeItem(at: m4a) }
        try await AudioExportService().export(workingURL: caf, format: .m4a, to: m4a)

        let engine = AudioPlaybackEngine()
        _ = try await engine.load(url: m4a)
        let duration = await engine.duration
        #expect(duration > 1.0)
    }

    @Test func importedRecordingFilePlaysBack() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("voxplay-\(UUID().uuidString)")
        let docs = root.appendingPathComponent("Documents")
        let caches = root.appendingPathComponent("Caches")
        try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = RecordingFileStore(documentsURL: docs, cachesURL: caches)

        let source = AudioTestSupport.tempURL("wav")
        try AudioTestSupport.writeSine(to: source, amplitude: 0.5, seconds: 1.2, sampleRate: 44_100)
        defer { try? FileManager.default.removeItem(at: source) }

        let container = try ModelContainer(
            for: Recording.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let vm = LibraryViewModel(fileStore: store)
        await vm.importRecordings(from: [source], context: container.mainContext)
        let imported = try #require(try container.mainContext.fetch(FetchDescriptor<Recording>()).first)

        let url = store.audioURL(forFileName: imported.fileName)
        let engine = AudioPlaybackEngine()
        _ = try await engine.load(url: url)
        #expect(await engine.duration > 0.8)
    }
}
