import Foundation
import Testing
@testable import VoxStudio

struct TranscriptExporterTests {
    private let exporter = TranscriptExporter()
    private let segments = [
        TranscriptExporter.Segment(text: "Zweiter Satz", startTime: 65),
        TranscriptExporter.Segment(text: "Erster Satz", startTime: 5),
    ]

    @Test func txtContainsAllTextsInOrder() {
        let out = exporter.render(title: "Titel", summary: "Summe", segments: segments, format: .txt)
        #expect(out.contains("Erster Satz"))
        #expect(out.contains("Zweiter Satz"))
        // Ordered by start time.
        if let first = out.range(of: "Erster Satz"), let second = out.range(of: "Zweiter Satz") {
            #expect(first.lowerBound < second.lowerBound)
        } else {
            Issue.record("Expected both segment texts in the output")
        }
        // TXT has bracketed timestamps but no markdown headings.
        #expect(out.contains("[00:05]"))
        #expect(!out.contains("#"))
    }

    @Test func markdownHasTitleSummaryAndTimestamps() {
        let out = exporter.render(title: "Mein Titel", summary: "Eine Summe", segments: segments, format: .markdown)
        #expect(out.contains("# Mein Titel"))
        #expect(out.contains("## Zusammenfassung"))
        #expect(out.contains("Eine Summe"))
        #expect(out.contains("00:05"))
        #expect(out.contains("Erster Satz"))
        #expect(out.contains("Erstellt mit Sprechly"))
    }

    @Test func includesSummaryAndTranslationInBothFormats() {
        let md = exporter.render(
            title: "T", summary: "Eine Summe", translation: "Hello", translationLanguage: "Englisch",
            segments: segments, format: .markdown
        )
        #expect(md.contains("## Zusammenfassung"))
        #expect(md.contains("Eine Summe"))
        #expect(md.contains("## Übersetzung (Englisch)"))
        #expect(md.contains("Hello"))

        let txt = exporter.render(
            title: "T", summary: "Eine Summe", translation: "Hello", translationLanguage: "Englisch",
            segments: segments, format: .txt
        )
        #expect(txt.contains("Zusammenfassung"))
        #expect(txt.contains("Eine Summe"))
        #expect(txt.contains("Übersetzung (Englisch)"))
        #expect(txt.contains("Hello"))
    }

    @Test func markdownOmitsSummaryHeadingWhenEmpty() {
        let out = exporter.render(title: "T", summary: nil, segments: segments, format: .markdown)
        #expect(!out.contains("## Zusammenfassung"))
        #expect(out.contains("## Transkript"))
    }

    @Test func writeProducesFileWithCorrectExtensionAndContent() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let url = try exporter.write(title: "Titel", summary: nil, segments: segments, format: .markdown, to: dir)
        #expect(url.pathExtension == "md")
        let written = try String(contentsOf: url, encoding: .utf8)
        #expect(written.contains("# Titel"))
    }

    @Test func writtenFileIsUTF8WithBOMAndIntactUmlauts() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let umlautSegments = [TranscriptExporter.Segment(text: "Staatsangehörigkeit, groß", startTime: 0)]
        let url = try exporter.write(
            title: "Prüfung", summary: "Größe", segments: umlautSegments, format: .markdown, to: dir
        )
        let raw = try Data(contentsOf: url)
        // Leading UTF-8 BOM.
        #expect(raw.prefix(3) == Data([0xEF, 0xBB, 0xBF]))
        // Body is single-encoded UTF-8: "ö" is C3 B6, not the double-encoded C3 83 C2 B6.
        #expect(raw.range(of: Data([0xC3, 0x83, 0xC2, 0xB6])) == nil)
        // Decodes losslessly as UTF-8.
        let decoded = String(decoding: raw, as: UTF8.self)
        #expect(decoded.contains("Staatsangehörigkeit, groß"))
        #expect(decoded.contains("Prüfung"))
        #expect(decoded.contains("Größe"))
    }

    @Test func sanitizeStripsPathHostileCharacters() {
        #expect(TranscriptExporter.sanitize("a/b:c?") == "a-b-c-")
        #expect(TranscriptExporter.sanitize("   ") == "Transkript")
    }
}
