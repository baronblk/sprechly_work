import Testing
@testable import SprechlyWork

struct PlaybackSkipTests {
    @Test func skipsForwardWithinBounds() {
        #expect(PlaybackViewModel.clampedTarget(position: 20, delta: 10, duration: 60) == 30)
    }

    @Test func clampsAtZero() {
        #expect(PlaybackViewModel.clampedTarget(position: 5, delta: -10, duration: 60) == 0)
    }

    @Test func clampsAtDuration() {
        #expect(PlaybackViewModel.clampedTarget(position: 55, delta: 10, duration: 60) == 60)
    }
}
