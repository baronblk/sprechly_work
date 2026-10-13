import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    private enum Scope: String, CaseIterable, Identifiable {
        case library = "Bibliothek"
        case trash = "Papierkorb"
        var id: String { rawValue }
    }

    /// Switches the root to the recording tab (wired from `RootView`), so the
    /// empty library can offer a direct call to action.
    var onStartRecording: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = LibraryViewModel()
    @State private var scope: Scope = .library
    @State private var searchText = ""
    @State private var renaming: Recording?
    @State private var renameText = ""
    @State private var isSelecting = false
    @State private var selection: Set<UUID> = []
    @State private var showMerge = false
    @State private var showSettings = false
    @State private var showImporter = false
    @State private var selectedRecording: Recording?

    @Query(filter: #Predicate<Recording> { !$0.isTrashed }, sort: \Recording.createdAt, order: .reverse)
    private var active: [Recording]

    @Query(filter: #Predicate<Recording> { $0.isTrashed }, sort: \Recording.createdAt, order: .reverse)
    private var trashed: [Recording]

    private var visible: [Recording] {
        let base = scope == .library ? active : trashed
        guard !searchText.isEmpty else { return base }
        return base.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                Picker("Ansicht", selection: $scope) {
                    ForEach(Scope.allCases) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.sm)

                List(selection: $selectedRecording) {
                    ForEach(visible) { recording in
                        row(for: recording)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .overlay { if visible.isEmpty { emptyState } }
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .overlay { if viewModel.isImporting { importingOverlay } }
            .navigationSplitViewColumnWidth(min: 300, ideal: 360, max: 460)
            .navigationTitle("Sprechly")
            // Pinned under the title on purpose: iOS 26 otherwise parks the
            // search field at the bottom edge, where this app's own tab bar
            // (a `safeAreaInset`, not a native TabView) covers it completely.
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Suchen"
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Einstellungen", systemImage: "gearshape") { showSettings = true }
                        .accessibilityIdentifier("settings.open")
                }
                if scope == .library {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(isSelecting ? "Abbrechen" : "Auswählen") {
                            isSelecting.toggle()
                            if !isSelecting { selection.removeAll() }
                        }
                    }
                    if !isSelecting {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Importieren", systemImage: "square.and.arrow.down") {
                                showImporter = true
                            }
                            .disabled(viewModel.isImporting)
                        }
                    }
                }
                if scope == .trash && !trashed.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Leeren", role: .destructive) {
                            if let selected = selectedRecording, selected.isTrashed { selectedRecording = nil }
                            viewModel.emptyTrash(trashed, context: modelContext)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { selectionBar }
            .sheet(isPresented: $showMerge) {
                NavigationStack {
                    MergeView(recordings: active.filter { selection.contains($0.id) })
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack { SettingsView() }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    Task { await viewModel.importRecordings(from: urls, context: modelContext) }
                case .failure(let error):
                    viewModel.errorMessage = error.localizedDescription
                }
            }
            .alert(
                "Import fehlgeschlagen",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .alert("Umbenennen", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField("Titel", text: $renameText)
                Button("Abbrechen", role: .cancel) { renaming = nil }
                Button("Speichern") {
                    if let renaming { viewModel.rename(renaming, to: renameText, context: modelContext) }
                    renaming = nil
                }
            }
        } detail: {
            if let selectedRecording {
                PlaybackView(recording: selectedRecording)
            } else {
                EmptyStateView(
                    systemName: "waveform",
                    title: "Aufnahme wählen",
                    message: "Wähle links eine Aufnahme, um sie abzuspielen, zu bearbeiten oder zu transkribieren."
                )
                .background(Theme.Colors.background.ignoresSafeArea())
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: selectedRecording) { _, newValue in
            // Returning to the list (or switching) stops the active playback —
            // selection-driven, so it doesn't rely on the detail's onDisappear.
            if newValue == nil { NowPlaying.shared.stopAll() }
        }
    }

    /// Floating action bar above the tab bar while selecting (a `.bottomBar`
    /// toolbar item would sit *behind* the TabView's tab bar).
    @ViewBuilder
    private var selectionBar: some View {
        if scope == .library && isSelecting {
            Button { showMerge = true } label: {
                Text("Zusammenführen (\(selection.count))")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.goldProminent)
            .controlSize(.large)
            .disabled(selection.count < 2)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(.bar)
        }
    }

    @ViewBuilder
    private func row(for recording: Recording) -> some View {
        if scope == .library && isSelecting {
            Button { toggleSelection(recording) } label: {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: selection.contains(recording.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selection.contains(recording.id) ? Theme.Colors.accent : Theme.Colors.textSecondary)
                    rowContent(recording)
                }
            }
            .buttonStyle(.plain)
            .listRowBackground(Theme.Colors.surface)
        } else {
            rowContent(recording)
            .tag(recording)
            .listRowBackground(Theme.Colors.surface)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if scope == .library {
                    Button("Löschen", role: .destructive) {
                        clearSelectionIfNeeded(recording)
                        viewModel.trash(recording, context: modelContext)
                    }
                    Button("Umbenennen") { startRename(recording) }.tint(Theme.Colors.accent)
                } else {
                    Button("Endgültig löschen", role: .destructive) {
                        clearSelectionIfNeeded(recording)
                        viewModel.permanentlyDelete(recording, context: modelContext)
                    }
                    Button("Wiederherstellen") { viewModel.restore(recording, context: modelContext) }
                        .tint(Theme.Colors.accent)
                }
            }
        }
    }

    /// Clears the detail selection if the given recording is the one shown, so a
    /// deleted recording doesn't stay open in the split view.
    private func clearSelectionIfNeeded(_ recording: Recording) {
        if selectedRecording == recording { selectedRecording = nil }
    }

    private func toggleSelection(_ recording: Recording) {
        if selection.contains(recording.id) {
            selection.remove(recording.id)
        } else {
            selection.insert(recording.id)
        }
    }

    private func rowContent(_ recording: Recording) -> some View {
        let hasTranscript = !recording.segmentList.isEmpty
        let hasSummary = recording.summary?.isEmpty == false
        return HStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle().fill(Theme.Colors.accentSoft).frame(width: 44, height: 44)
                Image(systemName: "waveform")
                    .foregroundStyle(Theme.Colors.accent)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(recording.title)
                    .font(Theme.Font.rowTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                Text("\(recording.createdAt.formatted(date: .abbreviated, time: .shortened)) · \(TimeFormatting.shortTimecode(recording.duration))")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                if hasTranscript || hasSummary {
                    HStack(spacing: Theme.Spacing.xs) {
                        if hasTranscript { Badge(systemName: "captions.bubble", title: "Transkript") }
                        if hasSummary { Badge(systemName: "sparkles", title: "KI") }
                    }
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityElement(children: .combine)
    }

    private var importingOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: Theme.Spacing.md) {
                ProgressView()
                Text("Wird importiert…")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .padding(Theme.Spacing.xl)
            .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 16))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Wird importiert")
    }

    @ViewBuilder
    private var emptyState: some View {
        if scope == .library {
            EmptyStateView(
                systemName: "mic.fill",
                title: searchText.isEmpty ? "Keine Aufnahmen" : "Nichts gefunden",
                message: searchText.isEmpty
                    ? "Starte deine erste Aufnahme — sie erscheint dann hier."
                    : "Keine Aufnahme passt zu „\(searchText)“.",
                actionTitle: searchText.isEmpty ? "Aufnahme starten" : nil,
                action: searchText.isEmpty ? onStartRecording : nil
            )
        } else {
            EmptyStateView(
                systemName: "trash",
                title: "Papierkorb ist leer",
                message: "Gelöschte Aufnahmen erscheinen hier und werden nach 30 Tagen endgültig entfernt."
            )
        }
    }

    private func startRename(_ recording: Recording) {
        renameText = recording.title
        renaming = recording
    }
}
