import AVFoundation
import Foundation
import SwiftData
import Testing
@testable import SprechlyWork

@MainActor
struct MergeViewModelTests {
    private func makeStore() throws -> (RecordingFileStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("voxmerge-\(UUID().uuidString)")
        let docs = root.appendingPathComponent("Documents")
        let caches = root.appendingPathComponent("Caches")
        try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
        return (RecordingFileStore(documentsURL: docs, cachesURL: caches), root)
    }

    @Test func mergeCreatesNewRecordingNonDestructively() async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        try AudioTestSupport.writeSine(to: store.audioURL(forFileName: "a.caf"), amplitude: 0.4, seconds: 1)
        try AudioTestSupport.writeSine(to: store.audioURL(forFileName: "b.caf"), amplitude: 0.4, seconds: 2)

        let container = try ModelContainer(
            for: Recording.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let a = Recording(title: "A", fileName: "a.caf", duration: 1)
        let b = Recording(title: "B", fileName: "b.caf", duration: 2)
        container.mainContext.insert(a)
        container.mainContext.insert(b)
        try container.mainContext.save()

        let vm = MergeViewModel(recordings: [a, b], fileStore: store)
        vm.configure(modelContext: container.mainContext)
        vm.format = .wav

        await vm.render()

        #expect(vm.phase == .done)
        let all = try container.mainContext.fetch(FetchDescriptor<Recording>())
        #expect(all.count == 3)
        let merged = try #require(all.first { $0.title.hasPrefix("Zusammenführung") })
        #expect(abs(merged.duration - 3.0) <= max(0.05, 3.0 * 0.02))

        // Originals untouched, no orphan working file.
        #expect(FileManager.default.fileExists(atPath: store.audioURL(forFileName: "a.caf").path))
        #expect(FileManager.default.fileExists(atPath: store.audioURL(forFileName: "b.caf").path))
        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: store.cachesURL.path)) ?? []
        #expect(leftovers.filter { $0.hasSuffix(".caf") }.isEmpty)
    }

    @Test func moveReordersIndependentlyOfSelection() {
        let a = Recording(title: "A", fileName: "a.m4a", duration: 1)
        let b = Recording(title: "B", fileName: "b.m4a", duration: 1)
        let c = Recording(title: "C", fileName: "c.m4a", duration: 1)
        let vm = MergeViewModel(recordings: [a, b, c])

        vm.move(fromOffsets: IndexSet(integer: 0), toOffset: 3) // A to the end

        #expect(vm.ordered.map(\.title) == ["B", "C", "A"])
    }
}
