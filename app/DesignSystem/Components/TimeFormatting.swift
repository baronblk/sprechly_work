import Foundation

enum TimeFormatting {
    /// Formats a duration as `mm:ss.SS` (hundredths).
    static func timecode(_ time: TimeInterval) -> String {
        let total = Swift.max(0, time)
        let minutes = Int(total) / 60
        let seconds = Int(total) % 60
        let hundredths = Int((total - total.rounded(.down)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, hundredths)
    }

    /// Compact `mm:ss` for list rows.
    static func shortTimecode(_ time: TimeInterval) -> String {
        let total = Swift.max(0, time)
        return String(format: "%02d:%02d", Int(total) / 60, Int(total) % 60)
    }
}
