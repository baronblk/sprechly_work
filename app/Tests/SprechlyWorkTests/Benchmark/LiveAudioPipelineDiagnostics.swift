import AVFoundation
import Foundation
import Speech
import Testing
@testable import SprechlyWork

/// Measures the live audio path's actual formats and conversion count.
///
/// Phase 1 noted that a live buffer is converted twice. Whether that can be
/// reduced to once depends entirely on whether the two consumers want the same
/// format, which is a device fact rather than a design choice — so it gets
/// measured before anything is changed.
///
/// Device only: the input node's format and the analyzer's preferred format do
/// not exist in the simulator.
@Suite(.serialized)
struct LiveAudioPipelineDiagnostics {
    private func describe(_ format: AVAudioFormat) -> String {
        "\(Int(format.sampleRate))Hz ch=\(format.channelCount) " +
        "fmt=\(format.commonFormat.rawValue) interleaved=\(format.isInterleaved)"
    }

    @Test func reportsTheThreeFormatsOfTheLivePath() async throws {
        #if targetEnvironment(simulator)
        print("PIPELINE SKIPPED: simulator")
        return
        #else
        // 1 — capture format: what the tap delivers (installTap(format: nil)).
        let engine = AVAudioEngine()
        let capture = engine.inputNode.outputFormat(forBus: 0)
        print("PIPELINE capture  \(describe(capture))")

        // 2 — writer target: the file's processing format.
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pipeline-\(UUID().uuidString).m4a")
        defer { try? FileManager.default.removeItem(at: url) }
        let file = try AVAudioFile(forWriting: url, settings: RecordingSettings.encoderSettings)
        let writerTarget = file.processingFormat
        print("PIPELINE writer   \(describe(writerTarget))")

        // 3 — what SpeechAnalyzer actually wants.
        let transcriber = SpeechTranscriber(
            locale: Locale(identifier: "de-DE"),
            preset: .timeIndexedProgressiveTranscription
        )
        let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        if let analyzerFormat {
            print("PIPELINE analyzer \(describe(analyzerFormat))")
        } else {
            print("PIPELINE analyzer nil")
        }

        // The decisive question for this phase.
        if let analyzerFormat {
            let shareable = analyzerFormat == writerTarget
            print("PIPELINE SHAREABLE writer-target-equals-analyzer-format=\(shareable)")
            print("PIPELINE capture-equals-writer-target=\(capture == writerTarget)")
            print("PIPELINE capture-equals-analyzer-format=\(capture == analyzerFormat)")
            // Also report the full list, in case a compatible format matches.
            let available = await transcriber.availableCompatibleAudioFormats
            for candidate in available {
                print("PIPELINE analyzer-candidate \(describe(candidate)) " +
                      "equals-writer-target=\(candidate == writerTarget)")
            }
        }
        #expect(Bool(true))
        #endif
    }
}
