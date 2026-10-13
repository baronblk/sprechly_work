import Foundation

/// Verpackt rohe Opus-Pakete in einen Ogg/Opus-Container – siehe `docs/d3200_protocol_spec.md` §7.
///
/// Die Standardwerte entsprechen den Aufnahmen des Soundcore Work und
/// reproduzieren die Referenz-Fixture bitgenau.
public struct OggOpusWriter: Sendable {
    /// Konfiguration des OpusHead-Pakets.
    public struct Format: Sendable, Equatable {
        public var channels: UInt8
        public var preSkip: UInt16
        public var inputSampleRate: UInt32
        public var outputGain: Int16
        public var channelMappingFamily: UInt8
        /// Samples pro Opus-Paket, bezogen auf 48 kHz (20 ms = 960).
        public var samplesPerPacket: Int

        public init(
            channels: UInt8 = 2,
            preSkip: UInt16 = 312,
            inputSampleRate: UInt32 = 16000,
            outputGain: Int16 = 0,
            channelMappingFamily: UInt8 = 0,
            samplesPerPacket: Int = 960
        ) {
            self.channels = channels
            self.preSkip = preSkip
            self.inputSampleRate = inputSampleRate
            self.outputGain = outputGain
            self.channelMappingFamily = channelMappingFamily
            self.samplesPerPacket = samplesPerPacket
        }

        /// Format der Soundcore-Work-Aufnahmen: Stereo, pre-skip 312, 16 kHz Eingang.
        public static let soundcoreWork = Format()
    }

    /// Inhalt des OpusTags-Pakets.
    public struct Tags: Sendable, Equatable {
        public var vendor: String
        public var comments: [String]

        public init(vendor: String, comments: [String]) {
            self.vendor = vendor
            self.comments = comments
        }

        /// Tags wie sie die Referenz-Aufnahme trägt.
        public static let soundcoreWork = Tags(
            vendor: "SoundCore D3200",
            comments: [
                "ENCODER=SoundCore D3200",
                "SAMPLERATE=16000",
                "CHANNELS=2",
                "BITRATE=64000",
            ]
        )
    }

    public enum Failure: Error, LocalizedError, Equatable {
        case packetTooLarge(Int)

        public var errorDescription: String? {
            switch self {
            case .packetTooLarge(let length):
                "Opus-Paket mit \(length) Byte passt nicht in eine Ogg-Page."
            }
        }
    }

    public var format: Format
    public var tags: Tags
    public var serialNumber: UInt32

    public init(
        format: Format = .soundcoreWork,
        tags: Tags = .soundcoreWork,
        serialNumber: UInt32 = 0x1234_5678
    ) {
        self.format = format
        self.tags = tags
        self.serialNumber = serialNumber
    }

    /// Baut eine vollständige Ogg/Opus-Datei: OpusHead, OpusTags, dann ein Paket pro Page.
    public func makeFile(packets: [Data]) throws -> Data {
        var file = Data()
        var sequence: UInt32 = 0

        file.append(try page(
            body: opusHead(),
            granulePosition: 0,
            sequence: sequence,
            headerType: .beginOfStream
        ))
        sequence += 1

        file.append(try page(
            body: opusTags(),
            granulePosition: 0,
            sequence: sequence,
            headerType: []
        ))
        sequence += 1

        for (index, packet) in packets.enumerated() {
            let isLast = index == packets.count - 1
            file.append(try page(
                body: packet,
                granulePosition: Int64((index + 1) * format.samplesPerPacket),
                sequence: sequence,
                headerType: isLast ? .endOfStream : []
            ))
            sequence += 1
        }
        return file
    }

    // MARK: - Header-Pakete

    func opusHead() -> Data {
        var head = Data("OpusHead".utf8)
        head.append(1)  // Version
        head.append(format.channels)
        head.append(littleEndian: format.preSkip)
        head.append(littleEndian: format.inputSampleRate)
        head.append(littleEndian: UInt16(bitPattern: format.outputGain))
        head.append(format.channelMappingFamily)
        return head
    }

    func opusTags() -> Data {
        var packet = Data("OpusTags".utf8)
        let vendor = Data(tags.vendor.utf8)
        packet.append(littleEndian: UInt32(vendor.count))
        packet.append(vendor)
        packet.append(littleEndian: UInt32(tags.comments.count))
        for comment in tags.comments {
            let bytes = Data(comment.utf8)
            packet.append(littleEndian: UInt32(bytes.count))
            packet.append(bytes)
        }
        return packet
    }

    // MARK: - Pages

    struct HeaderType: OptionSet {
        let rawValue: UInt8
        static let continued = HeaderType(rawValue: 0x01)
        static let beginOfStream = HeaderType(rawValue: 0x02)
        static let endOfStream = HeaderType(rawValue: 0x04)
    }

    /// Lacing-Tabelle eines Pakets: 255er-Segmente, abgeschlossen durch ein Segment < 255.
    static func segmentTable(forPacketOfLength length: Int) -> [UInt8] {
        var table = [UInt8](repeating: 255, count: length / 255)
        table.append(UInt8(length % 255))
        return table
    }

    func page(
        body: Data,
        granulePosition: Int64,
        sequence: UInt32,
        headerType: HeaderType
    ) throws -> Data {
        let segments = Self.segmentTable(forPacketOfLength: body.count)
        guard segments.count <= 255 else { throw Failure.packetTooLarge(body.count) }

        var page = Data("OggS".utf8)
        page.append(0)  // Stream-Structure-Version
        page.append(headerType.rawValue)
        page.append(littleEndian: UInt64(bitPattern: granulePosition))
        page.append(littleEndian: serialNumber)
        page.append(littleEndian: sequence)
        let crcOffset = page.count
        page.append(littleEndian: UInt32(0))  // Platzhalter, wird unten ersetzt
        page.append(UInt8(segments.count))
        page.append(contentsOf: segments)
        page.append(body)

        let crc = OggCRC32.checksum(page)
        page.replaceSubrange(
            page.index(page.startIndex, offsetBy: crcOffset)
                ..< page.index(page.startIndex, offsetBy: crcOffset + 4),
            with: crc.littleEndianBytes
        )
        return page
    }
}

/// CRC-32 nach Ogg-Spezifikation: Polynom 0x04C11DB7, direkt, Init 0, kein Final-XOR.
enum OggCRC32 {
    private static let table: [UInt32] = {
        (0 ..< 256).map { index in
            var remainder = UInt32(index) << 24
            for _ in 0 ..< 8 {
                if remainder & 0x8000_0000 != 0 {
                    remainder = (remainder << 1) ^ 0x04C1_1DB7
                } else {
                    remainder <<= 1
                }
            }
            return remainder
        }
    }()

    static func checksum(_ data: Data) -> UInt32 {
        data.reduce(UInt32(0)) { crc, byte in
            (crc << 8) ^ table[Int((crc >> 24) ^ UInt32(byte))]
        }
    }
}

extension UInt32 {
    var littleEndianBytes: [UInt8] {
        [
            UInt8(truncatingIfNeeded: self),
            UInt8(truncatingIfNeeded: self >> 8),
            UInt8(truncatingIfNeeded: self >> 16),
            UInt8(truncatingIfNeeded: self >> 24),
        ]
    }
}

extension Data {
    mutating func append(littleEndian value: UInt16) {
        append(contentsOf: [
            UInt8(truncatingIfNeeded: value),
            UInt8(truncatingIfNeeded: value >> 8),
        ])
    }

    mutating func append(littleEndian value: UInt64) {
        append(contentsOf: (0 ..< 8).map { UInt8(truncatingIfNeeded: value >> (8 * $0)) })
    }
}
