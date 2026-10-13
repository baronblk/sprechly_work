import Testing
@testable import SprechlyWork

struct AudioCutServiceTests {
    // window = 0.1s, minSilence = 0.3s → drops silent runs of ≥ 3 windows.

    @Test func dropsLongMiddleSilence() {
        // loud(0-0.2) · silence(0.2-0.6, 4 windows) · loud(0.6-0.8)
        let loud = [true, true, false, false, false, false, true, true]
        let keep = AudioCutService.keepRanges(loud: loud, windowDuration: 0.1, minSilence: 0.3)
        #expect(keep.count == 2)
        #expect(keep.first?.lowerBound == 0)
        #expect(abs((keep.first?.upperBound ?? 0) - 0.2) < 0.0001)
        #expect(abs((keep.last?.lowerBound ?? 0) - 0.6) < 0.0001)
    }

    @Test func keepsShortSilence() {
        // A single silent window (0.1s < 0.3s) stays — not a gap to remove.
        let loud = [true, false, true]
        let keep = AudioCutService.keepRanges(loud: loud, windowDuration: 0.1, minSilence: 0.3)
        #expect(keep.count == 1)
        #expect(keep.first?.lowerBound == 0)
        #expect(abs((keep.first?.upperBound ?? 0) - 0.3) < 0.0001)
    }

    @Test func dropsLeadingAndTrailingSilence() {
        let loud = [false, false, false, true, true, false, false, false]
        let keep = AudioCutService.keepRanges(loud: loud, windowDuration: 0.1, minSilence: 0.3)
        #expect(keep.count == 1)
        #expect(abs((keep.first?.lowerBound ?? -1) - 0.3) < 0.0001)
        #expect(abs((keep.first?.upperBound ?? 0) - 0.5) < 0.0001)
    }

    @Test func emptyWhenAllSilent() {
        #expect(AudioCutService.keepRanges(loud: [false, false, false, false], windowDuration: 0.1, minSilence: 0.3).isEmpty)
    }
}
