import Foundation

/// A streamed, not-yet-persisted transcript piece. Persisted as a
/// `TranscriptSegment` only when the whole transcription succeeds.
struct TranscriptDraft: Sendable, Equatable {
    var text: String
    var startTime: TimeInterval
    var endTime: TimeInterval
}
