import FoundationModels

/// The AI post-processing output for a transcript: a short title plus a concise
/// summary. Key points and transcript cleanup are deliberately deferred to a
/// later additive slice (see docs/DECISIONS.md).
@Generable
struct RecordingInsights: Equatable, Sendable {
    @Guide(description: "Ein kurzer, prägnanter Titel für die Aufnahme, höchstens 6 Wörter, ohne Anführungszeichen.")
    var title: String

    @Guide(description: "Das aufbereitete Ergebnis (Zusammenfassung, Protokoll oder Stichpunkte) in derselben Sprache wie das Transkript; ggf. als Markdown.")
    var summary: String
}
