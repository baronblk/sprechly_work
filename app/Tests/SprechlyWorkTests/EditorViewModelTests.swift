import AVFoundation
import Foundation
import SwiftData
import Testing
@testable import SprechlyWork

@MainActor
struct EditorViewModelTests {
    private func makeStore() throws -> (RecordingFileStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("voxedit-\(UUID().uuidString)")
        let docs = root.appendingPathComponent("Documents")
        let caches = root.appendingPathComponent("Caches")
        try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
        return (RecordingFileStore(documentsURL: docs, cachesURL: caches), root)
    }

    @Test func saveCreatesNewRecordingNonDestructivelyWithoutOrphans() async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let sourceName = "src.caf"
        try AudioTestSupport.writeSine(to: store.audioURL(forFileName: sourceName), amplitude: 0.3, seconds: 1)

        let container = try ModelContainer(
            for: Recording.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let source = Recording(title: "Test", fileName: sourceName, duration: 1)
        container.mainContext.insert(source)
        try container.mainContext.save()

        let vm = EditorViewModel(recording: source, fileStore: store)
        vm.configure(modelContext: container.mainContext)
        vm.speed = 2.0
        vm.normalize = true
        vm.format = .m4a

        await vm.save()

        #expect(vm.phase == .done)
        let exported = try #require(vm.exportedURL)
        #expect(FileManager.default.fileExists(atPath: exported.path))

        let all = try container.mainContext.fetch(FetchDescriptor<Recording>())
        #expect(all.count == 2)
        let edited = try #require(all.first { $0.title.hasSuffix("(bearbeitet)") })
        #expect(edited.fileName != sourceName)

        // Non-destructive: the original file is untouched.
        #expect(FileManager.default.fileExists(atPath: store.audioURL(forFileName: sourceName).path))

        // No orphans: no intermediate .caf working/speed files left in Caches.
        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: store.cachesURL.path)) ?? []
        #expect(leftovers.filter { $0.hasSuffix(".caf") }.isEmpty)
    }

    @Test func keepSelectionThenSaveProducesTrimmedRecording() async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let sourceName = "src.caf"
        try AudioTestSupport.writeSine(to: store.audioURL(forFileName: sourceName), amplitude: 0.3, seconds: 2)

        let container = try ModelContainer(
            for: Recording.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let source = Recording(title: "Test", fileName: sourceName, duration: 2)
        container.mainContext.insert(source)
        try container.mainContext.save()

        let vm = EditorViewModel(recording: source, fileStore: store)
        vm.configure(modelContext: container.mainContext)
        vm.trimStart = 0.5
        vm.trimEnd = 1.5
        vm.normalize = false
        vm.format = .wav

        await vm.keepSelection()
        #expect(abs(vm.duration - 1.0) <= 0.05)
        await vm.save()

        #expect(vm.phase == .done)
        let all = try container.mainContext.fetch(FetchDescriptor<Recording>())
        let edited = try #require(all.first { $0.title.hasSuffix("(bearbeitet)") })
        #expect(abs(edited.duration - 1.0) <= max(0.05, 1.0 * 0.02))
        #expect(FileManager.default.fileExists(atPath: store.audioURL(forFileName: sourceName).path))
        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: store.cachesURL.path)) ?? []
        #expect(leftovers.filter { $0.hasSuffix(".caf") }.isEmpty)
    }
}
