import AVFoundation
import Foundation
import Speech

/// One transcription engine under test.
///
/// Both implementations feed audio **identically** — same chunk size, same
/// conversion, same analyzer wiring as `SpeechTranscriptionService` — so the
/// only thing that differs between runs is the speech module itself. Using the
/// file-based initializer for one and manual feeding for the other would
/// confound the comparison.
protocol BenchmarkEngine: Sendable {
    var label: String { get }
    func transcribe(url: URL, locale: Locale) async throws -> String
}

/// Shared feeding path, mirroring `SpeechTranscriptionService.feed`.
enum BenchmarkFeeder {
    static let chunkFrames: AVAudioFrameCount = 16_384

    static func feed(
        file: AVAudioFile,
        to continuation: AsyncStream<AnalyzerInput>.Continuation,
        analysisFormat: AVAudioFormat?
    ) throws {
        let sourceFormat = file.processingFormat
        let target = analysisFormat ?? sourceFormat
        let converter = target != sourceFormat ? AVAudioConverter(from: sourceFormat, to: target) : nil

        while file.framePosition < file.length {
            guard let readBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: chunkFrames) else { break }
            try file.read(into: readBuffer)
            if readBuffer.frameLength == 0 { break }

            let buffer: AVAudioPCMBuffer
            if let converter, let converted = convert(readBuffer, using: converter, to: target) {
                buffer = converted
            } else {
                buffer = readBuffer
            }
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

/// A — what the app ships today.
struct CurrentSpeechTranscriber: BenchmarkEngine {
    let label = "SPEECH"

    func transcribe(url: URL, locale: Locale) async throws -> String {
        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        return try await Self.run(analyzer: analyzer, url: url, modules: [transcriber]) {
            var parts: [String] = []
            for try await result in transcriber.results {
                let text = String(result.text.characters)
                if !text.isEmpty { parts.append(text) }
            }
            return parts
        }
    }

    /// Drives the analyzer and collects results, identical for both engines.
    static func run(
        analyzer: SpeechAnalyzer,
        url: URL,
        modules: [any SpeechModule],
        collect: @escaping @Sendable () async throws -> [String]
    ) async throws -> String {
        let collecting = Task { try await collect() }
        let file = try AVAudioFile(forReading: url)
        let analysisFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: modules)
        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        try await analyzer.start(inputSequence: stream)
        try BenchmarkFeeder.feed(file: file, to: continuation, analysisFormat: analysisFormat)
        continuation.finish()
        try await analyzer.finalizeAndFinishThroughEndOfInput()
        return try await collecting.value.joined(separator: " ")
    }
}

/// B/C — the candidate. `contentHints` is empty for the neutral run.
struct CandidateDictationTranscriber: BenchmarkEngine {
    let label: String
    let preset: DictationTranscriber.Preset?
    let contentHints: Set<DictationTranscriber.ContentHint>

    init(
        label: String = "DICTATION",
        preset: DictationTranscriber.Preset? = .timeIndexedLongDictation,
        contentHints: Set<DictationTranscriber.ContentHint> = []
    ) {
        self.label = label
        self.preset = preset
        self.contentHints = contentHints
    }

    func transcribe(url: URL, locale: Locale) async throws -> String {
        let transcriber: DictationTranscriber
        if contentHints.isEmpty, let preset {
            transcriber = DictationTranscriber(locale: locale, preset: preset)
        } else {
            // Mirror the time-indexed long-form preset, plus the hint under test.
            transcriber = DictationTranscriber(
                locale: locale,
                contentHints: contentHints,
                transcriptionOptions: [],
                reportingOptions: [],
                attributeOptions: [.audioTimeRange]
            )
        }
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        return try await CurrentSpeechTranscriber.run(analyzer: analyzer, url: url, modules: [transcriber]) {
            var parts: [String] = []
            for try await result in transcriber.results {
                let text = String(result.text.characters)
                if !text.isEmpty { parts.append(text) }
            }
            return parts
        }
    }
}
