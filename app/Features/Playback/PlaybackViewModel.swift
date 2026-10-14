import Foundation
import Observation
import os

/// Drives the playback screen. Loads (or generates and caches) the waveform,
/// then plays the file via the persistence-agnostic engine.
@MainActor
@Observable
final class PlaybackViewModel {
    let recordingID: UUID
    let fileName: String

    private(set) var buckets: [WaveformBucket] = []
    private(set) var position: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var isPlaying = false
    var errorMessage: String?

    var progress: Double { duration > 0 ? position / duration : 0 }

    private let engine = AudioPlaybackEngine()
    private let fileStore = RecordingFileStore()
    private let session: AudioSessionController
    private let logger = Logger(subsystem: "de.gcng.sprechly.work", category: "PlaybackVM")

    private var positionTask: Task<Void, Never>?
    private var waveformTask: Task<Void, Never>?

    init(recordingID: UUID, fileName: String, duration: TimeInterval, session: AudioSessionController = AudioSessionController()) {
        self.recordingID = recordingID
        self.fileName = fileName
        self.duration = duration
        self.session = session
    }

    func load() async {
        let url = fileStore.audioURL(forFileName: fileName)
        // On a freshly synced device the metadata arrives before the audio asset.
        guard FileManager.default.fileExists(atPath: url.path) else {
            errorMessage = String(localized: "Diese Aufnahme wird noch aus iCloud geladen. Sobald die Audiodatei synchronisiert ist, kannst du sie abspielen.")
            return
        }
        // Activate the `.playback` session BEFORE the player is created/prepared.
        // iOS deactivates the app's session once the previous recording's player
        // is released, so a freshly opened recording would otherwise be prepared
        // against an inactive session and `play()` would silently return false
        // ("button toggles, no sound"). Setting the category here — not after the
        // player is prepared — is what makes it stick.
        do {
            try session.activateForPlayback()
        } catch {
            logger.error("Playback session activation failed: \(error.localizedDescription, privacy: .public)")
        }
        // Load the player so the transport enables immediately. The waveform is
        // purely visual and can be slow for long imports, so it must not gate
        // playability (it previously ran first → ~30 s before play).
        do {
            let stream = try await engine.load(url: url)
            duration = await engine.duration
            positionTask = Task { [weak self] in
                for await time in stream {
                    guard let self else { return }
                    self.position = time
                    if await self.engine.state == .finished {
                        self.isPlaying = false
                        NowPlaying.shared.ended(owner: self)
                    }
                }
            }
        } catch {
            logger.error("Load failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            return
        }
        waveformTask = Task { [weak self] in await self?.loadWaveform(url: url) }
    }

    func togglePlayback() async {
        if isPlaying {
            await engine.pause()
            isPlaying = false
            NowPlaying.shared.ended(owner: self)
        } else {
            // Stop any other recording that is currently playing — one player only.
            NowPlaying.shared.began(owner: self) { [weak self] in
                Task { await self?.stop() }
            }
            await engine.play()
            isPlaying = true
        }
    }

    func seek(toFraction fraction: Double) async {
        await engine.seek(to: fraction * duration)
        position = fraction * duration
    }

    /// Seeks to an absolute position, clamped to the file bounds. Used by the
    /// marker chips of a Soundcore Work import.
    func seek(to time: TimeInterval) async {
        let target = Swift.min(Swift.max(0, time), duration)
        await engine.seek(to: target)
        position = target
    }

    /// Skips relative to the current position, clamped to the file bounds
    /// (e.g. -10 / +10 for the dictaphone-style transport).
    func skip(by seconds: TimeInterval) async {
        let target = Self.clampedTarget(position: position, delta: seconds, duration: duration)
        await engine.seek(to: target)
        position = target
    }

    /// Pure clamp for the skip transport — kept separate so it is unit-testable
    /// without an audio engine.
    nonisolated static func clampedTarget(position: TimeInterval, delta: TimeInterval, duration: TimeInterval) -> TimeInterval {
        min(max(0, position + delta), duration)
    }

    /// Restarts from the beginning and plays.
    func restart() async {
        await engine.seek(to: 0)
        position = 0
        if !isPlaying {
            NowPlaying.shared.began(owner: self) { [weak self] in
                Task { await self?.stop() }
            }
            await engine.play()
            isPlaying = true
        }
    }

    func stop() async {
        positionTask?.cancel()
        positionTask = nil
        waveformTask?.cancel()
        waveformTask = nil
        await engine.stop()
        isPlaying = false
        NowPlaying.shared.ended(owner: self)
    }

    /// Called when the view disappears. Tears down fully — but ONLY if currently
    /// playing. SwiftUI fires a *transient* `onDisappear` during the navigation-in
    /// transition while the recording is still loaded-but-idle (never started);
    /// tearing down there is what killed the freshly loaded player ("play does
    /// nothing"). Guarding on `isPlaying` skips that case (the idle player
    /// survives), while a real leave of a playing recording stops it cleanly and
    /// releases the queue — no overlapping audio.
    func stopIfPlaying() async {
        guard isPlaying else { return }
        await stop()
    }

    private func loadWaveform(url: URL) async {
        if let cached = fileStore.loadPeaks(forRecordingID: recordingID) {
            buckets = cached
            return
        }
        let id = recordingID
        let store = fileStore
        let peaks = await Task.detached(priority: .utility) {
            (try? WaveformGenerator.peaks(forFileAt: url, columns: 300)) ?? []
        }.value
        buckets = peaks
        if !peaks.isEmpty { store.savePeaks(peaks, forRecordingID: id) }
    }
}
