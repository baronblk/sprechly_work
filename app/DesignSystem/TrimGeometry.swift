import CoreGraphics
import Foundation

/// Pure time ↔ x mapping for trim handles, so handle math is unit-testable
/// without driving the UI.
enum TrimGeometry {
    static func time(forX x: CGFloat, width: CGFloat, duration: TimeInterval) -> TimeInterval {
        guard width > 0 else { return 0 }
        let fraction = min(1, max(0, x / width))
        return TimeInterval(fraction) * duration
    }

    static func x(forTime time: TimeInterval, width: CGFloat, duration: TimeInterval) -> CGFloat {
        guard duration > 0 else { return 0 }
        let fraction = min(1, max(0, time / duration))
        return CGFloat(fraction) * width
    }
}
