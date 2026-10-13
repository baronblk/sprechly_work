import AVFoundation
import Testing
@testable import VoxStudio

struct ExportFormatTests {
    @Test func mp3IsNotOffered() {
        #expect(!ExportFormat.allCases.contains { $0.fileExtension == "mp3" })
    }

    @Test func m4aUsesAAC() {
        #expect((ExportFormat.m4a.settings()[AVFormatIDKey] as? AudioFormatID) == kAudioFormatMPEG4AAC)
        #expect(ExportFormat.m4a.fileExtension == "m4a")
    }

    @Test func wavUsesLinearPCM() {
        #expect((ExportFormat.wav.settings()[AVFormatIDKey] as? AudioFormatID) == kAudioFormatLinearPCM)
        #expect(ExportFormat.wav.fileExtension == "wav")
    }
}
