import Foundation
import SwiftData
import Testing
@testable import SprechlyWork

/// Records how the transcription stream ended, so a test can prove the preview
/// actually *terminates* the run instead of transcribing the whole file and
/// hiding the remainder. With `finishesAfterDrafts = false` the stream stays
/// open after its drafts — like a real transcriber still working through a long
/// file — so only a consumer that walks away produces `.cancelled`.
private final class PreviewStubTranscription: TranscriptionProviding, @unchecked Sendable {
    var drafts: [TranscriptDraft] = []
    var finishesAfterDrafts = true

    private let lock = NSLock()
    private var _wasCancelled: Bool?

    /// `true` when the consumer walked away, `false` when the stream ran to its
    /// end, `nil` while still open. (`Termination` is not `Equatable`.)
    var wasCancelled: Bool? { lock.withLock { _wasCancelled } }

    func assetState(for locale: Locale) async -> TranscriptionAssetState { .installed }
    func installAssets(for locale: Locale) -> AsyncStream<TranscriptionAssetState> {
        AsyncStream { $0.finish() }
    }

    func transcribe(fileAt url: URL, locale: Locale) -> AsyncThrowingStream<TranscriptDraft, Error> {
        let drafts = self.drafts
        let finishes = self.finishesAfterDrafts
        return AsyncThrowingStream { continuation in
            continuation.onTermination = { [lock] reason in
                lock.withLock {
                    if case .cancelled = reason { self._wasCancelled = true }
                    else { self._wasCancelled = false }
                }
            }
            for draft in drafts { continuation.yield(draft) }
            if finishes { continuation.finish() }
        }
    }
}

@MainActor
struct TranscriptionPreviewTests {
    /// Ten-second drafts covering 0…60 s, so the 30 s window falls on a boundary.
    private func minuteOfDrafts() -> [TranscriptDraft] {
        stride(from: 0.0, to: 60.0, by: 10.0).map { start in
            TranscriptDraft(
                text: "Abschnitt bei \(Int(start))",
                startTime: start,
                endTime: start + 10
            )
        }
    }

    private func setup(duration: TimeInterval = 60) throws
        -> (Recording, ModelContainer, PreviewStubTranscription) {
        let container = try ModelContainer(
            for: Recording.self, TranscriptSegment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let recording = Recording(title: "R", fileName: "r.m4a", duration: duration)
        container.mainContext.insert(recording)
        let stub = PreviewStubTranscription()
        stub.drafts = minuteOfDrafts()
        return (recording, container, stub)
    }

    private func makeViewModel(
        _ recording: Recording,
        _ container: ModelContainer,
        _ stub: PreviewStubTranscription,
        unlocked: Bool
    ) -> TranscriptionViewModel {
        let vm = TranscriptionViewModel(recording: recording, service: stub)
        vm.configure(
            modelContext: container.mainContext,
            store: unlocked
                ? MockEntitlementStore(unlockAll: true)
                : MockEntitlementStore(owned: [])
        )
        return vm
    }

    @Test func lockedRunPreviewsWithoutPersisting() async throws {
        let (recording, container, stub) = try setup()
        let vm = makeViewModel(recording, container, stub, unlocked: false)

        await vm.transcribe()

        #expect(vm.phase == .preview)
        #expect(vm.isShowingPreview)
        // The whole point: a preview leaves no persisted transcript behind.
        #expect(recording.segmentList.isEmpty)
        #expect(vm.segments.isEmpty)
        // The paywall is offered by the preview card, not thrown up immediately.
        #expect(!vm.showPaywall)
    }

    @Test func previewStopsAtTheThirtySecondWindow() async throws {
        let (recording, container, stub) = try setup()
        let vm = makeViewModel(recording, container, stub, unlocked: false)

        await vm.transcribe()

        // Drafts ending at 10, 20 and 30 s — the 30 s one trips the limit, so
        // the 40/50/60 s drafts never reach the transcript.
        #expect(vm.liveDrafts.count == 3)
        #expect(vm.liveDrafts.last?.endTime == 30)
    }

    @Test func previewCancelsTheTranscriptionRun() async throws {
        let (recording, container, stub) = try setup()
        // Stay open after the drafts, like a transcriber still chewing through a
        // long file: only walking away ends this stream.
        stub.finishesAfterDrafts = false
        let vm = makeViewModel(recording, container, stub, unlocked: false)

        await vm.transcribe()

        #expect(vm.phase == .preview)
        // Leaving the loop tears the stream down — a long recording is not
        // silently transcribed in full behind the paywall.
        #expect(stub.wasCancelled == true)
    }

    @Test func previewTextIsHandedToThePaywall() async throws {
        let (recording, container, stub) = try setup()
        let vm = makeViewModel(recording, container, stub, unlocked: false)

        await vm.transcribe()

        let text = try #require(vm.previewText)
        #expect(text.contains("Abschnitt bei 0"))
        #expect(text.contains("Abschnitt bei 20"))
        #expect(!text.contains("Abschnitt bei 40")) // beyond the window
    }

    @Test func previewIsMarkedTruncatedOnlyWhenMoreAudioRemains() async throws {
        let (longRecording, container, stub) = try setup(duration: 60)
        let longVM = makeViewModel(longRecording, container, stub, unlocked: false)
        await longVM.transcribe()
        #expect(longVM.isPreviewTruncated)

        // A recording shorter than the window is shown in full — still a
        // preview (nothing persisted), but nothing was cut off either.
        let (shortRecording, shortContainer, shortStub) = try setup(duration: 12)
        shortStub.drafts = [TranscriptDraft(text: "kurz", startTime: 0, endTime: 12)]
        let shortVM = makeViewModel(shortRecording, shortContainer, shortStub, unlocked: false)
        await shortVM.transcribe()

        #expect(shortVM.phase == .preview)
        #expect(!shortVM.isPreviewTruncated)
        #expect(shortRecording.segmentList.isEmpty)
    }

    @Test func unlockedRunTranscribesAndPersistsEverything() async throws {
        let (recording, container, stub) = try setup()
        let vm = makeViewModel(recording, container, stub, unlocked: true)

        await vm.transcribe()

        #expect(vm.phase == .done)
        #expect(!vm.isShowingPreview)
        #expect(vm.previewText == nil)
        #expect(recording.segmentList.count == 6) // the full minute, nothing cut
        #expect(stub.wasCancelled == false)        // consumed to the end
    }

    @Test func previewResultCannotBeExported() async throws {
        let (recording, container, stub) = try setup()
        let vm = makeViewModel(recording, container, stub, unlocked: false)

        await vm.transcribe()

        #expect(vm.isShowingPreview)
        // Export reads persisted segments and checks the entitlement — a
        // preview satisfies neither.
        #expect(vm.exportFile(.txt) == nil)
        #expect(vm.exportFile(.markdown) == nil)
    }

    @Test func previewIsDiscardedWhenTheRunFails() async throws {
        let (recording, container, stub) = try setup()
        stub.drafts = []
        let vm = makeViewModel(recording, container, stub, unlocked: false)

        await vm.transcribe()

        // An empty run reaches `.preview` but has nothing to show, so the view
        // must not treat it as a result.
        #expect(!vm.isShowingPreview)
        #expect(vm.previewText == nil)
    }
}
