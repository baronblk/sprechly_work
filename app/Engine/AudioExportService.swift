import AVFoundation
import Foundation

/// Transcodes a rendered working file into a target `ExportFormat`. Pure I/O:
/// the DSP lives in `AudioEditingService`.
actor AudioExportService {
    enum ExportError: Error, LocalizedError {
        case bufferUnavailable

        var errorDescription: String? {
            switch self {
            case .bufferUnavailable: return String(localized: "Der Export-Puffer konnte nicht erzeugt werden.")
            }
        }
    }

    /// Reads `workingURL` (float PCM) and writes `output` in `format`.
    func export(workingURL: URL, format: ExportFormat, to output: URL) throws {
        let inFile = try AVAudioFile(forReading: workingURL)
        let inFormat = inFile.processingFormat
        let outFile = try AVAudioFile(forWriting: output, settings: format.settings())
        guard let buffer = AVAudioPCMBuffer(pcmFormat: inFormat, frameCapacity: 16384) else {
            throw ExportError.bufferUnavailable
        }
        while inFile.framePosition < inFile.length {
            try inFile.read(into: buffer)
            if buffer.frameLength == 0 { break }
            try outFile.write(from: buffer)
        }
    }
}
