import SwiftUI

/// One onboarding slide.
private struct OnboardingPage: Identifiable {
    let id = UUID()
    let systemName: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
}

/// Lightweight first-run onboarding: three slides introducing recording,
/// on-device transcription and the AI layer. Shown once (flag in AppStorage).
struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            systemName: "mic.fill",
            title: "Aufnehmen",
            message: "Starte in Sekunden eine Aufnahme — mit Live-Pegel und Wellenform, auch im Hintergrund."
        ),
        OnboardingPage(
            systemName: "captions.bubble",
            title: "Transkribieren",
            message: "Wandle Aufnahmen direkt auf deinem Gerät in Text um — schnell und privat, ganz ohne Server."
        ),
        OnboardingPage(
            systemName: "sparkles",
            title: "KI-Zusammenfassung",
            message: "Lass dir Titel und Zusammenfassung erstellen und exportiere dein Transkript als Text oder Markdown."
        ),
    ]

    private var isLast: Bool { page == pages.count - 1 }

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, item in
                    slide(item).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            VStack(spacing: Theme.Spacing.sm) {
                Button(isLast ? "Los geht’s" : "Weiter") {
                    if isLast {
                        onFinish()
                    } else {
                        withAnimation { page += 1 }
                    }
                }
                .buttonStyle(.goldProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)

                Button("Überspringen") { onFinish() }
                    .opacity(isLast ? 0 : 1)
                    .disabled(isLast)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
    }

    private func slide(_ item: OnboardingPage) -> some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()
            ZStack {
                Circle().fill(Theme.Colors.accentSoft).frame(width: 140, height: 140)
                Image(systemName: item.systemName)
                    .font(.system(size: 60))
                    .foregroundStyle(Theme.Colors.accent)
            }
            .accessibilityHidden(true)

            Text(item.title)
                .font(Theme.Font.screenTitle)
                .foregroundStyle(Theme.Colors.textPrimary)

            Text(item.message)
                .font(.callout)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
