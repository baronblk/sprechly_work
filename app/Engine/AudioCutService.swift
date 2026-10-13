import AVFoundation
import Foundation

/// Non-destructive cut operations: remove a middle range, keep only a selection,
/// or auto-remove long silences. Built on the verified editing (trim) and merge
/// services — each op reads a source and writes a new float-PCM working file.
actor AudioCutService {
    enum CutError: Error, LocalizedError {
        case wouldBeEmpty
        var errorDescription: String? {
            switch self {
            case .wouldBeEmpty: return String(localized: "Das Ergebnis wäre leer.")
            }
        }
    }

    private let editing = AudioEditingService()
    private let merge = AudioMergeService()
    private let fileStore: RecordingFileStore
    private let epsilon: TimeInterval = 0.03

    init(fileStore: RecordingFileStore = RecordingFileStore()) {
        self.fileStore = fileStore
    }

    /// Keeps only `range`, dropping everything outside it.
    func keep(range: ClosedRange<TimeInterval>, from source: URL) async throws -> (URL, TimeInterval) {
        let out = fileStore.temporaryURL(pathExtension: "caf")
        let duration = try await editing.render(
            source: source,
            settings: EditSettings(trim: range, speed: 1.0, normalize: false),
            to: out
        )
        return (out, duration)
    }

    /// Removes `range` from the middle, stitching the head and tail.
    func remove(range: ClosedRange<TimeInterval>, from source: URL, duration: TimeInterval) async throws -> (URL, TimeInterval) {
        var keeps: [ClosedRange<TimeInterval>] = []
        if range.lowerBound > epsilon { keeps.append(0...range.lowerBound) }
        if range.upperBound < duration - epsilon { keeps.append(range.upperBound...duration) }
        guard !keeps.isEmpty else { throw CutError.wouldBeEmpty }
        return try await stitch(keeps, from: source)
    }

    /// Auto-removes silent passages longer than `minSilence`.
    func removeSilence(
        from source: URL,
        threshold: Float = 0.015,
        minSilence: TimeInterval = 0.6
    ) async throws -> (URL, TimeInterval) {
        let window: TimeInterval = 0.05
        let loud = try loudWindows(forFileAt: source, window: window, threshold: threshold)
        let keeps = Self.keepRanges(loud: loud, windowDuration: window, minSilence: minSilence)
        guard !keeps.isEmpty else { throw CutError.wouldBeEmpty }
        return try await stitch(keeps, from: source)
    }

    // MARK: - Helpers

    /// Renders each keep-range and merges them into one working file.
    private func stitch(_ ranges: [ClosedRange<TimeInterval>], from source: URL) async throws -> (URL, TimeInterval) {
        var parts: [URL] = []
        defer { parts.forEach { fileStore.removeTemporary($0) } }
        for range in ranges {
            let part = fileStore.temporaryURL(pathExtension: "caf")
            _ = try await editing.render(
                source: source,
                settings: EditSettings(trim: range, speed: 1.0, normalize: false),
                to: part
            )
            parts.append(part)
        }
        let out = fileStore.temporaryURL(pathExtension: "caf")
        let total = try await merge.merge(sources: parts, to: out)
        return (out, total)
    }

    /// Per-window loudness flags (RMS ≥ threshold) for `source`.
    private func loudWindows(forFileAt url: URL, window: TimeInterval, threshold: Float) throws -> [Bool] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frames = AVAudioFrameCount(format.sampleRate * window)
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return [] }

        var flags: [Bool] = []
        while file.framePosition < file.length {
            try file.read(into: buffer, frameCount: frames)
            if buffer.frameLength == 0 { break }
            flags.append(rms(buffer) >= threshold)
        }
        return flags
    }

    private func rms(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<count { sum += channel[i] * channel[i] }
        return (sum / Float(count)).squareRoot()
    }

    /// Pure: converts per-window loudness flags into the ranges to **keep**,
    /// dropping silent runs at least `minSilence` long. Unit-testable.
    static func keepRanges(loud: [Bool], windowDuration: Double, minSilence: Double) -> [ClosedRange<Double>] {
        guard !loud.isEmpty else { return [] }
        let count = loud.count
        let minSilentWindows = max(1, Int((minSilence / windowDuration).rounded()))
        var ranges: [ClosedRange<Double>] = []
        var keepStart = 0
        var i = 0
        while i < count {
            if loud[i] { i += 1; continue }
            var j = i
            while j < count && !loud[j] { j += 1 }
            if (j - i) >= minSilentWindows {
                if i > keepStart {
                    ranges.append(Double(keepStart) * windowDuration ... Double(i) * windowDuration)
                }
                keepStart = j
            }
            i = j
        }
        if keepStart < count {
            ranges.append(Double(keepStart) * windowDuration ... Double(count) * windowDuration)
        }
        return ranges
    }
}
