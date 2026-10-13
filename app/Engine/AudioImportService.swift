import AVFoundation
import Foundation

/// Converts an arbitrary external audio file (any container / sample rate /
/// channel count) into the app's recording format — **48 kHz mono float CAF** —
/// so it can be fed to the mixer, which requires a matching format. Persistence-
/// agnostic; streams block by block via `AVAudioConverter` (resample + downmix).
actor AudioImportService {
    enum ImportError: Error, LocalizedError {
        case unreadable
        case conversionFailed

        var errorDescription: String? {
            switch self {
            case .unreadable: return String(localized: "Die Datei konnte nicht gelesen werden.")
            case .conversionFailed: return String(localized: "Die Datei konnte nicht importiert werden.")
            }
        }
    }

    /// Transcodes `source` to a 48 kHz mono float CAF at `output`. Returns the
    /// output duration in seconds.
    @discardableResult
    func importToRecordingFormat(_ source: URL, to output: URL) async throws -> TimeInterval {
        let inFile: AVAudioFile
        do { inFile = try AVAudioFile(forReading: source) } catch { throw ImportError.unreadable }
        let inFormat = inFile.processingFormat
        guard inFile.length > 0 else { throw ImportError.unreadable }

        guard let outFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: RecordingSettings.sampleRate,
            channels: RecordingSettings.channelCount,
            interleaved: false
        ), let converter = AVAudioConverter(from: inFormat, to: outFormat) else {
            throw ImportError.conversionFailed
        }

        let outFile = try AVAudioFile(
            forWriting: output, settings: outFormat.settings,
            commonFormat: .pcmFormatFloat32, interleaved: false
        )

        let inChunk: AVAudioFrameCount = 16_384
        // `nonisolated(unsafe)`: the converter's input block is invoked
        // synchronously from `convert(to:error:)` below, on this very thread —
        // the buffer never crosses an isolation boundary, which the compiler
        // cannot see through the non-Sendable AVFAudio callback.
        nonisolated(unsafe) let inBuffer: AVAudioPCMBuffer
        guard let buffer = AVAudioPCMBuffer(pcmFormat: inFormat, frameCapacity: inChunk) else {
            throw ImportError.conversionFailed
        }
        inBuffer = buffer
        let ratio = outFormat.sampleRate / inFormat.sampleRate
        let outCapacity = AVAudioFrameCount(Double(inChunk) * ratio) + 4_096

        var finished = false
        while !finished {
            guard let outBuffer = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: outCapacity) else {
                throw ImportError.conversionFailed
            }
            var convError: NSError?
            let status = converter.convert(to: outBuffer, error: &convError) { _, inputStatus in
                do {
                    inBuffer.frameLength = 0
                    try inFile.read(into: inBuffer)
                } catch {
                    inputStatus.pointee = .endOfStream
                    return nil
                }
                if inBuffer.frameLength == 0 {
                    inputStatus.pointee = .endOfStream
                    return nil
                }
                inputStatus.pointee = .haveData
                return inBuffer
            }
            if convError != nil { throw ImportError.conversionFailed }
            if outBuffer.frameLength > 0 { try outFile.write(from: outBuffer) }
            if status == .endOfStream || status == .error { finished = true }
        }

        guard outFile.length > 0 else { throw ImportError.conversionFailed }
        return TimeInterval(outFile.length) / outFormat.sampleRate
    }
}
