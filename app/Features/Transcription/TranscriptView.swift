import SwiftData
import SwiftUI

struct TranscriptView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreManager.self) private var store
    @Environment(RatingPromptController.self) private var rating
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: TranscriptionViewModel
    @State private var summaryVM: AISummaryViewModel
    // Mirror the ephemeral translation so the toolbar export reliably re-renders.
    @State private var exportTranslation: String?
    @State private var exportTranslationLanguage: String?
    /// Reading view: flowing paragraphs instead of timestamped segment rows.
    @State private var readingMode = false

    /// Shared player from the playback screen — one engine, one audio session.
    let playback: PlaybackViewModel

    init(recording: Recording, playback: PlaybackViewModel) {
        _viewModel = State(wrappedValue: TranscriptionViewModel(recording: recording))
        _summaryVM = State(wrappedValue: AISummaryViewModel(recording: recording))
        self.playback = playback
    }

    private var isTranscribing: Bool { viewModel.phase == .transcribing }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    summaryCard
                    translationCard
                    transcriptContent
                }
                .padding(.vertical, Theme.Spacing.sm)
            }
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationTitle("Transkript")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !viewModel.segments.isEmpty && !isTranscribing {
                ToolbarItem(placement: .topBarTrailing) { readingToggle }
            }
            if !viewModel.segments.isEmpty {
                ToolbarItem(placement: .topBarTrailing) { exportControl }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Fertig") { dismiss() }
                    .accessibilityIdentifier("transcript.done")
            }
        }
        .onAppear {
            viewModel.configure(modelContext: modelContext, store: store)
            summaryVM.configure(modelContext: modelContext, store: store)
            // Seed the export mirror from a restored translation (onChange won't
            // fire for the value set in the view model's init).
            exportTranslation = summaryVM.translatedText
            exportTranslationLanguage = summaryVM.translationLanguage?.displayName
        }
        .task { await viewModel.loadInstalledLocales() }
        .task { await summaryVM.refreshAvailability() }
        .onChange(of: summaryVM.translatedText) { _, value in
            exportTranslation = value
            exportTranslationLanguage = summaryVM.translationLanguage?.displayName
            if value != nil { rating.registerDelight() }
        }
        // Positive, completed moments → maybe ask for a rating (gated/throttled
        // by the controller). Never on errors or paywalls.
        .onChange(of: viewModel.phase) { _, phase in
            if phase == .done, !viewModel.segments.isEmpty { rating.registerDelight() }
        }
        .onChange(of: summaryVM.phase) { _, phase in
            if phase == .done { rating.registerDelight() }
        }
        .sheet(isPresented: $viewModel.showPaywall) {
            NavigationStack { PaywallView(previewText: viewModel.previewText) }
        }
        .sheet(isPresented: $summaryVM.showPaywall) {
            NavigationStack { PaywallView() }
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
        .alert(
            "Fehler",
            isPresented: Binding(
                get: { summaryVM.errorMessage != nil },
                set: { if !$0 { summaryVM.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(summaryVM.errorMessage ?? "")
        }
    }

    /// Export menu (TXT/Markdown). Gated on `.ai`: unlocked → share the file,
    /// locked → paywall. File generation lives in the view model.
    @ViewBuilder
    private var exportControl: some View {
        if store.isUnlocked(.ai) {
            Menu {
                ForEach(TranscriptExportFormat.allCases) { format in
                    if let url = viewModel.exportFile(
                        format,
                        translation: exportTranslation,
                        translationLanguage: exportTranslationLanguage
                    ) {
                        ShareLink(item: url) {
                            Label(format.displayName, systemImage: "square.and.arrow.up")
                        }
                    }
                }
            } label: {
                Label("Exportieren", systemImage: "square.and.arrow.up")
            }
        } else {
            Button {
                viewModel.showPaywall = true
            } label: {
                Label("Exportieren", systemImage: "square.and.arrow.up")
            }
        }
    }

    private var transcriptText: String {
        viewModel.segments.map(\.text).joined(separator: " ")
    }

    /// Toggles between timestamped segments and the flowing reading view.
    private var readingToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { readingMode.toggle() }
            Haptics.impact(.light)
        } label: {
            Label(
                readingMode ? "Segmente" : "Lesen",
                systemImage: readingMode ? "list.bullet" : "text.alignleft"
            )
        }
        .accessibilityLabel(Text(readingMode ? "Segmentansicht" : "Leseansicht"))
    }

    /// Groups segments into paragraphs, breaking where the speaker paused for
    /// more than ~2 s — a comfortable approximation of natural paragraphs.
    private var readingParagraphs: [String] {
        var paragraphs: [String] = []
        var current = ""
        var previousEnd: TimeInterval?
        for segment in viewModel.segments {
            let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            if let previousEnd, segment.startTime - previousEnd > 2.0, !current.isEmpty {
                paragraphs.append(current)
                current = ""
            }
            current += current.isEmpty ? text : " " + text
            previousEnd = segment.endTime
        }
        if !current.isEmpty { paragraphs.append(current) }
        return paragraphs
    }

    @ViewBuilder
    private var translationCard: some View {
        if !viewModel.segments.isEmpty && !isTranscribing {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Label("Übersetzung", systemImage: "globe")
                        .font(Theme.Font.cardTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    if summaryVM.isTranslating {
                        ProgressView()
                    } else if !summaryVM.isUnlocked {
                        Button { summaryVM.showPaywall = true } label: {
                            HStack(spacing: Theme.Spacing.xs) { PremiumCrown(); Text("Übersetzen") }
                        }
                    } else {
                        Menu {
                            ForEach(TranslationLanguage.common) { language in
                                Button(language.displayName) {
                                    Task { await summaryVM.translate(transcript: transcriptText, to: language) }
                                }
                            }
                        } label: {
                            Label(summaryVM.translatedText == nil ? "Übersetzen" : "Andere Sprache", systemImage: "globe")
                        }
                        .disabled(summaryVM.availability != .available)
                    }
                }

                if let target = summaryVM.translationLanguage, let translatedText = summaryVM.translatedText {
                    Text(target.displayName)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.accent)
                    Text(translatedText)
                        .font(.callout)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .textSelection(.enabled)
                    ShareLink(item: translatedText) {
                        Label("Teilen", systemImage: "square.and.arrow.up").font(.caption)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.sm)
        }
    }


    @ViewBuilder
    private var summaryCard: some View {
        if !viewModel.segments.isEmpty && !isTranscribing {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Label("KI", systemImage: "sparkles")
                        .font(Theme.Font.cardTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    if summaryVM.phase == .generating {
                        ProgressView()
                    } else if !summaryVM.isUnlocked {
                        Button {
                            summaryVM.showPaywall = true
                        } label: {
                            HStack(spacing: Theme.Spacing.xs) {
                                PremiumCrown()
                                Text("Erstellen")
                            }
                        }
                    } else {
                        Menu {
                            ForEach(SummaryStyle.allCases) { style in
                                Button {
                                    summaryVM.style = style
                                    Task { await summaryVM.generate() }
                                } label: {
                                    Label(LocalizedStringKey(style.title), systemImage: style.icon)
                                }
                            }
                        } label: {
                            Label(summaryVM.hasSummary ? "Neu erstellen" : "Erstellen", systemImage: "sparkles")
                        }
                        .disabled(summaryVM.availability != .available)
                    }
                }

                // Only explain the model's absence when there is nothing to
                // show. Printing "the model is still preparing" above a summary
                // that is right there reads as a malfunction.
                if summaryVM.availability != .available, !summaryVM.hasSummary {
                    Text(AISummaryError.unavailable(summaryVM.availability).errorDescription ?? "")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                if let aiTitle = summaryVM.recording.aiTitle, !aiTitle.isEmpty {
                    Text(aiTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
                if let summary = summaryVM.recording.summary, !summary.isEmpty {
                    Text((try? AttributedString(
                        markdown: summary,
                        options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                    )) ?? AttributedString(summary))
                        .font(.callout)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .textSelection(.enabled)
                }
                if summaryVM.canApplyTitle {
                    Button("Titel übernehmen") { summaryVM.applyTitle() }
                        .font(.caption)
                        .buttonStyle(.borderless)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
    }

    /// Locked users are invited to the free preview by name — an unlabelled
    /// "Transkribieren" that silently truncates would feel like a bug.
    private var transcribeButtonTitle: LocalizedStringKey {
        guard viewModel.isUnlocked else { return "30 Sekunden gratis testen" }
        return viewModel.segments.isEmpty ? "Transkribieren" : "Neu transkribieren"
    }

    @ViewBuilder
    private var header: some View {
        VStack(spacing: Theme.Spacing.sm) {
            if viewModel.hasInstalledLocale {
                HStack {
                    Label("Sprache", systemImage: "globe")
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Spacer()
                    Picker("Sprache", selection: $viewModel.locale) {
                        ForEach(viewModel.installedLocales, id: \.identifier) { locale in
                            Text(TranscriptionLocale.displayName(for: locale)).tag(locale)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(isTranscribing)
                }
                .font(.subheadline)
                .padding(.horizontal, Theme.Spacing.xs)

                if isTranscribing {
                    ProgressView("Wird transkribiert… (\(viewModel.liveDrafts.count))")
                } else {
                    Button {
                        Task { await viewModel.transcribe() }
                    } label: {
                        HStack(spacing: Theme.Spacing.xs) {
                            if !viewModel.isUnlocked { PremiumCrown() }
                            Text(transcribeButtonTitle)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.goldProminent)
                }
            } else if viewModel.segments.isEmpty {
                // Only nudge to install a model when there's nothing to show yet;
                // showing it above an existing transcript is contradictory.
                Text("Kein Sprachmodell geladen. Lade es unter „Transkription“ in der Bibliothek.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Theme.Spacing.md)
    }

    /// Closes the preview with the actual ask: the user has just read their own
    /// words, so the card names what the purchase adds rather than what it
    /// blocks. Nothing from the preview is persisted, exportable or AI-usable.
    private var previewUnlockCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.xs) {
                PremiumCrown()
                Text(viewModel.isPreviewTruncated ? "Vorschau endet hier" : "Vorschau")
                    .font(Theme.Font.cardTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }

            Text(previewMessage)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                viewModel.showPaywall = true
            } label: {
                Text("Vollständig freischalten").frame(maxWidth: .infinity)
            }
            .buttonStyle(.goldProminent)
            .accessibilityIdentifier("preview.unlock")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.sm)
        .padding(.bottom, Theme.Spacing.lg)
    }

    private var previewMessage: LocalizedStringKey {
        viewModel.isPreviewTruncated
            ? "Das waren die ersten 30 Sekunden. Schalte frei, um diese Aufnahme vollständig zu transkribieren, das Transkript zu behalten, zu exportieren, zu übersetzen und per KI zusammenzufassen."
            : "Diese Vorschau wird nicht gespeichert. Schalte frei, um Transkripte zu behalten, zu exportieren, zu übersetzen und per KI zusammenzufassen."
    }

    @ViewBuilder
    private var transcriptContent: some View {
        if isTranscribing {
            ForEach(Array(viewModel.liveDrafts.enumerated()), id: \.offset) { _, draft in
                segmentRow(text: draft.text, start: draft.startTime, tappable: false)
            }
        } else if viewModel.isShowingPreview {
            ForEach(Array(viewModel.liveDrafts.enumerated()), id: \.offset) { _, draft in
                segmentRow(text: draft.text, start: draft.startTime, tappable: false)
            }
            previewUnlockCard
        } else if viewModel.segments.isEmpty {
            EmptyStateView(
                systemName: "captions.bubble",
                title: "Noch kein Transkript",
                message: "Tippe oben auf „Transkribieren“, um aus dieser Aufnahme Text zu erzeugen."
            )
            .padding(.top, Theme.Spacing.lg)
        } else if readingMode {
            readingContent
        } else {
            ForEach(viewModel.segments) { segment in
                segmentRow(text: segment.text, start: segment.startTime, tappable: true)
            }
        }
    }

    /// Continuous, comfortable-to-read paragraphs (selectable, no timecodes).
    private var readingContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            ForEach(Array(readingParagraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(.system(.body, design: .serif))
                    .lineSpacing(6)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .textSelection(.enabled)
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.sm)
    }

    private func segmentRow(text: String, start: TimeInterval, tappable: Bool) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Text(TimeFormatting.shortTimecode(start))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.Colors.accent)
            Text(text)
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.xs)
        .contentShape(Rectangle())
        .onTapGesture {
            guard tappable, playback.duration > 0 else { return }
            Task {
                await playback.seek(toFraction: start / playback.duration)
                if !playback.isPlaying { await playback.togglePlayback() }
            }
        }
    }
}
