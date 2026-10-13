import AVFoundation
import Foundation
import Testing
@testable import SprechlyWork

/// Records from the real microphone for a configurable span and checks the
/// result for the failure modes a long session actually has: drift between
/// wall-clock and recorded time, lost frames, a gap in the meter stream, and a
/// buffer sink that stops being fed.
///
/// Opt-in, because it costs its own runtime: set `LONG_RECORDING_SECONDS`.
/// Device only — there is no microphone in the simulator.
@Suite(.serialized)
struct LongRecordingDeviceTests {
    /// Reads the knob under either name.
    ///
    /// `xcodebuild test` does not forward the invoking shell's environment to
    /// the test runner; only variables prefixed `TEST_RUNNER_` are passed
    /// through. Accepting both means the same command works whether the test
    /// runs on device through xcodebuild or directly in Xcode.
    private var requestedSeconds: Double? {
        let environment = ProcessInfo.processInfo.environment
        let raw = environment["LONG_RECORDING_SECONDS"]
            ?? environment["TEST_RUNNER_LONG_RECORDING_SECONDS"]
        return raw.flatMap(Double.init)
    }

    @Test func longRecordingStaysCorrect() async throws {
        #if targetEnvironment(simulator)
        print("LONGREC SKIPPED: simulator")
        return
        #else
        guard let seconds = requestedSeconds else {
            print("LONGREC SKIPPED: set LONG_RECORDING_SECONDS to run")
            return
        }

        let session = AudioSessionController()
        try session.activateForRecording()
        defer { session.deactivate() }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("longrec-\(UUID().uuidString).m4a")
        defer { try? FileManager.default.removeItem(at: url) }

        // Counts every buffer handed to live transcription, and their frames —
        // the live path's input integrity over the whole session.
        let sink = SinkCounter()
        let engine = AudioRecorderEngine()

        let wallStart = Date()
        let meters = try await engine.start(to: url, bufferSink: { buffer in
            sink.record(frames: Int(buffer.frameLength), format: buffer.format)
        })

        // Observe the meter stream for gaps while the recording runs.
        let watcher = Task { () -> MeterStats in
            var stats = MeterStats()
            var previous: Date?
            for await meter in meters {
                let now = Date()
                if let previous { stats.maxGap = Swift.max(stats.maxGap, now.timeIntervalSince(previous)) }
                previous = now
                stats.count += 1
                stats.lastElapsed = meter.elapsed
            }
            return stats
        }

        try await Task.sleep(for: .seconds(seconds))
        let reportedDuration = await engine.stop()
        let wallElapsed = Date().timeIntervalSince(wallStart)
        let stats = await watcher.value

        // File integrity.
        let file = try await openWhenReadable(url, label: "long")
        let fileFrames = file.length
        let fileSeconds = Double(fileFrames) / file.fileFormat.sampleRate
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0

        let sinkSnapshot = sink.snapshot()
        let sinkSeconds = Double(sinkSnapshot.frames) / RecordingSettings.sampleRate
        let drift = fileSeconds - reportedDuration

        print("LONGREC requested=\(fmt(seconds))s wall=\(fmt(wallElapsed))s " +
              "reported=\(fmt(reportedDuration))s file=\(fmt(fileSeconds))s " +
              "drift=\(fmt(drift))s bytes=\(size ?? 0)")
        print("LONGREC sink buffers=\(sinkSnapshot.buffers) frames=\(sinkSnapshot.frames) " +
              "seconds=\(fmt(sinkSeconds)) formats=\(sinkSnapshot.formats)")
        print("LONGREC meters count=\(stats.count) maxGap=\(fmt(stats.maxGap))s " +
              "lastElapsed=\(fmt(stats.lastElapsed))s")

        // The file holds what the engine says it holds. AAC priming makes an
        // exact match impossible, so the tolerance is a fraction of a second,
        // not a fraction of the duration — drift would grow with length.
        #expect(abs(drift) < 0.5, "recorded length drifted from reported duration")
        // No whole-second hole in capture: recorded time tracks wall clock.
        #expect(reportedDuration > seconds - 1.5)
        #expect(file.fileFormat.sampleRate == RecordingSettings.sampleRate)
        #expect(file.fileFormat.channelCount == RecordingSettings.channelCount)
        #expect((size ?? 0) > 0)

        // The live sink saw the same audio the file did.
        #expect(sinkSnapshot.buffers > 0)
        #expect(abs(sinkSeconds - reportedDuration) < 0.5, "buffer sink lost frames")
        // One capture format throughout, so no silent route change mid-test.
        #expect(sinkSnapshot.formats == 1)

        // Meters arrive ~30x/second with no long gap.
        #expect(stats.count > Int(seconds * 20))
        #expect(stats.maxGap < 1.0, "gap in the meter stream")
        #endif
    }

    /// Cancellation: stopping early must leave a complete, readable file.
    @Test func stoppingEarlyLeavesAValidFile() async throws {
        #if targetEnvironment(simulator)
        print("LONGREC CANCEL SKIPPED: simulator")
        return
        #else
        guard requestedSeconds != nil else {
            print("LONGREC CANCEL SKIPPED: set LONG_RECORDING_SECONDS to run")
            return
        }
        let session = AudioSessionController()
        try session.activateForRecording()
        defer { session.deactivate() }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cancel-\(UUID().uuidString).m4a")
        defer { try? FileManager.default.removeItem(at: url) }

        let engine = AudioRecorderEngine()
        _ = try await engine.start(to: url, bufferSink: nil)
        try await Task.sleep(for: .seconds(2))
        let duration = await engine.stop()

        let file = try await openWhenReadable(url, label: "cancel")
        let fileSeconds = Double(file.length) / file.fileFormat.sampleRate
        print("LONGREC CANCEL reported=\(fmt(duration))s file=\(fmt(fileSeconds))s")
        #expect(duration > 1.0)
        #expect(abs(fileSeconds - duration) < 0.5)
        #endif
    }

    /// Opens the recording once the AAC container is finalized.
    ///
    /// `stop()` returning does **not** guarantee a readable file: the container
    /// is completed when the writer's `AVAudioFile` is actually released, which
    /// is not synchronous with `stop()`. Measured on device and reproduced on
    /// the state before this phase, so it is a pre-existing property of the
    /// engine, not of this change — see docs/LIVE_AUDIO_PIPELINE.md. The bounded
    /// wait reflects that instead of hiding it, and reports how long it took.
    private func openWhenReadable(
        _ url: URL,
        timeout: TimeInterval = 5,
        label: String
    ) async throws -> AVAudioFile {
        let deadline = Date().addingTimeInterval(timeout)
        var lastError: Error?
        var waited: TimeInterval = 0
        while Date() < deadline {
            do {
                let file = try AVAudioFile(forReading: url)
                print("LONGREC \(label) readable after \(fmt(waited))s")
                return file
            } catch {
                lastError = error
                try await Task.sleep(for: .milliseconds(100))
                waited += 0.1
            }
        }
        throw try #require(lastError, "file never became readable")
    }

    private func fmt(_ value: Double) -> String { String(format: "%.3f", value) }

    private struct MeterStats {
        var count = 0
        var maxGap: TimeInterval = 0
        var lastElapsed: TimeInterval = 0
    }

    /// Counts buffers from the audio thread. A lock, not an actor: the sink is
    /// called on the realtime path and must not hop.
    private final class SinkCounter: @unchecked Sendable {
        struct Snapshot { let buffers: Int; let frames: Int; let formats: Int }

        private let lock = NSLock()
        private var buffers = 0
        private var frames = 0
        private var seenFormats: Set<String> = []

        func record(frames count: Int, format: AVAudioFormat) {
            let key = "\(format.sampleRate)-\(format.channelCount)-\(format.commonFormat.rawValue)"
            lock.lock()
            buffers += 1
            frames += count
            seenFormats.insert(key)
            lock.unlock()
        }

        func snapshot() -> Snapshot {
            lock.lock(); defer { lock.unlock() }
            return Snapshot(buffers: buffers, frames: frames, formats: seenFormats.count)
        }
    }
}
