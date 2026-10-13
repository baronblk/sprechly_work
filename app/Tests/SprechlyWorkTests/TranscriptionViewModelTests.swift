import Foundation
import SwiftData
import Testing
@testable import SprechlyWork

private enum StubError: Error { case aborted }

private final class StubTranscription: TranscriptionProviding, @unchecked Sendable {
    var installed: Set<String> = ["de-DE", "en-US"]
    var drafts: [TranscriptDraft] = []
    /// If set, throw after yielding this many drafts (simulates an aborted run).
    var throwAfter: Int?

    func assetState(for locale: Locale) async -> TranscriptionAssetState {
        installed.contains(locale.identifier) ? .installed : .notInstalled
    }

    func installAssets(for locale: Locale) -> AsyncStream<TranscriptionAssetState> {
        AsyncStream { $0.finish() }
    }

    func transcribe(fileAt url: URL, locale: Locale) -> AsyncThrowingStream<TranscriptDraft, Error> {
        let drafts = self.drafts
        let throwAfter = self.throwAfter
        return AsyncThrowingStream { continuation in
            for (index, draft) in drafts.enumerated() {
                if let throwAfter, index >= throwAfter {
                    continuation.finish(throwing: StubError.aborted)
                    return
                }
                continuation.yield(draft)
            }
            if throwAfter != nil {
                continuation.finish(throwing: StubError.aborted)
            } else {
                continuation.finish()
            }
        }
    }
}

@MainActor
struct TranscriptionViewModelTests {
    // Keep the container alive for the test's lifetime — returning only its
    // mainContext would deallocate the container and dangle the context.
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Recording.self, TranscriptSegment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeRecording(in context: ModelContext) -> Recording {
        let recording = Recording(title: "R", fileName: "r.m4a", duration: 30)
        context.insert(recording)
        return recording
    }

    @Test func transcribePersistsSortedSegments() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let recording = makeRecording(in: context)
        let stub = StubTranscription()
        stub.drafts = [
            TranscriptDraft(text: "zwei", startTime: 2, endTime: 3),
            TranscriptDraft(text: "eins", startTime: 0, endTime: 1)
        ]
        let vm = TranscriptionViewModel(recording: recording, service: stub)
        vm.configure(modelContext: context, store: MockEntitlementStore(unlockAll: true))

        await vm.transcribe()

        #expect(vm.phase == .done)
        #expect(vm.segments.map(\.text) == ["eins", "zwei"]) // sorted by start
    }

    @Test func reTranscribeReplacesNotDuplicates() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let recording = makeRecording(in: context)
        let stub = StubTranscription()
        stub.drafts = [TranscriptDraft(text: "a", startTime: 0, endTime: 1),
                       TranscriptDraft(text: "b", startTime: 1, endTime: 2)]
        let vm = TranscriptionViewModel(recording: recording, service: stub)
        vm.configure(modelContext: context, store: MockEntitlementStore(unlockAll: true))
        await vm.transcribe()
        #expect(recording.segmentList.count == 2)

        stub.drafts = [TranscriptDraft(text: "c", startTime: 0, endTime: 1)]
        await vm.transcribe()

        #expect(recording.segmentList.count == 1)
        #expect(recording.segmentList.first?.text == "c")
    }

    @Test func abortedReTranscriptionKeepsOldSegments() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let recording = makeRecording(in: context)
        let stub = StubTranscription()
        stub.drafts = [TranscriptDraft(text: "alt1", startTime: 0, endTime: 1),
                       TranscriptDraft(text: "alt2", startTime: 1, endTime: 2)]
        let vm = TranscriptionViewModel(recording: recording, service: stub)
        vm.configure(modelContext: context, store: MockEntitlementStore(unlockAll: true))
        await vm.transcribe()
        #expect(recording.segmentList.count == 2)

        // A second run that aborts mid-stream must not touch the old segments.
        stub.drafts = [TranscriptDraft(text: "neu1", startTime: 0, endTime: 1),
                       TranscriptDraft(text: "neu2", startTime: 1, endTime: 2),
                       TranscriptDraft(text: "neu3", startTime: 2, endTime: 3)]
        stub.throwAfter = 1
        await vm.transcribe()

        #expect(vm.phase == .failed)
        #expect(recording.segmentList.count == 2)
        #expect(Set(recording.segmentList.map(\.text)) == ["alt1", "alt2"])
    }

    @Test func defaultLocalePicksDevicePreferredLanguage() {
        let de = Locale(identifier: "de-DE")
        let en = Locale(identifier: "en-US")
        #expect(TranscriptionViewModel.defaultLocale(installed: [de, en], preferred: ["de-DE"])?.identifier == "de-DE")
        #expect(TranscriptionViewModel.defaultLocale(installed: [de, en], preferred: ["en-GB"])?.identifier == "en-US")
        #expect(TranscriptionViewModel.defaultLocale(installed: [de, en], preferred: ["fr-FR"])?.identifier == "de-DE")
        #expect(TranscriptionViewModel.defaultLocale(installed: [], preferred: ["de-DE"]) == nil)
    }
}
