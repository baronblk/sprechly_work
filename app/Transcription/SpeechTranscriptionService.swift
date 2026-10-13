import AVFoundation
import Foundation
import Speech

/// Real implementation backed by the Speech framework (`SpeechTranscriber` +
/// `AssetInventory`). Stateless, so a value type. The actual asset download and
/// transcription run **only on a real device** — this is the first device-only
/// surface of Phase 3 (verified via docs/DEVICE_TESTS.md "3a").
struct SpeechTranscriptionService: TranscriptionProviding {
    func assetState(for locale: Locale) async -> TranscriptionAssetState {
        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
        let status = await AssetInventory.status(forModules: [transcriber])
        return TranscriptionAssetState.from(status)
    }

    func supportedLocales() async -> [Locale] {
        await SpeechTranscriber.supportedLocales
    }

    func installedLocales() async -> [Locale] {
        await SpeechTranscriber.installedLocales
    }

    func installAssets(for locale: Locale) -> AsyncStream<TranscriptionAssetState> {
        AsyncStream { continuation in
            let task = Task {
                do {
                    _ = try await AssetInventory.reserve(locale: locale)
                    let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
                    guard let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) else {
                        continuation.yield(.installed) // already installed / nothing to fetch
                        continuation.finish()
                        return
                    }

                    continuation.yield(.downloading(progress: 0))
                    let poller = Task {
                        while !Task.isCancelled {
                            continuation.yield(.downloading(progress: request.progress.fractionCompleted))
                            try? await Task.sleep(for: .milliseconds(250))
                        }
                    }

                    try await request.downloadAndInstall()
                    poller.cancel()
                    continuation.yield(.installed)
                    continuation.finish()
                } catch {
                    continuation.yield(Self.mapError(error))
                    continuation.finish()
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func transcribe(fileAt url: URL, locale: Locale) -> AsyncThrowingStream<TranscriptDraft, Error> {
        transcribe(fileAt: url, locale: locale, contextualStrings: [])
    }

    /// Same run with optional contextual strings handed to the analyzer, used by
    /// the transcription benchmark to A/B `AnalysisContext` against the very
    /// pipeline the app ships. An empty list builds **no** context at all, so
    /// the production path above is byte-for-byte the previous behaviour.
    func transcribe(
        fileAt url: URL,
        locale: Locale,
        contextualStrings: [String]
    ) -> AsyncThrowingStream<TranscriptDraft, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
                    let analyzer: SpeechAnalyzer
                    if contextualStrings.isEmpty {
                        analyzer = SpeechAnalyzer(modules: [transcriber])
                    } else {
                        let context = AnalysisContext()
                        context.contextualStrings[.general] = contextualStrings
                        analyzer = SpeechAnalyzer(modules: [transcriber])
                        try await analyzer.setContext(context)
                    }

                    // Presentation repair happens here and nowhere else: this
                    // is the single point every transcript passes through, so
                    // view, persistence and export all receive the same text
                    // and the formatter runs exactly once per segment.
                    let formatter = TranscriptSemanticFormatter(locale: locale)

                    let resultsTask = Task {
                        for try await result in transcriber.results {
                            let raw = String(result.text.characters)
                            guard !raw.isEmpty else { continue }
                            // Only finalized text is formatted. A volatile
                            // result is a half-finished sentence, where a
                            // clock-time or version rule would be guessing.
                            let text = result.isFinal ? formatter.format(raw) : raw
                            continuation.yield(TranscriptDraft(
                                text: text,
                                startTime: result.range.start.seconds,
                                endTime: result.range.end.seconds
                            ))
                        }
                    }

                    let file = try AVAudioFile(forReading: url)
                    let analysisFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
                    let (inputStream, inputContinuation) = AsyncStream<AnalyzerInput>.makeStream()
                    try await analyzer.start(inputSequence: inputStream)
                    try Self.feed(file: file, to: inputContinuation, analysisFormat: analysisFormat)
                    inputContinuation.finish()
                    try await analyzer.finalizeAndFinishThroughEndOfInput()
                    try await resultsTask.value
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Streams the file's audio (converted to the analyzer's format) as timed input.
    private static func feed(
        file: AVAudioFile,
        to continuation: AsyncStream<AnalyzerInput>.Continuation,
        analysisFormat: AVAudioFormat?
    ) throws {
        let sourceFormat = file.processingFormat
        let target = analysisFormat ?? sourceFormat
        let converter = target != sourceFormat ? AVAudioConverter(from: sourceFormat, to: target) : nil
        let chunk: AVAudioFrameCount = 16384

        while file.framePosition < file.length {
            guard let readBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: chunk) else { break }
            try file.read(into: readBuffer)
            if readBuffer.frameLength == 0 { break }

            let buffer: AVAudioPCMBuffer
            if let converter, let converted = convert(readBuffer, using: converter, to: target) {
                buffer = converted
            } else {
                buffer = readBuffer
            }
            // No explicit start time: the analyzer derives timing from the
            // contiguous buffer stream (explicit per-chunk times overlapped).
            continuation.yield(AnalyzerInput(buffer: buffer))
        }
    }

    private static func convert(
        _ input: AVAudioPCMBuffer,
        using converter: AVAudioConverter,
        to target: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let ratio = target.sampleRate / input.format.sampleRate
        let capacity = AVAudioFrameCount(Double(input.frameLength) * ratio) + 1
        guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return nil }
        // The pull block is declared NS_SWIFT_NONSENDABLE and NS_NOESCAPE, so a
        // local holds the buffer and hands it over exactly once — no box, no
        // @unchecked Sendable.
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

    private static func mapError(_ error: Error) -> TranscriptionAssetState {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileWriteOutOfSpaceError {
            return .insufficientStorage
        }
        if nsError.domain == NSPOSIXErrorDomain, nsError.code == Int(ENOSPC) {
            return .insufficientStorage
        }
        return .failed(message: error.localizedDescription)
    }
}
