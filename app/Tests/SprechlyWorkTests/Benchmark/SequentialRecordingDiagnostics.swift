import AVFoundation
import Foundation
import Testing
@testable import VoxStudio

/// Pins down when a finished recording becomes readable.
///
/// `AudioRecorderEngine.stop()` returning does not guarantee a valid file: the
/// AAC container is completed when the writer's `AVAudioFile` is released,
/// which is not synchronous with `stop()`. Measured here as a bounded wait —
/// the audio is always on disk, only the container header lags. Reproduced on
/// the state before Phase 6, so it is pre-existing; documented in
/// docs/LIVE_AUDIO_PIPELINE.md rather than worked around in production code.
@Suite(.serialized)
struct SequentialRecordingDiagnostics {
    private func record(engine: AudioRecorderEngine, seconds: Double, label: String) async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("seq-\(UUID().uuidString).m4a")
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            _ = try await engine.start(to: url, bufferSink: nil)
            try await Task.sleep(for: .seconds(seconds))
            let duration = await engine.stop()
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
            // Audio is on disk immediately; only the container header may lag.
            #expect((size ?? 0) > 0, "\(label): nothing written")

            var waited: TimeInterval = 0
            var opened: AVAudioFile?
            while waited < 5, opened == nil {
                opened = try? AVAudioFile(forReading: url)
                if opened == nil {
                    try await Task.sleep(for: .milliseconds(100))
                    waited += 0.1
                }
            }
            if let opened {
                let fileSeconds = Double(opened.length) / opened.fileFormat.sampleRate
                print("SEQ \(label) readable-after=\(String(format: "%.1f", waited))s " +
                      "reported=\(duration) file=\(fileSeconds) bytes=\(size ?? 0)")
                #expect(abs(fileSeconds - duration) < 0.5, "\(label): length mismatch")
            } else {
                Issue.record("\(label): file never became readable within 5s")
            }
        } catch {
            Issue.record("\(label) start failed: \(error)")
        }
    }

    /// One engine, one session, two takes — what the app itself does.
    @Test func twoTakesWithOneEngineAndOneSession() async throws {
        #if targetEnvironment(simulator)
        print("SEQ SKIPPED: simulator")
        return
        #else
        let session = AudioSessionController()
        try session.activateForRecording()
        defer { session.deactivate() }
        let engine = AudioRecorderEngine()
        await record(engine: engine, seconds: 2, label: "same-engine-take1")
        await record(engine: engine, seconds: 2, label: "same-engine-take2")
        #endif
    }

    /// Fresh engine and a recycled session each time — what the failing test did.
    @Test func twoTakesWithFreshEnginesAndRecycledSessions() async throws {
        #if targetEnvironment(simulator)
        print("SEQ SKIPPED: simulator")
        return
        #else
        for index in 1...2 {
            let session = AudioSessionController()
            try session.activateForRecording()
            let engine = AudioRecorderEngine()
            await record(engine: engine, seconds: 2, label: "fresh-engine-take\(index)")
            session.deactivate()
        }
        #endif
    }

    /// A single short take in isolation — the control.
    @Test func oneShortTakeInIsolation() async throws {
        #if targetEnvironment(simulator)
        print("SEQ SKIPPED: simulator")
        return
        #else
        let session = AudioSessionController()
        try session.activateForRecording()
        defer { session.deactivate() }
        await record(engine: AudioRecorderEngine(), seconds: 2, label: "isolated")
        #endif
    }
}
