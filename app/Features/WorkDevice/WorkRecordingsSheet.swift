import SoundcoreWorkKit
import SwiftData
import SwiftUI

/// Aufnahmen auf dem Soundcore Work: anzeigen und in die Bibliothek holen.
/// Wird über die Geräte-Karte im Aufnahme-Screen geöffnet.
struct WorkRecordingsSheet: View {
    @Environment(WorkDeviceViewModel.self) private var work
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if work.items.isEmpty {
                EmptyStateView(
                    systemName: "waveform",
                    title: work.isLoadingList ? "Lade …" : "Keine Aufnahmen",
                    message: work.isLoadingList ? nil : "Auf dem Work liegen keine Aufnahmen."
                )
            } else {
                list
            }
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationTitle(Text("Aufnahmen auf dem Work"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button { dismiss() } label: { Text("Fertig") }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    Task { await work.reloadList() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(work.isLoadingList)
                .accessibilityLabel(Text("Neu laden"))
            }
        }
        .task {
            if work.items.isEmpty { await work.reloadList() }
        }
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(work.items) { item in
                    WorkRecordingRow(item: item) {
                        Task { await work.importRecording(item, context: modelContext) }
                    }
                }

                if work.items.contains(where: { $0.importState == .notImported }) {
                    Button {
                        Task { await work.importAll(context: modelContext) }
                    } label: {
                        Text("Alle importieren")
                    }
                    .buttonStyle(.goldProminent)
                    .padding(.top, Theme.Spacing.sm)
                }

                Text("Importierte Aufnahmen liegen danach in der Bibliothek.")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.top, Theme.Spacing.xs)
            }
            .padding(Theme.Spacing.md)
        }
    }
}

/// Eine Zeile der Geräte-Aufnahmeliste.
struct WorkRecordingRow: View {
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
