import AVFoundation
import Foundation
import Testing
@testable import VoxStudio

/// What the two live conversions actually cost, measured on device with the
/// real formats from `LiveAudioPipelineDiagnostics`.
///
/// The point is not a microbenchmark: it is to decide whether removing the
/// format-identical writer conversion is worth any change at all. A saving that
/// does not show up against the work of recording is not a saving.
@Suite(.serialized)
struct LiveAudioConversionCost {
    /// The tap's real parameters: 4096-frame buffers at 48 kHz.
    private let frames: AVAudioFrameCount = 4096
    private let sampleRate: Double = 48_000

    private func captureFormat() -> AVAudioFormat? {
        AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
    }

    private func analyzerFormat() -> AVAudioFormat? {
        AVAudioFormat(
            commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true
        )
    }

    /// A buffer of plausible speech-level noise, not silence — a converter may
    /// shortcut on zeroes.
    private func filled(_ format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames
        guard let channel = buffer.floatChannelData?[0] else { return nil }
        for index in 0..<Int(frames) {
            channel[index] = Float(sin(Double(index) * 0.01)) * 0.25
        }
        return buffer
    }

    private func convert(
        _ input: AVAudioPCMBuffer,
        using converter: AVAudioConverter,
        to target: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let ratio = target.sampleRate / input.format.sampleRate
        let capacity = AVAudioFrameCount(Double(input.frameLength) * ratio) + 1
        guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return nil }
        var pending: AVAudioPCMBuffer? = input
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if let buffer = pending {
                pending = nil
                status.pointee = .haveData
                return buffer
            }
            status.pointee = .noDataNow
            return nil
        }
        return error == nil ? output : nil
    }

    @Test func costOfTheFormatIdenticalWriterConversion() throws {
        let capture = try #require(captureFormat())
        let input = try #require(filled(capture))
        // What the recorder does today when capture == target: convert 48k mono
        // Float32 to 48k mono Float32.
        let converter = try #require(AVAudioConverter(from: capture, to: capture))

        // One hour of tap callbacks at 4096 frames / 48 kHz.
        let callbacksPerHour = Int(3600.0 * sampleRate / Double(frames))
        let iterations = callbacksPerHour

        let start = Date()
        var produced = 0
        for _ in 0..<iterations {
            if convert(input, using: converter, to: capture) != nil { produced += 1 }
        }
        let elapsed = Date().timeIntervalSince(start)

        #expect(produced == iterations)
        print("COST noop-conversion callbacks=\(iterations) total=\(fmt(elapsed))s " +
              "per-callback=\(fmtMicro(elapsed / Double(iterations)))us " +
              "cpu-share-of-realtime=\(fmtPercent(elapsed / 3600.0))")
    }

    @Test func costOfTheRequiredSpeechConversion() throws {
        let capture = try #require(captureFormat())
        let analyzer = try #require(analyzerFormat())
        let input = try #require(filled(capture))
        let converter = try #require(AVAudioConverter(from: capture, to: analyzer))

        let callbacksPerHour = Int(3600.0 * sampleRate / Double(frames))
        let start = Date()
        var produced = 0
        for _ in 0..<callbacksPerHour {
            if convert(input, using: converter, to: analyzer) != nil { produced += 1 }
        }
        let elapsed = Date().timeIntervalSince(start)

        #expect(produced == callbacksPerHour)
        print("COST speech-conversion callbacks=\(callbacksPerHour) total=\(fmt(elapsed))s " +
              "per-callback=\(fmtMicro(elapsed / Double(callbacksPerHour)))us " +
              "cpu-share-of-realtime=\(fmtPercent(elapsed / 3600.0))")
    }

    /// The other half of the question: what writing the file costs, so the
    /// conversion can be read against it rather than in isolation.
    @Test func costOfWritingTheFile() throws {
        let capture = try #require(captureFormat())
        let input = try #require(filled(capture))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cost-\(UUID().uuidString).m4a")
        defer { try? FileManager.default.removeItem(at: url) }
        let file = try AVAudioFile(forWriting: url, settings: RecordingSettings.encoderSettings)

        // One minute is plenty to characterise the per-callback cost.
        let callbacks = Int(60.0 * sampleRate / Double(frames))
        let start = Date()
        for _ in 0..<callbacks { try file.write(from: input) }
        let elapsed = Date().timeIntervalSince(start)

        print("COST aac-file-write callbacks=\(callbacks) total=\(fmt(elapsed))s " +
              "per-callback=\(fmtMicro(elapsed / Double(callbacks)))us " +
              "cpu-share-of-realtime=\(fmtPercent(elapsed / 60.0))")
    }

    private func fmt(_ value: Double) -> String { String(format: "%.4f", value) }
    private func fmtMicro(_ seconds: Double) -> String { String(format: "%.1f", seconds * 1_000_000) }
    private func fmtPercent(_ share: Double) -> String { String(format: "%.4f%%", share * 100) }
}
