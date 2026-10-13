import AVFoundation
import Testing
@testable import VoxStudio

struct AudioImportServiceTests {
    @Test func transcodesToRecordingFormat() async throws {
        let source = AudioTestSupport.tempURL("caf")
        try AudioTestSupport.writeSine(to: source, amplitude: 0.5, seconds: 1.0, sampleRate: 44_100)
        defer { try? FileManager.default.removeItem(at: source) }

        let output = AudioTestSupport.tempURL("caf")
        defer { try? FileManager.default.removeItem(at: output) }

        let duration = try await AudioImportService().importToRecordingFormat(source, to: output)

        let file = try AVAudioFile(forReading: output)
        #expect(file.processingFormat.sampleRate == RecordingSettings.sampleRate)
        #expect(file.processingFormat.channelCount == RecordingSettings.channelCount)
        #expect(abs(duration - 1.0) < 0.05)
        #expect(try AudioTestSupport.peak(of: output) > 0.1) // signal survives the resample
    }

    @Test func unreadableSourceThrows() async throws {
        let missing = AudioTestSupport.tempURL("m4a")
        let output = AudioTestSupport.tempURL("caf")
        await #expect(throws: (any Error).self) {
            try await AudioImportService().importToRecordingFormat(missing, to: output)
        }
    }
}
