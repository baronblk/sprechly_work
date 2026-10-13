import SoundcoreWorkKit
import SwiftData
import SwiftUI

/// Geräte-Ansicht für den Soundcore Work: verbinden, Live-Status, Aufnahmen
/// importieren.
struct WorkDeviceView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = WorkDeviceViewModel()
    var onOpenLibrary: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                connectionCard
                if viewModel.isReady {
                    liveCard
                    recordingsSection
                }
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationTitle(Text("Work-Gerät"))
        .alert(
            Text("Fehler"),
            isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button(role: .cancel) { viewModel.errorMessage = nil } label: { Text("OK") }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onDisappear { Task { await viewModel.disconnect() } }
    }

    // MARK: - Verbindung

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(viewModel.connection.label)
                    .font(Theme.Font.rowTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                if viewModel.connection.isBusy || viewModel.isLoadingList {
                    ProgressView().controlSize(.small)
                }
            }

            if case .failed(let reason) = viewModel.connection {
                Text(reason)
                    .font(.footnote)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Text("Der Work erlaubt nur eine Bluetooth-Verbindung. Trenne ihn vorher vom Handy.")
                .font(.footnote)
                .foregroundStyle(Theme.Colors.textSecondary)

            if viewModel.isReady {
                Button {
                    Task { await viewModel.disconnect() }
                } label: {
                    Text("Trennen")
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    Task { await viewModel.connect() }
                } label: {
                    Text("Verbinden")
                }
                .buttonStyle(.goldProminent)
                .disabled(viewModel.connection.isBusy)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
    }

    private var statusColor: Color {
        switch viewModel.connection {
        case .ready: Theme.Colors.success
        case .connecting: Theme.Colors.accent
        case .failed: Theme.Colors.destructive
        case .disconnected: Theme.Colors.textSecondary
        }
    }

    // MARK: - Live-Status

    /// Zeigt, was am Gerät gerade passiert. Das Gerät meldet nur Start und
    /// Ende – eine Pause am Gerät ist über Bluetooth nicht erkennbar.
    @ViewBuilder private var liveCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            switch viewModel.liveActivity {
            case .idle:
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text("Warte auf das Gerät – drücke am Work die Aufnahmetaste.")
                        .font(.footnote)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

            case .recording(_, _):
                HStack(spacing: Theme.Spacing.sm) {
                    Circle()
                        .fill(Theme.Colors.destructive)
                        .frame(width: 12, height: 12)
                        .symbolEffect(.pulse)
                    Text("Aufnahme läuft")
                        .font(Theme.Font.rowTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    Text(TimeFormatting.timecode(viewModel.runningDuration))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(Theme.Colors.accent)
                        .monospacedDigit()
                }
                Text("Die Zeit ist eine Schätzung; die genaue Dauer meldet das Gerät am Ende.")
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.textSecondary)

            case .finished(_, let duration):
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.Colors.success)
                    Text("Aufnahme fertig – \(TimeFormatting.timecode(duration))")
                        .font(Theme.Font.rowTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(
            viewModel.liveActivity.isRecording
                ? Theme.Colors.destructive.opacity(0.12)
                : Theme.Colors.surface,
            in: RoundedRectangle(cornerRadius: Theme.Radius.lg)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(liveAccessibilityLabel)
    }

    private var liveAccessibilityLabel: Text {
        switch viewModel.liveActivity {
        case .idle: Text("Gerät bereit, keine Aufnahme")
        case .recording: Text("Aufnahme läuft seit \(TimeFormatting.timecode(viewModel.runningDuration))")
        case .finished(_, let duration): Text("Aufnahme fertig, Dauer \(TimeFormatting.timecode(duration))")
        }
    }

    // MARK: - Aufnahmen

    @ViewBuilder private var recordingsSection: some View {
        if viewModel.items.isEmpty {
            EmptyStateView(
                systemName: "waveform",
                title: "Keine Aufnahmen",
                message: "Auf dem Work liegen keine Aufnahmen."
            )
        } else {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text("Aufnahmen auf dem Gerät")
                        .font(Theme.Font.screenTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    Button {
                        Task { await viewModel.reloadList() }
                    } label: {
                        Text("Neu laden")
                    }
                    .font(.footnote)
                    .disabled(viewModel.isLoadingList)
                }

                ForEach(viewModel.items) { item in
                    WorkRecordingRow(item: item) {
                        Task { await viewModel.importRecording(item, context: modelContext) }
                    }
                }

                if viewModel.items.contains(where: { $0.importState == .notImported }) {
                    Button {
                        Task { await viewModel.importAll(context: modelContext) }
                    } label: {
                        Text("Alle importieren")
                    }
                    .buttonStyle(.goldProminent)
                    .padding(.top, Theme.Spacing.sm)
                }

                Button { onOpenLibrary() } label: { Text("Zur Bibliothek") }
                    .font(.footnote)
                    .padding(.top, Theme.Spacing.xs)
            }
        }
    }
}

/// Eine Zeile der Geräte-Aufnahmeliste.
private struct WorkRecordingRow: View {
    let item: WorkRecordingItem
    let onImport: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.recording.recordedAt, format: .dateTime.day().month().hour().minute())
                    .font(Theme.Font.rowTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("\(TimeFormatting.timecode(item.recording.duration)) · \(item.identifierText)")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .monospacedDigit()
            }
            Spacer()
            trailing
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var trailing: some View {
        switch item.importState {
        case .notImported:
            Button(action: onImport) { Text("Importieren") }
                .buttonStyle(.bordered)
        case .downloading(let progress):
            VStack(spacing: 2) {
                ProgressView(value: progress).frame(width: 60)
                Text("\(Int(progress * 100)) %")
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .monospacedDigit()
            }
        case .converting:
            HStack(spacing: Theme.Spacing.xs) {
                ProgressView().controlSize(.small)
                Text("Wandle um").font(.caption2).foregroundStyle(Theme.Colors.textSecondary)
            }
        case .imported:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.Colors.success)
                .accessibilityLabel(Text("In der Bibliothek"))
        case .failed(let reason):
            VStack(alignment: .trailing, spacing: 2) {
                Button(action: onImport) { Text("Erneut") }
                    .buttonStyle(.bordered)
                Text(reason)
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.destructive)
                    .lineLimit(2)
            }
        }
    }
}
