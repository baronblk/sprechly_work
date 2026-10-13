import SwiftData
import SwiftUI

struct MergeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(RatingPromptController.self) private var rating
    @State private var viewModel: MergeViewModel

    init(recordings: [Recording]) {
        _viewModel = State(wrappedValue: MergeViewModel(recordings: recordings))
    }

    private var isBusy: Bool { viewModel.phase == .rendering }

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section("Reihenfolge") {
                    ForEach(viewModel.ordered) { recording in
                        HStack {
                            Text(recording.title)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Spacer()
                            Text(TimeFormatting.shortTimecode(recording.duration))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                    .onMove { viewModel.move(fromOffsets: $0, toOffset: $1) }
                }
            }
            .environment(\.editMode, .constant(.active))
            .disabled(isBusy)

            VStack(spacing: Theme.Spacing.md) {
                Picker("Format", selection: $viewModel.format) {
                    ForEach(ExportFormat.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                .disabled(isBusy)

                actionSection
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationTitle("Zusammenführen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Fertig") { dismiss() }
            }
        }
        // Register on the way out, not the moment the render finishes: the
        // screen stays open to offer sharing, and a review prompt on top of a
        // still-open sheet is both ugly and easy to miss.
        .onDisappear { if viewModel.phase == .done { rating.registerDelight() } }
        .onAppear { viewModel.configure(modelContext: modelContext) }
        .alert(
            "Fehler",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var actionSection: some View {
        switch viewModel.phase {
        case .idle, .failed:
            Button {
                Task { await viewModel.render() }
            } label: {
                Text("Zusammenführen").frame(maxWidth: .infinity)
            }
            .buttonStyle(.goldProminent)
        case .rendering:
            ProgressView(value: viewModel.progress) { Text("Wird zusammengeführt…") }
        case .done:
            VStack(spacing: Theme.Spacing.sm) {
                Label("In Bibliothek gespeichert", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Theme.Colors.accent)
                if let url = viewModel.exportedURL {
                    ShareLink(item: url) { Label("Teilen", systemImage: "square.and.arrow.up") }
                }
            }
        }
    }
}
