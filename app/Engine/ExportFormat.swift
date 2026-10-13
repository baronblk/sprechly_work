import AVFoundation

/// Audio export formats. MP3 is intentionally excluded — iOS 26 has no native
/// MP3 encoder (verified against the SDK, see docs/DECISIONS.md).
enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case m4a
    case wav

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .m4a: return "M4A (AAC)"
        case .wav: return "WAV"
        }
    }

    var fileExtension: String {
        switch self {
        case .m4a: return "m4a"
        case .wav: return "wav"
        }
    }

    /// Settings for `AVAudioFile(forWriting:settings:)`.
    func settings(
        sampleRate: Double = RecordingSettings.sampleRate,
        channels: AVAudioChannelCount = RecordingSettings.channelCount
    ) -> [String: Any] {
        switch self {
        case .m4a:
            return [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channels,
                AVEncoderBitRateKey: RecordingSettings.bitRate
            ]
        case .wav:
            return [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channels,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
        }
    }
}
