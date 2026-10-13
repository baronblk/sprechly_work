@preconcurrency import ActivityKit
import Foundation
import os

/// Abstracts the recording Live Activity so the view model stays testable and
/// the real ActivityKit calls are isolated. All calls are no-ops when Live
/// Activities are unavailable (iPad, disabled in Settings).
@MainActor
protocol RecordingActivityControlling {
    /// Begins a Live Activity for a fresh run (no-op if one is already live).
    func start(elapsed: TimeInterval, isPaused: Bool) async
    /// Reflects a state change (record ⇄ pause, resumed-from-cursor).
    func update(elapsed: TimeInterval, isPaused: Bool) async
    /// Dismisses the Live Activity (no-op if none is live).
    func end() async
}

/// Drives the lock-screen / Dynamic Island Live Activity for the active
/// recording via ActivityKit. The widget renders the elapsed timer on-device,
/// so this only pushes updates on state transitions, not per frame.
@MainActor
final class LiveActivityController: RecordingActivityControlling {
    // `Activity` is not Sendable; calling its nonisolated async `update`/`end`
    // on a MainActor-isolated stored property trips region isolation. Access is
    // already serialized on the MainActor (this whole type is @MainActor), so
    // opting the reference out of isolation is safe and avoids the false race.
    private nonisolated(unsafe) var activity: Activity<RecordingActivityAttributes>?
    private let logger = Logger(subsystem: "de.gcng.sprechly.work", category: "LiveActivity")

    func start(elapsed: TimeInterval, isPaused: Bool) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard activity == nil else {
            await update(elapsed: elapsed, isPaused: isPaused)
            return
        }
        do {
            activity = try Activity.request(
                attributes: RecordingActivityAttributes(),
                content: ActivityContent(state: makeState(elapsed: elapsed, isPaused: isPaused), staleDate: nil)
            )
        } catch {
            logger.error("Live Activity start failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func update(elapsed: TimeInterval, isPaused: Bool) async {
        guard let activity else { return }
        let content = ActivityContent(state: makeState(elapsed: elapsed, isPaused: isPaused), staleDate: nil)
        await activity.update(content)
    }

    func end() async {
        guard let activity else { return }
        self.activity = nil
        await activity.end(nil, dismissalPolicy: .immediate)
    }

    private func makeState(elapsed: TimeInterval, isPaused: Bool) -> RecordingActivityAttributes.ContentState {
        RecordingActivityAttributes.ContentState(
            isPaused: isPaused,
            startedAt: Date.now.addingTimeInterval(-elapsed),
            elapsed: elapsed
        )
    }
}
