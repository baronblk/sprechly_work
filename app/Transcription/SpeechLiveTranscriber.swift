import AVFoundation
import Foundation
import Speech

/// Real live transcription via `SpeechAnalyzer` with a progressive, time-indexed
/// transcriber (volatile results). Device-only; verified via DEVICE_TESTS "3c".
struct SpeechLiveTranscriber: LiveTranscribing {
    func start(locale: Locale) async throws -> any LiveTranscriptionHandle {
        let transcriber = SpeechTranscriber(locale: locale, preset: .timeIndexedProgressiveTranscription)
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let handle = SpeechLiveHandle(analyzer: analyzer, transcriber: transcriber, locale: locale)
        try await handle.beginConsuming()
        return handle
    }
}

/// `@unchecked Sendable`: `feed` runs on the recorder's audio thread; shared
/// state (converter, collected segments) is guarded by a lock.
private final class SpeechLiveHandle: LiveTranscriptionHandle, @unchecked Sendable {
    let updates: AsyncStream<LiveTranscriptUpdate>

    private let analyzer: SpeechAnalyzer
    private let transcriber: SpeechTranscriber
    /// Full repair, for finalized phrases only.
    private let formatter: TranscriptSemanticFormatter
    /// Markup removal alone, safe to apply to a sentence in progress.
    private let markupOnly: TranscriptSemanticFormatter
    private let inputStream: AsyncStream<AnalyzerInput>
    private let inputContinuation: AsyncStream<AnalyzerInput>.Continuation
    private let updatesContinuation: AsyncStream<LiveTranscriptUpdate>.Continuation

    private let lock = NSLock()
    private var converter: AVAudioConverter?
    private var analyzerFormat: AVAudioFormat?
    private var segments: [Double: (end: Double, text: String)] = [:]
    private var resultsTask: Task<Void, Never>?

    init(analyzer: SpeechAnalyzer, transcriber: SpeechTranscriber, locale: Locale) {
        self.analyzer = analyzer
        self.transcriber = transcriber
        self.formatter = TranscriptSemanticFormatter(locale: locale)
        self.markupOnly = TranscriptSemanticFormatter(locale: locale, rules: .spelledLetterMarkup)
        (inputStream, inputContinuation) = AsyncStream<AnalyzerInput>.makeStream()
        (updates, updatesContinuation) = AsyncStream<LiveTranscriptUpdate>.makeStream()
    }

    func beginConsuming() async throws {
        analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        resultsTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await result in transcriber.results {
                    self.absorb(result)
                }
            } catch {
                // Stream ended/failed; updates already finished on finish().
            }
        }
        try await analyzer.start(inputSequence: inputStream)
    }

    func feed(_ buffer: AVAudioPCMBuffer) {
        let input: AVAudioPCMBuffer
        if let analyzerFormat, analyzerFormat != buffer.format {
            lock.lock()
            if converter == nil || converter?.inputFormat != buffer.format {
                converter = AVAudioConverter(from: buffer.format, to: analyzerFormat)
            }
            let activeConverter = converter
            lock.unlock()
            guard let activeConverter, let converted = convert(buffer, using: activeConverter, to: analyzerFormat) else { return }
            input = converted
        } else {
            input = buffer
        }
        inputContinuation.yield(AnalyzerInput(buffer: input))
    }

    func finish() async -> [TranscriptDraft] {
        inputContinuation.finish()
        try? await analyzer.finalizeAndFinishThroughEndOfInput()
        resultsTask?.cancel()
        updatesContinuation.finish()
        return snapshotDrafts()
    }

    private func snapshotDrafts() -> [TranscriptDraft] {
        lock.lock(); defer { lock.unlock() }
        return drafts()
    }

    private func absorb(_ result: SpeechTranscriber.Result) {
        let start = result.range.start.seconds
        let raw = String(result.text.characters)
        // A volatile result is a sentence in progress. The semantic rules must
        // not touch it: guessing at a half-spoken time or version would mean
        // visibly correcting the guess as more words arrive.
        //
        // Markup removal is the exception, and deliberately so. It is a bug
        // fix, not a heuristic — it guesses nothing and is exactly as safe on
        // a partial phrase as on a finished one. Without it the live line
        // shows the user "die K\letter I\letter" while they speak, which is
        // the very defect this release set out to remove. Verified on device:
        // see TranscriptionIntegrationDeviceTests.liveSessionFormatsOnlyFinalizedText.
        let text = result.isFinal ? formatter.format(raw) : markupOnly.format(raw)
        lock.lock()
        // Keyed by start time: a volatile phrase updates in place; a new phrase
        // is a new key. The latest (highest start) is the running volatile line.
        segments[start] = (result.range.end.seconds, text)
        let volatile = segments.keys.max().flatMap { segments[$0]?.text } ?? text
        let snapshot = drafts()
        lock.unlock()
        updatesContinuation.yield(LiveTranscriptUpdate(volatileText: volatile, finalized: snapshot))
    }

    /// Caller holds `lock`.
    private func drafts() -> [TranscriptDraft] {
        segments.keys.sorted().compactMap { start in
            segments[start].map { TranscriptDraft(text: $0.text, startTime: start, endTime: $0.end) }
        }
    }

    private func convert(_ input: AVAudioPCMBuffer, using converter: AVAudioConverter, to target: AVAudioFormat) -> AVAudioPCMBuffer? {
        let ratio = target.sampleRate / input.format.sampleRate
        let capacity = AVAudioFrameCount(Double(input.frameLength) * ratio) + 1
        guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return nil }
        // Runs on the recorder's audio thread. The pull block is non-Sendable
        // and non-escaping, so a local suffices — which also spares this path
        // one heap allocation per captured buffer.
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
}
