import Foundation
import SwiftData

/// One timestamped piece of a recording's transcript. Tapping a segment seeks
/// the audio to `startTime`. Added in Phase 3 (the relationship deferred from
/// Phase 1); an additive lightweight SwiftData migration.
@Model
final class TranscriptSegment {
    // Defaults on every stored property are required for CloudKit sync.
    var id: UUID = UUID()
    var text: String = ""
    var startTime: TimeInterval = 0
    var endTime: TimeInterval = 0
    var recording: Recording?

    init(
        id: UUID = UUID(),
        text: String,
        startTime: TimeInterval,
        endTime: TimeInterval,
        recording: Recording? = nil
    ) {
        self.id = id
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.recording = recording
    }
}
