import AVFoundation
import Testing
@testable import VoxStudio

struct RecorderConverterFactoryTests {
    private let target = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 1, interleaved: false
    )!
    private func format(_ rate: Double) -> AVAudioFormat {
        AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rate, channels: 1, interleaved: false)!
    }

    @Test func buildsConverterForInputFormat() {
        let converter = RecorderConverterFactory.converter(for: format(16_000), target: target, reusing: nil)
        let unwrapped = try! #require(converter)
        #expect(unwrapped.inputFormat.sampleRate == 16_000)
        #expect(unwrapped.outputFormat == target)
    }

    @Test func reusesConverterWhenFormatUnchanged() {
        let first = try! #require(RecorderConverterFactory.converter(for: format(16_000), target: target, reusing: nil))
        let second = RecorderConverterFactory.converter(for: format(16_000), target: target, reusing: first)
        #expect(second === first)
    }

    @Test func rebuildsWhenBufferFormatChanges() {
        // Simulates HFP 16 kHz → built-in mic 48 kHz after a route change.
        let stale = try! #require(RecorderConverterFactory.converter(for: format(16_000), target: target, reusing: nil))
        let rebuilt = try! #require(RecorderConverterFactory.converter(for: format(48_000), target: target, reusing: stale))
        #expect(rebuilt !== stale)
        #expect(rebuilt.inputFormat.sampleRate == 48_000)
        #expect(rebuilt.outputFormat == target) // invariant preserved
    }
}
