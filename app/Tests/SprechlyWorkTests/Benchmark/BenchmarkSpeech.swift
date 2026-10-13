import Foundation
import Speech

/// Access to the frozen benchmark audio.
///
/// **What this is for:** an identical, repeatable input so two pipeline
/// variants can be compared. The audio is synthetic — cleanly articulated,
/// free of room acoustics, background noise, accent and disfluency — so a
/// score here says nothing about real-world accuracy. Use it for A/B only.
///
/// The files are generated once by `scripts/make_benchmark_fixtures.sh` and
/// pinned by its SHA-256 manifest, which `BenchmarkFixtureTests` verifies.
/// They are deliberately *not* synthesized per run: `AVSpeechSynthesizer` is
/// not bit-identical between runs, which made figures from separate runs
/// incomparable and is why the Phase-2 and Phase-3 numbers for the same
/// transcriber disagreed.
enum BenchmarkSpeech {
    /// Frozen fixture for a corpus case, shipped in the test bundle.
    static func fixtureURL(for id: String) -> URL? {
        Bundle(for: BundleToken.self).url(forResource: id, withExtension: "m4a")
    }

    private final class BundleToken {}

    /// Whether this environment can actually run the benchmark: the Speech
    /// stack is device-only, and the locale's model must be installed.
    static func isAvailable(for locale: Locale) async -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        guard SpeechTranscriber.isAvailable else { return false }
        let installed = await SpeechTranscriber.installedLocales
        let wanted = locale.identifier.replacingOccurrences(of: "_", with: "-").lowercased()
        return installed.contains { $0.identifier.replacingOccurrences(of: "_", with: "-").lowercased() == wanted }
        #endif
    }
}
