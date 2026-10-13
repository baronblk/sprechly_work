import Foundation

/// Transcript export formats. Two are enough for this slice; PDF/SRT are out of
/// scope (see docs/DECISIONS.md).
enum TranscriptExportFormat: String, CaseIterable, Identifiable, Sendable {
    case txt
    case markdown

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .txt: return "txt"
        case .markdown: return "md"
        }
    }

    var displayName: String {
        switch self {
        case .txt: return "Text (.txt)"
        case .markdown: return "Markdown (.md)"
        }
    }
}

/// Renders a transcript to TXT or Markdown and writes a named file. Pure value
/// type — no SwiftData, no main-actor dependency, fully unit-testable.
struct TranscriptExporter {
    struct Segment: Sendable {
        let text: String
        let startTime: TimeInterval
    }

    /// Renders the transcript to a string. Includes the AI summary and, if
    /// present, the translation, then the timestamped transcript.
    func render(
        title: String,
        summary: String?,
        translation: String? = nil,
        translationLanguage: String? = nil,
        date: Date? = nil,
        duration: TimeInterval? = nil,
        segments: [Segment],
        format: TranscriptExportFormat
    ) -> String {
        let ordered = segments.sorted { $0.startTime < $1.startTime }
        let summaryText = nonEmpty(summary)
        // The translation is one LLM block — break it into readable paragraphs.
        let translationText = nonEmpty(translation).map { Self.paragraphs($0) }
        let translationHeading = translationLanguage.map { String(localized: "Übersetzung (\($0))") } ?? String(localized: "Übersetzung")
        let meta = metaLine(date: date, duration: duration)

        switch format {
        case .txt:
            var parts: [String] = [title]
            if let meta { parts.append(meta) }
            if let summaryText { parts.append("\(String(localized: "Zusammenfassung"))\n\(summaryText)") }
            if let translationText { parts.append("\(translationHeading)\n\(translationText)") }
            parts.append("\(String(localized: "Transkript"))\n" + ordered
                .map { "[\(TimeFormatting.shortTimecode($0.startTime))] \($0.text)" }
                .joined(separator: "\n\n"))
            return parts.joined(separator: "\n\n") + "\n"
        case .markdown:
            var out = "# \(title)\n"
            if let meta { out += "\n*\(meta)*\n" }
            if let summaryText { out += "\n---\n\n## \(String(localized: "Zusammenfassung"))\n\n\(summaryText)\n" }
            if let translationText { out += "\n---\n\n## \(translationHeading)\n\n\(translationText)\n" }
            out += "\n---\n\n## \(String(localized: "Transkript"))\n\n"
            out += ordered
                .map { "**`\(TimeFormatting.shortTimecode($0.startTime))`** \($0.text)" }
                .joined(separator: "\n\n")
            out += "\n\n---\n\n*\(String(localized: "Erstellt mit Sprechly"))*\n"
            return out
        }
    }

    private func metaLine(date: Date?, duration: TimeInterval?) -> String? {
        var bits: [String] = []
        if let date { bits.append(date.formatted(date: .abbreviated, time: .shortened)) }
        if let duration {
            let timecode = TimeFormatting.shortTimecode(duration)
            bits.append(String(localized: "Dauer \(timecode)"))
        }
        return bits.isEmpty ? nil : bits.joined(separator: " · ")
    }

    /// Writes the rendered transcript to a uniquely-named file in `directory`.
    @discardableResult
    func write(
        title: String,
        summary: String?,
        translation: String? = nil,
        translationLanguage: String? = nil,
        date: Date? = nil,
        duration: TimeInterval? = nil,
        segments: [Segment],
        format: TranscriptExportFormat,
        to directory: URL
    ) throws -> URL {
        let content = render(
            title: title, summary: summary, translation: translation,
            translationLanguage: translationLanguage, date: date, duration: duration,
            segments: segments, format: format
        )
        let url = directory.appendingPathComponent("\(Self.sanitize(title)).\(format.fileExtension)")
        // The content is already valid UTF-8; the byte-order mark makes editors
        // that would otherwise guess Latin-1/Windows-1252 detect UTF-8, so German
        // umlauts/ß render correctly everywhere (the cause of mojibake exports).
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data(content.utf8))
        try data.write(to: url, options: .atomic)
        return url
    }

    private func nonEmpty(_ string: String?) -> String? {
        guard let string, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return string
    }

    /// Groups a single prose block into paragraphs (a few sentences each) so a
    /// long translation reads well instead of being one wall of text.
    static func paragraphs(_ text: String, sentencesPerParagraph: Int = 3) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        var sentences: [String] = []
        var current = ""
        for char in trimmed {
            current.append(char)
            if char == "." || char == "!" || char == "?" {
                let s = current.trimmingCharacters(in: .whitespaces)
                if !s.isEmpty { sentences.append(s) }
                current = ""
            }
        }
        let tail = current.trimmingCharacters(in: .whitespaces)
        if !tail.isEmpty { sentences.append(tail) }

        var paragraphs: [String] = []
        var index = 0
        while index < sentences.count {
            let end = min(index + sentencesPerParagraph, sentences.count)
            paragraphs.append(sentences[index..<end].joined(separator: " "))
            index = end
        }
        return paragraphs.joined(separator: "\n\n")
    }

    /// Strips path-hostile characters so the title becomes a safe file name.
    static func sanitize(_ title: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>").union(.newlines)
        let cleaned = title.components(separatedBy: invalid).joined(separator: "-")
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: "Transkript") : trimmed
    }
}
