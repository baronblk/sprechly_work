import AVFoundation
import Testing
@testable import SprechlyWork

struct AudioExportServiceTests {
    private let service = AudioExportService()

    @Test(arguments: ExportFormat.allCases)
    func exportProducesValidPlayableFile(_ format: ExportFormat) async throws {
        let working = AudioTestSupport.tempURL("caf")
        let output = AudioTestSupport.tempURL(format.fileExtension)
        defer { [working, output].forEach { try? FileManager.default.removeItem(at: $0) } }
        try AudioTestSupport.writeSine(to: working, amplitude: 0.5, seconds: 1)

        try await service.export(workingURL: working, format: format, to: output)

        let read = try AVAudioFile(forReading: output)
        #expect(read.length > 0)
        #expect(try AudioTestSupport.duration(of: output) > 0.9)
    }
}
