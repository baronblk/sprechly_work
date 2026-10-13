import ActivityKit
import SwiftUI
import WidgetKit

/// Lock-screen banner + Dynamic Island for an in-progress recording. The elapsed
/// counter runs on-device via `Text(timerInterval:)` while recording and shows a
/// frozen value while paused.
struct RecordingLiveActivity: Widget {
    // Brand palette, inlined so the extension stays decoupled from the app's
    // DesignSystem (matches the vintage-microphone icon).
    private static let record = Color(red: 1.0, green: 0.36, blue: 0.30)
    private static let gold = Color(red: 0.89, green: 0.70, blue: 0.33)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingActivityAttributes.self) { context in
            lockScreen(context.state)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text("Sprechly").font(.headline)
                    } icon: {
                        statusIcon(context.state)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timer(context.state)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(statusText(context.state))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                statusIcon(context.state)
            } compactTrailing: {
                timer(context.state)
                    .font(.system(.body, design: .rounded))
                    .frame(maxWidth: 56)
            } minimal: {
                statusIcon(context.state)
            }
            .keylineTint(Self.record)
        }
    }

    private func lockScreen(_ state: RecordingActivityAttributes.ContentState) -> some View {
        HStack(spacing: 14) {
            statusIcon(state)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Sprechly")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white)
                Text(statusText(state))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            timer(state)
                .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private func statusIcon(_ state: RecordingActivityAttributes.ContentState) -> some View {
        Image(systemName: state.isPaused ? "pause.circle.fill" : "mic.fill")
            .foregroundStyle(state.isPaused ? Self.gold : Self.record)
            .symbolEffect(.pulse, isActive: !state.isPaused)
    }

    @ViewBuilder
    private func timer(_ state: RecordingActivityAttributes.ContentState) -> some View {
        if state.isPaused {
            Text(Self.clock(state.elapsed)).monospacedDigit()
        } else {
            Text(timerInterval: state.startedAt...Date.distantFuture, countsDown: false)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
    }

    private func statusText(_ state: RecordingActivityAttributes.ContentState) -> LocalizedStringKey {
        state.isPaused ? "Pausiert" : "Aufnahme läuft"
    }

    /// mm:ss (or h:mm:ss past an hour) for the frozen paused value.
    private static func clock(_ time: TimeInterval) -> String {
        let total = Int(time.rounded())
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }
}
