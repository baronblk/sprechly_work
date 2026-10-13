import Foundation
import Testing

@testable import SoundcoreWorkKit

/// Der End-to-End-Test aus `docs/test_vectors.md`: vom Roh-Stream zur fertigen
/// Ogg/Opus-Datei, ohne Gerät.
@Suite("End-to-End: Roh-Stream → Ogg/Opus")
struct DecryptE2ETests {
    private let header: D3200FileHeader
    private let fileKey: Data
    private let raw: Data
    private let expectedOgg: Data

    init() throws {
        header = try D3200FileHeader(response: try Fixture.fileHeaderResponse())
        // Session-Key wird – wie am Gerät – aus dem Shared Secret abgeleitet,
        // nicht aus der Fixture übernommen.
        let sharedSecret = try #require(Data(hex: Fixture.session().sharedSecret))
        let sessionKey = try D3200Crypto.sessionKey(sharedSecret: sharedSecret)
        fileKey = try D3200Crypto.unwrapFileKey(header: header, sessionKey: sessionKey)
        raw = try Fixture.rawAudio()
        expectedOgg = try Fixture.expectedOgg()
    }

    @Test("Roh-Stream enthält 45 Frames à 164 Byte")
    func rawStreamShape() {
        #expect(raw.count == 7380)
        #expect(raw.count % D3200Crypto.rawFrameSize == 0)
        #expect(raw.count / D3200Crypto.rawFrameSize == 45)
    }

    @Test("Entschlüsselung ergibt 45 Opus-Pakete à 160 Byte")
    func decryptsToOpusPackets() throws {
        let packets = try D3200Crypto.decryptRawStream(raw, fileKey: fileKey, nonce: header.nonce)

        #expect(packets.count == 45)
        #expect(packets.allSatisfy { $0.count == D3200Crypto.opusPacketSize })
        #expect(packets.reduce(0) { $0 + $1.count } == 7200)
        // Erster Opus-TOC: 0xbc → config 23, stereo
        let toc = try #require(packets.first?.first)
        #expect(toc == 0xBC)
        #expect(toc >> 3 == 23)
        #expect((toc >> 2) & 1 == 1)
    }

    @Test("Abgeschnittener Roh-Stream wird abgewiesen")
    func rejectsTruncatedRawStream() {
        #expect(throws: D3200Crypto.Failure.truncatedRawStream(100)) {
            try D3200Crypto.decryptRawStream(
                Data(repeating: 0, count: 100),
                fileKey: fileKey,
                nonce: header.nonce
            )
        }
    }

    @Test("Ogg-Datei ist bitgenau identisch mit der Referenz-Fixture")
    func reproducesReferenceOggByteForByte() throws {
        let packets = try D3200Crypto.decryptRawStream(raw, fileKey: fileKey, nonce: header.nonce)
        let ogg = try OggOpusWriter().makeFile(packets: packets)

        #expect(ogg.count == expectedOgg.count)
        #expect(ogg == expectedOgg)
    }

    @Test("Der BLE-Weg liefert dieselben Pakete wie das Rohformat")
    func bleChunkPathMatchesRawPath() throws {
        let fromRaw = try D3200Crypto.decryptRawStream(raw, fileKey: fileKey, nonce: header.nonce)

        // 08b0-Chunks nachbilden: Präfix + 160-B-Nutzlast + Checksum-Byte.
        let chunkPrefix = Data([0x09, 0xFF, 0x00, 0x00, 0x01, 0x1A, 0x08, 0xB0, 0x00, 0x00, 0x00, 0x00])
        var fromChunks: [Data] = []
        for index in 0 ..< raw.count / D3200Crypto.rawFrameSize {
            let start = raw.startIndex + index * D3200Crypto.rawFrameSize + 2
            let payload = Data(raw[start ..< start + D3200Crypto.opusPacketSize])
            let frame = chunkPrefix + payload + Data([RCSPFrame.checksum(payload)])
            fromChunks.append(try D3200Crypto.decryptPacket(
                D3200Client.audioPayload(from: frame),
                sequence: index,
                fileKey: fileKey,
                nonce: header.nonce
            ))
        }

        #expect(fromChunks == fromRaw)
    }
}

@Suite("Ogg/Opus-Container")
struct OggOpusWriterTests {
    @Test("OpusHead: Stereo, pre-skip 312, 16 kHz Eingang")
    func opusHeadLayout() {
        let head = OggOpusWriter().opusHead()
        #expect(head.count == 19)
        #expect(head.hexString == "4f7075734865616401023801803e0000000000")
    }

    @Test("OpusTags entspricht der Referenz-Aufnahme")
    func opusTagsLayout() {
        let tags = OggOpusWriter().opusTags()
        #expect(tags.count == 109)
        #expect(tags.prefix(8) == Data("OpusTags".utf8))
        #expect(String(decoding: tags, as: UTF8.self).contains("SoundCore D3200"))
    }

    /// Ogg-CRC: Polynom 0x04C11DB7, direkt, Init 0, kein Final-XOR.
    @Test("Ogg-CRC32 gegen bekannte Werte")
    func oggCRC() {
        #expect(OggCRC32.checksum(Data()) == 0)
        #expect(OggCRC32.checksum(Data("OggS".utf8)) == 0x5FB0_A94F)
        #expect(OggCRC32.checksum(Data("123456789".utf8)) == 0x89A1_897F)
    }

    @Test("Lacing-Tabelle", arguments: [
        (0, [0] as [UInt8]),
        (1, [1] as [UInt8]),
        (160, [160] as [UInt8]),
        (254, [254] as [UInt8]),
        (255, [255, 0] as [UInt8]),
        (256, [255, 1] as [UInt8]),
        (510, [255, 255, 0] as [UInt8]),
    ])
    func segmentTable(length: Int, expected: [UInt8]) {
        #expect(OggOpusWriter.segmentTable(forPacketOfLength: length) == expected)
    }

    @Test("Seitenstruktur: BOS auf Page 0, EOS auf der letzten, Granule = (i+1) * 960")
    func pageStructure() throws {
        let packets = (0 ..< 3).map { Data(repeating: UInt8($0), count: 160) }
        let file = try OggOpusWriter().makeFile(packets: packets)
        let pages = try OggPage.parseAll(file)

        #expect(pages.count == 5)  // OpusHead + OpusTags + 3 Audio-Pages
        #expect(pages.map(\.sequence) == [0, 1, 2, 3, 4])
        #expect(pages.map(\.granulePosition) == [0, 0, 960, 1920, 2880])
        #expect(pages[0].headerType == 0x02)   // BOS
        #expect(pages[1].headerType == 0x00)
        #expect(pages[2].headerType == 0x00)
        #expect(pages[4].headerType == 0x04)   // EOS
        #expect(pages.allSatisfy { $0.serialNumber == 0x1234_5678 })
        #expect(pages.allSatisfy { $0.hasValidCRC })
    }

    @Test("Alle Pages der Referenz-Fixture haben gültige CRCs")
    func referenceOggHasValidCRCs() throws {
        let pages = try OggPage.parseAll(try Fixture.expectedOgg())
        #expect(pages.count == 47)
        #expect(pages.allSatisfy { $0.hasValidCRC })
    }
}

/// Minimaler Ogg-Page-Parser – nur für die Tests, um die Ausgabe zu prüfen.
struct OggPage {
    let headerType: UInt8
    let granulePosition: Int64
    let serialNumber: UInt32
    let sequence: UInt32
    let crc: UInt32
    let segments: [UInt8]
    let body: Data
    let hasValidCRC: Bool

    static func parseAll(_ file: Data) throws -> [OggPage] {
        var pages: [OggPage] = []
        var offset = file.startIndex
        while offset < file.endIndex {
            try #require(file.count - (offset - file.startIndex) >= 27, "Page-Header zu kurz")
            try #require(Data(file[offset ..< offset + 4]) == Data("OggS".utf8), "Capture-Pattern fehlt")
            let segmentCount = Int(file[offset + 26])
            let tableEnd = offset + 27 + segmentCount
            try #require(tableEnd <= file.endIndex, "Segment-Tabelle zu kurz")
            let segments = Array(file[offset + 27 ..< tableEnd])
            let bodyLength = segments.reduce(0) { $0 + Int($1) }
            let bodyEnd = tableEnd + bodyLength
            try #require(bodyEnd <= file.endIndex, "Page-Body zu kurz")

            let pageData = Data(file[offset ..< bodyEnd])
            let crc = pageData.littleEndianUInt32(at: 22) ?? 0
            var zeroed = pageData
            zeroed.replaceSubrange(
                zeroed.index(zeroed.startIndex, offsetBy: 22)
                    ..< zeroed.index(zeroed.startIndex, offsetBy: 26),
                with: [0, 0, 0, 0]
            )

            pages.append(OggPage(
                headerType: pageData[pageData.startIndex + 5],
                granulePosition: Int64(bitPattern: UInt64(
                    littleEndianBytes: Array(pageData[pageData.startIndex + 6 ..< pageData.startIndex + 14])
                )),
                serialNumber: pageData.littleEndianUInt32(at: 14) ?? 0,
                sequence: pageData.littleEndianUInt32(at: 18) ?? 0,
                crc: crc,
                segments: segments,
                body: Data(file[tableEnd ..< bodyEnd]),
                hasValidCRC: OggCRC32.checksum(zeroed) == crc
            ))
            offset = bodyEnd
        }
        return pages
    }
}

extension UInt64 {
    init(littleEndianBytes bytes: [UInt8]) {
        self = bytes.enumerated().reduce(UInt64(0)) { $0 | UInt64($1.element) << (8 * $1.offset) }
    }
}
