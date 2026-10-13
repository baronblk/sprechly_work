import AVFoundation

/// Central recording-format configuration. Default: mono 48 kHz AAC in `.m4a`.
/// Variable selection (rate/bitrate) is a later slice.
enum RecordingSettings {
    static let sampleRate: Double = 48_000
    static let channelCount: AVAudioChannelCount = 1
    static let bitRate: Int = 128_000
    static let fileExtension = "m4a"

    /// AAC encoder settings for `AVAudioFile(forWriting:settings:)`.
    static var encoderSettings: [String: Any] {
        [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channelCount,
            AVEncoderBitRateKey: bitRate
        ]
    }

    /// Lossless 16-bit PCM (CAF) for dictaphone overwrite/continuation runs:
    /// no AAC encoder priming/padding, so merged seams are gapless. Transcoded
    /// to m4a on final save.
    static var losslessSettings: [String: Any] {
        [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channelCount,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
    }

    /// Picks encoder settings from the target file extension (`caf` → PCM).
    static func settings(forFileExtension ext: String) -> [String: Any] {
        ext.lowercased() == "caf" ? losslessSettings : encoderSettings
    }
}
