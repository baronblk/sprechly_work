import SoundcoreWorkKit
import SwiftData
import SwiftUI

/// Aufnahmen auf dem Soundcore Work: anzeigen und in die Bibliothek holen.
/// Wird über die Geräte-Karte im Aufnahme-Screen geöffnet.
struct WorkRecordingsSheet: View {
    @Environment(WorkDeviceViewModel.self) private var work
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Markierte Aufnahmen im Auswahlmodus.
    @State private var selection = Set<UInt32>()
    @State private var editMode: EditMode = .inactive
    /// Aufnahmen, für die gerade nachgefragt wird – leer heißt: keine Rückfrage.
    @State private var pendingDeletion: [WorkRecordingItem] = []

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
        .environment(\.editMode, $editMode)
        .toolbar { toolbarContent }
        .task {
            if work.items.isEmpty { await work.reloadList() }
        }
        .confirmationDialog(
            Text(pendingDeletion.count == 1
                 ? "Aufnahme auf dem Work löschen?"
                 : "\(pendingDeletion.count) Aufnahmen auf dem Work löschen?"),
            isPresented: .init(
                get: { !pendingDeletion.isEmpty },
                set: { if !$0 { pendingDeletion = [] } }
            ),
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                let targets = pendingDeletion
                pendingDeletion = []
                Task {
                    await work.deleteRecordings(targets)
                    selection.removeAll()
                    editMode = .inactive
                }
            } label: {
                Text("Löschen")
            }
            Button(role: .cancel) { pendingDeletion = [] } label: { Text("Abbrechen") }
        } message: {
            Text(deletionMessage)
        }
    }

    private var deletionMessage: String {
        let gesamt = pendingDeletion.reduce(0) { $0 + $1.recording.duration }
        return String(
            localized: "\(TimeFormatting.timecode(gesamt)) vom Gerät entfernen. Das lässt sich nicht rückgängig machen. Bereits importierte Aufnahmen bleiben in der Bibliothek."
        )
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            if editMode == .active {
                Button {
                    selection.removeAll()
                    editMode = .inactive
                } label: {
                    Text("Fertig")
                }
            } else {
                Button { dismiss() } label: { Text("Fertig") }
            }
        }
        ToolbarItem(placement: .cancellationAction) {
            if editMode == .active {
                Button(role: .destructive) {
                    pendingDeletion = work.items.filter { selection.contains($0.id) }
                } label: {
                    Text("Löschen (\(selection.count))")
                }
                .disabled(selection.isEmpty)
            } else {
                Button {
                    editMode = .active
                } label: {
                    Text("Auswählen")
                }
                .disabled(work.items.isEmpty)
            }
        }
        ToolbarItem(placement: .topBarLeading) {
            if editMode != .active {
                Button {
                    Task { await work.reloadList() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(work.isLoadingList)
                .accessibilityLabel(Text("Neu laden"))
            }
        }
    }

    private var list: some View {
        List(selection: $selection) {
            ForEach(work.items) { item in
                WorkRecordingRow(item: item) {
                    Task { await work.importRecording(item, context: modelContext) }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        pendingDeletion = [item]
                    } label: {
                        Label { Text("Löschen") } icon: { Image(systemName: "trash") }
                    }
                }
            }

            if editMode != .active {
                Section {
                    if work.items.contains(where: { $0.importState == .notImported }) {
                        Button {
                            Task { await work.importAll(context: modelContext) }
                        } label: {
                            Text("Alle importieren")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.goldProminent)
                    }
                    Text("Nach links wischen löscht eine Aufnahme auf dem Gerät. Über „Auswählen“ mehrere auf einmal.")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
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
