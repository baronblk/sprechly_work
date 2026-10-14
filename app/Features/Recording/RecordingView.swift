import SwiftData
import SwiftUI

struct RecordingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreManager.self) private var store
    @Environment(RatingPromptController.self) private var rating
    @Environment(WorkDeviceViewModel.self) private var work
    @AppStorage("liveTranscriptEnabled") private var liveTranscriptEnabled = false
    @State private var viewModel = RecordingViewModel()
    @State private var showSettings = false
    /// Shown after a take is saved, so the recorder answers "what now?" instead
    /// of silently returning to zero.
    @State private var showSavedConfirmation = false

    /// Switches to the library tab (injected by `RootView`).
    var onOpenLibrary: () -> Void = {}

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            timeDisplay

            if isWorkMode {
                workArea
            } else {
                if viewModel.state == .paused {
                    reviewArea
                } else {
                    liveArea
                }
                if viewModel.state == .idle || viewModel.state == .stopped { idleCard }
            }

            Spacer()

            Group {
                if isWorkMode { workTransport } else { transport }
            }
            .padding(.bottom, Theme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.25), value: isWorkMode)
        .background { DepthGlow().frame(width: 440, height: 440) }
        .background(Theme.Colors.background.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(Theme.Spacing.md)
            }
            .accessibilityLabel(Text("Einstellungen"))
        }
        // A finished, saved take is the recorder's own positive moment — the
        // free path to the rating prompt, which used to be reachable only via
        // the purchased AI features.
        .onChange(of: viewModel.savedTakeCount) { _, count in
            guard count > 0 else { return }
            withAnimation(.easeOut(duration: 0.25)) { showSavedConfirmation = true }
            rating.registerDelight()
        }
        .onChange(of: viewModel.state) { _, state in
            // A new take supersedes the previous confirmation.
            if state == .recording { showSavedConfirmation = false }
        }
        .onAppear { viewModel.configure(modelContext: modelContext, store: store) }
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView() }
        }
        .sheet(isPresented: $viewModel.showPaywall) {
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
    }

    // Big timecode with a pulsing record indicator while recording.
    /// Solange der Work verbunden ist und das Telefon selbst nicht aufnimmt,
    /// steuert der zentrale Transport das Gerät. Zwei Aufnahme-Buttons
    /// nebeneinander wären verwirrend.
    private var isWorkMode: Bool {
        work.isReady && (viewModel.state == .idle || viewModel.state == .stopped)
    }

    @ViewBuilder
    private var timeDisplay: some View {
        if isWorkMode {
            workTimeDisplay
        } else {
            phoneTimeDisplay
        }
    }

    /// Laufzeit der Geräte-Aufnahme. Geschätzt – die genaue Dauer meldet
    /// der Work am Ende.
    private var workTimeDisplay: some View {
        HStack(spacing: Theme.Spacing.sm) {
            if work.liveActivity.isRecording {
                Image(systemName: "circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Colors.destructive)
                    .symbolEffect(.pulse, options: .repeating)
                    .accessibilityHidden(true)
            }
            // „min." macht sichtbar, dass die Zeit bei einer vorgefundenen
            // Aufnahme nur eine Untergrenze ist – der Beginn ist nicht erfragbar.
            if !work.liveActivity.hasKnownStart {
                Text("min.")
                    .font(.title3)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Text(TimeFormatting.timecode(work.runningDuration))
                .font(.system(size: 56, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(
                    work.liveActivity.isActive ? Theme.Colors.textPrimary : Theme.Colors.textSecondary
                )
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Aufnahmedauer am Work"))
    }

    @ViewBuilder
    private var phoneTimeDisplay: some View {
        HStack(spacing: Theme.Spacing.sm) {
            if viewModel.state == .recording {
                Image(systemName: "circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Colors.destructive)
                    .symbolEffect(.pulse, options: .repeating)
                    .accessibilityHidden(true)
            }
            Text(viewModel.state == .paused
                 ? "\(TimeFormatting.timecode(viewModel.reviewCursor)) / \(TimeFormatting.timecode(viewModel.committedDuration))"
                 : TimeFormatting.timecode(viewModel.elapsed))
                .font(.system(size: viewModel.state == .paused ? 34 : 56, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.Colors.textPrimary)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Aufnahmedauer"))
    }

    // Live recording UI: caption, waveform, level, transcript toggle.
    @ViewBuilder
    private var liveArea: some View {
        if viewModel.liveEnabled {
            Text(viewModel.liveCaption.isEmpty ? String(localized: "Live-Transkript läuft …") : viewModel.liveCaption)
                .font(.callout)
                .foregroundStyle(viewModel.liveCaption.isEmpty ? Theme.Colors.textSecondary.opacity(0.6) : Theme.Colors.textSecondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 40)
                .cardSurface()
                .padding(.horizontal, Theme.Spacing.lg)
                .accessibilityLabel(Text("Live-Transkript"))
        }

        WaveformView(buckets: viewModel.liveBuckets)
            .frame(height: 160)
            .padding(.horizontal, Theme.Spacing.lg)

        LevelMeter(level: viewModel.level)
            .frame(height: 6)
            .padding(.horizontal, Theme.Spacing.xl)
    }

    // Dictaphone review UI: scrubable committed take + hint.
    @ViewBuilder
    private var reviewArea: some View {
        WaveformView(
            buckets: viewModel.reviewBuckets,
            progress: viewModel.reviewProgress,
            onScrub: { fraction in Task { await viewModel.reviewScrub(toFraction: fraction) } }
        )
        .frame(height: 160)
        .padding(.horizontal, Theme.Spacing.lg)

        Text("Spule zurück und nimm ab dem Cursor neu auf.")
            .font(.footnote)
            .foregroundStyle(Theme.Colors.textSecondary)
            .padding(.horizontal, Theme.Spacing.lg)
    }

    /// Fills the idle screen with the two things it was missing: what this app
    /// does beyond recording, and where the take just saved has gone.
    @ViewBuilder
    private var idleCard: some View {
        if showSavedConfirmation {
            VStack(spacing: Theme.Spacing.sm) {
                Label("Aufnahme gespeichert", systemImage: "checkmark.circle.fill")
                    .font(Theme.Font.cardTitle)
                    .foregroundStyle(Theme.Colors.success)
                Text("In der Bibliothek kannst du sie transkribieren, zusammenfassen lassen und bearbeiten.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    Haptics.impact(.light)
                    onOpenLibrary()
                } label: {
                    Text("In Bibliothek öffnen").frame(maxWidth: .infinity)
                }
                .buttonStyle(.goldProminent)
                .accessibilityIdentifier("recording.openLibrary")
            }
            .cardSurface()
            .padding(.horizontal, Theme.Spacing.lg)
            .transition(.opacity)
        } else {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Toggle(isOn: $liveTranscriptEnabled) {
                    HStack(spacing: Theme.Spacing.xs) {
                        if !store.isUnlocked(.ai) { PremiumCrown() }
                        Text("Live-Transkript")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.Colors.textPrimary)
                }
                .tint(Theme.Colors.accent)

                Text("Schreibt schon während der Aufnahme mit. Danach: Transkript, KI-Zusammenfassung und Übersetzung.")
                    .font(.footnote)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .cardSurface()
            .padding(.horizontal, Theme.Spacing.lg)
        }
    }

    /// Statt Pegel und Live-Wellenform: der Zustand des Geräts. Das Audio
    /// liegt auf dem Work und erreicht die App erst beim Import, ein
    /// Live-Pegel ist darum nicht möglich.
    @ViewBuilder
    private var workArea: some View {
        VStack(spacing: Theme.Spacing.sm) {
            WorkDeviceCard()
            Text(workHint)
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .transition(.opacity)
    }

    private var workHint: LocalizedStringKey {
        switch work.liveActivity {
        case .idle: "Die Aufnahme läuft auf dem Work. Hol sie danach über die Karte in die Bibliothek."
        case .recording: "Der Work nimmt auf. Pegel und Live-Transkript gibt es erst nach dem Import."
        case .openRecording: "Der Work nahm schon auf, als die App sich verband. Wie lange, weiß nur das Gerät – die Zeit ist eine Untergrenze."
        case .paused: "Pausiert – die Aufnahme bleibt eine Datei."
        case .finished: "Fertig. Tippe die Karte an, um sie zu importieren."
        }
    }

    /// Derselbe Transport wie fürs Telefon, nur dass er den Work steuert.
    @ViewBuilder
    private var workTransport: some View {
        workControls
            .disabled(work.isSendingCommand)
            .opacity(work.isSendingCommand ? 0.6 : 1)
    }

    @ViewBuilder
    private var workControls: some View {
        if work.liveActivity.isRecording {
            HStack(spacing: Theme.Spacing.xxl) {
                TransportButton(systemName: "pause.fill", size: 60, accessibilityLabel: "Work pausieren") {
                    Haptics.impact(.light); Task { await work.pauseRecording() }
                }
                RecordButton(mode: .stop) {
                    Haptics.notify(.success); Task { await work.stopRecording() }
                }
            }
        } else if work.liveActivity.isPaused {
            HStack(spacing: Theme.Spacing.xxl) {
                RecordButton(mode: .record, size: 64) {
                    Haptics.impact(.medium); Task { await work.startRecording() }
                }
                RecordButton(mode: .stop, size: 64) {
                    Haptics.notify(.success); Task { await work.stopRecording() }
                }
            }
        } else {
            RecordButton(mode: .record) {
                Haptics.impact(.medium); Task { await work.startRecording() }
            }
        }
    }

    @ViewBuilder
    private var transport: some View {
        switch viewModel.state {
        case .idle, .stopped:
            RecordButton(mode: .record) {
                Haptics.impact(.medium)
                viewModel.liveEnabled = liveTranscriptEnabled
                Task { await viewModel.startRecording() }
            }
        case .recording:
            HStack(spacing: Theme.Spacing.xxl) {
                TransportButton(systemName: "pause.fill", size: 60, accessibilityLabel: "Pausieren") {
                    Haptics.impact(.light); Task { await viewModel.pause() }
                }
                RecordButton(mode: .stop) {
                    Haptics.notify(.success); Task { await viewModel.stopAndSave() }
                }
            }
        case .paused:
            VStack(spacing: Theme.Spacing.xl) {
                HStack(spacing: Theme.Spacing.xl) {
                    TransportButton(systemName: "gobackward.10", size: 52, accessibilityLabel: "10 Sekunden zurück") {
                        Haptics.impact(.light); Task { await viewModel.reviewSkip(by: -10) }
                    }
                    TransportButton(
                        systemName: viewModel.isReviewPlaying ? "pause.fill" : "play.fill",
                        size: 64,
                        accessibilityLabel: viewModel.isReviewPlaying ? "Pause" : "Anhören"
                    ) { Task { await viewModel.toggleReviewPlayback() } }
                    TransportButton(systemName: "goforward.10", size: 52, accessibilityLabel: "10 Sekunden vor") {
                        Haptics.impact(.light); Task { await viewModel.reviewSkip(by: 10) }
                    }
                }
                HStack(spacing: Theme.Spacing.xxl) {
                    RecordButton(mode: .record, size: 64) {
                        Haptics.impact(.medium); Task { await viewModel.continueRecording() }
                    }
                    RecordButton(mode: .stop, size: 64) {
                        Haptics.notify(.success); Task { await viewModel.stopAndSave() }
                    }
                }
            }
        }
    }
}

/// Simple horizontal level meter (0...1).
private struct LevelMeter: View {
    let level: Float

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Colors.surfaceElevated)
                Capsule()
                    .fill(Theme.Colors.accent)
                    .frame(width: geo.size.width * CGFloat(min(1, max(0, level))))
            }
        }
        .accessibilityLabel(Text("Pegel"))
        .accessibilityValue(Text(String(localized: "\(Int(level * 100)) Prozent")))
    }
}
