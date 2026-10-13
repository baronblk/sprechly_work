import AVFoundation
import Foundation

/// Reduces PCM samples to a small number of renderable buckets. Pure and
/// off-main; the file variant streams in chunks so it never holds the whole
/// signal in memory.
enum WaveformGenerator {
    /// Reduces `samples` to at most `columns` buckets, partitioning the signal
    /// into evenly sized contiguous groups. Returns `[]` for empty input.
    static func buckets(from samples: [Float], columns: Int) -> [WaveformBucket] {
        guard columns > 0, !samples.isEmpty else { return [] }
        let count = Swift.min(columns, samples.count)
        let total = samples.count
        var result: [WaveformBucket] = []
        result.reserveCapacity(count)
        for i in 0..<count {
            let start = i * total / count
            let end = (i + 1) * total / count
            result.append(reduce(samples[start..<end]))
        }
        return result
    }

    /// Streams the audio file in chunks and reduces it to exactly `columns`
    /// buckets without loading the full signal into memory.
    static func peaks(forFileAt url: URL, columns: Int) throws -> [WaveformBucket] {
        guard columns > 0 else { return [] }
        let file = try AVAudioFile(forReading: url)
        let total = file.length
        guard total > 0 else { return [] }

        let bucketCount = Int(Swift.min(Int64(columns), total))
        var accumulators = Array(repeating: Accumulator(), count: bucketCount)

        let format = file.processingFormat
        let chunkFrames: AVAudioFrameCount = 65_536
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkFrames) else {
            return []
        }

        var frameIndex: Int64 = 0
        while file.framePosition < total {
            try file.read(into: buffer)
            let frames = Int(buffer.frameLength)
            if frames == 0 { break }
            guard let channelData = buffer.floatChannelData else { break }
            let channelCount = Int(format.channelCount)

            for f in 0..<frames {
                // Down-mix to mono.
                var sample: Float = 0
                for c in 0..<channelCount { sample += channelData[c][f] }
                sample /= Float(channelCount)

                let column = Int((frameIndex + Int64(f)) * Int64(bucketCount) / total)
                accumulators[Swift.min(column, bucketCount - 1)].add(sample)
            }
            frameIndex += Int64(frames)
        }

        return accumulators.map { $0.bucket }
    }

    private static func reduce(_ slice: ArraySlice<Float>) -> WaveformBucket {
        guard !slice.isEmpty else { return .silent }
        var minValue: Float = .greatestFiniteMagnitude
        var maxValue: Float = -.greatestFiniteMagnitude
        var sumSquares: Float = 0
        for sample in slice {
            minValue = Swift.min(minValue, sample)
            maxValue = Swift.max(maxValue, sample)
            sumSquares += sample * sample
        }
        let rms = (sumSquares / Float(slice.count)).squareRoot()
        return WaveformBucket(min: minValue, max: maxValue, rms: rms)
    }

    private struct Accumulator {
        var minValue: Float = .greatestFiniteMagnitude
        var maxValue: Float = -.greatestFiniteMagnitude
        var sumSquares: Float = 0
        var count: Int = 0

        mutating func add(_ sample: Float) {
            minValue = Swift.min(minValue, sample)
            maxValue = Swift.max(maxValue, sample)
            sumSquares += sample * sample
            count += 1
        }

        var bucket: WaveformBucket {
            guard count > 0 else { return .silent }
            return WaveformBucket(
                min: minValue,
                max: maxValue,
                rms: (sumSquares / Float(count)).squareRoot()
            )
        }
    }
}
