import Foundation
import Testing
@testable import SprechlyWork

struct LoudnessNormalizerTests {
    @Test func peakNormalizerComputesGainToTarget() throws {
        let url = AudioTestSupport.tempURL("caf")
        defer { try? FileManager.default.removeItem(at: url) }
        try AudioTestSupport.writeSine(to: url, amplitude: 0.5, seconds: 1)

        let gain = try PeakNormalizer().gain(forSignalAt: url, targetDBFS: -1.0)
        let target = Float(pow(10.0, -1.0 / 20.0))
        #expect(abs(gain - target / 0.5) < 0.001)
    }

    @Test func silenceYieldsUnityGain() throws {
        let url = AudioTestSupport.tempURL("caf")
        defer { try? FileManager.default.removeItem(at: url) }
        try AudioTestSupport.writeSine(to: url, amplitude: 0.0, seconds: 0.5)

        #expect(try PeakNormalizer().gain(forSignalAt: url, targetDBFS: -1.0) == 1.0)
    }

    @Test func nearSilenceIsBoostCapped() throws {
        let url = AudioTestSupport.tempURL("caf")
        defer { try? FileManager.default.removeItem(at: url) }
        try AudioTestSupport.writeSine(to: url, amplitude: 0.0001, seconds: 0.5)

        let normalizer = PeakNormalizer()
        #expect(try normalizer.gain(forSignalAt: url, targetDBFS: -1.0) == normalizer.maxGain)
    }
}
