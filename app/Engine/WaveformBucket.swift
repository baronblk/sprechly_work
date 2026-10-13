import Foundation

/// One renderable column of a waveform: the min/max envelope and RMS energy of
/// the samples it summarizes. `Codable` so it can be cached as a sidecar file.
struct WaveformBucket: Sendable, Equatable, Codable {
    var min: Float
    var max: Float
    var rms: Float

    static let silent = WaveformBucket(min: 0, max: 0, rms: 0)
}
