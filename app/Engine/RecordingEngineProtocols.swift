import AVFoundation
import Foundation

/// Abstractions so view models depend on protocols, not concrete engines —
/// enabling state-machine tests without audio hardware (see §12).
protocol RecordingEngine: Sendable {
    /// Starts recording. `bufferSink` (optional) receives each captured input
    /// buffer on the audio thread — used to feed live transcription without a
    /// second tap or audio session.
    func start(to url: URL, bufferSink: (@Sendable (AVAudioPCMBuffer) -> Void)?) async throws -> AsyncStream<RecordingMeter>
    func pause() async
    func resume() async throws
    func stop() async -> TimeInterval
    /// Stops the engine and flushes the in-progress file so it can be played
    /// back for review (dictaphone mode), leaving the engine paused. Returns the
    /// recorded duration; the file at the start URL is complete and readable.
    func finalizeCurrentFile() async -> TimeInterval
}

extension RecordingEngine {
    func start(to url: URL) async throws -> AsyncStream<RecordingMeter> {
        try await start(to: url, bufferSink: nil)
    }
}

protocol RecordingSession: Sendable {
    func activateForRecording() throws
    func deactivate()
    func events() -> AsyncStream<AudioSessionEvent>
}

extension AudioRecorderEngine: RecordingEngine {}
extension AudioSessionController: RecordingSession {}
