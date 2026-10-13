import AVFoundation
import Foundation

/// A `LoudnessNormalizer` that only **attenuates** — it scales the signal down to
/// the target when it would exceed it, but never boosts a quiet signal up. This
/// is the clipping protection for mixing: sum two tracks in float, then limit the
/// summed peak to the target instead of hard-clipping (see docs/DECISIONS.md).
struct PeakLimiter: LoudnessNormalizer {
    func gain(forSignalAt url: URL, targetDBFS: Double) throws -> Float {
        let peak = try AudioSignalStats.peak(forSignalAt: url)
        guard peak > 0 else { return 1.0 }
        let target = Float(pow(10.0, targetDBFS / 20.0))
        return min(1.0, target / peak)
    }
}
