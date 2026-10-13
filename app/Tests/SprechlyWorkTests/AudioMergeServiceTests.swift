import AVFoundation
import Testing
@testable import VoxStudio

struct AudioMergeServiceTests {
    private let service = AudioMergeService()

    @Test func mergeDurationIsSumOfSources() async throws {
        let a = AudioTestSupport.tempURL("caf")
        let b = AudioTestSupport.tempURL("caf")
        let out = AudioTestSupport.tempURL("caf")
        defer { [a, b, out].forEach { try? FileManager.default.removeItem(at: $0) } }
        try AudioTestSupport.writeSine(to: a, amplitude: 0.5, seconds: 1)
        try AudioTestSupport.writeSine(to: b, amplitude: 0.5, seconds: 2)

        let duration = try await service.merge(sources: [a, b], to: out)

        #expect(abs(duration - 3.0) <= max(0.05, 3.0 * 0.02))
        #expect(abs(try AudioTestSupport.duration(of: out) - 3.0) <= max(0.05, 3.0 * 0.02))
    }

    @Test func mergeRespectsOrder() async throws {
        let quiet = AudioTestSupport.tempURL("caf")  // 0.2, 1 s
        let loud = AudioTestSupport.tempURL("caf")   // 0.6, 2 s
        let abOut = AudioTestSupport.tempURL("caf")
        let baOut = AudioTestSupport.tempURL("caf")
        defer { [quiet, loud, abOut, baOut].forEach { try? FileManager.default.removeItem(at: $0) } }
        try AudioTestSupport.writeSine(to: quiet, amplitude: 0.2, seconds: 1)
        try AudioTestSupport.writeSine(to: loud, amplitude: 0.6, seconds: 2)

        _ = try await service.merge(sources: [quiet, loud], to: abOut)
        _ = try await service.merge(sources: [loud, quiet], to: baOut)

        // First second reflects whichever source came first.
        #expect(try AudioTestSupport.peak(of: abOut, firstSeconds: 0.8) < 0.4)
        #expect(try AudioTestSupport.peak(of: baOut, firstSeconds: 0.8) > 0.4)
    }

    @Test func rejectsFormatMismatchBeforeWriting() async throws {
        let ok = AudioTestSupport.tempURL("caf")
        let odd = AudioTestSupport.tempURL("caf")
        let out = AudioTestSupport.tempURL("caf")
        defer { [ok, odd, out].forEach { try? FileManager.default.removeItem(at: $0) } }
        try AudioTestSupport.writeSine(to: ok, amplitude: 0.5, seconds: 1)
        try AudioTestSupport.writeSine(to: odd, amplitude: 0.5, seconds: 1, sampleRate: 44_100)

        await #expect(throws: AudioMergeService.MergeError.self) {
            _ = try await service.merge(sources: [ok, odd], to: out)
        }
        // Stronger guarantee: no output was ever created.
        #expect(!FileManager.default.fileExists(atPath: out.path))
    }

    @Test func rejectsMissingSourceBeforeWriting() async throws {
        let ok = AudioTestSupport.tempURL("caf")
        let missing = AudioTestSupport.tempURL("caf")  // never written
        let out = AudioTestSupport.tempURL("caf")
        defer { [ok, out].forEach { try? FileManager.default.removeItem(at: $0) } }
        try AudioTestSupport.writeSine(to: ok, amplitude: 0.5, seconds: 1)

        await #expect(throws: AudioMergeService.MergeError.self) {
            _ = try await service.merge(sources: [ok, missing], to: out)
        }
        #expect(!FileManager.default.fileExists(atPath: out.path))
    }
}
