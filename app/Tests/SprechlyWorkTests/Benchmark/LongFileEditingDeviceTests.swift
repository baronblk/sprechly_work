import AVFoundation
import Foundation
import Testing
@testable import SprechlyWork

/// Release gate 2a: editor, merge, mix and export against a file of half an
/// hour or more, on real hardware.
///
/// The obligation in docs/DEVICE_TESTS.md is that the offline pipeline holds up
/// on a long file — progress smooth, memory flat, result playable. That is
/// about the renderers, not about the UI, so it is checked here rather than by
/// tapping through the app.
///
/// Opt-in via `LONG_FILE_MINUTES` (same reason as the recording suite: it costs
/// its own runtime). Device only.
@Suite(.serialized)
struct LongFileEditingDeviceTests {
    private var minutes: Double? {
        let environment = ProcessInfo.processInfo.environment
        let raw = environment["LONG_FILE_MINUTES"]
            ?? environment["TEST_RUNNER_LONG_FILE_MINUTES"]
        return raw.flatMap(Double.init)
    }

    /// Writes a tone of `seconds` at the app's own recording format.
    ///
    /// A tone rather than silence: a normalizer or limiter can shortcut on
    /// zeroes, which would make the render cheaper than the real thing.
    private func makeSource(seconds: Double, at url: URL) throws -> TimeInterval {
        let settings = RecordingSettings.settings(forFileExtension: url.pathExtension)
        let file = try AVAudioFile(forWriting: url, settings: settings)
        let format = file.processingFormat
        let chunkFrames: AVAudioFrameCount = 48_000
        var written: AVAudioFramePosition = 0
        let total = AVAudioFramePosition(seconds * format.sampleRate)
        var phase = 0.0
        let increment = 2.0 * Double.pi * 440.0 / format.sampleRate

        while written < total {
            let frames = AVAudioFrameCount(Swift.min(AVAudioFramePosition(chunkFrames), total - written))
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { break }
            buffer.frameLength = frames
            guard let channel = buffer.floatChannelData?[0] else { break }
            for index in 0..<Int(frames) {
                channel[index] = Float(sin(phase)) * 0.3
                phase += increment
            }
            try file.write(from: buffer)
            written += AVAudioFramePosition(frames)
        }
        return Double(written) / format.sampleRate
    }

    private func duration(of url: URL) throws -> TimeInterval {
        let file = try AVAudioFile(forReading: url)
        return Double(file.length) / file.fileFormat.sampleRate
    }

    /// Peak level, so a render that produced silence cannot pass as success.
    private func peak(of url: URL) throws -> Float {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        var highest: Float = 0
        while file.framePosition < file.length {
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48_000) else { break }
            try file.read(into: buffer)
            if buffer.frameLength == 0 { break }
            guard let channel = buffer.floatChannelData?[0] else { break }
            for index in 0..<Int(buffer.frameLength) {
                highest = Swift.max(highest, abs(channel[index]))
            }
        }
        return highest
    }

    @Test func editorMergeMixAndExportHandleALongFile() async throws {
        #if targetEnvironment(simulator)
        print("LONGEDIT SKIPPED: simulator")
        return
        #else
        guard let minutes else {
            print("LONGEDIT SKIPPED: set LONG_FILE_MINUTES to run")
            return
        }
        let seconds = minutes * 60

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("longedit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let source = directory.appendingPathComponent("source.m4a")
        var start = Date()
        let sourceSeconds = try makeSource(seconds: seconds, at: source)
        print("LONGEDIT source \(fmt(sourceSeconds))s written in \(fmt(Date().timeIntervalSince(start)))s " +
              "bytes=\(size(of: source))")
        #expect(sourceSeconds >= seconds - 1)

        // 1 — Editor: trim plus a speed change, the expensive combination
        // (time-stretch then normalize over the whole file).
        let edited = directory.appendingPathComponent("edited.caf")
        let (progressStream, progress) = AsyncStream<Double>.makeStream()
        let watcher = Task { () -> (count: Int, last: Double, monotonic: Bool) in
            var count = 0
            var last = 0.0
            var monotonic = true
            for await value in progressStream {
                if value < last - 0.0001 { monotonic = false }
                last = value
                count += 1
            }
            return (count, last, monotonic)
        }
        start = Date()
        let editedSeconds = try await AudioEditingService().render(
            source: source,
            settings: EditSettings(trim: 60...(seconds - 60), speed: 1.25, normalize: true),
            to: edited,
            progress: progress
        )
        progress.finish()
        let editElapsed = Date().timeIntervalSince(start)
        let stats = await watcher.value
        let expectedEdited = (seconds - 120) / 1.25
        print("LONGEDIT edit out=\(fmt(editedSeconds))s expected=\(fmt(expectedEdited))s " +
              "took=\(fmt(editElapsed))s progress=\(stats.count) last=\(fmt(stats.last)) " +
              "monotonic=\(stats.monotonic) peak=\(try peak(of: edited))")
        #expect(abs(editedSeconds - expectedEdited) < 1.0, "edited duration off")
        #expect(abs(try duration(of: edited) - editedSeconds) < 0.5, "edited file length off")
        #expect(stats.count > 1, "no progress reported")
        #expect(stats.monotonic, "progress went backwards")
        #expect(try peak(of: edited) > 0.1, "edited render is silent")

        // 2 — Merge: duration must be the sum.
        let merged = directory.appendingPathComponent("merged.caf")
        start = Date()
        let mergedSeconds = try await AudioMergeService().merge(sources: [source, edited], to: merged)
        print("LONGEDIT merge out=\(fmt(mergedSeconds))s " +
              "expected=\(fmt(sourceSeconds + editedSeconds))s took=\(fmt(Date().timeIntervalSince(start)))s")
        #expect(abs(mergedSeconds - (sourceSeconds + editedSeconds)) < 1.0, "merge duration not the sum")
        #expect(abs(try duration(of: merged) - mergedSeconds) < 0.5)
        #expect(try peak(of: merged) > 0.1)

        // 3 — Mix: truncated to the main track.
        let mixed = directory.appendingPathComponent("mixed.caf")
        start = Date()
        let mixedSeconds = try await AudioMixService().mix(
            main: source, mix: edited, settings: MixSettings(), to: mixed
        )
        print("LONGEDIT mix out=\(fmt(mixedSeconds))s main=\(fmt(sourceSeconds))s " +
              "took=\(fmt(Date().timeIntervalSince(start)))s")
        #expect(abs(mixedSeconds - sourceSeconds) < 1.0, "mix not truncated to main")
        #expect(try peak(of: mixed) > 0.1)

        // 4 — Export every shipped format, from the long merged working file.
        for format in ExportFormat.allCases {
            let output = directory.appendingPathComponent("export.\(format.fileExtension)")
            start = Date()
            try await AudioExportService().export(workingURL: merged, format: format, to: output)
            let exported = try duration(of: output)
            print("LONGEDIT export \(format.rawValue) \(fmt(exported))s " +
                  "took=\(fmt(Date().timeIntervalSince(start)))s bytes=\(size(of: output))")
            #expect(abs(exported - mergedSeconds) < 1.0, "\(format.rawValue) duration off")
            #expect(try peak(of: output) > 0.1, "\(format.rawValue) export is silent")
        }
        #endif
    }

    private func fmt(_ value: Double) -> String { String(format: "%.3f", value) }

    private func size(of url: URL) -> Int {
        ((try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? Int) ?? 0
    }
}
