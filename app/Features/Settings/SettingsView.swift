import SwiftData
import SwiftUI

/// App settings, reached via the gear in the library toolbar. Makes the premium
/// (AI) layer transparent: what it unlocks, the current status, purchase and
/// restore — plus recording preferences, models, legal and app info.
struct SettingsView: View {
    @AppStorage(AppSettings.keepScreenAwakeKey) private var keepScreenAwake = false
    @Environment(StoreManager.self) private var store
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("liveTranscriptEnabled") private var liveTranscriptEnabled = false
    @AppStorage(PersistenceController.syncPreferenceKey) private var icloudSyncEnabled = true
    @State private var showPaywall = false
    @State private var isRestoring = false
    @State private var errorMessage: String?
    @State private var totalRecordings = 0
    @State private var localAudioCount = 0
    @State private var aiAvailable = true

    private var syncMonitor: CloudSyncMonitor { appState.syncMonitor }
    private var pendingDownloads: Int { max(0, totalRecordings - localAudioCount) }
    private var iCloudSignedIn: Bool { FileManager.default.ubiquityIdentityToken != nil }

    private var unlocked: Bool { store.isUnlocked(.ai) }

    private let premiumFeatures: [(icon: String, title: LocalizedStringKey, requiresAI: Bool)] = [
        ("captions.bubble", "Transkription (on-device)", false),
        ("waveform.badge.mic", "Live-Transkript während der Aufnahme", false),
        ("square.and.arrow.up", "Transkript-Export (TXT/Markdown)", false),
        ("sparkles", "KI-Titel & Zusammenfassung", true),
        ("globe", "Übersetzung", true),
    ]

    var body: some View {
        List {
            premiumSection
            if unlocked { recordingSection }

            // Language models are only useful once transcription is purchased.
            if unlocked {
                Section("Transkription") {
                    NavigationLink {
                        TranscriptionSetupView()
                    } label: {
                        Label("Sprachmodelle", systemImage: "waveform.badge.mic")
                    }
                }
            }

            displaySection
            WorkSettingsSection()
            iCloudSection

            Section("Rechtliches") {
                NavigationLink { ImprintView() } label: {
                    Label("Impressum", systemImage: "building.columns")
                }
                NavigationLink { PrivacyPolicyView() } label: {
                    Label("Datenschutz", systemImage: "lock.shield")
                }
            }

            Section("Über") {
                LabeledContent("App", value: AppInfo.displayName)
                LabeledContent("Version", value: AppInfo.versionString)
                // Permanent entry alongside the automatic prompt, which fires
                // once per version at most — this is the way back for someone
                // who dismissed it or wants to rate later.
                if let reviewURL = AppInfo.reviewURL {
                    Link(destination: reviewURL) {
                        Label("Sprechly bewerten", systemImage: "star")
                    }
                    .accessibilityIdentifier("settings.rate")
                }
                Text("Transkription und KI laufen vollständig auf deinem Gerät. Der optionale iCloud-Sync nutzt ausschließlich deine eigene private iCloud.")
                    .font(.footnote)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            // Quiet cross-reference, not a banner: it only surfaces for people
            // who open Settings — no popup, no launch screen promotion.
            if let whisperScribeURL = SiblingApp.whisperScribeProURL {
                Section("Weitere Apps") {
                    Link(destination: whisperScribeURL) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Label("Auch auf dem Mac transkribieren?", systemImage: "laptopcomputer")
                            Text("WhisperScribe Pro entdecken")
                                .font(.footnote)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                    .accessibilityIdentifier("settings.whisperscribe")
                }
            }

            #if DEBUG
            Section("Debug") {
                Toggle("Premium im Test entsperren", isOn: Binding(
                    get: { store.debugUnlockAll },
                    set: { store.setDebugUnlockAll($0) }
                ))
                Text("Nur in Debug-Builds: simuliert den Premium-Kauf auf dem Gerät, solange der IAP in App Store Connect noch nicht existiert.")
                    .font(.footnote)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            #endif
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationTitle("Einstellungen")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            refreshCounts()
            aiAvailable = await AISummaryService().availability() == .available
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("Fertig") { dismiss() } }
        }
        .sheet(isPresented: $showPaywall) {
            NavigationStack { PaywallView() }
        }
        .alert(
            "Fehler",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    /// Gilt für die ganze App, nicht nur für ein Feature.
    private var displaySection: some View {
        Section {
            Toggle(isOn: $keepScreenAwake) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bildschirm anlassen")
                    Text("Verhindert den Bildschirm-Timeout, solange Sprechly geöffnet ist. Im Hintergrund gilt wieder die normale Einstellung.")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        } header: {
            Text("Anzeige")
        }
    }

    private var premiumSection: some View {
        Section {
            // Status line.
            HStack {
                Label("Sprechly KI", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                if unlocked {
                    Label("Freigeschaltet", systemImage: "checkmark.seal.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.success)
                }
            }

            // What the one-time purchase unlocks — honest and per-device.
            ForEach(premiumFeatures, id: \.icon) { feature in
                let unavailable = feature.requiresAI && !aiAvailable
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: feature.icon)
                        .frame(width: 24)
                        .foregroundStyle(unavailable ? Theme.Colors.textSecondary : Theme.Colors.accent)
                    Text(feature.title)
                        .foregroundStyle(unavailable ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
                    Spacer()
                    if unavailable {
                        Text("nicht verfügbar").font(.caption).foregroundStyle(Theme.Colors.textSecondary)
                    } else {
                        Image(systemName: unlocked ? "checkmark.circle.fill" : "lock.fill")
                            .foregroundStyle(unlocked ? Theme.Colors.success : Theme.Colors.textSecondary)
                    }
                }
                .font(.subheadline)
            }

            if !aiAvailable {
                Text("KI-Funktionen erfordern Apple Intelligence und sind auf diesem Gerät nicht verfügbar. Transkription, Live-Transkript und Export funktionieren.")
                    .font(.footnote)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            if !unlocked {
                Button {
                    showPaywall = true
                } label: {
                    Label("Alles freischalten", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.goldProminent)
            }

            Button {
                restore()
            } label: {
                Label("Käufe wiederherstellen", systemImage: "arrow.clockwise")
            }
            .disabled(isRestoring)
        } header: {
            Text("Premium")
        } footer: {
            Text("Einmaliger Kauf, kein Abo. Schaltet alle KI-Funktionen frei — vollständig on-device.")
        }
    }

    @ViewBuilder
    private var iCloudSection: some View {
        Section {
            Toggle(isOn: $icloudSyncEnabled) {
                Label("iCloud-Sync", systemImage: "icloud")
            }

            if !icloudSyncEnabled {
                LabeledContent("Status") { Text("Aus").foregroundStyle(Theme.Colors.textSecondary) }
            } else if !iCloudSignedIn {
                LabeledContent("Status") {
                    Text("Nicht bei iCloud angemeldet").foregroundStyle(Theme.Colors.destructive)
                }
            } else {
                LabeledContent("Status") { syncStatusView }
                LabeledContent("Aufnahmen") { Text("\(localAudioCount)/\(totalRecordings) mit Audio") }
                LabeledContent("Zuletzt hochgeladen", value: relative(syncMonitor.lastUpload))
                LabeledContent("Zuletzt geladen", value: relative(syncMonitor.lastDownload))
                if pendingDownloads > 0 {
                    Label("\(pendingDownloads) Aufnahme(n) ohne lokales Audio", systemImage: "arrow.down.circle")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                if let error = syncMonitor.lastError {
                    Text("Letzter Fehler: \(error)")
                        .font(.footnote)
                        .foregroundStyle(Theme.Colors.destructive)
                }
                Button {
                    Task {
                        await CloudAudioReconciler.reconcileNow(container: modelContext.container)
                        refreshCounts()
                    }
                } label: {
                    Label("Jetzt aktualisieren", systemImage: "arrow.triangle.2.circlepath")
                }
            }
        } header: {
            Text("iCloud")
        } footer: {
            Text("Synchronisiert Aufnahmen, Transkripte und Audio über Geräte mit derselben Apple-ID. Audio wird im Hintergrund übertragen; das An/Aus wirkt beim nächsten App-Start.")
        }

        if !syncMonitor.events.isEmpty {
            Section("Sync-Verlauf") {
                ForEach(syncMonitor.events.prefix(4)) { event in
                    LabeledContent(event.text, value: event.date.formatted(date: .omitted, time: .standard))
                        .font(.footnote)
                }
            }
        }
    }

    @ViewBuilder
    private var syncStatusView: some View {
        switch syncMonitor.activity {
        case .uploading:
            HStack(spacing: Theme.Spacing.xs) { ProgressView(); Text("Lädt hoch …") }
                .foregroundStyle(Theme.Colors.textSecondary)
        case .downloading:
            HStack(spacing: Theme.Spacing.xs) { ProgressView(); Text("Lädt herunter …") }
                .foregroundStyle(Theme.Colors.textSecondary)
        case .idle:
            Label(syncMonitor.lastError == nil ? "Aktuell" : "Mit Fehlern", systemImage: syncMonitor.lastError == nil ? "checkmark.icloud" : "exclamationmark.icloud")
                .labelStyle(.titleAndIcon)
                .foregroundStyle(syncMonitor.lastError == nil ? Theme.Colors.success : Theme.Colors.destructive)
        }
    }

    private func relative(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(.relative(presentation: .named))
    }

    private func refreshCounts() {
        let fileStore = RecordingFileStore()
        // Only count active recordings — trashed (soft-deleted) ones must not
        // inflate the sync count (e.g. showing 5/5 when 2 remain + 3 in trash).
        let descriptor = FetchDescriptor<Recording>(predicate: #Predicate { !$0.isTrashed })
        let recordings = ((try? modelContext.fetch(descriptor)) ?? [])
            .filter { !$0.fileName.isEmpty }
        totalRecordings = recordings.count
        localAudioCount = recordings.filter {
            FileManager.default.fileExists(atPath: fileStore.audioURL(forFileName: $0.fileName).path)
        }.count
    }

    private var recordingSection: some View {
        Section {
            Toggle(isOn: $liveTranscriptEnabled) {
                Label("Live-Transkript", systemImage: "captions.bubble")
            }
        } header: {
            Text("Aufnahme")
        } footer: {
            Text("Zeigt während der Aufnahme eine mitlaufende Transkription über der Wellenform.")
        }
    }

    private func restore() {
        Task {
            isRestoring = true
            defer { isRestoring = false }
            do {
                try await store.restore()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
