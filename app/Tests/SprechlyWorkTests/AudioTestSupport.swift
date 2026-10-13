import AVFoundation
import Foundation

/// Helpers to synthesize and measure audio files in tests (no hardware).
enum AudioTestSupport {
    static func floatFormat(sampleRate: Double = 48_000) -> AVAudioFormat {
        AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!
    }

    /// Writes a mono float `.caf` sine of the given peak amplitude and duration.
    static func writeSine(
        to url: URL,
        amplitude: Float,
        seconds: Double,
        sampleRate: Double = 48_000,
        frequency: Double = 440
    ) throws {
        let format = floatFormat(sampleRate: sampleRate)
        let file = try AVAudioFile(
            forWriting: url, settings: format.settings,
            commonFormat: .pcmFormatFloat32, interleaved: false
        )
        let total = Int(seconds * sampleRate)
        let chunk = 4096
        var written = 0
        var phase = 0.0
        let inc = 2 * Double.pi * frequency / sampleRate
        while written < total {
            let n = min(chunk, total - written)
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(n))!
            buffer.frameLength = AVAudioFrameCount(n)
            let channel = buffer.floatChannelData![0]
            for i in 0..<n {
                channel[i] = amplitude * Float(sin(phase))
                phase += inc
            }
            try file.write(from: buffer)
            written += n
        }
    }

    static func peak(of url: URL) throws -> Float {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16384)!
        var peak: Float = 0
        while file.framePosition < file.length {
            try file.read(into: buffer)
            if buffer.frameLength == 0 { break }
            let channel = buffer.floatChannelData![0]
            for i in 0..<Int(buffer.frameLength) { peak = Swift.max(peak, abs(channel[i])) }
        }
        return peak
    }

    /// Peak amplitude within the first `seconds` of the file (for order tests).
    static func peak(of url: URL, firstSeconds seconds: Double) throws -> Float {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        var remaining = AVAudioFramePosition(seconds * format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16384)!
        var peak: Float = 0
        while file.framePosition < file.length, remaining > 0 {
            try file.read(into: buffer)
            let frames = min(Int(buffer.frameLength), Int(remaining))
            if frames == 0 { break }
            let channel = buffer.floatChannelData![0]
            for i in 0..<frames { peak = Swift.max(peak, abs(channel[i])) }
            remaining -= AVAudioFramePosition(frames)
        }
        return peak
    }

    /// Peak amplitude within a time window `[from, to)` seconds.
    static func peak(of url: URL, fromSeconds from: Double, toSeconds to: Double) throws -> Float {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let startFrame = AVAudioFramePosition(from * format.sampleRate)
        var remaining = AVAudioFramePosition((to - from) * format.sampleRate)
        file.framePosition = startFrame
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16384)!
        var peak: Float = 0
        while file.framePosition < file.length, remaining > 0 {
            try file.read(into: buffer)
            let frames = min(Int(buffer.frameLength), Int(remaining))
            if frames == 0 { break }
            let channel = buffer.floatChannelData![0]
            for i in 0..<frames { peak = Swift.max(peak, abs(channel[i])) }
            remaining -= AVAudioFramePosition(frames)
        }
        return peak
    }

    static func duration(of url: URL) throws -> TimeInterval {
        let file = try AVAudioFile(forReading: url)
        return TimeInterval(file.length) / file.processingFormat.sampleRate
    }

    static func tempURL(_ ext: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).\(ext)")
    }
}
