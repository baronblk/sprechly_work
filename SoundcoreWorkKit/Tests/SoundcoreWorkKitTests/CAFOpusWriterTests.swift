import AVFoundation
import Foundation
import Testing

@testable import SoundcoreWorkKit

/// Der Import in die App hängt daran, dass AVFoundation die geschriebene
/// Datei lesen kann – Ogg/Opus kann es auf iOS nicht.
@Suite("CAF/Opus-Writer")
struct CAFOpusWriterTests {
    private let packets: [Data]
    private let directory: URL

    init() throws {
        let header = try D3200FileHeader(response: try Fixture.fileHeaderResponse())
        let sharedSecret = try #require(Data(hex: Fixture.session().sharedSecret))
        let sessionKey = try D3200Crypto.sessionKey(sharedSecret: sharedSecret)
        let fileKey = try D3200Crypto.unwrapFileKey(header: header, sessionKey: sessionKey)
        packets = try D3200Crypto.decryptRawStream(
            try Fixture.rawAudio(), fileKey: fileKey, nonce: header.nonce
        )
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("SoundcoreWorkKitTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func makeURL() -> URL {
        directory.appendingPathComponent("\(UUID().uuidString).caf")
    }

    @Test("AVFoundation liest die geschriebene CAF als 48 kHz Opus")
    func writesReadableCAF() throws {
        let url = makeURL()
        try CAFOpusWriter().write(packets: packets, to: url)

        let file = try AVAudioFile(forReading: url)
        #expect(file.fileFormat.sampleRate == 48000)
        #expect(file.fileFormat.channelCount == 2)
        // 45 Pakete à 960 Samples
        #expect(file.length == 43200)
        #expect(packets.count == 45)
    }

    @Test("Dauer der CAF entspricht der Aufnahme")
    func durationMatches() async throws {
        let url = makeURL()
        try CAFOpusWriter().write(packets: packets, to: url)

        let duration = try await AVURLAsset(url: url).load(.duration)
        #expect(abs(CMTimeGetSeconds(duration) - 0.9) < 0.01)
    }

    @Test("Download schreibt direkt als CAF")
    func downloadWritesCAF() throws {
        let header = try D3200FileHeader(response: try Fixture.fileHeaderResponse())
        let download = D3200Download(header: header, opusPackets: packets)
        let url = makeURL()

        try download.writeCAFOpus(to: url)
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(try AVAudioFile(forReading: url).length == 43200)
    }

    @Test("Ohne Pakete wird nichts geschrieben")
    func rejectsEmptyPackets() {
        #expect(throws: CAFOpusWriter.Failure.noPackets) {
            try CAFOpusWriter().write(packets: [], to: makeURL())
        }
    }
}
