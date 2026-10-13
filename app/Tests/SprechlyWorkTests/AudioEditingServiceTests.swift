import AVFoundation
import Testing
@testable import SprechlyWork

private struct StubNormalizer: LoudnessNormalizer {
    let fixedGain: Float
    func gain(forSignalAt url: URL, targetDBFS: Double) throws -> Float { fixedGain }
}

struct AudioEditingServiceTests {
    private let service = AudioEditingService()
    private let targetDBFS = -1.0
    private var targetPeak: Float { Float(pow(10.0, targetDBFS / 20.0)) }

    @Test func usesInjectedNormalizerSeam() async throws {
        let source = AudioTestSupport.tempURL("caf")
        let output = AudioTestSupport.tempURL("caf")
        defer { [source, output].forEach { try? FileManager.default.removeItem(at: $0) } }
        try AudioTestSupport.writeSine(to: source, amplitude: 0.1, seconds: 1)

        let service = AudioEditingService(normalizer: StubNormalizer(fixedGain: 2.0))
        try await service.render(
            source: source,
            settings: EditSettings(speed: 1.0, normalize: true),
            to: output
        )

        // The service applied the seam's gain (0.1 × 2.0), not a hardwired peak calc.
        #expect(abs(try AudioTestSupport.peak(of: output) - 0.2) < 0.01)
    }

    @Test func normalizationHitsTargetPeak() async throws {
        let source = AudioTestSupport.tempURL("caf")
        let output = AudioTestSupport.tempURL("caf")
        defer { [source, output].forEach { try? FileManager.default.removeItem(at: $0) } }
        try AudioTestSupport.writeSine(to: source, amplitude: 0.3, seconds: 1)

        try await service.render(
            source: source,
            settings: EditSettings(speed: 1.0, normalize: true, targetPeakDBFS: targetDBFS),
            to: output
        )

        let peak = try AudioTestSupport.peak(of: output)
        #expect(abs(peak - targetPeak) < 0.02)
    }

    @Test func normalizedPeakIsEqualAcrossSpeeds() async throws {
        // Proves the render order: speed first, then normalize on the result.
        let source = AudioTestSupport.tempURL("caf")
        let out1 = AudioTestSupport.tempURL("caf")
        let out2 = AudioTestSupport.tempURL("caf")
        defer { [source, out1, out2].forEach { try? FileManager.default.removeItem(at: $0) } }
        try AudioTestSupport.writeSine(to: source, amplitude: 0.4, seconds: 2)

        try await service.render(source: source, settings: EditSettings(speed: 1.0, normalize: true, targetPeakDBFS: targetDBFS), to: out1)
        try await service.render(source: source, settings: EditSettings(speed: 2.0, normalize: true, targetPeakDBFS: targetDBFS), to: out2)

        let p1 = try AudioTestSupport.peak(of: out1)
        let p2 = try AudioTestSupport.peak(of: out2)
        #expect(abs(p1 - targetPeak) < 0.02)
        #expect(abs(p2 - targetPeak) < 0.02)
        #expect(abs(p1 - p2) < 0.02)
    }

    @Test func speedChangesDurationWithinTolerance() async throws {
        let source = AudioTestSupport.tempURL("caf")
        let fast = AudioTestSupport.tempURL("caf")
        let slow = AudioTestSupport.tempURL("caf")
        defer { [source, fast, slow].forEach { try? FileManager.default.removeItem(at: $0) } }
        try AudioTestSupport.writeSine(to: source, amplitude: 0.5, seconds: 2)

        try await service.render(source: source, settings: EditSettings(speed: 2.0, normalize: false), to: fast)
        try await service.render(source: source, settings: EditSettings(speed: 0.5, normalize: false), to: slow)

        let dFast = try AudioTestSupport.duration(of: fast)
        let dSlow = try AudioTestSupport.duration(of: slow)
        // Time-stretch is approximate (frame rounding / latency) — tolerance, not exact.
        #expect(abs(dFast - 1.0) <= max(0.05, 1.0 * 0.02))
        #expect(abs(dSlow - 4.0) <= max(0.05, 4.0 * 0.02))
    }

    @Test func trimProducesRangeDuration() async throws {
        let source = AudioTestSupport.tempURL("caf")
        let output = AudioTestSupport.tempURL("caf")
        defer { [source, output].forEach { try? FileManager.default.removeItem(at: $0) } }
        try AudioTestSupport.writeSine(to: source, amplitude: 0.5, seconds: 4)

        try await service.render(source: source, settings: EditSettings(trim: 1.0...3.0, normalize: false), to: output)

        #expect(abs(try AudioTestSupport.duration(of: output) - 2.0) <= max(0.05, 2.0 * 0.02))
    }

    @Test func identityTrimKeepsFullDuration() async throws {
        // start = 0, end = full duration — the identity case where off-by-one
        // frame errors at the boundaries would show up.
        let source = AudioTestSupport.tempURL("caf")
        let output = AudioTestSupport.tempURL("caf")
        defer { [source, output].forEach { try? FileManager.default.removeItem(at: $0) } }
        try AudioTestSupport.writeSine(to: source, amplitude: 0.5, seconds: 3)

        try await service.render(source: source, settings: EditSettings(trim: 0.0...3.0, normalize: false), to: output)

        #expect(abs(try AudioTestSupport.duration(of: output) - 3.0) <= 0.01)
    }

    @Test func trimCombinesWithSpeed() async throws {
        let source = AudioTestSupport.tempURL("caf")
        let output = AudioTestSupport.tempURL("caf")
        defer { [source, output].forEach { try? FileManager.default.removeItem(at: $0) } }
        try AudioTestSupport.writeSine(to: source, amplitude: 0.5, seconds: 4)

        // Trim 1...3 (2 s) at 2× → ~1 s.
        try await service.render(source: source, settings: EditSettings(trim: 1.0...3.0, speed: 2.0, normalize: false), to: output)

        #expect(abs(try AudioTestSupport.duration(of: output) - 1.0) <= max(0.05, 1.0 * 0.02))
    }

    @Test func reTrimOfTrimmedFileStaysValid() async throws {
        let source = AudioTestSupport.tempURL("caf")
        let first = AudioTestSupport.tempURL("caf")
        let second = AudioTestSupport.tempURL("caf")
        defer { [source, first, second].forEach { try? FileManager.default.removeItem(at: $0) } }
        try AudioTestSupport.writeSine(to: source, amplitude: 0.5, seconds: 4)

        try await service.render(source: source, settings: EditSettings(trim: 0.0...3.0, normalize: false), to: first)
        try await service.render(source: first, settings: EditSettings(trim: 0.5...2.0, normalize: false), to: second)

        #expect(try AVAudioFile(forReading: second).length > 0)
        #expect(abs(try AudioTestSupport.duration(of: second) - 1.5) <= max(0.05, 1.5 * 0.02))
    }

    @Test func normalizeOffLeavesLevelUnchanged() async throws {
        let source = AudioTestSupport.tempURL("caf")
        let output = AudioTestSupport.tempURL("caf")
        defer { [source, output].forEach { try? FileManager.default.removeItem(at: $0) } }
        try AudioTestSupport.writeSine(to: source, amplitude: 0.3, seconds: 1)

        try await service.render(source: source, settings: EditSettings(speed: 1.0, normalize: false), to: output)

        let peak = try AudioTestSupport.peak(of: output)
        #expect(abs(peak - 0.3) < 0.02)
    }

    @Test func sourceFileIsUntouched() async throws {
        let source = AudioTestSupport.tempURL("caf")
        let output = AudioTestSupport.tempURL("caf")
        defer { [source, output].forEach { try? FileManager.default.removeItem(at: $0) } }
        try AudioTestSupport.writeSine(to: source, amplitude: 0.3, seconds: 1)
        let before = try AudioTestSupport.peak(of: source)

        try await service.render(source: source, settings: EditSettings(speed: 2.0, normalize: true), to: output)

        #expect(FileManager.default.fileExists(atPath: source.path))
        #expect(try AudioTestSupport.peak(of: source) == before)
    }
}
