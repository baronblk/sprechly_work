import AVFoundation
import Foundation

/// Settings for overlaying a second (mix) track on the main recording.
struct MixSettings: Sendable {
    /// Mix-track volume, 0...1. The main track stays at 1.0.
    var volume: Double = 0.5
    /// Where the mix track starts on the timeline, in seconds.
    var offset: TimeInterval = 0
    /// Optional trim of the mix source (only this range is mixed).
    var mixTrim: ClosedRange<TimeInterval>?
    /// Ceiling the summed signal is limited to.
    var limitDBFS: Double = -1.0
}

/// Overlays a second audio track on the main recording by **summing in float**,
/// then limits the summed peak to the target (no hard clipping) via the
/// `PeakLimiter` seam. Persistence-agnostic; streams both sources block by block
/// (never both fully in memory). The result is **truncated to the main
/// recording's duration** — an overhanging mix track is cut.
actor AudioMixService {
    enum MixError: Error, LocalizedError {
        case unreadableSource(URL)
        case incompatibleFormat(URL)
        case renderFailed

        var errorDescription: String? {
            switch self {
            case .unreadableSource: return String(localized: "Eine Audiodatei konnte nicht gelesen werden.")
            case .incompatibleFormat: return String(localized: "Eine Audiodatei hat ein abweichendes Format.")
            case .renderFailed: return String(localized: "Der Mix konnte nicht gerendert werden.")
            }
        }
    }

    private let limiter: any LoudnessNormalizer = PeakLimiter()

    /// Mixes `mix` onto `main` and writes the float working result to `output`.
    /// Returns the output duration (== main duration).
    func mix(
        main: URL,
        mix: URL,
        settings: MixSettings,
        to output: URL,
        progress: AsyncStream<Double>.Continuation? = nil
    ) async throws -> TimeInterval {
        let sampleRate = RecordingSettings.sampleRate
        let channels = RecordingSettings.channelCount

        // Pre-flight: validate BOTH sources before any write.
        let mainFile = try open(main, sampleRate: sampleRate, channels: channels)
        let mixFile = try open(mix, sampleRate: sampleRate, channels: channels)

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: sampleRate,
            channels: channels, interleaved: false
        ) else { throw MixError.renderFailed }

        let outputLength = mainFile.length // truncate to main
        let offsetFrames = max(0, AVAudioFramePosition((settings.offset * sampleRate).rounded()))
        let (mixStart, mixCount) = mixRange(settings.mixTrim, in: mixFile, sampleRate: sampleRate)
        let summed = output.deletingLastPathComponent().appendingPathComponent("mix-\(UUID().uuidString).caf")

        do {
            try streamSum(
                mainFile: mainFile, mixFile: mixFile, format: format,
                outputLength: outputLength, offsetFrames: offsetFrames,
                mixStart: mixStart, mixCount: mixCount, volume: Float(settings.volume),
                to: summed, progress: progress
            )

            // Clipping protection: attenuate the summed signal to the ceiling if needed.
            let gain = try limiter.gain(forSignalAt: summed, targetDBFS: settings.limitDBFS)
            if gain < 0.999 {
                try applyGain(gain, from: summed, to: output, format: format)
                try? FileManager.default.removeItem(at: summed)
            } else {
                if FileManager.default.fileExists(atPath: output.path) {
                    try FileManager.default.removeItem(at: output)
                }
                try FileManager.default.moveItem(at: summed, to: output)
            }
            progress?.yield(1.0)
            return TimeInterval(outputLength) / sampleRate
        } catch {
            try? FileManager.default.removeItem(at: summed)
            try? FileManager.default.removeItem(at: output)
            throw error
        }
    }

    // MARK: - Steps

    private func open(_ url: URL, sampleRate: Double, channels: AVAudioChannelCount) throws -> AVAudioFile {
        let file: AVAudioFile
        do { file = try AVAudioFile(forReading: url) } catch { throw MixError.unreadableSource(url) }
        let format = file.processingFormat
        guard format.sampleRate == sampleRate, format.channelCount == channels else {
            throw MixError.incompatibleFormat(url)
        }
        return file
    }

    private func mixRange(_ trim: ClosedRange<TimeInterval>?, in file: AVAudioFile, sampleRate: Double) -> (AVAudioFramePosition, AVAudioFramePosition) {
        guard let trim else { return (0, file.length) }
        var start = AVAudioFramePosition((trim.lowerBound * sampleRate).rounded())
        var end = AVAudioFramePosition((trim.upperBound * sampleRate).rounded())
        start = max(0, min(start, file.length))
        end = max(start, min(end, file.length))
        return (start, end - start)
    }

    private func streamSum(
        mainFile: AVAudioFile,
        mixFile: AVAudioFile,
        format: AVAudioFormat,
        outputLength: AVAudioFramePosition,
        offsetFrames: AVAudioFramePosition,
        mixStart: AVAudioFramePosition,
        mixCount: AVAudioFramePosition,
        volume: Float,
        to output: URL,
        progress: AsyncStream<Double>.Continuation?
    ) throws {
        let outFile = try AVAudioFile(
            forWriting: output, settings: format.settings,
            commonFormat: .pcmFormatFloat32, interleaved: false
        )
        let chunk: AVAudioFrameCount = 16384
        guard let mainBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunk),
              let mixBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunk) else {
            throw MixError.renderFailed
        }

        mixFile.framePosition = mixStart
        let mixActiveStart = offsetFrames
        let mixActiveEnd = offsetFrames + mixCount

        var produced: AVAudioFramePosition = 0
        while produced < outputLength {
            let n = AVAudioFrameCount(min(Int64(chunk), outputLength - produced))
            try mainFile.read(into: mainBuffer, frameCount: n)
            let got = Int(mainBuffer.frameLength)
            if got == 0 { break }

            let blockStart = produced
            let blockEnd = produced + AVAudioFramePosition(got)
            let overlapStart = max(blockStart, mixActiveStart)
            let overlapEnd = min(blockEnd, mixActiveEnd, outputLength)
            if overlapEnd > overlapStart, let out = mainBuffer.floatChannelData?[0] {
                let m = AVAudioFrameCount(overlapEnd - overlapStart)
                try mixFile.read(into: mixBuffer, frameCount: m)
                if let mixCh = mixBuffer.floatChannelData?[0] {
                    let dst = Int(overlapStart - blockStart)
                    for j in 0..<min(Int(mixBuffer.frameLength), Int(m)) {
                        out[dst + j] += volume * mixCh[j]
                    }
                }
            }

            try outFile.write(from: mainBuffer)
            produced += AVAudioFramePosition(got)
            if outputLength > 0 {
                progress?.yield(0.7 * Double(produced) / Double(outputLength))
            }
        }
    }

    private func applyGain(_ gain: Float, from input: URL, to output: URL, format: AVAudioFormat) throws {
        let inFile = try AVAudioFile(forReading: input)
        let outFile = try AVAudioFile(
            forWriting: output, settings: format.settings,
            commonFormat: .pcmFormatFloat32, interleaved: false
        )
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16384) else {
            throw MixError.renderFailed
        }
        while inFile.framePosition < inFile.length {
            try inFile.read(into: buffer)
            let frames = Int(buffer.frameLength)
            if frames == 0 { break }
            if let channel = buffer.floatChannelData?[0] {
                for i in 0..<frames { channel[i] *= gain }
            }
            try outFile.write(from: buffer)
        }
    }
}
