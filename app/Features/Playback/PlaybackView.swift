import SwiftUI

/// Unified recording detail: playback transport plus, at a glance, the AI
/// summary (markdown-formatted) and the transcript — each shown only when it
/// exists. Generating/editing/mixing stay reachable via the action row.
struct PlaybackView: View {
    @Environment(StoreManager.self) private var store
    @State private var viewModel: PlaybackViewModel
    @State private var showEditor = false
    @State private var showMix = false
    @State private var showTranscript = false
    let recording: Recording
    let title: String

    init(recording: Recording) {
        self.recording = recording
        title = recording.title
        _viewModel = State(
            wrappedValue: PlaybackViewModel(
                recordingID: recording.id,
                fileName: recording.fileName,
                duration: recording.duration
            )
        )
    }

    /// Device tap markers, in order. Empty for recordings made in the app.
    private var markers: [TimeInterval] { recording.markers.sorted() }

    private var sortedSegments: [TranscriptSegment] {
        recording.segmentList.sorted { $0.startTime < $1.startTime }
    }

    /// The split view's detail column does not inherit the root tab bar's
    /// safe-area inset, so the last transcript lines would sit behind it.
    @Environment(\.tabBarHeight) private var tabBarHeight

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                player
                // Actions sit directly under the player so they never collide
                // with the root tab bar at the bottom of the screen.
                actionRow
                    .padding(.horizontal, Theme.Spacing.lg)
                if recording.summary?.isEmpty == false { summarySection }
                if !recording.segmentList.isEmpty { transcriptSection }
            }
            .padding(.vertical, Theme.Spacing.lg)
            .padding(.bottom, tabBarHeight)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Von vorn", systemImage: "arrow.counterclockwise") {
                    Haptics.impact(.light)
                    Task { await viewModel.restart() }
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack { EditorView(recording: recording) }
        }
        .sheet(isPresented: $showMix) {
            NavigationStack { MixView(recording: recording) }
        }
        .sheet(isPresented: $showTranscript) {
            NavigationStack { TranscriptView(recording: recording, playback: viewModel) }
        }
        .task { await viewModel.load() }
        .onDisappear { Task { await viewModel.stopIfPlaying() } }
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

    // MARK: - Player (hero)

    private var player: some View {
        VStack(spacing: Theme.Spacing.lg) {
            WaveformView(
                buckets: viewModel.buckets,
                progress: viewModel.progress,
                markers: markers,
                duration: viewModel.duration,
                onScrub: { fraction in Task { await viewModel.seek(toFraction: fraction) } }
            )
            .frame(height: 160)
            .padding(.horizontal, Theme.Spacing.lg)
            .background { DepthGlow().frame(height: 280) }

            HStack {
                Text(TimeFormatting.timecode(viewModel.position))
                Spacer()
                Text(TimeFormatting.timecode(viewModel.duration))
            }
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(Theme.Colors.textSecondary)
            .padding(.horizontal, Theme.Spacing.lg)

            if !markers.isEmpty { markerStrip }

            transport
        }
    }

    /// Tap markers of a Soundcore Work import: tapping a chip jumps there.
    private var markerStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(Array(markers.enumerated()), id: \.offset) { index, marker in
                    Button {
                        Haptics.impact(.light)
                        Task { await viewModel.seek(to: marker) }
                    } label: {
                        Label(
                            TimeFormatting.shortTimecode(marker),
                            systemImage: "hand.tap.fill"
                        )
                        .font(.caption.monospacedDigit())
                        .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .accessibilityLabel(Text("Markierung \(index + 1)"))
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
    }

    /// Playback transport — enabled only once the audio is loaded.
    private var transport: some View {
        let ready = viewModel.duration > 0
        return HStack(spacing: Theme.Spacing.xl) {
            TransportButton(systemName: "gobackward.10", size: 56, accessibilityLabel: "10 Sekunden zurück") {
                Haptics.impact(.light); Task { await viewModel.skip(by: -10) }
            }
            CircleIconButton(
                systemName: viewModel.isPlaying ? "pause.fill" : "play.fill",
                tint: Theme.Colors.onAccent,
                background: Theme.Colors.accent,
                diameter: 84,
                accessibilityLabel: viewModel.isPlaying ? "Pause" : "Wiedergabe"
            ) { Task { await viewModel.togglePlayback() } }
            .accessibilityIdentifier("transport.play")
            TransportButton(systemName: "goforward.10", size: 56, accessibilityLabel: "10 Sekunden vor") {
                Haptics.impact(.light); Task { await viewModel.skip(by: 10) }
            }
        }
        .disabled(!ready)
        .opacity(ready ? 1 : 0.4)
    }

    // MARK: - AI summary

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Label("KI-Zusammenfassung", systemImage: "sparkles")
                    .font(Theme.Font.cardTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Badge(systemName: "sparkles", title: "KI")
            }
            if let aiTitle = recording.aiTitle, !aiTitle.isEmpty {
                Text(aiTitle)
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            if let summary = recording.summary {
                Text(markdown(summary))
                    .font(.callout)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
        .padding(.horizontal, Theme.Spacing.lg)
    }

    // MARK: - Transcript

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Label("Transkript", systemImage: "captions.bubble")
                    .font(Theme.Font.cardTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Button("Öffnen & Export") { showTranscript = true }
                    .font(.subheadline)
            }
            LazyVStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                ForEach(sortedSegments) { segment in
                    transcriptRow(segment)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }

    private func transcriptRow(_ segment: TranscriptSegment) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Text(TimeFormatting.shortTimecode(segment.startTime))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.Colors.accent)
            Text(segment.text)
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard viewModel.duration > 0 else { return }
            Task {
                await viewModel.seek(toFraction: segment.startTime / viewModel.duration)
                if !viewModel.isPlaying { await viewModel.togglePlayback() }
            }
        }
    }

    // MARK: - Actions

    private var actionRow: some View {
        HStack(spacing: Theme.Spacing.md) {
            ActionTile(
                systemName: "captions.bubble",
                title: recording.segmentList.isEmpty ? "Transkribieren" : "Transkript",
                premium: !store.isUnlocked(.ai)
            ) { showTranscript = true }
            .accessibilityIdentifier("action.transcript")
            ActionTile(systemName: "slider.horizontal.3", title: "Bearbeiten") { showEditor = true }
                .accessibilityIdentifier("action.edit")
            ActionTile(systemName: "waveform.badge.plus", title: "Mix") { showMix = true }
                .accessibilityIdentifier("action.mix")
        }
    }

    /// Renders summary text as markdown, falling back to plain text.
    private func markdown(_ string: String) -> AttributedString {
        (try? AttributedString(
            markdown: string,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(string)
    }
}
