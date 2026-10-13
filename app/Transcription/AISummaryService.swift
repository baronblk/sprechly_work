import Foundation
import FoundationModels
import os

/// On-device AI post-processing via Foundation Models. Wraps a
/// `LanguageModelSession` and produces a `@Generable` `RecordingInsights`.
///
/// `actor` per the architecture rules (CLAUDE.md §7): availability checks and
/// generation are isolated; failures map to defined `AISummaryError` cases —
/// never a crash. Runs only on a real device (no model in the Simulator).
actor AISummaryService: AISummarizing {
    private let logger = Logger(subsystem: "de.gcng.sprechly.work", category: "AISummary")

    /// All work here transforms the user's *own* recording (summarize, translate,
    /// condense). The default guardrail false-positives on benign content — most
    /// visibly on translation — so we use Apple's content-transformation guardrail,
    /// designed for exactly this. A flagged result still falls back gracefully via
    /// `mapped` → `.contentFlagged`.
    private let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)

    func availability() async -> AIAvailability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(.deviceNotEligible):
            return .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled):
            return .appleIntelligenceNotEnabled
        case .unavailable(.modelNotReady):
            return .modelNotReady
        case .unavailable:
            return .unknown
        }
    }

    /// Conservative character budget per model request (well under the on-device
    /// context window, leaving room for instructions and the generated output).
    private static let maxCharsPerRequest = 800

    func summarize(transcript: String, style: SummaryStyle) async throws -> RecordingInsights {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AISummaryError.emptyTranscript }

        let state = await availability()
        guard state == .available else { throw AISummaryError.unavailable(state) }

        // Long transcripts: recursively condense until the text fits one request,
        // then summarize that in the requested style (avoids context overflow).
        let source = try await condense(trimmed)

        let session = LanguageModelSession(model: model, instructions: Self.instructions(for: style))
        do {
            let response = try await session.respond(
                to: Self.prompt(for: source, style: style),
                generating: RecordingInsights.self
            )
            return response.content
        } catch {
            logger.error("Summary generation failed: \(error.localizedDescription, privacy: .public)")
            throw Self.mapped(error)
        }
    }

    /// Maps Foundation Models generation errors to user-presentable cases —
    /// especially the safety guardrail, which false-positives on medical topics.
    private static func mapped(_ error: Error) -> AISummaryError {
        if let generation = error as? LanguageModelSession.GenerationError {
            switch generation {
            case .guardrailViolation:
                return .contentFlagged
            case .exceededContextWindowSize:
                return .tooLong
            default:
                break
            }
        }
        return .generationFailed(error.localizedDescription)
    }

    func translate(_ text: String, to language: String) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AISummaryError.emptyTranscript }

        let state = await availability()
        guard state == .available else { throw AISummaryError.unavailable(state) }

        let instructions = """
        Du bist ein professioneller Übersetzer. Übersetze den Text exakt und \
        natürlich nach \(language). Gib ausschließlich die Übersetzung aus, ohne \
        Kommentar oder Anführungszeichen.
        """
        // Translate chunk by chunk (fresh session each) so long transcripts never
        // exceed the context window; stitch the parts back together.
        let chunks = Self.chunk(trimmed, maxChars: Self.maxCharsPerRequest)
        var parts: [String] = []
        for chunk in chunks {
            let session = LanguageModelSession(model: model, instructions: instructions)
            parts.append(try await respond(session, to: chunk))
        }
        return parts.joined(separator: " ")
    }

    /// Recursively condenses `text` until it fits a single request, by summarizing
    /// each chunk and re-summarizing the combined result. Bounded by a few passes.
    private func condense(_ text: String) async throws -> String {
        var current = text
        var passes = 0
        while current.count > Self.maxCharsPerRequest && passes < 5 {
            let chunks = Self.chunk(current, maxChars: Self.maxCharsPerRequest)
            var partials: [String] = []
            for chunk in chunks {
                let session = LanguageModelSession(
                    model: model,
                    instructions: "Fasse den folgenden Abschnitt knapp und sachlich zusammen, in derselben Sprache."
                )
                partials.append(try await respond(session, to: chunk))
            }
            current = partials.joined(separator: "\n")
            passes += 1
        }
        return current
    }

    private func respond(_ session: LanguageModelSession, to prompt: String) async throws -> String {
        do {
            return try await session.respond(to: prompt).content
        } catch {
            logger.error("AI request failed: \(error.localizedDescription, privacy: .public)")
            throw Self.mapped(error)
        }
    }

    /// Splits text into chunks no larger than `maxChars`, preferring sentence
    /// boundaries. Pure and unit-testable.
    static func chunk(_ text: String, maxChars: Int) -> [String] {
        guard text.count > maxChars else { return [text] }
        let sentences = text
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: ". ")
        var chunks: [String] = []
        var current = ""

        func flush() {
            let trimmed = current.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { chunks.append(trimmed) }
            current = ""
        }

        for (index, sentence) in sentences.enumerated() {
            let piece = index < sentences.count - 1 ? sentence + ". " : sentence
            // A single piece longer than the limit: flush, then hard-split it.
            if piece.count > maxChars {
                flush()
                var start = piece.startIndex
                while start < piece.endIndex {
                    let end = piece.index(start, offsetBy: maxChars, limitedBy: piece.endIndex) ?? piece.endIndex
                    chunks.append(String(piece[start..<end]).trimmingCharacters(in: .whitespaces))
                    start = end
                }
                continue
            }
            if !current.isEmpty, current.count + piece.count > maxChars { flush() }
            current += piece
        }
        flush()
        return chunks
    }

    private static func instructions(for style: SummaryStyle) -> String {
        """
        Du bist ein Assistent, der Sprachaufnahmen aufbereitet. Antworte sachlich \
        und in derselben Sprache wie das Transkript. Erfinde keine Inhalte, die nicht \
        im Transkript vorkommen. \(style.instructions)
        """
    }

    private static func prompt(for transcript: String, style: SummaryStyle) -> String {
        """
        Erstelle einen kurzen Titel und das Ergebnis im Stil „\(style.title)“ für das folgende Transkript:

        \(transcript)
        """
    }
}
