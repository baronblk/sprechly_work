import Foundation

/// Pure trim-range clamping, independent of UI so it can be unit-tested.
enum TrimBounds {
    /// Minimum trim length (below this, a speech clip is a single phoneme and the
    /// render can hit degenerate zero/one-frame ranges).
    static let minimumLength: TimeInterval = 0.25

    /// Clamps `[start, end]` into `[0, duration]`, ordering them and enforcing the
    /// minimum length — itself clamped to `duration`, so a recording shorter than
    /// the minimum stays valid instead of producing an invalid range.
    static func clamp(start: TimeInterval, end: TimeInterval, duration: TimeInterval) -> ClosedRange<TimeInterval> {
        let dur = max(0, duration)
        let minLength = min(minimumLength, dur)
        var lower = min(max(0, start), dur)
        var upper = min(max(0, end), dur)
        if upper < lower { swap(&lower, &upper) }
        if upper - lower < minLength {
            upper = min(dur, lower + minLength)
            lower = max(0, upper - minLength)
        }
        return lower...upper
    }

    /// Whether the range effectively covers the whole source (no trim to apply).
    static func isFullRange(_ range: ClosedRange<TimeInterval>, duration: TimeInterval, epsilon: TimeInterval = 0.001) -> Bool {
        range.lowerBound <= epsilon && range.upperBound >= duration - epsilon
    }
}
