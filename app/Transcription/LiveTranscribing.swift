import AVFoundation
import Foundation

/// A live transcription update: the in-progress (volatile) line plus the
/// segments finalized so far.
struct LiveTranscriptUpdate: Sendable, Equatable {
    var volatileText: String
    var finalized: [TranscriptDraft]
}

/// Starts a live transcription session. Behind a protocol so the recording view
/// model is testable with a mock; the real session runs only on device.
protocol LiveTranscribing: Sendable {
    func start(locale: Locale) async throws -> any LiveTranscriptionHandle
}

/// A running live session: feed audio buffers in real time, observe updates,
/// and finish to get the finalized segments.
protocol LiveTranscriptionHandle: Sendable {
    var updates: AsyncStream<LiveTranscriptUpdate> { get }
    /// Called from the recorder's audio thread for each captured buffer.
    func feed(_ buffer: AVAudioPCMBuffer)
    /// Finishes input and returns the finalized segments to persist.
    func finish() async -> [TranscriptDraft]
}
