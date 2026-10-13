import Foundation

/// One benchmark sentence with everything needed to score a run.
///
/// `contextualStrings` is what the context run hands to `AnalysisContext`. It
/// deliberately contains terms that are **not** spoken in this case as well, so
/// the run also measures false positives.
struct BenchmarkCase: Sendable {
    enum Category: String, Sendable, CaseIterable {
        case names, technical, abbreviations, numbers, mixed
    }

    let id: String
    let category: Category
    /// Spoken aloud by the synthesizer and used as the WER/CER reference.
    let reference: String
    /// What the run is really about: terms recognition tends to get wrong.
    let targetTerms: [String]
    /// Terms offered to the analyzer in the context run.
    let contextualStrings: [String]
    /// Terms present in `contextualStrings` but *not* spoken — if these turn up
    /// in the transcript, the context invented them.
    let absentTerms: [String]
    let locale: Locale
    /// Noted where the synthesizer's pronunciation needed checking.
    let pronunciationNote: String?

    init(
        id: String,
        category: Category,
        reference: String,
        targetTerms: [String],
        contextualStrings: [String]? = nil,
        absentTerms: [String] = [],
        locale: Locale = Locale(identifier: "de-DE"),
        pronunciationNote: String? = nil
    ) {
        self.id = id
        self.category = category
        self.reference = reference
        self.targetTerms = targetTerms
        self.contextualStrings = contextualStrings ?? targetTerms
        self.absentTerms = absentTerms
        self.locale = locale
        self.pronunciationNote = pronunciationNote
    }
}

enum BenchmarkCorpus {
    /// Decoys offered to the analyzer in every context run although they are
    /// never spoken. They are deliberately close to common German words, which
    /// is where a context would do damage if it over-applies.
    static let decoys = ["Proxmox", "Intune", "Kubernetes", "Jacqueline", "Hanning & Kahl"]

    /// German corpus. All terms are public product names, public company names
    /// or generic — nothing private, no contact details, no credentials.
    static let german: [BenchmarkCase] = [
        // A — names and proper nouns
        BenchmarkCase(
            id: "names-01",
            category: .names,
            reference: "René arbeitet bei der Chemnitzer Verkehrs-AG.",
            targetTerms: ["René", "Chemnitzer Verkehrs-AG"],
            absentTerms: ["Jacqueline", "Proxmox"]
        ),
        BenchmarkCase(
            id: "names-02",
            category: .names,
            reference: "Jacqueline hat den Termin mit Hanning und Kahl bestätigt.",
            targetTerms: ["Jacqueline", "Hanning"],
            contextualStrings: ["Jacqueline", "Hanning & Kahl"],
            absentTerms: ["René", "Intune"],
            pronunciationNote: "Ampersand spoken as 'und' so the synthesizer does not spell it out."
        ),

        // B — technical terms
        BenchmarkCase(
            id: "technical-01",
            category: .technical,
            reference: "Die Doku liegt in SharePoint, der Container läuft in Docker.",
            targetTerms: ["SharePoint", "Docker"],
            absentTerms: ["Kubernetes", "Proxmox"]
        ),
        BenchmarkCase(
            id: "technical-02",
            category: .technical,
            reference: "Der Kauf läuft über StoreKit, die Synchronisierung über CloudKit.",
            targetTerms: ["StoreKit", "CloudKit"],
            absentTerms: ["Intune"]
        ),
        BenchmarkCase(
            id: "technical-03",
            category: .technical,
            reference: "Die Oberfläche ist in SwiftUI geschrieben.",
            targetTerms: ["SwiftUI"],
            absentTerms: ["Docker", "Kubernetes"]
        ),
        BenchmarkCase(
            id: "technical-04",
            category: .technical,
            reference: "SpeechAnalyzer bekommt die Begriffe über AnalysisContext.",
            targetTerms: ["SpeechAnalyzer", "AnalysisContext"],
            absentTerms: ["Proxmox"],
            pronunciationNote: "Compound API names; checked that the synthesizer keeps them as one word."
        ),

        // C — abbreviations
        BenchmarkCase(
            id: "abbrev-01",
            category: .abbreviations,
            reference: "Der Zugriff läuft über VPN, die Geräte kommen aus dem MDM.",
            targetTerms: ["VPN", "MDM"],
            absentTerms: ["CVAG"]
        ),
        BenchmarkCase(
            id: "abbrev-02",
            category: .abbreviations,
            reference: "Die API ist dokumentiert, die KI läuft auf dem Gerät.",
            targetTerms: ["API", "KI"],
            absentTerms: ["MDM", "VPN"]
        ),

        // D — numbers, dates, times, versions, addresses
        BenchmarkCase(
            id: "numbers-01",
            category: .numbers,
            reference: "Der Kauf kostet 9,99 Euro.",
            targetTerms: ["9,99"],
            contextualStrings: ["9,99 Euro"],
            absentTerms: ["Proxmox"]
        ),
        BenchmarkCase(
            id: "numbers-02",
            category: .numbers,
            reference: "Das Treffen ist am 4. Oktober 2026 um 13:45 Uhr.",
            targetTerms: ["4. Oktober 2026", "13:45"],
            absentTerms: []
        ),
        BenchmarkCase(
            id: "numbers-03",
            category: .numbers,
            reference: "Der Server hat die Adresse 192.168.2.4.",
            targetTerms: ["192.168.2.4"],
            absentTerms: [],
            pronunciationNote: "Dotted quad; the synthesizer reads the dots as 'Punkt'."
        ),
        BenchmarkCase(
            id: "numbers-04",
            category: .numbers,
            reference: "Wir veröffentlichen Version 1.2.0 als Build 10.",
            targetTerms: ["1.2.0", "10"],
            absentTerms: []
        ),

        // E — mixed, the realistic shape
        BenchmarkCase(
            id: "mixed-01",
            category: .mixed,
            reference: "René legt die CVAG-Unterlagen bis 13:45 Uhr in SharePoint ab.",
            targetTerms: ["René", "CVAG", "13:45", "SharePoint"],
            absentTerms: ["Docker"]
        ),
        BenchmarkCase(
            id: "mixed-02",
            category: .mixed,
            reference: "Für Version 1.2.0 prüfen wir die API und den VPN-Zugang am 4. Oktober.",
            targetTerms: ["1.2.0", "API", "VPN", "4. Oktober"],
            absentTerms: ["CloudKit"]
        ),
        BenchmarkCase(
            id: "mixed-03",
            category: .mixed,
            reference: "Die KI-Zusammenfassung läuft on-device, der Export geht nach Markdown.",
            targetTerms: ["KI", "Markdown"],
            absentTerms: ["SwiftUI", "StoreKit"]
        )
    ]

    /// English corpus, mirroring the German categories so the two are directly
    /// comparable. Same restraint on content: public product names, public
    /// company names or generic text only.
    ///
    /// It exists to answer one question — does a rule built and measured on
    /// German damage English? A rule that is not safe here gets locale-gated
    /// rather than generalised.
    static let english: [BenchmarkCase] = [
        // A — names and proper nouns
        BenchmarkCase(
            id: "en-names-01",
            category: .names,
            reference: "Rene works at the Chemnitz transport company.",
            targetTerms: ["Rene", "Chemnitz"],
            absentTerms: ["Jacqueline", "Proxmox"],
            locale: Locale(identifier: "en-US")
        ),
        BenchmarkCase(
            id: "en-names-02",
            category: .names,
            reference: "Jacqueline confirmed the meeting with Hanning and Kahl.",
            targetTerms: ["Jacqueline", "Hanning"],
            absentTerms: ["Rene", "Intune"],
            locale: Locale(identifier: "en-US")
        ),

        // B — technical terms
        BenchmarkCase(
            id: "en-technical-01",
            category: .technical,
            reference: "The docs are in SharePoint and the container runs in Docker.",
            targetTerms: ["SharePoint", "Docker"],
            absentTerms: ["Kubernetes", "Proxmox"],
            locale: Locale(identifier: "en-US")
        ),
        BenchmarkCase(
            id: "en-technical-02",
            category: .technical,
            reference: "The purchase goes through StoreKit and syncing through CloudKit.",
            targetTerms: ["StoreKit", "CloudKit"],
            absentTerms: ["Intune"],
            locale: Locale(identifier: "en-US")
        ),
        BenchmarkCase(
            id: "en-technical-03",
            category: .technical,
            reference: "The interface is written in SwiftUI.",
            targetTerms: ["SwiftUI"],
            absentTerms: ["Docker", "Kubernetes"],
            locale: Locale(identifier: "en-US")
        ),
        BenchmarkCase(
            id: "en-technical-04",
            category: .technical,
            reference: "SpeechAnalyzer receives the terms through AnalysisContext.",
            targetTerms: ["SpeechAnalyzer", "AnalysisContext"],
            absentTerms: ["Kubernetes"],
            locale: Locale(identifier: "en-US")
        ),

        // C — abbreviations, including the spelled-letter path
        BenchmarkCase(
            id: "en-abbrev-01",
            category: .abbreviations,
            reference: "Access runs over VPN and the devices come from MDM.",
            targetTerms: ["VPN", "MDM"],
            absentTerms: ["Intune"],
            locale: Locale(identifier: "en-US")
        ),
        BenchmarkCase(
            id: "en-abbrev-02",
            category: .abbreviations,
            reference: "The API is documented and the AI runs on the device.",
            targetTerms: ["API", "AI"],
            absentTerms: ["VPN"],
            locale: Locale(identifier: "en-US"),
            pronunciationNote: "The AI case is the English counterpart of the German KI marker case."
        ),

        // D — numbers, times, versions
        BenchmarkCase(
            id: "en-numbers-01",
            category: .numbers,
            reference: "The purchase costs 9.99 dollars.",
            targetTerms: ["9.99"],
            absentTerms: [],
            locale: Locale(identifier: "en-US")
        ),
        BenchmarkCase(
            id: "en-numbers-02",
            category: .numbers,
            reference: "The meeting is on October 4th 2026 at 13:45 o'clock.",
            targetTerms: ["October", "13:45"],
            absentTerms: [],
            locale: Locale(identifier: "en-US")
        ),
        BenchmarkCase(
            id: "en-numbers-03",
            category: .numbers,
            reference: "The server address is 192.168.2.4.",
            targetTerms: ["192.168.2.4"],
            absentTerms: [],
            locale: Locale(identifier: "en-US")
        ),
        BenchmarkCase(
            id: "en-numbers-04",
            category: .numbers,
            reference: "We are shipping version 1.2.0 as build 10.",
            targetTerms: ["1.2.0", "10"],
            absentTerms: [],
            locale: Locale(identifier: "en-US")
        ),

        // E — mixed, the realistic shape
        BenchmarkCase(
            id: "en-mixed-01",
            category: .mixed,
            reference: "Rene files the CVAG documents in SharePoint by 13:45 o'clock.",
            targetTerms: ["Rene", "CVAG", "13:45", "SharePoint"],
            absentTerms: ["Docker"],
            locale: Locale(identifier: "en-US")
        ),
        BenchmarkCase(
            id: "en-mixed-02",
            category: .mixed,
            reference: "For version 1.2.0 we check the API and the VPN access on October 4th.",
            targetTerms: ["1.2.0", "API", "VPN", "October"],
            absentTerms: ["CloudKit"],
            locale: Locale(identifier: "en-US")
        ),
        BenchmarkCase(
            id: "en-mixed-03",
            category: .mixed,
            reference: "The AI summary runs on-device and the export goes to Markdown.",
            targetTerms: ["AI", "Markdown"],
            absentTerms: ["SwiftUI", "StoreKit"],
            locale: Locale(identifier: "en-US")
        )
    ]

    /// Both corpora, for checks that must cover every frozen fixture.
    static let all: [BenchmarkCase] = german + english
}
