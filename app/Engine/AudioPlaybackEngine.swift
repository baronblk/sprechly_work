import AVFoundation
import Foundation
import os

/// Plays a recording and reports playback position. Speed stays 1× (variable
/// speed is Phase 2). Persistence-agnostic: it works with a file URL only.
actor AudioPlaybackEngine {
    enum State: Sendable, Equatable {
        case idle, playing, paused, finished
    }

    private(set) var state: State = .idle
    private(set) var duration: TimeInterval = 0

    private let logger = Logger(subsystem: "de.gcng.sprechly.work", category: "PlaybackEngine")
    private var player: AVAudioPlayer?
    private var positionContinuation: AsyncStream<TimeInterval>.Continuation?
    private var pollTask: Task<Void, Never>?

    var currentTime: TimeInterval { player?.currentTime ?? 0 }

    /// Loads `url` and returns a stream of playback positions (seconds).
    func load(url: URL) throws -> AsyncStream<TimeInterval> {
        stopPolling()
        positionContinuation?.finish()

        let player = try AVAudioPlayer(contentsOf: url)
        player.prepareToPlay()
        self.player = player
        duration = player.duration
        state = .idle

        let (stream, continuation) = AsyncStream<TimeInterval>.makeStream()
        positionContinuation = continuation
        return stream
    }

    func play() {
        guard let player, state != .playing else { return }
        if state == .finished { player.currentTime = 0 }
        // `play()` returns false when the audio session is not active — surface it
        // instead of silently flipping to `.playing` with no sound.
        if !player.play() {
            logger.error("AVAudioPlayer.play() returned false (session likely inactive)")
        }
        state = .playing
        startPolling()
    }

    func pause() {
        guard state == .playing else { return }
        player?.pause()
        state = .paused
        stopPolling()
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        let clamped = Swift.min(Swift.max(0, time), duration)
        player.currentTime = clamped
        positionContinuation?.yield(clamped)
    }

    func stop() {
        player?.stop()
        stopPolling()
        positionContinuation?.finish()
        positionContinuation = nil
        player = nil
        state = .idle
        duration = 0
    }

    private func startPolling() {
        stopPolling()
        pollTask = Task { [weak self] in
            while let self, await self.state == .playing {
                await self.tick()
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func tick() {
        guard let player else { return }
        if player.isPlaying {
            positionContinuation?.yield(player.currentTime)
        } else {
            // Reached the end.
            positionContinuation?.yield(duration)
            state = .finished
            stopPolling()
        }
    }
}
