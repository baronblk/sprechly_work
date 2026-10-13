import SwiftUI

/// A simple scrollable legal/text page used for Imprint and Privacy.
private struct LegalPage<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LegalHeading: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(Theme.Colors.textPrimary)
            .padding(.top, Theme.Spacing.sm)
    }
}

private struct LegalBody: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(Theme.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Operator data (single source of truth for both pages)

/// Replace the placeholders with the real legal details before release.
/// Both the Imprint and the Privacy policy read from here.
private enum LegalInfo {
    static let operatorName = "Rene Süß"
    static let role = "Freiberuflicher Softwareentwickler"
    static let street = "Barbarossastr. 91"
    static let city = "09112 Chemnitz"
    static let country = "Deutschland"
    static let email = "support@gcng.de"
    static let phone = "0151 55386821"
    static let website = "https://support.gcng.de"
    static let lastUpdated = "Juni 2026"
}

/// Imprint per DDG §5.
struct ImprintView: View {
    var body: some View {
        LegalPage(title: "Impressum") {
            LegalHeading("Angaben gemäß § 5 DDG")
            LegalBody("\(LegalInfo.operatorName)\n\(LegalInfo.role)\n\(LegalInfo.street)\n\(LegalInfo.city)\n\(LegalInfo.country)")

            LegalHeading("Kontakt")
            LegalBody("Telefon: \(LegalInfo.phone)\nE-Mail: \(LegalInfo.email)\nWeb: \(LegalInfo.website)")

            LegalHeading("Verbraucherstreitbeilegung")
            LegalBody("Wir sind nicht bereit oder verpflichtet, an Streitbeilegungsverfahren vor einer Verbraucherschlichtungsstelle teilzunehmen.")
        }
    }
}

/// Privacy policy — accurate to what Sprechly actually does: everything runs on
/// the device; no own servers, no tracking, no third-party SDKs.
struct PrivacyPolicyView: View {
    var body: some View {
        LegalPage(title: "Datenschutz") {
            LegalBody("Stand: \(LegalInfo.lastUpdated)")

            LegalHeading("Verantwortlicher")
            LegalBody("\(LegalInfo.operatorName)\n\(LegalInfo.street)\n\(LegalInfo.city)\n\(LegalInfo.country)\nE-Mail: \(LegalInfo.email)")

            LegalHeading("Grundsatz: Verarbeitung auf deinem Gerät")
            LegalBody("Sprechly verarbeitet deine Aufnahmen, Transkripte und KI-Ergebnisse vollständig lokal auf deinem Gerät. Wir betreiben keine eigenen Server und übertragen deine Inhalte nicht an uns oder Dritte. Es findet keine Analyse, kein Tracking und keine Werbung statt, und es werden keine Drittanbieter-SDKs eingesetzt.")

            LegalHeading("Mikrofon")
            LegalBody("Der Mikrofonzugriff wird ausschließlich für Aufnahmen verwendet und nur nach deiner ausdrücklichen Zustimmung aktiviert. Aufnahmen werden lokal im App-Speicher abgelegt.")

            LegalHeading("Spracherkennung & KI")
            LegalBody("Transkription erfolgt on-device über Apples Speech-Framework. Titel, Zusammenfassungen, Protokolle und Übersetzungen werden on-device über Apple Foundation Models (Apple Intelligence) erstellt, sofern dein Gerät dies unterstützt. Diese Verarbeitung verlässt dein Gerät nicht.")

            LegalHeading("iCloud-Synchronisierung (optional)")
            LegalBody("Wenn du iCloud-Sync aktivierst, werden deine Aufnahmen und Transkripte in deinem privaten iCloud-Konto (CloudKit) gespeichert und zwischen deinen Geräten synchronisiert. Anbieter ist Apple; es gilt zusätzlich Apples Datenschutzrichtlinie. Wir haben keinen Zugriff auf diese Daten. Die Synchronisierung lässt sich in den Einstellungen deaktivieren.")

            LegalHeading("Käufe")
            LegalBody("Der einmalige In-App-Kauf wird über den App Store (StoreKit) durch Apple abgewickelt. Sprechly erhält oder speichert keine Zahlungsdaten.")

            LegalHeading("Speicherdauer & Löschung")
            LegalBody("Deine Inhalte bleiben gespeichert, bis du sie löschst. Gelöschte Aufnahmen liegen im Papierkorb und werden nach 30 Tagen endgültig entfernt. Bei aktivem iCloud-Sync wird die Löschung auf deine Geräte übertragen.")

            LegalHeading("Deine Rechte")
            LegalBody("Dir stehen die Rechte nach DSGVO zu (Auskunft, Berichtigung, Löschung, Einschränkung, Datenübertragbarkeit, Widerspruch). Da die Daten auf deinem Gerät bzw. in deinem iCloud-Konto liegen, kannst du sie jederzeit selbst in der App oder über iCloud einsehen und löschen. Bei Fragen erreichst du uns unter \(LegalInfo.email).")

            LegalHeading("Kinder")
            LegalBody("Die App richtet sich nicht an Kinder und erhebt nicht wissentlich Daten von Kindern.")

            LegalHeading("Änderungen")
            LegalBody("Wir können diese Datenschutzerklärung anpassen, etwa bei neuen Funktionen. Die jeweils aktuelle Fassung ist in der App einsehbar.")
        }
    }
}
