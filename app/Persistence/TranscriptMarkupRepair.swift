import Foundation
import SwiftData
import os

/// Repairs the recogniser's literal `\letter` markup in transcripts that were
/// saved before the formatter existed.
///
/// **Strictly a bug fix, not a reformatting.** Clock-time, version, compound
/// and spelling rules are deliberately *not* applied to existing data: text the
/// user already has must not change retroactively because a new heuristic
/// shipped. The marker is different, because it was never text the user said or
/// wrote.
///
/// A run of marked letters is joined (`K\letter I\letter` → `KI`). That is not
/// the general acronym heuristic: Apple's own marker already states that these
/// characters were spelled out, so the run is identified by the recogniser, not
/// guessed by us. An unmarked `K I` in old text is therefore left exactly as it
/// is — the join is driven by the marker and by nothing else.
///
/// Runs in the launch maintenance pass next to the trash purge, which is the
/// project's existing mechanism for this; there is no separate migration stack.
/// It is filtered by the marker rather than gated behind a one-shot flag on
/// purpose: CloudKit can deliver an affected segment from another device long
/// after a flag would have been set, and a pass that finds nothing costs one
/// indexed fetch. Each segment is therefore still touched exactly once.
enum TranscriptMarkupRepair {
    private static let logger = Logger(subsystem: "de.gcng.sprechly.work", category: "MarkupRepair")

    /// The one marker observed in measured output. Documented in
    /// docs/TRANSCRIPTION_ERROR_TAXONOMY.md.
    static let marker = #"\letter"#

    /// Resolves the markup in one segment's text.
    ///
    /// Three ordered steps, each anchored on the marker:
    /// 1. A run of two or more marked letters becomes one token (`VPN`).
    /// 2. A lone marked letter keeps the letter, loses the marker.
    /// 3. A space doubled by step 2 is collapsed.
    ///
    /// Text without a backslash returns untouched, and anything else carrying a
    /// backslash — a Windows path, a dictated escape sequence, the words
    /// `\letters` or `\letterbox` — is not matched by any step.
    static func repair(_ text: String) -> String {
        guard text.contains("\\") else { return text }

        var result = text
        // A single letter plus the marker, repeated — no trailing whitespace in
        // the match, so the space after the run survives the replacement.
        let runPattern = #"\p{L}\\letter(?:\s*\p{L}\\letter)+"#
        if let regex = try? NSRegularExpression(pattern: runPattern) {
            let nsText = result as NSString
            let matches = regex.matches(in: result, range: NSRange(location: 0, length: nsText.length))
            for match in matches.reversed() {
                let run = nsText.substring(with: match.range)
                // Everything that is not the marker or whitespace is a letter.
                let joined = run
                    .replacingOccurrences(of: marker, with: "")
                    .filter { !$0.isWhitespace }
                guard let range = Range(match.range, in: result) else { continue }
                result.replaceSubrange(range, with: joined)
            }
        }

        // Whatever marked letters are left stood alone; keep the letter.
        if let regex = try? NSRegularExpression(pattern: #"(\p{L})\\letter"#) {
            result = regex.stringByReplacingMatches(
                in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "$1"
            )
        }

        guard result != text else { return text }
        guard let spaces = try? NSRegularExpression(pattern: #"[ \t]{2,}"#) else { return result }
        return spaces.stringByReplacingMatches(
            in: result, range: NSRange(result.startIndex..., in: result), withTemplate: " "
        )
    }

    /// Repairs every affected segment and returns how many were changed.
    @discardableResult
    static func run(in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<TranscriptSegment>(
            predicate: #Predicate { $0.text.contains(marker) }
        )
        guard let affected = try? context.fetch(descriptor), !affected.isEmpty else { return 0 }

        var repaired = 0
        for segment in affected {
            let cleaned = repair(segment.text)
            guard cleaned != segment.text else { continue }
            segment.text = cleaned
            repaired += 1
        }
        guard repaired > 0 else { return 0 }

        do {
            try context.save()
            logger.info("Repaired spelled-letter markup in \(repaired, privacy: .public) segment(s)")
        } catch {
            logger.error("Markup repair could not be saved: \(error.localizedDescription, privacy: .public)")
            return 0
        }
        return repaired
    }
}
