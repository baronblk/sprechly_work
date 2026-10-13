import CryptoKit
import Foundation
import Testing
@testable import VoxStudio

/// Guards the frozen benchmark audio.
///
/// Every quality figure recorded from Phase 4 onwards refers to these exact
/// files. `AVSpeechSynthesizer` does not render bit-identical audio across
/// runs, so a regenerated fixture would silently invalidate the comparison
/// instead of failing loudly. This suite makes that failure loud.
///
/// Runs anywhere — no Speech framework, no device needed.
struct BenchmarkFixtureTests {
    /// Parses `SHA256SUMS` into `[filename: hash]`.
    private func manifest() throws -> [String: String] {
        let url = try #require(
            Bundle(for: BundleToken.self).url(forResource: "SHA256SUMS", withExtension: nil)
        )
        let text = try String(contentsOf: url, encoding: .utf8)
        var entries: [String: String] = [:]
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            let parts = trimmed.split(whereSeparator: { $0.isWhitespace })
            guard parts.count == 2 else { continue }
            entries[String(parts[1])] = String(parts[0])
        }
        return entries
    }

    private final class BundleToken {}

    @Test func everyCorpusCaseHasAFixture() throws {
        for testCase in BenchmarkCorpus.all {
            let url = BenchmarkSpeech.fixtureURL(for: testCase.id)
            #expect(url != nil, "missing frozen audio for case \(testCase.id)")
        }
    }

    @Test func fixtureHashesMatchTheManifest() throws {
        let expected = try manifest()
        #expect(expected.count == BenchmarkCorpus.all.count)

        for testCase in BenchmarkCorpus.all {
            let url = try #require(BenchmarkSpeech.fixtureURL(for: testCase.id))
            let data = try Data(contentsOf: url)
            let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            let name = "\(testCase.id).m4a"
            #expect(
                digest == expected[name],
                "\(name) differs from the frozen manifest — recorded baselines no longer apply"
            )
        }
    }
}
