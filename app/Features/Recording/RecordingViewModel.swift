import AVFoundation
import Foundation
import Observation
import SwiftData
import os

/// Drives the recording screen. Orchestrates the (persistence-agnostic) engine,
/// the audio session, file finalization and SwiftData persistence.
@MainActor
@Observable
final class RecordingViewModel {
    enum State: Equatable {
        /// `paused` is always a reviewable state: the committed take can be
        /// played/scrubbed and recording can continue (overwriting) from the
        /// cursor — like a physical dictaphone, no extra "review" step.
        case idle, recording, paused, stopped
    }

    private(set) var state: State = .idle
    private(set) var elapsed: TimeInterval = 0
    private(set) var level: Float = 0
    /// Bumped every time a take is persisted. The view turns this into a
    /// rating moment — a counter rather than a flag so consecutive saves each
    /// register, and so the free recorder path (not just the paid AI path) can
    /// reach the prompt threshold.
    private(set) var savedTakeCount = 0

    private(set) var liveBuckets: [WaveformBucket] = []
    var errorMessage: String?

    /// Live transcription (premium): toggle in the recording screen.
    var liveEnabled = false
    /// The running volatile caption line shown above the waveform.
    private(set) var liveCaption = ""
    var showPaywall = false

    // Dictaphone review state (valid while paused).
    private(set) var reviewBuckets: [WaveformBucket] = []
    private(set) var reviewCursor: TimeInterval = 0
    private(set) var committedDuration: TimeInterval = 0
    private(set) var isReviewPlaying = false
    var reviewProgress: Double { committedDuration > 0 ? reviewCursor / committedDuration : 0 }

    var isActive: Bool { state == .recording || state == .paused }
    /// Whether a committed take exists (dictaphone mode has been entered).
    private(set) var inDictation = false

    private let recorder: any RecordingEngine
    private let session: any RecordingSession
    private let fileStore: RecordingFileStore
    private let live: any LiveTranscribing
    private let assembler: any DictationAssembling
    private let activity: any RecordingActivityControlling
    private let reviewPlayer = AudioPlaybackEngine()
    private let logger = Logger(subsystem: "de.gcng.sprechly.work", category: "RecordingVM")

    private var modelContext: ModelContext?
    private var store: (any EntitlementProviding)?

    private var liveHandle: (any LiveTranscriptionHandle)?
    private var liveTask: Task<Void, Never>?
    private var liveActive = false

    init(
        recorder: any RecordingEngine = AudioRecorderEngine(),
        session: any RecordingSession = AudioSessionController(),
        fileStore: RecordingFileStore = RecordingFileStore(),
        live: any LiveTranscribing = SpeechLiveTranscriber(),
        assembler: any DictationAssembling = DictationAssembler(),
        activity: any RecordingActivityControlling = LiveActivityController()
    ) {
        self.recorder = recorder
        self.session = session
        self.fileStore = fileStore
        self.live = live
        self.assembler = assembler
        self.activity = activity
    }
    private var target: (temporaryURL: URL, fileName: String)?
    private var meterTask: Task<Void, Never>?
    private var sessionTask: Task<Void, Never>?
    private var reviewTask: Task<Void, Never>?
    /// Committed duration at the current run's start (so `elapsed` shows total).
    private var runBaseDuration: TimeInterval = 0

    private let liveWindow = 240

    func configure(modelContext: ModelContext, store: (any EntitlementProviding)? = nil) {
        self.modelContext = modelContext
        self.store = store
    }

    func startRecording() async {
        guard state == .idle || state == .stopped else { return }

        // Fresh take: clear any previous committed dictation timeline.
        await assembler.cleanup()
        inDictation = false
        committedDuration = 0
        runBaseDuration = 0

        // Live captions are premium (unlock-only — no free trial). Recording
        // itself is always free; if locked, we record without live + show paywall.
        var sink: (@Sendable (AVAudioPCMBuffer) -> Void)?
        if liveEnabled {
            if store?.isUnlocked(.ai) == true {
                await startLive(into: &sink)
            } else {
                showPaywall = true
            }
        }

        do {
            try session.activateForRecording()
            let target = fileStore.makeRecordingTarget()
            self.target = target
            let stream = try await recorder.start(to: target.temporaryURL, bufferSink: sink)
            reset()
            state = .recording
            await activity.start(elapsed: 0, isPaused: false)
            meterTask = Task { [weak self] in
                for await meter in stream { self?.apply(meter) }
            }
            sessionTask = Task { [weak self] in
                guard let self else { return }
                for await event in session.events() { await self.handle(event) }
            }
        } catch {
            logger.error("Start failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            session.deactivate()
            cancelLive()
        }
    }

    private func startLive(into sink: inout (@Sendable (AVAudioPCMBuffer) -> Void)?) async {
        do {
            let locale = Locale(identifier: Locale.preferredLanguages.first ?? "en-US")
            let handle = try await live.start(locale: locale)
            liveHandle = handle
            liveActive = true
            liveCaption = ""
            sink = { [handle] buffer in handle.feed(buffer) }
            liveTask = Task { [weak self] in
                for await update in handle.updates { self?.liveCaption = update.volatileText }
            }
        } catch {
            logger.error("Live start failed: \(error.localizedDescription, privacy: .public)")
            liveActive = false
        }
    }

    private func cancelLive() {
        liveTask?.cancel()
        liveTask = nil
        liveHandle = nil
        liveActive = false
        liveCaption = ""
    }

    /// Pausing always commits the current run and drops straight into the
    /// reviewable paused state (scrub/play/overwrite available immediately).
    func pause() async {
        guard state == .recording else { return }
        await commitCurrentRun()
        await enterReviewState()
        await activity.update(elapsed: committedDuration, isPaused: true)
    }

    /// Skips the review cursor (e.g. -10 / +10), clamped to the take.
    func reviewSkip(by seconds: TimeInterval) async {
        guard state == .paused else { return }
        reviewCursor = PlaybackViewModel.clampedTarget(position: reviewCursor, delta: seconds, duration: committedDuration)
        await reviewPlayer.seek(to: reviewCursor)
    }

    func reviewScrub(toFraction fraction: Double) async {
        guard state == .paused else { return }
        reviewCursor = min(max(0, fraction), 1) * committedDuration
        await reviewPlayer.seek(to: reviewCursor)
    }

    func toggleReviewPlayback() async {
        guard state == .paused else { return }
        if isReviewPlaying {
            await reviewPlayer.pause()
            isReviewPlaying = false
        } else {
            await reviewPlayer.play()
            isReviewPlaying = true
        }
    }

    /// Resumes recording from the review cursor, overwriting everything after it.
    func continueRecording() async {
        guard state == .paused else { return }
        await reviewPlayer.stop()
        reviewTask?.cancel()
        reviewTask = nil
        isReviewPlaying = false

        let cursor = reviewCursor
        do {
            // Start capturing immediately so no continued speech is lost while
            // the committed head is trimmed (trim runs after recording begins).
            try session.activateForRecording()
            // Continuation runs are captured lossless (CAF/PCM): merging an AAC
            // run would splice in ~40 ms of encoder priming silence and leave a
            // gap at the overwrite seam. The committed head is transcoded to m4a
            // only at final save.
            let target = fileStore.makeTarget(fileExtension: "caf")
            self.target = target
            let stream = try await recorder.start(to: target.temporaryURL, bufferSink: nil)
            runBaseDuration = cursor
            elapsed = cursor
            level = 0
            state = .recording
            await activity.update(elapsed: cursor, isPaused: false)
            meterTask = Task { [weak self] in
                for await meter in stream { self?.apply(meter) }
            }
            sessionTask = Task { [weak self] in
                guard let self else { return }
                for await event in session.events() { await self.handle(event) }
            }
        } catch {
            logger.error("Continue failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            session.deactivate()
            return
        }
        // Trim the committed head to the cursor — recording is already running.
        do {
            try await assembler.truncate(to: cursor)
            committedDuration = await assembler.committedDuration
        } catch {
            logger.error("Truncate failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Finalizes the in-progress run and appends it to the committed take.
    private func commitCurrentRun() async {
        let duration = await recorder.finalizeCurrentFile()
        meterTask?.cancel()
        sessionTask?.cancel()
        meterTask = nil
        sessionTask = nil
        cancelLive()
        guard let target else { return }
        do {
            try await assembler.append(segment: target.temporaryURL, duration: duration)
            inDictation = true
        } catch {
            logger.error("Append failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
        self.target = nil
    }

    /// Loads the committed take for review (waveform + player) and shows it.
    private func enterReviewState() async {
        committedDuration = await assembler.committedDuration
        reviewCursor = committedDuration
        await loadReviewWaveform()
        if let url = await assembler.committedURL() {
            do {
                let stream = try await reviewPlayer.load(url: url)
                reviewTask = Task { [weak self] in
                    for await time in stream {
                        guard let self else { return }
                        self.reviewCursor = time
                        if await self.reviewPlayer.state == .finished { self.isReviewPlaying = false }
                    }
                }
            } catch {
                logger.error("Review load failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        session.deactivate()
        state = .paused
    }

    private func loadReviewWaveform() async {
        guard let url = await assembler.committedURL() else { reviewBuckets = []; return }
        reviewBuckets = await Task.detached(priority: .utility) {
            (try? WaveformGenerator.peaks(forFileAt: url, columns: 300)) ?? []
        }.value
    }

    /// Stops, finalizes the file and persists a `Recording`.
    func stopAndSave() async {
        guard isActive else { return }
        if inDictation {
            await dictationStopAndSave()
            return
        }
        let duration = await recorder.stop()
        meterTask?.cancel()
        sessionTask?.cancel()
        meterTask = nil
        sessionTask = nil
        session.deactivate()
        await activity.end()
        state = .stopped

        // Finalize live captions (if any) before persisting.
        var liveSegments: [TranscriptDraft] = []
        if liveActive, let handle = liveHandle {
            liveSegments = await handle.finish()
        }
        cancelLive()

        guard let target, let modelContext else {
            self.target = nil; elapsed = 0; level = 0; liveBuckets = []; state = .idle
            return
        }
        do {
            try fileStore.finalize(temporaryURL: target.temporaryURL, fileName: target.fileName)
            let recording = Recording(
                title: Recording.defaultTitle(),
                fileName: target.fileName,
                duration: duration
            )
            modelContext.insert(recording)
            for draft in liveSegments {
                modelContext.insert(TranscriptSegment(
                    text: draft.text, startTime: draft.startTime, endTime: draft.endTime, recording: recording
                ))
            }
            try modelContext.save()
            savedTakeCount += 1
        } catch {
            logger.error("Finalize failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
        self.target = nil
        elapsed = 0
        level = 0
        liveBuckets = []
        state = .idle
    }

    /// Finalizes a dictaphone take (commit current run if needed, drop any tail
    /// after the cursor) and persists it.
    private func dictationStopAndSave() async {
        // Stopping mid-record extends the take — the cursor was already consumed
        // by `continueRecording`. Only stopping from review (rewound, no new run)
        // should drop the tail after the cursor.
        let stoppedWhileRecording = (state == .recording)
        if stoppedWhileRecording {
            await commitCurrentRun()
        }
        await reviewPlayer.stop()
        reviewTask?.cancel()
        reviewTask = nil
        session.deactivate()
        await activity.end()

        do {
            if !stoppedWhileRecording, reviewCursor < committedDuration {
                try await assembler.truncate(to: reviewCursor)
                committedDuration = await assembler.committedDuration
            }
            // Rewound to the start (nothing left): discard silently — not an error.
            let committedURLExists = await assembler.committedURL() != nil
            let hasContent = committedDuration > 0 && committedURLExists
            if hasContent, let modelContext {
                let finalURL = try await assembler.finalizeM4A()
                let duration = await assembler.committedDuration
                let fileName = "\(UUID().uuidString).m4a"
                try fileStore.finalize(temporaryURL: finalURL, fileName: fileName)
                let recording = Recording(
                    title: Recording.defaultTitle(),
                    fileName: fileName,
                    duration: duration
                )
                modelContext.insert(recording)
                try modelContext.save()
                savedTakeCount += 1
            }
        } catch {
            logger.error("Dictation save failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
        await assembler.cleanup()
        resetDictation()
    }

    private func resetDictation() {
        target = nil
        inDictation = false
        elapsed = 0
        level = 0
        liveBuckets = []
        reviewBuckets = []
        reviewCursor = 0
        committedDuration = 0
        runBaseDuration = 0
        isReviewPlaying = false
        state = .idle
    }

    private func apply(_ meter: RecordingMeter) {
        elapsed = runBaseDuration + meter.elapsed
        level = meter.level
        liveBuckets.append(meter.bucket)
        if liveBuckets.count > liveWindow {
            liveBuckets.removeFirst(liveBuckets.count - liveWindow)
        }
    }

    private func handle(_ event: AudioSessionEvent) async {
        switch event {
        case .interruptionBegan:
            await pause()
        case .interruptionEnded:
            break // Resume is a deliberate user action.
        case .routeChanged:
            // Pause on route change; resume rebuilds the converter from the live
            // buffer format, so it is correct on the new route.
            await pause()
        }
    }

    private func reset() {
        elapsed = 0
        level = 0
        liveBuckets = []
    }
}
