import AVFoundation
import Foundation
import SwiftData
import Testing
@testable import VoxStudio

// MARK: - Mocks

private final class MockRecordingEngine: RecordingEngine, @unchecked Sendable {
    var startCount = 0
    var pauseCount = 0
    var resumeCount = 0
    var stopCount = 0
    var stopDuration: TimeInterval = 12.5

    private var continuation: AsyncStream<RecordingMeter>.Continuation?

    func start(to url: URL, bufferSink: (@Sendable (AVAudioPCMBuffer) -> Void)?) async throws -> AsyncStream<RecordingMeter> {
        startCount += 1
        // Write a placeholder so the view model's finalize() can move it.
        try? Data("audio".utf8).write(to: url)
        let (stream, continuation) = AsyncStream<RecordingMeter>.makeStream()
        self.continuation = continuation
        return stream
    }

    func pause() async { pauseCount += 1 }
    func resume() async throws { resumeCount += 1 }
    func stop() async -> TimeInterval {
        stopCount += 1
        continuation?.finish()
        return stopDuration
    }
    func finalizeCurrentFile() async -> TimeInterval {
        continuation?.finish()
        return stopDuration
    }
}

private final class MockRecordingSession: RecordingSession, @unchecked Sendable {
    var activateCount = 0
    var deactivateCount = 0

    // Created eagerly so events sent before consumption are buffered.
    private let stream: AsyncStream<AudioSessionEvent>
    private let continuation: AsyncStream<AudioSessionEvent>.Continuation

    init() {
        (stream, continuation) = AsyncStream<AudioSessionEvent>.makeStream()
    }

    func activateForRecording() throws { activateCount += 1 }
    func deactivate() { deactivateCount += 1 }
    func events() -> AsyncStream<AudioSessionEvent> { stream }
    func send(_ event: AudioSessionEvent) { continuation.yield(event) }
}

private final class MockLiveTranscriber: LiveTranscribing, @unchecked Sendable {
    let handle = MockLiveHandle()
    private(set) var startCount = 0

    func start(locale: Locale) async throws -> any LiveTranscriptionHandle {
        startCount += 1
        return handle
    }
}

private final class MockLiveHandle: LiveTranscriptionHandle, @unchecked Sendable {
    let updates: AsyncStream<LiveTranscriptUpdate>
    private let continuation: AsyncStream<LiveTranscriptUpdate>.Continuation

    private(set) var feedCount = 0
    private(set) var finishCount = 0
    var finalSegments: [TranscriptDraft] = []

    init() {
        (updates, continuation) = AsyncStream<LiveTranscriptUpdate>.makeStream()
    }

    func emit(_ update: LiveTranscriptUpdate) { continuation.yield(update) }
    func feed(_ buffer: AVAudioPCMBuffer) { feedCount += 1 }
    func finish() async -> [TranscriptDraft] {
        finishCount += 1
        continuation.finish()
        return finalSegments
    }
}

private actor MockAssembler: DictationAssembling {
    private var duration: TimeInterval = 0
    private var committedFile: URL?
    private(set) var appendCount = 0
    private(set) var truncatedTo: TimeInterval?
    private(set) var cleanupCount = 0

    var committedDuration: TimeInterval { duration }
    func committedURL() async -> URL? { committedFile }

    func append(segment: URL, duration runDuration: TimeInterval) async throws {
        appendCount += 1
        duration += runDuration
        committedFile = segment
    }
    func truncate(to seconds: TimeInterval) async throws {
        truncatedTo = seconds
        duration = seconds
    }
    func finalizeM4A() async throws -> URL {
        guard let committedFile else { throw DictationAssembler.DictationError.empty }
        return committedFile
    }
    func cleanup() async { cleanupCount += 1 }
}

@MainActor
private final class MockActivityController: RecordingActivityControlling {
    private(set) var startCount = 0
    private(set) var updateCount = 0
    private(set) var endCount = 0
    private(set) var lastPaused: Bool?

    func start(elapsed: TimeInterval, isPaused: Bool) async { startCount += 1; lastPaused = isPaused }
    func update(elapsed: TimeInterval, isPaused: Bool) async { updateCount += 1; lastPaused = isPaused }
    func end() async { endCount += 1 }
}

// MARK: - Tests

@MainActor
struct RecordingViewModelTests {
    private func makeTempStore() throws -> (RecordingFileStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("voxvm-\(UUID().uuidString)")
        let docs = root.appendingPathComponent("Documents")
        let caches = root.appendingPathComponent("Caches")
        try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
        return (RecordingFileStore(documentsURL: docs, cachesURL: caches), root)
    }

    private func waitUntil(_ condition: @escaping () -> Bool) async -> Bool {
        for _ in 0..<200 {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    @Test func startMovesToRecording() async throws {
        let (store, root) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let recorder = MockRecordingEngine()
        let session = MockRecordingSession()
        let vm = RecordingViewModel(recorder: recorder, session: session, fileStore: store, activity: MockActivityController())

        await vm.startRecording()

        #expect(vm.state == .recording)
        #expect(recorder.startCount == 1)
        #expect(session.activateCount == 1)
    }

    @Test func pauseEntersReviewAndContinueRecords() async throws {
        let (store, root) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let recorder = MockRecordingEngine()
        let vm = RecordingViewModel(recorder: recorder, session: MockRecordingSession(), fileStore: store, activity: MockActivityController())

        await vm.startRecording()
        await vm.pause()
        // Pausing always commits the run and drops into the reviewable state.
        #expect(vm.state == .paused)
        #expect(vm.inDictation)

        await vm.continueRecording()
        #expect(vm.state == .recording)
        #expect(recorder.startCount == 2)
    }

    @Test func interruptionPausesRecording() async throws {
        let (store, root) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let session = MockRecordingSession()
        let vm = RecordingViewModel(recorder: MockRecordingEngine(), session: session, fileStore: store, activity: MockActivityController())

        await vm.startRecording()
        session.send(.interruptionBegan)

        #expect(await waitUntil { vm.state == .paused })
    }

    @Test func routeChangePausesRecording() async throws {
        let (store, root) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let recorder = MockRecordingEngine()
        let session = MockRecordingSession()
        let vm = RecordingViewModel(recorder: recorder, session: session, fileStore: store, activity: MockActivityController())

        await vm.startRecording()
        session.send(.routeChanged)

        // A route change commits the run and drops into the reviewable state.
        #expect(await waitUntil { vm.state == .paused })
        #expect(vm.inDictation)
    }

    @Test func stopAndSavePersistsRecording() async throws {
        let (store, root) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let recorder = MockRecordingEngine()
        recorder.stopDuration = 7.0
        let vm = RecordingViewModel(recorder: recorder, session: MockRecordingSession(), fileStore: store, activity: MockActivityController())

        let container = try ModelContainer(
            for: Recording.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        vm.configure(modelContext: container.mainContext)

        await vm.startRecording()
        await vm.stopAndSave()

        let recordings = try container.mainContext.fetch(FetchDescriptor<Recording>())
        #expect(recordings.count == 1)
        let saved = try #require(recordings.first)
        #expect(saved.duration == 7.0)
        #expect(saved.title.hasPrefix("Aufnahme "))
        #expect(FileManager.default.fileExists(atPath: store.audioURL(forFileName: saved.fileName).path))
        #expect(vm.state == .idle)
        #expect(vm.savedTakeCount == 1) // free rating moment fired
    }

    @Test func reviewTakeEntersDictaphoneReview() async throws {
        let (store, root) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let recorder = MockRecordingEngine()
        let assembler = MockAssembler()
        let vm = RecordingViewModel(
            recorder: recorder, session: MockRecordingSession(), fileStore: store, assembler: assembler, activity: MockActivityController()
        )
        let container = try ModelContainer(
            for: Recording.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        vm.configure(modelContext: container.mainContext)

        await vm.startRecording()
        await vm.pause()

        #expect(vm.state == .paused)
        #expect(vm.inDictation)
        #expect(await assembler.appendCount == 1)
    }

    @Test func continueRecordingTruncatesAtCursorAndRecords() async throws {
        let (store, root) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let recorder = MockRecordingEngine()
        recorder.stopDuration = 12
        let assembler = MockAssembler()
        let vm = RecordingViewModel(
            recorder: recorder, session: MockRecordingSession(), fileStore: store, assembler: assembler, activity: MockActivityController()
        )
        let container = try ModelContainer(
            for: Recording.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        vm.configure(modelContext: container.mainContext)

        await vm.startRecording()
        await vm.pause()
        await vm.reviewSkip(by: -5) // cursor 12 -> 7
        await vm.continueRecording()

        #expect(vm.state == .recording)
        #expect(await assembler.truncatedTo == 7)
    }

    @Test func dictationStopPersistsRecording() async throws {
        let (store, root) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let recorder = MockRecordingEngine()
        recorder.stopDuration = 9
        let assembler = MockAssembler()
        let vm = RecordingViewModel(
            recorder: recorder, session: MockRecordingSession(), fileStore: store, assembler: assembler, activity: MockActivityController()
        )
        let container = try ModelContainer(
            for: Recording.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        vm.configure(modelContext: container.mainContext)

        await vm.startRecording()
        await vm.pause()
        await vm.stopAndSave()

        let recordings = try container.mainContext.fetch(FetchDescriptor<Recording>())
        #expect(recordings.count == 1)
        #expect(recordings.first?.duration == 9)
        #expect(vm.state == .idle)
        #expect(vm.savedTakeCount == 1) // dictaphone takes count too
    }

    @Test func overwriteThenStopKeepsNewRecording() async throws {
        let (store, root) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let recorder = MockRecordingEngine()
        recorder.stopDuration = 10
        let assembler = MockAssembler()
        let vm = RecordingViewModel(
            recorder: recorder, session: MockRecordingSession(), fileStore: store, assembler: assembler, activity: MockActivityController()
        )
        let container = try ModelContainer(
            for: Recording.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        vm.configure(modelContext: container.mainContext)

        await vm.startRecording()
        await vm.pause()                 // committed = 10
        await vm.reviewSkip(by: -6)      // cursor 10 -> 4
        await vm.continueRecording()     // truncate to 4, record again
        await vm.stopAndSave()           // commit appends 10 -> 14; must NOT re-truncate to 4

        let recordings = try container.mainContext.fetch(FetchDescriptor<Recording>())
        #expect(recordings.count == 1)
        #expect((recordings.first?.duration ?? 0) > 4) // new recording kept, not chopped
    }

    @Test func rewindToZeroAndStopDiscardsWithoutError() async throws {
        let (store, root) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let recorder = MockRecordingEngine()
        recorder.stopDuration = 8
        let assembler = MockAssembler()
        let vm = RecordingViewModel(
            recorder: recorder, session: MockRecordingSession(), fileStore: store, assembler: assembler, activity: MockActivityController()
        )
        let container = try ModelContainer(
            for: Recording.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        vm.configure(modelContext: container.mainContext)

        await vm.startRecording()
        await vm.pause()
        await vm.reviewScrub(toFraction: 0) // rewind to the very start
        await vm.stopAndSave()

        #expect(vm.state == .idle)
        #expect(vm.errorMessage == nil)
        let recordings = try container.mainContext.fetch(FetchDescriptor<Recording>())
        #expect(recordings.isEmpty)
        // Nothing was saved, so this is not a moment worth asking about.
        #expect(vm.savedTakeCount == 0)
    }

    @Test func liveActivityFollowsRecordingLifecycle() async throws {
        let (store, root) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let activity = MockActivityController()
        let vm = RecordingViewModel(
            recorder: MockRecordingEngine(), session: MockRecordingSession(),
            fileStore: store, assembler: MockAssembler(), activity: activity
        )
        let container = try ModelContainer(
            for: Recording.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        vm.configure(modelContext: container.mainContext)

        await vm.startRecording()
        #expect(activity.startCount == 1)
        #expect(activity.lastPaused == false)

        await vm.pause()
        #expect(activity.updateCount >= 1)
        #expect(activity.lastPaused == true)

        await vm.continueRecording()
        #expect(activity.lastPaused == false)

        await vm.stopAndSave()
        #expect(activity.endCount == 1)
    }

    @Test func liveTranscriptLockedShowsPaywallAndRecordsWithoutLive() async throws {
        let (store, root) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let recorder = MockRecordingEngine()
        let live = MockLiveTranscriber()
        let vm = RecordingViewModel(
            recorder: recorder, session: MockRecordingSession(), fileStore: store, live: live, activity: MockActivityController()
        )
        let container = try ModelContainer(
            for: Recording.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        vm.configure(modelContext: container.mainContext, store: MockEntitlementStore())

        vm.liveEnabled = true
        await vm.startRecording()

        // Locked: paywall shown, live session never started, recording still runs.
        #expect(vm.showPaywall)
        #expect(live.startCount == 0)
        #expect(vm.state == .recording)
        #expect(recorder.startCount == 1)
    }

    @Test func liveTranscriptUnlockedUpdatesCaptionAndPersistsSegments() async throws {
        let (store, root) = try makeTempStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let recorder = MockRecordingEngine()
        let live = MockLiveTranscriber()
        live.handle.finalSegments = [TranscriptDraft(text: "Hallo Welt", startTime: 0, endTime: 1.5)]
        let vm = RecordingViewModel(
            recorder: recorder, session: MockRecordingSession(), fileStore: store, live: live, activity: MockActivityController()
        )
        let container = try ModelContainer(
            for: Recording.self, TranscriptSegment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        vm.configure(modelContext: container.mainContext, store: MockEntitlementStore(unlockAll: true))

        vm.liveEnabled = true
        await vm.startRecording()
        #expect(live.startCount == 1)
        #expect(!vm.showPaywall)

        live.handle.emit(LiveTranscriptUpdate(volatileText: "Hallo", finalized: []))
        #expect(await waitUntil { vm.liveCaption == "Hallo" })

        await vm.stopAndSave()

        #expect(live.handle.finishCount == 1)
        let segments = try container.mainContext.fetch(FetchDescriptor<TranscriptSegment>())
        #expect(segments.count == 1)
        #expect(segments.first?.text == "Hallo Welt")
    }
}
