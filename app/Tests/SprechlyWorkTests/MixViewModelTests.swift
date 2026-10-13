import AVFoundation
import Foundation
import SwiftData
import Testing
@testable import SprechlyWork

@MainActor
struct MixViewModelTests {
    private func makeStore() throws -> (RecordingFileStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("voxmix-\(UUID().uuidString)")
        let docs = root.appendingPathComponent("Documents")
        let caches = root.appendingPathComponent("Caches")
        try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
        return (RecordingFileStore(documentsURL: docs, cachesURL: caches), root)
    }

    @Test func mixCreatesNewRecordingTruncatedToMainNonDestructively() async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        try AudioTestSupport.writeSine(to: store.audioURL(forFileName: "main.caf"), amplitude: 0.4, seconds: 2)
        try AudioTestSupport.writeSine(to: store.audioURL(forFileName: "bg.caf"), amplitude: 0.4, seconds: 3)

        let container = try ModelContainer(
            for: Recording.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let main = Recording(title: "Main", fileName: "main.caf", duration: 2)
        let bg = Recording(title: "Hintergrund", fileName: "bg.caf", duration: 3)
        container.mainContext.insert(main)
        container.mainContext.insert(bg)
        try container.mainContext.save()

        let vm = MixViewModel(recording: main, fileStore: store)
        vm.configure(modelContext: container.mainContext)
        await vm.selectMix(bg)
        vm.volume = 0.5
        vm.format = .wav

        await vm.render()

        #expect(vm.phase == .done)
        let all = try container.mainContext.fetch(FetchDescriptor<Recording>())
        #expect(all.count == 3)
        let mixed = try #require(all.first { $0.title.hasSuffix("(Mix)") })
        // Result length == main duration, not the longer bg track.
        #expect(abs(mixed.duration - 2.0) <= max(0.05, 2.0 * 0.02))

        #expect(FileManager.default.fileExists(atPath: store.audioURL(forFileName: "main.caf").path))
        #expect(FileManager.default.fileExists(atPath: store.audioURL(forFileName: "bg.caf").path))
        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: store.cachesURL.path)) ?? []
        #expect(leftovers.filter { $0.hasSuffix(".caf") }.isEmpty)
    }
}
