import Foundation

/// The kind of AI post-processing to run on a transcript. Each style drives a
/// different prompt; the result is stored in `Recording.summary` (markdown).
enum SummaryStyle: String, CaseIterable, Identifiable, Sendable {
    case summary
    case minutes
    case bullets
    case keypoints
    case cleanup

    var id: String { rawValue }

    var title: String {
        switch self {
        case .summary: return "Zusammenfassung"
        case .minutes: return "Protokoll"
        case .bullets: return "Stichpunkte"
        case .keypoints: return "Kernaussagen"
        case .cleanup: return "Bereinigung"
        }
    }

    var icon: String {
        switch self {
        case .summary: return "text.alignleft"
        case .minutes: return "list.bullet.clipboard"
        case .bullets: return "list.bullet"
        case .keypoints: return "key"
        case .cleanup: return "wand.and.sparkles"
        }
    }

    /// Style-specific guidance appended to the base instructions.
    var instructions: String {
        switch self {
        case .summary:
            return "Fasse das Transkript sachlich in 2 bis 4 Sätzen zusammen."
        case .minutes:
            return """
            Erstelle ein strukturiertes Protokoll in Markdown mit passenden \
            Abschnitten (z. B. Themen, Entscheidungen, offene Punkte, Aufgaben). \
            Verwende Überschriften (##) und Aufzählungen (-).
            """
        case .bullets:
            return "Fasse die wichtigsten Punkte als Markdown-Aufzählung (-) zusammen, je ein Punkt pro Zeile."
        case .keypoints:
            return """
            Nenne die 3 bis 5 wichtigsten Kernaussagen als Markdown-Aufzählung (-). \
            Jede Aussage knapp und eigenständig verständlich.
            """
        case .cleanup:
            return """
            Bereinige das Transkript: Entferne Füllwörter, Wiederholungen und \
            Versprecher, korrigiere Zeichensetzung und Absätze, bewahre aber \
            Inhalt, Bedeutung und Sprache exakt. Gib den bereinigten Fließtext \
            ohne Kommentar aus.
            """
        }
    }
}
