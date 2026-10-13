import CoreGraphics
import Testing
@testable import SprechlyWork

struct TrimGeometryTests {
    @Test func timeAndXRoundTrip() {
        #expect(TrimGeometry.x(forTime: 5, width: 100, duration: 10) == 50)
        #expect(TrimGeometry.time(forX: 50, width: 100, duration: 10) == 5)
    }

    @Test func clampsOutOfBounds() {
        #expect(TrimGeometry.time(forX: -10, width: 100, duration: 10) == 0)
        #expect(TrimGeometry.time(forX: 200, width: 100, duration: 10) == 10)
        #expect(TrimGeometry.x(forTime: -1, width: 100, duration: 10) == 0)
        #expect(TrimGeometry.x(forTime: 99, width: 100, duration: 10) == 100)
    }

    @Test func degenerateInputsAreSafe() {
        #expect(TrimGeometry.time(forX: 50, width: 0, duration: 10) == 0)
        #expect(TrimGeometry.x(forTime: 5, width: 100, duration: 0) == 0)
    }
}
