import AVFoundation
import Foundation
import os

/// Parameters for a non-destructive edit render.
struct EditSettings: Sendable, Equatable {
    /// Optional trim range in seconds. `nil` keeps the full source. Applied
    /// **before** speed/normalization (the render order: trim → speed → normalize).
    var trim: ClosedRange<TimeInterval>?
    /// Playback speed, 0.5...3.0. Pitch is preserved (`AVAudioUnitTimePitch`).
    var speed: Double = 1.0
    /// Whether to peak-normalize after the speed render.
    var normalize: Bool = true
    /// Target peak in dBFS when normalizing.
    var targetPeakDBFS: Double = -1.0
}

/// Offline edit renderer. Persistence-agnostic: it reads a source URL and writes
/// a float-PCM working file. **Invariant: speed/time-stretch is rendered first,
/// then the peak is measured on that result and normalized** — normalizing
/// before stretching would invalidate the target level (see docs/DECISIONS.md).
actor AudioEditingService {
    enum EditError: Error, LocalizedError {
        case emptySource
        case renderFailed

        var errorDescription: String? {
            switch self {
            case .emptySource: return String(localized: "Die Quelldatei ist leer.")
            case .renderFailed: return String(localized: "Die Bearbeitung konnte nicht gerendert werden.")
            }
        }
    }

    private let normalizer: any LoudnessNormalizer
    private let logger = Logger(subsystem: "de.gcng.sprechly.work", category: "Editing")

    init(normalizer: any LoudnessNormalizer = PeakNormalizer()) {
        self.normalizer = normalizer
    }

    /// Renders `source` to a float-PCM working file at `output`, applying speed
    /// then peak normalization. Emits progress 0...1. Returns the output duration.
    @discardableResult
    func render(
        source: URL,
        settings: EditSettings,
        to output: URL,
        progress: AsyncStream<Double>.Continuation? = nil
    ) async throws -> TimeInterval {
        let sourceFile = try AVAudioFile(forReading: source)
        guard sourceFile.length > 0 else { throw EditError.emptySource }
        let format = sourceFile.processingFormat

        // Trim window in frames (clamped). Render order: trim → speed → normalize.
        let (startFrame, frameCount) = trimFrames(settings.trim, in: sourceFile)
        guard frameCount > 0 else { throw EditError.emptySource }
        let isFullRange = startFrame == 0 && frameCount == sourceFile.length

        // 1) Produce the speed-rendered (and trimmed) working signal.
        let speedURL: URL
        let cleanupSpeed: Bool
        if abs(settings.speed - 1.0) >= 0.0001 {
            let temp = scratchURL(near: output)
            try renderSpeed(
                sourceFile, speed: settings.speed, startFrame: startFrame, frameCount: frameCount,
                to: temp, format: format, progress: progress
            )
            speedURL = temp
            cleanupSpeed = true
        } else if !isFullRange {
            let temp = scratchURL(near: output)
            try copyRange(sourceFile, startFrame: startFrame, frameCount: frameCount,
                          to: temp, format: format, progress: progress)
            speedURL = temp
            cleanupSpeed = true
        } else {
            speedURL = source
            cleanupSpeed = false
        }

        // 2) Normalization gain — measured on the speed-rendered signal via the
        // swappable normalizer seam (peak today; RMS/LUFS later, drop-in).
        let gain = settings.normalize
            ? try normalizer.gain(forSignalAt: speedURL, targetDBFS: settings.targetPeakDBFS)
            : 1.0

        // 3) Apply gain while writing the working file.
        let duration = try applyGain(gain, from: speedURL, to: output, format: format, progress: progress)

        if cleanupSpeed { try? FileManager.default.removeItem(at: speedURL) }
        progress?.yield(1.0)
        return duration
    }

    // MARK: - Steps

    /// Frames `[startFrame, startFrame+frameCount)` for the (clamped) trim range.
    private func trimFrames(_ trim: ClosedRange<TimeInterval>?, in file: AVAudioFile) -> (AVAudioFramePosition, AVAudioFramePosition) {
        guard let trim else { return (0, file.length) }
        let sr = file.processingFormat.sampleRate
        var start = AVAudioFramePosition((trim.lowerBound * sr).rounded())
        var end = AVAudioFramePosition((trim.upperBound * sr).rounded())
        start = max(0, min(start, file.length))
        end = max(start, min(end, file.length))
        return (start, end - start)
    }

    private func scratchURL(near output: URL) -> URL {
        output.deletingLastPathComponent().appendingPathComponent("edit-\(UUID().uuidString).caf")
    }

    /// Frame-exact copy of a range into a float working file (no re-encode).
    private func copyRange(
        _ source: AVAudioFile,
        startFrame: AVAudioFramePosition,
        frameCount: AVAudioFramePosition,
        to output: URL,
        format: AVAudioFormat,
        progress: AsyncStream<Double>.Continuation?
    ) throws {
        source.framePosition = startFrame
        let outFile = try AVAudioFile(
            forWriting: output, settings: format.settings,
            commonFormat: .pcmFormatFloat32, interleaved: false
        )
        let chunk: AVAudioFrameCount = 16384
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunk) else {
            throw EditError.renderFailed
        }
        var remaining = frameCount
        while remaining > 0 {
            let n = AVAudioFrameCount(min(Int64(chunk), remaining))
            try source.read(into: buffer, frameCount: n)
            if buffer.frameLength == 0 { break }
            try outFile.write(from: buffer)
            remaining -= AVAudioFramePosition(buffer.frameLength)
            if frameCount > 0 {
                progress?.yield(0.5 * Double(frameCount - remaining) / Double(frameCount))
            }
        }
    }

    private func renderSpeed(
        _ source: AVAudioFile,
        speed: Double,
        startFrame: AVAudioFramePosition,
        frameCount: AVAudioFramePosition,
        to output: URL,
        format: AVAudioFormat,
        progress: AsyncStream<Double>.Continuation?
    ) throws {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let timePitch = AVAudioUnitTimePitch()
        timePitch.rate = Float(speed)

        engine.attach(player)
        engine.attach(timePitch)
        engine.connect(player, to: timePitch, format: format)
        engine.connect(timePitch, to: engine.mainMixerNode, format: format)

        let maxFrames: AVAudioFrameCount = 4096
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: maxFrames)
        try engine.start()
        player.scheduleSegment(
            source, startingFrame: startFrame,
            frameCount: AVAudioFrameCount(frameCount), at: nil
        )
        player.play()

        let outFile = try AVAudioFile(
            forWriting: output,
            settings: format.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: engine.manualRenderingFormat,
            frameCapacity: maxFrames
        ) else { throw EditError.renderFailed }

        let totalOut = AVAudioFramePosition(ceil(Double(frameCount) / speed))
        while engine.manualRenderingSampleTime < totalOut {
            let remaining = totalOut - engine.manualRenderingSampleTime
            let frames = AVAudioFrameCount(min(Int64(maxFrames), remaining))
            let status = try engine.renderOffline(frames, to: buffer)
            guard status == .success else { break }
            try outFile.write(from: buffer)
            if totalOut > 0 {
                progress?.yield(0.5 * Double(engine.manualRenderingSampleTime) / Double(totalOut))
            }
        }
        engine.stop()
    }

    private func applyGain(
        _ gain: Float,
        from input: URL,
        to output: URL,
        format: AVAudioFormat,
        progress: AsyncStream<Double>.Continuation?
    ) throws -> TimeInterval {
        let inFile = try AVAudioFile(forReading: input)
        let inFormat = inFile.processingFormat
        let outFile = try AVAudioFile(
            forWriting: output,
            settings: inFormat.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        guard let buffer = AVAudioPCMBuffer(pcmFormat: inFormat, frameCapacity: 16384) else {
            throw EditError.renderFailed
        }
        let total = max(inFile.length, 1)
        while inFile.framePosition < inFile.length {
            try inFile.read(into: buffer)
            let frames = Int(buffer.frameLength)
            if frames == 0 { break }
            if gain != 1.0, let channels = buffer.floatChannelData {
                for c in 0..<Int(inFormat.channelCount) {
                    for i in 0..<frames { channels[c][i] *= gain }
                }
            }
            try outFile.write(from: buffer)
            progress?.yield(0.5 + 0.5 * Double(inFile.framePosition) / Double(total))
        }
        return TimeInterval(outFile.length) / inFormat.sampleRate
    }
}
