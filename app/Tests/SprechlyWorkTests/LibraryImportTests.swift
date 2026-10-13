import AVFoundation
import Foundation
import SwiftData
import Testing
@testable import SprechlyWork

@MainActor
struct LibraryImportTests {
    private func makeStore() throws -> (RecordingFileStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("voximport-\(UUID().uuidString)")
        let docs = root.appendingPathComponent("Documents")
        let caches = root.appendingPathComponent("Caches")
        try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
        return (RecordingFileStore(documentsURL: docs, cachesURL: caches), root)
    }

    @Test func importCreatesPlayableRecordingWithWaveform() async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        // A foreign-format source (44.1 kHz) that must be resampled on import.
        let source = AudioTestSupport.tempURL("wav")
        try AudioTestSupport.writeSine(to: source, amplitude: 0.5, seconds: 1.5, sampleRate: 44_100)
        defer { try? FileManager.default.removeItem(at: source) }

        let container = try ModelContainer(
            for: Recording.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let vm = LibraryViewModel(fileStore: store)

        await vm.importRecordings(from: [source], context: container.mainContext)

        #expect(vm.errorMessage == nil)
        #expect(vm.isImporting == false)

        let all = try container.mainContext.fetch(FetchDescriptor<Recording>())
        #expect(all.count == 1)
        let imported = try #require(all.first)
        #expect(imported.title == source.deletingPathExtension().lastPathComponent)
        #expect(abs(imported.duration - 1.5) < 0.05)

        // Final audio is an m4a in Documents, in the recording format.
        #expect(imported.fileName.hasSuffix(".m4a"))
        let audioURL = store.audioURL(forFileName: imported.fileName)
        #expect(FileManager.default.fileExists(atPath: audioURL.path))
        let file = try AVAudioFile(forReading: audioURL)
        #expect(file.processingFormat.sampleRate == RecordingSettings.sampleRate)
        #expect(file.processingFormat.channelCount == RecordingSettings.channelCount)

        // Waveform sidecar generated, and no CAF leftovers in Caches.
        #expect(store.loadPeaks(forRecordingID: imported.id)?.isEmpty == false)
        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: store.cachesURL.path)) ?? []
        #expect(leftovers.filter { $0.hasSuffix(".caf") }.isEmpty)
    }

    @Test func unreadableSourceReportsErrorAndInsertsNothing() async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let missing = AudioTestSupport.tempURL("m4a") // never created
        let container = try ModelContainer(
            for: Recording.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let vm = LibraryViewModel(fileStore: store)

        await vm.importRecordings(from: [missing], context: container.mainContext)

        #expect(vm.errorMessage != nil)
        #expect(try container.mainContext.fetch(FetchDescriptor<Recording>()).isEmpty)
        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: store.cachesURL.path)) ?? []
        #expect(leftovers.isEmpty)
    }
}
