import AVFoundation
import Foundation
import Testing
@testable import VoxStudio

/// Measures how long the playback engine takes to open an imported long file,
/// to turn the reported "~30 s before playable" into a hard number.
@MainActor
struct LoadTimingTests {
    @Test func importedLongFileOpensQuickly() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("voxtiming-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        // Podcast-like source: 45 s at 44.1 kHz (import must resample to 48 kHz).
        let source = root.appendingPathComponent("podcast.caf")
        try AudioTestSupport.writeSine(to: source, amplitude: 0.4, seconds: 45, sampleRate: 44_100)

        let workCAF = root.appendingPathComponent("work.caf")
        let imported = root.appendingPathComponent("imported.m4a")
        _ = try await AudioImportService().importToRecordingFormat(source, to: workCAF)
        try await AudioExportService().export(workingURL: workCAF, format: .m4a, to: imported)

        let engine = AudioPlaybackEngine()
        let start = Date()
        _ = try await engine.load(url: imported)
        let elapsed = Date().timeIntervalSince(start)
        let dur = await engine.duration
        print("LOAD-TIMING imported(\(String(format: "%.1f", dur))s) load=\(String(format: "%.3f", elapsed))s")

        #expect(dur > 40)
        // Generous bound: a healthy import opens in well under a second; this only
        // trips if the export ever produces a pathologically slow-to-open file.
        #expect(elapsed < 10.0)
    }
}
