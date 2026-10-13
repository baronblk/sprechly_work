import StoreKit
import SwiftUI

struct PaywallView: View {
    /// The user's own 30-second preview result, when the paywall was reached
    /// from a preview run. Arguing with the buyer's own words converts better
    /// than a feature list — the canned example is only the fallback.
    var previewText: String?

    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var aiAvailable = true
    /// Set once the initial product load finishes, so a missing product shows a
    /// clear message instead of an endless spinner (e.g. on device before the
    /// IAP exists in App Store Connect, where no StoreKit config is available).
    @State private var didLoad = false
    @State private var showPrivacy = false

    /// Apple's standard EULA (Terms of Use) — required alongside the IAP.
    private let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")

    private var product: Product? {
        store.products.first { $0.id == StoreCatalog.aiProductID }
    }

    private let features: [(icon: String, title: LocalizedStringKey, requiresAI: Bool)] = [
        ("captions.bubble", "Transkription in voller Länge", false),
        ("waveform.badge.mic", "Live-Transkript", false),
        ("tray.and.arrow.down", "Transkripte dauerhaft speichern", false),
        ("square.and.arrow.up", "Transkript-Export (TXT/Markdown)", false),
        ("sparkles", "KI-Titel & Zusammenfassung", true),
        ("globe", "Übersetzung", true),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    headline
                    valueDemo
                    featureList
                    if !aiAvailable { aiUnavailableNote }
                }
                .padding(Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.sm)
            }
            purchaseBar
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationTitle("Sprechly KI")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("Schließen") { dismiss() } }
        }
        .task {
            if store.products.isEmpty { await store.load() }
            aiAvailable = await AISummaryService().availability() == .available
            didLoad = true
        }
        .sheet(isPresented: $showPrivacy) {
            NavigationStack { PrivacyPolicyView() }
        }
        .onChange(of: store.owned) { if store.isUnlocked(.ai) { dismiss() } }
        .alert(
            "Fehler",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Headline

    private var headline: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "captions.bubble.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.Colors.accent)
                .accessibilityHidden(true)

            Text("Sprechly KI")
                .font(.title2.bold())
                .foregroundStyle(Theme.Colors.textPrimary)

            Text("Einmal kaufen, läuft vollständig auf deinem Gerät, kein Abo.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    // MARK: - Value demo

    /// Shows the result *before* the purchase: either the transcript the user
    /// just produced in the free preview, or — when they arrived from elsewhere
    /// — a clearly labelled example of what the AI layer returns.
    @ViewBuilder
    private var valueDemo: some View {
        if let previewText, !previewText.isEmpty {
            demoCard(
                title: "Das hast du gerade transkribiert",
                badge: "Vorschau"
            ) {
                Text(previewText)
                    .font(.callout)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Diese Vorschau wird nicht gespeichert. Mit dem Kauf transkribierst du die ganze Aufnahme und behältst das Ergebnis.")
                    .font(.footnote)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            demoCard(
                title: "So sieht das Ergebnis aus",
                badge: "Beispiel"
            ) {
                Label("Transkript", systemImage: "captions.bubble")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.Colors.accent)
                Text(Self.sampleTranscript)
                    .font(.callout)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider().overlay(Theme.Colors.textSecondary.opacity(0.3))

                Label("KI-Zusammenfassung", systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.Colors.accent)
                Text(Self.sampleSummary)
                    .font(.callout)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func demoCard(
        title: LocalizedStringKey,
        badge: LocalizedStringKey,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text(title)
                    .font(Theme.Font.cardTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Text(badge)
                    .font(Theme.Font.badge)
                    .foregroundStyle(Theme.Colors.onAccent)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 2)
                    .background(Theme.Colors.accent, in: Capsule())
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    /// Deliberately generic sample content — a plausible voice memo, not a claim
    /// about a real recording. Labelled "Beispiel" in the UI.
    private static let sampleTranscript = String(
        localized: "„Termin bleibt Donnerstag, 14 Uhr. Petra kümmert sich um das Angebot, ich melde mich bis Mittwoch beim Kunden.“"
    )

    private static let sampleSummary = String(
        localized: "Termin Donnerstag 14 Uhr bestätigt. Petra übernimmt das Angebot, Rückmeldung an den Kunden bis Mittwoch."
    )

    // MARK: - Features

    private var featureList: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            ForEach(features, id: \.icon) { feature in
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
                        Image(systemName: "checkmark").foregroundStyle(Theme.Colors.success)
                    }
                }
                .font(.subheadline)
            }
        }
    }

    private var aiUnavailableNote: some View {
        Text("KI-Funktionen erfordern Apple Intelligence (auf diesem Gerät nicht verfügbar). Transkription, Live-Transkript und Export funktionieren.")
            .font(.footnote)
            .multilineTextAlignment(.center)
            .foregroundStyle(Theme.Colors.textSecondary)
    }

    // MARK: - Purchase

    /// Pinned below the scroll area so the price and restore stay reachable no
    /// matter how long the demo content is.
    private var purchaseBar: some View {
        VStack(spacing: Theme.Spacing.sm) {
            if let product {
                Button {
                    purchase(product)
                } label: {
                    HStack {
                        Text("Freischalten")
                        Spacer()
                        Text(product.displayPrice).bold()
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.goldProminent)
                .controlSize(.large)
                .disabled(isWorking)
                .accessibilityIdentifier("paywall.unlock")
            } else if !didLoad {
                ProgressView()
            } else {
                VStack(spacing: Theme.Spacing.xs) {
                    Text("Der Kauf ist gerade nicht verfügbar. Bitte versuche es später erneut oder stelle frühere Käufe wieder her.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Button("Erneut versuchen") { Task { await reload() } }
                        .font(.subheadline.weight(.medium))
                        .tint(Theme.Colors.accent)
                        .disabled(isWorking)
                }
            }

            // Restore must be prominent — a buyer who reinstalls or switches
            // devices lands here before ever transcribing.
            Button("Käufe wiederherstellen") { restore() }
                .disabled(isWorking)

            // Terms of Use (Apple's standard EULA) + privacy — required for IAP.
            HStack(spacing: Theme.Spacing.sm) {
                if let termsURL {
                    Link("Nutzungsbedingungen", destination: termsURL)
                }
                Text("·").foregroundStyle(Theme.Colors.textSecondary)
                Button("Datenschutz") { showPrivacy = true }
            }
            .font(.caption)
            .tint(Theme.Colors.accent)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.sm)
        .background(Theme.Colors.background)
    }

    private func reload() async {
        didLoad = false
        await store.load()
        didLoad = true
    }

    private func purchase(_ product: Product) {
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                _ = try await store.purchase(.ai)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func restore() {
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                try await store.restore()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
