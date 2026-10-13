import AVFoundation
import Foundation

/// Strategy that measures a signal and returns the gain needed to reach a target
/// level. Swappable by design: RMS or LUFS normalization can be added as new
/// conforming types without touching the render pipeline in `AudioEditingService`
/// (see docs/DECISIONS.md).
protocol LoudnessNormalizer: Sendable {
    /// Gain to apply to the (already speed-rendered) signal at `url` to reach
    /// `targetDBFS`. Returns 1.0 when no change is needed (e.g. silence).
    func gain(forSignalAt url: URL, targetDBFS: Double) throws -> Float
}

/// Peak normalization: scales so the loudest sample hits the target. Cannot clip
/// (output peak == target ≤ 0 dBFS). Known weakness: a single transient sets the
/// peak, so quiet speech can stay quiet — RMS/LUFS is the planned successor.
struct PeakNormalizer: LoudnessNormalizer {
    /// Boost cap for near-silent input (+24 dB).
    var maxGain: Float = 15.85

    func gain(forSignalAt url: URL, targetDBFS: Double) throws -> Float {
        let peak = try AudioSignalStats.peak(forSignalAt: url)
        guard peak > 0 else { return 1.0 }
        let target = Float(pow(10.0, targetDBFS / 20.0))
        return min(maxGain, target / peak)
    }
}

/// Streaming signal measurements shared by normalizers.
enum AudioSignalStats {
    static func peak(forSignalAt url: URL) throws -> Float {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16384) else {
            return 0
        }
        var peak: Float = 0
        while file.framePosition < file.length {
            try file.read(into: buffer)
            let frames = Int(buffer.frameLength)
            if frames == 0 { break }
            guard let channels = buffer.floatChannelData else { break }
            for c in 0..<Int(format.channelCount) {
                for i in 0..<frames { peak = max(peak, abs(channels[c][i])) }
            }
        }
        return peak
    }
}
