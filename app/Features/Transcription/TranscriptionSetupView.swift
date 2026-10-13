import SwiftUI

struct TranscriptionSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = TranscriptionSetupViewModel()

    var body: some View {
        List {
            Section {
                ForEach(viewModel.filteredEntries) { entry in
                    row(for: entry)
                }
                if viewModel.filteredEntries.isEmpty {
                    Text("Keine Sprache gefunden")
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            } footer: {
                Text("Transkription läuft vollständig on-device. Sprachmodelle werden einmalig geladen (mehrere hundert MB) und funktionieren danach offline.")
            }
        }
        .navigationTitle("Sprachmodelle")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.searchText, prompt: "Sprache suchen")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("Fertig") { dismiss() } }
        }
        .task { await viewModel.refresh() }
    }

    @ViewBuilder
    private func row(for entry: TranscriptionSetupViewModel.LocaleEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(entry.displayName).foregroundStyle(Theme.Colors.textPrimary)
                Text(statusText(entry.state))
                    .font(.caption)
                    .foregroundStyle(statusColor(entry.state))
            }
            Spacer()
            trailing(for: entry)
        }
    }

    @ViewBuilder
    private func trailing(for entry: TranscriptionSetupViewModel.LocaleEntry) -> some View {
        switch entry.state {
        case .installed:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.Colors.accent)
        case .downloading(let progress):
            ProgressView(value: progress).frame(width: 80)
        case .notInstalled, .failed, .insufficientStorage:
            Button("Laden") { viewModel.download(entry.locale) }
                .buttonStyle(.bordered)
        case .unsupported:
            Text("Nicht verfügbar").font(.caption).foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    private func statusText(_ state: TranscriptionAssetState) -> String {
        switch state {
        case .unsupported: return String(localized: "Auf diesem Gerät nicht unterstützt")
        case .notInstalled: return String(localized: "Nicht geladen")
        case .downloading(let p): return String(localized: "Wird geladen… \(Int(p * 100)) %")
        case .installed: return String(localized: "Bereit (offline)")
        case .failed(let message): return String(localized: "Fehlgeschlagen: \(message)")
        case .insufficientStorage: return String(localized: "Nicht genug Speicherplatz")
        }
    }

    private func statusColor(_ state: TranscriptionAssetState) -> Color {
        switch state {
        case .installed: return Theme.Colors.accent
        case .failed, .insufficientStorage, .unsupported: return Theme.Colors.destructive
        default: return Theme.Colors.textSecondary
        }
    }
}
