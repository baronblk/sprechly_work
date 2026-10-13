import AVFoundation
import Foundation
import os

/// A throttled snapshot of recording progress, emitted ~30×/second.
struct RecordingMeter: Sendable {
    /// Peak level in 0...1 for the live level indicator.
    let level: Float
    /// Envelope/energy of this slice for the live waveform.
    let bucket: WaveformBucket
    /// Elapsed recorded time.
    let elapsed: TimeInterval
}

/// Records microphone input to a single AAC file via `AVAudioEngine`.
///
/// Persistence-agnostic: it writes to the URL it is given and reports state and
/// meters; the view model owns the file move and SwiftData. Pause/resume keeps
/// one continuous file (`engine.pause()/start()`), so the duration stays exact.
///
/// Resilient to route changes (Bluetooth ↔ built-in mic) without caching a
/// stale input format — the fix for `-10868` (`kAudioUnitErr_FormatNotSupported`):
/// - `resume()` recreates the `AVAudioEngine` so its input node binds to the
///   *current* hardware format. (`installTap(format: nil)` resolves the tap
///   format once, at install time, and does **not** update afterwards — so a
///   plain `engine.start()` after a route change keeps the stale tap format.)
/// - The converter is rebuilt from the **live** buffer format; its output stays
///   a constant 48 kHz mono, so the open file stays valid (A6).
actor AudioRecorderEngine {
    enum State: Sendable, Equatable {
        case idle, recording, paused, stopped
    }

    enum RecorderError: Error, LocalizedError {
        case engineUnavailable

        var errorDescription: String? {
            switch self {
            case .engineUnavailable: return String(localized: "Die Audio-Engine konnte nicht gestartet werden.")
            }
        }
    }

    private(set) var state: State = .idle

    private var engine = AVAudioEngine()
    private var writer: RecordingWriter?
    private var continuation: AsyncStream<RecordingMeter>.Continuation?
    private var tapInstalled = false
    private let logger = Logger(subsystem: "de.gcng.sprechly.work", category: "Recorder")

    /// Starts recording into `url`. Returns a stream of throttled meters.
    /// `bufferSink` (optional) receives each captured buffer for live transcription.
    func start(
        to url: URL,
        bufferSink: (@Sendable (AVAudioPCMBuffer) -> Void)? = nil
    ) throws -> AsyncStream<RecordingMeter> {
        let file = try AVAudioFile(
            forWriting: url,
            settings: RecordingSettings.settings(forFileExtension: url.pathExtension)
        )
        let targetFormat = file.processingFormat

        let (stream, continuation) = AsyncStream<RecordingMeter>.makeStream()
        self.continuation = continuation

        let emitEvery = Swift.max(1, Int(targetFormat.sampleRate / 30))
        let writer = RecordingWriter(
            file: file,
            targetFormat: targetFormat,
            emitEvery: emitEvery,
            continuation: continuation,
            bufferSink: bufferSink
        )
        self.writer = writer

        do {
            try startFreshEngine(writer: writer)
        } catch {
            continuation.finish()
            self.writer = nil
            self.continuation = nil
            throw RecorderError.engineUnavailable
        }
        state = .recording
        return stream
    }

    func pause() {
        guard state == .recording else { return }
        engine.pause()
        writer?.setPaused(true)
        state = .paused
    }

    /// Resumes by recreating the engine, so its input node binds to the current
    /// hardware format — correct even after a route change (e.g. BT 16 kHz →
    /// built-in 48 kHz).
    func resume() throws {
        guard state == .paused, let writer else { return }
        do {
            try startFreshEngine(writer: writer)
        } catch {
            throw RecorderError.engineUnavailable
        }
        writer.setPaused(false)
        state = .recording
    }

    /// Stops recording and returns the recorded duration in seconds.
    @discardableResult
    func stop() -> TimeInterval {
        guard state == .recording || state == .paused else { return 0 }
        engine.stop()
        removeTapIfNeeded()
        let duration = writer?.duration ?? 0
        continuation?.finish()
        writer = nil
        continuation = nil
        state = .stopped
        return duration
    }

    /// Stops the engine and flushes the in-progress file (releasing the writer
    /// closes its `AVAudioFile`), leaving the recorder paused so the file can be
    /// played back for review. Returns the recorded duration.
    func finalizeCurrentFile() -> TimeInterval {
        guard state == .recording || state == .paused else { return 0 }
        engine.stop()
        removeTapIfNeeded()
        let duration = writer?.duration ?? 0
        continuation?.finish()
        writer = nil
        continuation = nil
        state = .paused
        return duration
    }

    /// Tears down the current engine and starts a fresh one so the input node
    /// reflects the current hardware format, then installs the tap and starts.
    private func startFreshEngine(writer: RecordingWriter) throws {
        engine.stop()
        removeTapIfNeeded()
        engine = AVAudioEngine()

        // format: nil resolves to the (now current) input node format.
        engine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: nil) { buffer, _ in
            writer.append(buffer)
        }
        tapInstalled = true

        engine.prepare()
        do {
            try engine.start()
        } catch {
            removeTapIfNeeded()
            throw RecorderError.engineUnavailable
        }
    }

    private func removeTapIfNeeded() {
        guard tapInstalled else { return }
        engine.inputNode.removeTap(onBus: 0)
        tapInstalled = false
    }
}

/// Realtime sink for the recorder's tap. Rebuilds its converter from the live
/// buffer format, writes converted buffers, and emits throttled meters.
/// `@unchecked Sendable` because it is touched only from the serial audio tap
/// thread, with a lock guarding the pause flag.
private final class RecordingWriter: @unchecked Sendable {
    let targetFormat: AVAudioFormat

    private let file: AVAudioFile
    private let emitEvery: Int
    private let continuation: AsyncStream<RecordingMeter>.Continuation
    private let bufferSink: (@Sendable (AVAudioPCMBuffer) -> Void)?

    private let lock = NSLock()
    private var paused = false

    // Tap-thread only — no lock needed.
    private var converter: AVAudioConverter?
    private var writtenFrames: AVAudioFramePosition = 0

    private var accMin: Float = 0
    private var accMax: Float = 0
    private var accSumSquares: Float = 0
    private var accPeak: Float = 0
    private var accCount: Int = 0

    init(
        file: AVAudioFile,
        targetFormat: AVAudioFormat,
        emitEvery: Int,
        continuation: AsyncStream<RecordingMeter>.Continuation,
        bufferSink: (@Sendable (AVAudioPCMBuffer) -> Void)? = nil
    ) {
        self.file = file
        self.targetFormat = targetFormat
        self.emitEvery = emitEvery
        self.continuation = continuation
        self.bufferSink = bufferSink
    }

    var duration: TimeInterval {
        TimeInterval(writtenFrames) / targetFormat.sampleRate
    }

    func setPaused(_ value: Bool) {
        lock.lock()
        paused = value
        lock.unlock()
    }

    func append(_ inputBuffer: AVAudioPCMBuffer) {
        lock.lock()
        let isPaused = paused
        lock.unlock()
        guard !isPaused else { return }

        // Forward the raw buffer to live transcription (if any).
        bufferSink?(inputBuffer)

        // Rebuild the converter whenever the live buffer format changes.
        converter = RecorderConverterFactory.converter(
            for: inputBuffer.format,
            target: targetFormat,
            reusing: converter
        )
        guard let converter else { return }

        guard let output = convert(inputBuffer, using: converter) else { return }
        do {
            try file.write(from: output)
        } catch {
            return
        }
        writtenFrames += AVAudioFramePosition(output.frameLength)
        accumulate(output)
    }

    private func convert(
        _ inputBuffer: AVAudioPCMBuffer,
        using converter: AVAudioConverter
    ) -> AVAudioPCMBuffer? {
        let ratio = targetFormat.sampleRate / inputBuffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(inputBuffer.frameLength) * ratio) + 1
        guard let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
            return nil
        }
        // A local, not instance state: the pull block is non-escaping, so the
        // buffer never outlives this call and nothing is shared across
        // callbacks. No `[self]` capture on the realtime path either.
        var pending: AVAudioPCMBuffer? = inputBuffer
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

    private func accumulate(_ buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let frames = Int(buffer.frameLength)
        for i in 0..<frames {
            let sample = channel[i]
            if accCount == 0 {
                accMin = sample
                accMax = sample
            } else {
                accMin = Swift.min(accMin, sample)
                accMax = Swift.max(accMax, sample)
            }
            accSumSquares += sample * sample
            accPeak = Swift.max(accPeak, abs(sample))
            accCount += 1

            if accCount >= emitEvery {
                emit()
            }
        }
    }

    private func emit() {
        guard accCount > 0 else { return }
        let bucket = WaveformBucket(
            min: accMin,
            max: accMax,
            rms: (accSumSquares / Float(accCount)).squareRoot()
        )
        let meter = RecordingMeter(
            level: Swift.min(1, accPeak),
            bucket: bucket,
            elapsed: TimeInterval(writtenFrames) / targetFormat.sampleRate
        )
        continuation.yield(meter)
        accMin = 0
        accMax = 0
        accSumSquares = 0
        accPeak = 0
        accCount = 0
    }
}
