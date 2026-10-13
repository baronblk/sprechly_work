import SwiftUI

/// Voice-memos-style record control: a red disc inside a thin ring that morphs
/// into a rounded square for "stop". Sleek — no heavy chrome.
struct RecordButton: View {
    enum Mode { case record, stop }

    var mode: Mode
    var size: CGFloat = 84
    var action: () -> Void

    private var innerSize: CGFloat { mode == .record ? size * 0.62 : size * 0.40 }
    private var innerRadius: CGFloat { mode == .record ? size * 0.31 : size * 0.10 }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.20), lineWidth: 3)
                    .frame(width: size, height: size)
                RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                    .fill(Theme.Colors.destructive)
                    .frame(width: innerSize, height: innerSize)
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: mode)
        .accessibilityLabel(Text(mode == .record ? "Aufnahme" : "Stoppen und speichern"))
        .accessibilityIdentifier(mode == .record ? "transport.record" : "transport.stop")
    }
}

/// A slim secondary transport control — light translucent disc, no heavy fill.
struct TransportButton: View {
    let systemName: String
    var size: CGFloat = 60
    var accessibilityLabel: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(width: size, height: size)
                .background(Circle().fill(Color.white.opacity(0.08)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel))
    }
}
