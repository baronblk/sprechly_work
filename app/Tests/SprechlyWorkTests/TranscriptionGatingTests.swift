import Foundation
import SwiftData
import Testing
@testable import SprechlyWork

private final class GateStubTranscription: TranscriptionProviding, @unchecked Sendable {
    var drafts: [TranscriptDraft] = [TranscriptDraft(text: "hallo", startTime: 0, endTime: 1)]
    var fails = false
    func assetState(for locale: Locale) async -> TranscriptionAssetState { .installed }
    func installAssets(for locale: Locale) -> AsyncStream<TranscriptionAssetState> { AsyncStream { $0.finish() } }
    func transcribe(fileAt url: URL, locale: Locale) -> AsyncThrowingStream<TranscriptDraft, Error> {
        let drafts = self.drafts
        let fails = self.fails
        return AsyncThrowingStream { continuation in
            for draft in drafts { continuation.yield(draft) }
            if fails { continuation.finish(throwing: CancellationError()) } else { continuation.finish() }
        }
    }
}

@MainActor
struct TranscriptionGatingTests {
    // Returns the container so the caller keeps it alive (returning only the
    // context would deallocate the container and invalidate the models).
    private func setup() throws -> (Recording, ModelContainer, GateStubTranscription) {
        let container = try ModelContainer(
            for: Recording.self, TranscriptSegment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let recording = Recording(title: "R", fileName: "r.m4a", duration: 10)
        container.mainContext.insert(recording)
        return (recording, container, GateStubTranscription())
    }

    /// Locked runs now produce an unpersisted 30-second preview instead of an
    /// immediate paywall (see TranscriptionPreviewTests). What stays true here:
    /// a locked run never writes segments, so nothing premium leaks out.
    @Test func lockedRunPersistsNothing() async throws {
        let (recording, container, stub) = try setup()
        let vm = TranscriptionViewModel(recording: recording, service: stub)
        vm.configure(modelContext: container.mainContext, store: MockEntitlementStore(owned: []))

        await vm.transcribe()

        #expect(recording.segmentList.isEmpty) // persistence stays premium
        #expect(vm.phase == .preview)
    }

    @Test func unlockedTranscribes() async throws {
        let (recording, container, stub) = try setup()
        let vm = TranscriptionViewModel(recording: recording, service: stub)
        vm.configure(modelContext: container.mainContext, store: MockEntitlementStore(unlockAll: true))

        await vm.transcribe()

        #expect(vm.phase == .done)
        #expect(recording.segmentList.count == 1)
        #expect(!vm.showPaywall)
    }

    @Test func abortedTranscriptionKeepsExistingSegments() async throws {
        let (recording, container, stub) = try setup()
        stub.fails = true
        let vm = TranscriptionViewModel(recording: recording, service: stub)
        vm.configure(modelContext: container.mainContext, store: MockEntitlementStore(unlockAll: true))

        await vm.transcribe()

        #expect(vm.phase == .failed)
        #expect(recording.segmentList.isEmpty)
    }

    @Test func exportLockedReturnsNil() throws {
        let (recording, container, stub) = try setup()
        container.mainContext.insert(
            TranscriptSegment(text: "hallo", startTime: 0, endTime: 1, recording: recording)
        )
        let vm = TranscriptionViewModel(recording: recording, service: stub)
        vm.configure(modelContext: container.mainContext, store: MockEntitlementStore(owned: []))

        #expect(vm.exportFile(.txt) == nil) // export is premium
    }

    @Test func exportUnlockedWritesShareableFile() throws {
        let (recording, container, stub) = try setup()
        container.mainContext.insert(
            TranscriptSegment(text: "hallo", startTime: 0, endTime: 1, recording: recording)
        )
        let vm = TranscriptionViewModel(recording: recording, service: stub)
        vm.configure(modelContext: container.mainContext, store: MockEntitlementStore(unlockAll: true))

        let url = try #require(vm.exportFile(.markdown))
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(url.pathExtension == "md")
        #expect(FileManager.default.fileExists(atPath: url.path))
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(content.contains("hallo"))
    }
}
