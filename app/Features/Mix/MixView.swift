import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct MixView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(RatingPromptController.self) private var rating
    @State private var viewModel: MixViewModel
    @State private var showPicker = false
    @State private var showFileImporter = false

    @Query(filter: #Predicate<Recording> { !$0.isTrashed }, sort: \Recording.createdAt, order: .reverse)
    private var recordings: [Recording]

    init(recording: Recording) {
        _viewModel = State(wrappedValue: MixViewModel(recording: recording))
    }

    private var isBusy: Bool { viewModel.phase == .rendering }
    private var candidates: [Recording] {
        recordings.filter { $0.fileName != viewModel.mainFileName }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                mainSection
                mixSection
                if viewModel.hasMixTrack { optionsSection }
                formatAndAction
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationTitle("Mix")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("Fertig") { dismiss() } }
        }
        // Register on the way out, not the moment the render finishes: the
        // screen stays open to offer sharing, and a review prompt on top of a
        // still-open sheet is both ugly and easy to miss.
        .onDisappear { if viewModel.phase == .done { rating.registerDelight() } }
        .onAppear { viewModel.configure(modelContext: modelContext) }
        .task { await viewModel.loadMainWaveform() }
        .sheet(isPresented: $showPicker) { pickerSheet }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.audio]) { result in
            switch result {
            case .success(let url):
                Task { await viewModel.importExternal(url: url) }
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
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

    private var mainSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Aufnahme").font(.subheadline).foregroundStyle(Theme.Colors.textSecondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    WaveformView(buckets: viewModel.mainBuckets)
                    if viewModel.hasMixTrack {
                        Rectangle()
                            .fill(Theme.Colors.accent)
                            .frame(width: 3)
                            .offset(x: TrimGeometry.x(forTime: viewModel.offset, width: geo.size.width, duration: viewModel.mainDuration))
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        viewModel.offset = min(viewModel.mainDuration, max(0,
                                            TrimGeometry.time(forX: value.location.x, width: geo.size.width, duration: viewModel.mainDuration)))
                                    }
                            )
                    }
                }
            }
            .frame(height: 120)
        }
    }

    @ViewBuilder
    private var mixSection: some View {
        if viewModel.hasMixTrack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    Text("Mix-Spur: \(viewModel.selectedMixTitle ?? "")")
                        .font(.subheadline).foregroundStyle(Theme.Colors.textSecondary)
                    Spacer()
                    Menu("Ändern") {
                        Button("Aus Aufnahmen") { showPicker = true }
                        Button("Aus Dateien") { showFileImporter = true }
                    }
                    .disabled(isBusy)
                }
                TrimmableWaveformView(
                    buckets: viewModel.mixBuckets,
                    duration: viewModel.mixDuration,
                    start: $viewModel.mixTrimStart,
                    end: $viewModel.mixTrimEnd
                )
                .frame(height: 120)
                .disabled(isBusy)
            }
        } else {
            VStack(spacing: Theme.Spacing.sm) {
                Button {
                    showPicker = true
                } label: {
                    Label("Aus Aufnahmen wählen", systemImage: "waveform").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                Button {
                    showFileImporter = true
                } label: {
                    Label("Aus Dateien importieren", systemImage: "folder.badge.plus").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var optionsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Mix-Lautstärke")
                        Spacer()
                        Text("\(Int(viewModel.volume * 100)) %").monospacedDigit()
                    }
                    Slider(value: $viewModel.volume, in: 0...1)
                }
                VStack(alignment: .leading) {
                    HStack {
                        Text("Position")
                        Spacer()
                        Text(TimeFormatting.timecode(viewModel.offset)).monospacedDigit()
                    }
                    Slider(value: $viewModel.offset, in: 0...max(0.01, viewModel.mainDuration))
                }
            }
            .padding(.vertical, Theme.Spacing.xs)
        }
        .disabled(isBusy)
    }

    private var formatAndAction: some View {
        VStack(spacing: Theme.Spacing.md) {
            Picker("Format", selection: $viewModel.format) {
                ForEach(ExportFormat.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
            .disabled(isBusy || !viewModel.hasMixTrack)

            switch viewModel.phase {
            case .idle, .failed:
                Button {
                    Task { await viewModel.render() }
                } label: {
                    Text("Mixen").frame(maxWidth: .infinity)
                }
                .buttonStyle(.goldProminent)
                .disabled(!viewModel.canRender)
            case .rendering:
                ProgressView(value: viewModel.progress) { Text("Wird gemischt…") }
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

    private var pickerSheet: some View {
        NavigationStack {
            List(candidates) { recording in
                Button {
                    Task { await viewModel.selectMix(recording) }
                    showPicker = false
                } label: {
                    VStack(alignment: .leading) {
                        Text(recording.title).foregroundStyle(Theme.Colors.textPrimary)
                        Text(TimeFormatting.shortTimecode(recording.duration))
                            .font(.caption).foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }
            .navigationTitle("Mix-Spur wählen")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Abbrechen") { showPicker = false } } }
            .overlay { if candidates.isEmpty { ContentUnavailableView("Keine weitere Aufnahme", systemImage: "waveform") } }
        }
    }
}
