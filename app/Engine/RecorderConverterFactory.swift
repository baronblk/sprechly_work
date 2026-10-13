import AVFoundation

/// Builds the recording converter from the **live** buffer format, never a
/// cached one. Reuses the existing converter while the input format is
/// unchanged, and rebuilds the moment it changes (route change, BT connect, …).
/// The output format is always the constant target (48 kHz mono), so the open
/// `AVAudioFile` stays valid (A6 invariant).
enum RecorderConverterFactory {
    static func converter(
        for inputFormat: AVAudioFormat,
        target: AVAudioFormat,
        reusing existing: AVAudioConverter?
    ) -> AVAudioConverter? {
        if let existing, existing.inputFormat == inputFormat {
            return existing
        }
        guard let converter = AVAudioConverter(from: inputFormat, to: target),
              converter.outputFormat == target else {
            return nil
        }
        return converter
    }
}
