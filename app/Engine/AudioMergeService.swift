import AVFoundation
import Foundation

/// Concatenates homogeneous library recordings (48 kHz mono) into one file.
/// Persistence-agnostic: works with URLs and writes a float-PCM working file.
///
/// **Pre-flight:** every source's format and readability is validated *before*
/// the output is created, so a mismatched/missing source throws before anything
/// is written (no partial output). The render then streams segment by segment —
/// never all sources in memory at once. A runtime cleanup remains as a safety net
/// for a source that becomes unreadable mid-render (see docs/DECISIONS.md).
actor AudioMergeService {
    enum MergeError: Error, LocalizedError {
        case empty
        case unreadableSource(URL)
        case incompatibleFormat(URL)

        var errorDescription: String? {
            switch self {
            case .empty: return String(localized: "Keine Aufnahmen zum Zusammenführen ausgewählt.")
            case .unreadableSource: return String(localized: "Eine Aufnahme konnte nicht gelesen werden.")
            case .incompatibleFormat: return String(localized: "Eine Aufnahme hat ein abweichendes Format.")
            }
        }
    }

    /// Merges `sources` in order into `output`. Returns the summed duration.
    func merge(
        sources: [URL],
        to output: URL,
        progress: AsyncStream<Double>.Continuation? = nil
    ) async throws -> TimeInterval {
        guard !sources.isEmpty else { throw MergeError.empty }

        let sampleRate = RecordingSettings.sampleRate
        let channels = RecordingSettings.channelCount

        // Pre-flight: validate ALL sources before creating the output.
        for url in sources {
            let file: AVAudioFile
            do { file = try AVAudioFile(forReading: url) } catch { throw MergeError.unreadableSource(url) }
            let format = file.processingFormat
            guard format.sampleRate == sampleRate, format.channelCount == channels else {
                throw MergeError.incompatibleFormat(url)
            }
        }

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: sampleRate,
            channels: channels, interleaved: false
        ), let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16384) else {
            throw MergeError.empty
        }

        let outFile = try AVAudioFile(
            forWriting: output, settings: format.settings,
            commonFormat: .pcmFormatFloat32, interleaved: false
        )

        do {
            var totalFrames: AVAudioFramePosition = 0
            for (index, url) in sources.enumerated() {
                let file: AVAudioFile
                do { file = try AVAudioFile(forReading: url) } catch { throw MergeError.unreadableSource(url) }
                while file.framePosition < file.length {
                    try file.read(into: buffer)
                    if buffer.frameLength == 0 { break }
                    try outFile.write(from: buffer)
                }
                totalFrames += file.length
                progress?.yield(Double(index + 1) / Double(sources.count))
            }
            return TimeInterval(totalFrames) / sampleRate
        } catch {
            // Safety net: a source failed mid-render — leave no orphan output.
            try? FileManager.default.removeItem(at: output)
            throw error
        }
    }
}
