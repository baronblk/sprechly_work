import Foundation
import Testing
@testable import SprechlyWork

struct TrimBoundsTests {
    @Test func enforcesMinimumLength() {
        let range = TrimBounds.clamp(start: 1.0, end: 1.1, duration: 10)
        #expect(abs((range.upperBound - range.lowerBound) - TrimBounds.minimumLength) < 0.0001)
    }

    @Test func clampsToZeroAndDuration() {
        let range = TrimBounds.clamp(start: -5, end: 20, duration: 10)
        #expect(range == 0...10)
    }

    @Test func ordersSwappedBounds() {
        let range = TrimBounds.clamp(start: 8, end: 2, duration: 10)
        #expect(range == 2...8)
    }

    @Test func shortSourceStaysValid() {
        // A recording shorter than the minimum must not produce an invalid range.
        let range = TrimBounds.clamp(start: 0, end: 0.1, duration: 0.1)
        #expect(range.lowerBound >= 0)
        #expect(range.upperBound <= 0.1 + 0.0001)
        #expect(range.lowerBound <= range.upperBound)
    }

    @Test func detectsFullRange() {
        #expect(TrimBounds.isFullRange(0...10, duration: 10))
        #expect(!TrimBounds.isFullRange(1...9, duration: 10))
    }
}
