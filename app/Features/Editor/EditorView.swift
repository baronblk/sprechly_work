import SwiftData
import SwiftUI

struct EditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(RatingPromptController.self) private var rating
    @State private var viewModel: EditorViewModel
    @State private var showDiscardConfirm = false

    init(recording: Recording) {
        _viewModel = State(wrappedValue: EditorViewModel(recording: recording))
    }

    private var isBusy: Bool { viewModel.phase == .working }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                trimSection
                cutSection
                optionsSection
                actionSection
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationTitle("Bearbeiten")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Fertig") {
                    // The editor is non-destructive: a cut only changes the
                    // working copy and is persisted via "Als neue Aufnahme
                    // speichern". Don't silently discard an unsaved edit.
                    if viewModel.hasEdits && viewModel.phase == .idle {
                        showDiscardConfirm = true
                    } else {
                        dismiss()
                    }
                }
                .accessibilityIdentifier("editor.done")
            }
        }
        .confirmationDialog(
            "Nicht gespeicherte Bearbeitung",
            isPresented: $showDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button("Als neue Aufnahme speichern") { Task { await viewModel.save() } }
            Button("Änderungen verwerfen", role: .destructive) { dismiss() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Dein Schnitt wird als neue Aufnahme gespeichert – die Originalaufnahme bleibt unverändert.")
        }
        // Register on the way out, not the moment the render finishes: the
        // screen stays open to offer sharing, and a review prompt on top of a
        // still-open sheet is both ugly and easy to miss.
        .onDisappear { if viewModel.phase == .done { rating.registerDelight() } }
        .onAppear { viewModel.configure(modelContext: modelContext) }
        .task { await viewModel.loadWaveform() }
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

    // Primary: trim is the dominant interaction of this screen.
    private var trimSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            TrimmableWaveformView(
                buckets: viewModel.buckets,
                duration: viewModel.duration,
                start: $viewModel.trimStart,
                end: $viewModel.trimEnd
            )
            .frame(height: 200)
            .disabled(isBusy)

            HStack {
                Text(TimeFormatting.timecode(viewModel.trimRange.lowerBound))
                Spacer()
                Text("Auswahl \(TimeFormatting.timecode(viewModel.trimRange.upperBound - viewModel.trimRange.lowerBound))")
                Spacer()
                Text(TimeFormatting.timecode(viewModel.trimRange.upperBound))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    // Cut actions on the current selection / whole take.
    private var cutSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Button {
                    Task { await viewModel.keepSelection() }
                } label: {
                    Label("Auswahl behalten", systemImage: "scissors").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                Button(role: .destructive) {
                    Task { await viewModel.removeSelection() }
                } label: {
                    Label("Auswahl entfernen", systemImage: "delete.left").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            Button {
                Task { await viewModel.removeSilence() }
            } label: {
                Label("Stille automatisch entfernen", systemImage: "wand.and.stars").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .disabled(isBusy)
    }

    // Secondary: speed/normalize/format are compact options under the trim.
    private var optionsSection: some View {
        GroupBox("Weitere Optionen") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Tempo")
                        Spacer()
                        Text(String(format: "%.2f×", viewModel.speed)).monospacedDigit()
                    }
                    Slider(value: $viewModel.speed, in: 0.5...3.0, step: 0.05)
                }
                Toggle("Lautstärke normalisieren", isOn: $viewModel.normalize)
                Picker("Format", selection: $viewModel.format) {
                    ForEach(ExportFormat.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .padding(.vertical, Theme.Spacing.xs)
        }
        .disabled(isBusy)
    }

    @ViewBuilder
    private var actionSection: some View {
        switch viewModel.phase {
        case .idle, .failed:
            Button {
                Task { await viewModel.save() }
            } label: {
                Text("Als neue Aufnahme speichern").frame(maxWidth: .infinity)
            }
            .buttonStyle(.goldProminent)
        case .working:
            ProgressView()
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
