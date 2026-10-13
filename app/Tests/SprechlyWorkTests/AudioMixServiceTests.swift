import AVFoundation
import Testing
@testable import VoxStudio

struct AudioMixServiceTests {
    private let service = AudioMixService()
    private var target: Float { Float(pow(10.0, -1.0 / 20.0)) }

    @Test func clippingIsPrevented() async throws {
        // Two near-full-scale tracks summed must not exceed the ceiling.
        let main = AudioTestSupport.tempURL("caf")
        let mix = AudioTestSupport.tempURL("caf")
        let out = AudioTestSupport.tempURL("caf")
        defer { [main, mix, out].forEach { try? FileManager.default.removeItem(at: $0) } }
        try AudioTestSupport.writeSine(to: main, amplitude: 0.9, seconds: 1)
        try AudioTestSupport.writeSine(to: mix, amplitude: 0.9, seconds: 1, frequency: 660)

        _ = try await service.mix(main: main, mix: mix, settings: MixSettings(volume: 1.0), to: out)

        #expect(try AudioTestSupport.peak(of: out) <= target + 0.001)
    }

    @Test func quietMixIsNotLimited() async throws {
        let main = AudioTestSupport.tempURL("caf")
        let mix = AudioTestSupport.tempURL("caf")
        let out = AudioTestSupport.tempURL("caf")
        defer { [main, mix, out].forEach { try? FileManager.default.removeItem(at: $0) } }
        try AudioTestSupport.writeSine(to: main, amplitude: 0.2, seconds: 1)
        try AudioTestSupport.writeSine(to: mix, amplitude: 0.2, seconds: 1, frequency: 660)

        _ = try await service.mix(main: main, mix: mix, settings: MixSettings(volume: 1.0), to: out)

        // ~0.4 summed, below the ceiling → untouched.
        #expect(try AudioTestSupport.peak(of: out) > 0.3)
        #expect(try AudioTestSupport.peak(of: out) < target)
    }

    @Test func overhangTruncatesToMainDuration() async throws {
        let main = AudioTestSupport.tempURL("caf")
        let mix = AudioTestSupport.tempURL("caf")
        let out = AudioTestSupport.tempURL("caf")
        defer { [main, mix, out].forEach { try? FileManager.default.removeItem(at: $0) } }
        try AudioTestSupport.writeSine(to: main, amplitude: 0.4, seconds: 2)
        try AudioTestSupport.writeSine(to: mix, amplitude: 0.4, seconds: 2)

        // Mix starts at 1.5 s and would run to 3.5 s, but the result is the main length.
        let duration = try await service.mix(main: main, mix: mix, settings: MixSettings(volume: 1.0, offset: 1.5), to: out)

        #expect(abs(duration - 2.0) <= 0.01)
        #expect(abs(try AudioTestSupport.duration(of: out) - 2.0) <= 0.01)
    }

    @Test func offsetPlacesMixOnTimeline() async throws {
        let main = AudioTestSupport.tempURL("caf")
        let mix = AudioTestSupport.tempURL("caf")
        let out = AudioTestSupport.tempURL("caf")
        defer { [main, mix, out].forEach { try? FileManager.default.removeItem(at: $0) } }
        try AudioTestSupport.writeSine(to: main, amplitude: 0.15, seconds: 3)
        try AudioTestSupport.writeSine(to: mix, amplitude: 0.6, seconds: 1, frequency: 660)

        _ = try await service.mix(main: main, mix: mix, settings: MixSettings(volume: 1.0, offset: 1.0), to: out)

        // First second is main-only; the mix appears around its offset.
        #expect(try AudioTestSupport.peak(of: out, fromSeconds: 0, toSeconds: 0.8) < 0.3)
        #expect(try AudioTestSupport.peak(of: out, fromSeconds: 1.1, toSeconds: 1.8) > 0.4)
    }

    @Test func mixTrimMixesOnlyTheRange() async throws {
        let main = AudioTestSupport.tempURL("caf")
        let mix = AudioTestSupport.tempURL("caf")
        let out = AudioTestSupport.tempURL("caf")
        defer { [main, mix, out].forEach { try? FileManager.default.removeItem(at: $0) } }
        try AudioTestSupport.writeSine(to: main, amplitude: 0.1, seconds: 2)
        try AudioTestSupport.writeSine(to: mix, amplitude: 0.6, seconds: 2, frequency: 660)

        // Only the first 0.5 s of the mix is used, at offset 0.
        _ = try await service.mix(main: main, mix: mix, settings: MixSettings(volume: 1.0, offset: 0, mixTrim: 0.0...0.5), to: out)

        #expect(try AudioTestSupport.peak(of: out, fromSeconds: 0, toSeconds: 0.4) > 0.4)   // mix present
        #expect(try AudioTestSupport.peak(of: out, fromSeconds: 1.0, toSeconds: 2.0) < 0.2) // main only
    }

    @Test func rejectsFormatMismatchBeforeWriting() async throws {
        let main = AudioTestSupport.tempURL("caf")
        let mix = AudioTestSupport.tempURL("caf")
        let out = AudioTestSupport.tempURL("caf")
        defer { [main, mix, out].forEach { try? FileManager.default.removeItem(at: $0) } }
        try AudioTestSupport.writeSine(to: main, amplitude: 0.5, seconds: 1)
        try AudioTestSupport.writeSine(to: mix, amplitude: 0.5, seconds: 1, sampleRate: 44_100)

        await #expect(throws: AudioMixService.MixError.self) {
            _ = try await service.mix(main: main, mix: mix, settings: MixSettings(), to: out)
        }
        #expect(!FileManager.default.fileExists(atPath: out.path))
    }

    @Test func rejectsMissingSourceBeforeWriting() async throws {
        let main = AudioTestSupport.tempURL("caf")
        let missing = AudioTestSupport.tempURL("caf")
        let out = AudioTestSupport.tempURL("caf")
        defer { [main, out].forEach { try? FileManager.default.removeItem(at: $0) } }
        try AudioTestSupport.writeSine(to: main, amplitude: 0.5, seconds: 1)

        await #expect(throws: AudioMixService.MixError.self) {
            _ = try await service.mix(main: main, mix: missing, settings: MixSettings(), to: out)
        }
        #expect(!FileManager.default.fileExists(atPath: out.path))
    }
}
