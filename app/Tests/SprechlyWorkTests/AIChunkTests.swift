import Testing
@testable import SprechlyWork

struct AIChunkTests {
    @Test func shortTextIsSingleChunk() {
        let chunks = AISummaryService.chunk("Kurzer Satz.", maxChars: 1500)
        #expect(chunks == ["Kurzer Satz."])
    }

    @Test func longTextSplitsIntoMultipleChunks() {
        let sentence = "Dies ist ein Testsatz mit etwas Länge. "
        let text = String(repeating: sentence, count: 200) // ~7800 chars
        let chunks = AISummaryService.chunk(text, maxChars: 1500)
        #expect(chunks.count > 1)
        #expect(chunks.allSatisfy { $0.count <= 1600 }) // bounded near the limit
        // Nothing lost: every chunk has content.
        #expect(chunks.allSatisfy { !$0.isEmpty })
    }

    @Test func splitsOverlongSingleSentence() {
        let text = String(repeating: "wort ", count: 1000) // one long run, no ". "
        let chunks = AISummaryService.chunk(text, maxChars: 1500)
        #expect(chunks.count > 1)
    }
}
