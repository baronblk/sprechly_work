import StoreKit
import SwiftData
import SwiftUI

/// Top-level destinations.
private enum RootTab: String, CaseIterable, Identifiable {
    case recording, library
    var id: String { rawValue }
    var title: LocalizedStringKey { self == .recording ? "Aufnahme" : "Bibliothek" }
    var icon: String { self == .recording ? "mic.fill" : "waveform" }
}

/// Root navigation: a flat, full-width bottom bar (icon over label) instead of
/// the floating system pill.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.requestReview) private var requestReview
    @Environment(RatingPromptController.self) private var rating
    @State private var maintenance = LibraryViewModel()
    @State private var tab: RootTab = .recording
    @State private var showSettings = false
    /// Measured height of the custom tab bar, handed down so screens in the
    /// split view's detail column can clear it (see `TabBarHeight.swift`).
    @State private var measuredTabBarHeight: CGFloat = 0
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage(WorkSettings.autoConnectKey) private var workAutoConnect = false
    @AppStorage(WorkSettings.keepAwakeKey) private var workKeepAwake = false
    @Environment(WorkDeviceViewModel.self) private var work
    #if DEBUG
    /// Presents the paywall at launch for the IAP review screenshot.
    @State private var showLaunchPaywall = ProcessInfo.processInfo.arguments.contains("SHOW_PAYWALL")
    #endif

    /// Hält den Bildschirm an, solange es etwas zu sehen gibt.
    private func applyIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = workKeepAwake && work.isReady
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .recording:
            RecordingView(onOpenLibrary: { tab = .library })
        case .library:
            LibraryView(onStartRecording: { tab = .recording })
        }
    }

    var body: some View {
        layout
        .background(Theme.Colors.background.ignoresSafeArea())
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView() }
        }
        .task {
            if workAutoConnect { await work.connectAutomatically() }
            purgeExpiredTrash()
            TranscriptMarkupRepair.run(in: modelContext)
            CloudAudioReconciler.reconcile(container: modelContext.container)
            // Re-materialize audio whenever CloudKit pulls changes (the audio
            // asset usually arrives after the recording's metadata).
            for await _ in NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange) {
                CloudAudioReconciler.reconcile(container: modelContext.container)
            }
        }
        // Im Standby bricht die Bluetooth-Verbindung ab, deshalb nur solange
        // der Work wirklich verbunden ist – und nie darüber hinaus.
        .onChange(of: work.isReady) { _, _ in applyIdleTimer() }
        .onChange(of: workKeepAwake) { _, _ in applyIdleTimer() }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                if workAutoConnect {
                    Task { await work.connectAutomatically() }
                }
                CloudAudioReconciler.reconcile(container: modelContext.container)
            }
        }
        .onChange(of: rating.pendingRequest) { _, pending in
            // A positive moment elsewhere flagged a rating ask; show Apple's
            // native prompt and clear the flag.
            guard pending else { return }
            requestReview()
            rating.consume()
        }
        .fullScreenCover(isPresented: Binding(get: { !hasSeenOnboarding }, set: { _ in })) {
            OnboardingView { hasSeenOnboarding = true }
        }
        #if DEBUG
        .sheet(isPresented: $showLaunchPaywall) {
            NavigationStack { PaywallView() }
        }
        #endif
    }

    /// Bottom tab bar on compact width (iPhone), a persistent section sidebar
    /// on regular width (iPad / large landscape).
    @ViewBuilder private var layout: some View {
        if sizeClass == .regular {
            HStack(spacing: 0) {
                sidebar
                Rectangle().fill(Color.white.opacity(0.08)).frame(width: 0.5).ignoresSafeArea()
                content.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .environment(\.tabBarHeight, measuredTabBarHeight)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    tabBar.onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { height in
                        measuredTabBarHeight = height
                    }
                }
        }
    }

    /// iPad section rail: top-level destinations + Settings.
    private var sidebar: some View {
        VStack(spacing: Theme.Spacing.xs) {
            ForEach(RootTab.allCases) { item in
                railItem(icon: item.icon, title: item.title, selected: tab == item, id: "tab.\(item.rawValue)") {
                    tab = item
                }
            }
            Spacer()
            railItem(icon: "gearshape", title: "Einstellungen", selected: false, id: "tab.settings") {
                showSettings = true
            }
        }
        .padding(.vertical, Theme.Spacing.lg)
        .frame(width: 96)
        .frame(maxHeight: .infinity)
        .background(Theme.Colors.surface.opacity(0.96).ignoresSafeArea())
    }

    private func railItem(
        icon: String,
        title: LocalizedStringKey,
        selected: Bool,
        id: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.impact(.light)
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 22, weight: .semibold))
                Text(title).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.sm)
            .foregroundStyle(selected ? Theme.Colors.accent : Theme.Colors.textSecondary)
            .background(selected ? Theme.Colors.accentSoft : .clear, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Theme.Spacing.sm)
        .accessibilityIdentifier(id)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(RootTab.allCases) { item in
                Button {
                    Haptics.impact(.light)
                    tab = item
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.icon)
                            .font(.system(size: 20, weight: .semibold))
                        Text(item.title)
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(tab == item ? Theme.Colors.accent : Theme.Colors.textSecondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tab.\(item.rawValue)")
                .accessibilityAddTraits(tab == item ? [.isSelected] : [])
            }
        }
        .padding(.top, Theme.Spacing.sm)
        .padding(.bottom, Theme.Spacing.xs)
        .background(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.5)
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .background(Theme.Colors.surface.opacity(0.96))
    }

    /// Removes trashed recordings past the retention window on launch.
    private func purgeExpiredTrash() {
        let descriptor = FetchDescriptor<Recording>(predicate: #Predicate { $0.isTrashed })
        guard let trashed = try? modelContext.fetch(descriptor) else { return }
        maintenance.purgeExpired(trashed, context: modelContext)
    }
}

#Preview {
    RootView()
        .modelContainer(for: Recording.self, inMemory: true)
        .environment(StoreManager())
        .environment(RatingPromptController())
        .environment(WorkDeviceViewModel())
}
