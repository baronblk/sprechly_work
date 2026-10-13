import Foundation
import Testing
@testable import SprechlyWork

struct PeakLimiterTests {
    private var target: Float { Float(pow(10.0, -1.0 / 20.0)) }

    @Test func attenuatesWhenOverTarget() throws {
        let url = AudioTestSupport.tempURL("caf")
        defer { try? FileManager.default.removeItem(at: url) }
        try AudioTestSupport.writeSine(to: url, amplitude: 1.0, seconds: 0.5)

        let gain = try PeakLimiter().gain(forSignalAt: url, targetDBFS: -1.0)
        #expect(abs(gain - target / 1.0) < 0.001)
        #expect(gain < 1.0)
    }

    @Test func doesNotBoostWhenUnderTarget() throws {
        let url = AudioTestSupport.tempURL("caf")
        defer { try? FileManager.default.removeItem(at: url) }
        try AudioTestSupport.writeSine(to: url, amplitude: 0.3, seconds: 0.5)

        #expect(try PeakLimiter().gain(forSignalAt: url, targetDBFS: -1.0) == 1.0)
    }
}
