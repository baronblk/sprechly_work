import Testing
@testable import SprechlyWork

struct WaveformGeneratorTests {
    @Test func emptyInputProducesNoBuckets() {
        #expect(WaveformGenerator.buckets(from: [], columns: 10).isEmpty)
    }

    @Test func zeroColumnsProducesNoBuckets() {
        #expect(WaveformGenerator.buckets(from: [0.1, 0.2], columns: 0).isEmpty)
    }

    @Test func producesRequestedColumnCount() {
        let samples = (0..<100).map { Float($0) / 100 }
        #expect(WaveformGenerator.buckets(from: samples, columns: 10).count == 10)
    }

    @Test func shortSignalProducesOneBucketPerSample() {
        let buckets = WaveformGenerator.buckets(from: [0.5, -0.5, 0.25], columns: 10)
        #expect(buckets.count == 3)
    }

    @Test func computesMinMaxAndRMS() {
        // Single bucket over the whole signal.
        let buckets = WaveformGenerator.buckets(from: [-1, 1, -1, 1], columns: 1)
        let bucket = try! #require(buckets.first)
        #expect(bucket.min == -1)
        #expect(bucket.max == 1)
        #expect(bucket.rms == 1) // sqrt(mean(1,1,1,1)) == 1
    }

    @Test func silentSignalHasZeroEnvelope() {
        let buckets = WaveformGenerator.buckets(from: [0, 0, 0, 0], columns: 2)
        #expect(buckets.allSatisfy { $0.min == 0 && $0.max == 0 && $0.rms == 0 })
    }

    @Test func partitionsCoverDistinctRanges() {
        let samples: [Float] = [0, 0, 1, 1] // first half quiet, second half loud
        let buckets = WaveformGenerator.buckets(from: samples, columns: 2)
        #expect(buckets.count == 2)
        #expect(buckets[0].max == 0)
        #expect(buckets[1].max == 1)
    }
}
