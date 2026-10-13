import ActivityKit
import Foundation

/// Shared between the app (which starts/updates/ends the activity) and the widget
/// extension (which renders it). Lives in its own folder so both targets compile it.
struct RecordingActivityAttributes: ActivityAttributes {
    /// The dynamic part of a running recording. Kept tiny: ActivityKit budgets
    /// updates, so the elapsed counter is driven on-device by `Text(timerInterval:)`
    /// from `startedAt` rather than pushed every second.
    struct ContentState: Codable, Hashable, Sendable {
        /// Whether the take is currently paused (frozen) vs. actively recording.
        var isPaused: Bool
        /// Wall-clock anchor the elapsed timeline maps to (`now - elapsed`) so the
        /// widget's on-device timer shows the correct value while recording.
        var startedAt: Date
        /// Elapsed seconds at the last update — rendered statically while paused.
        var elapsed: TimeInterval
    }
}
