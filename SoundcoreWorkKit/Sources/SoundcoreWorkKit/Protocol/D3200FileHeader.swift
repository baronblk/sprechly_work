import Foundation

/// File-Header aus der `0761`-Response – siehe `docs/d3200_protocol_spec.md` §5.
public struct D3200FileHeader: Sendable, Equatable {
    public static let minimumLength = 97

    /// Aufnahme-ID; entspricht dem Unix-Timestamp der Aufnahme.
    public let fileID: UInt32
    public let fileSize: UInt32
    /// 16 Byte; Basis für den AES-CTR-Zähler der Audio-Pakete.
    public let nonce: Data
    /// 46 Byte; enthält verpackt `"soundcored3200" ‖ fileKey`.
    public let encryptedFileKey: Data
    /// 16 Byte; IV zum Entpacken von `encryptedFileKey`.
    public let sessionNonce: Data
    public let status: UInt8
    public let checksum: UInt8

    public enum Failure: Error, LocalizedError, Equatable {
        case tooShort(Int)

        public var errorDescription: String? {
            switch self {
            case .tooShort(let length):
                "File-Header braucht mindestens \(D3200FileHeader.minimumLength) Byte (war \(length))."
            }
        }
    }

    /// Parst den Header aus der vollständigen `0761`-Response (inklusive `09FF0000`-Präfix).
    public init(response: Data) throws {
        guard response.count >= Self.minimumLength else {
            throw Failure.tooShort(response.count)
        }
        let bytes = Data(response)
        func slice(_ offset: Int, _ length: Int) -> Data {
            let start = bytes.startIndex + offset
            return Data(bytes[start ..< start + length])
        }
        fileID = bytes.littleEndianUInt32(at: 9) ?? 0
        fileSize = bytes.littleEndianUInt32(at: 13) ?? 0
        nonce = slice(17, 16)
        encryptedFileKey = slice(33, 46)
        sessionNonce = slice(79, 16)
        status = bytes[bytes.startIndex + 95]
        checksum = bytes[bytes.startIndex + 96]
    }
}

/// Ein Eintrag aus der Dateiliste (Spec §4).
public struct D3200Recording: Sendable, Equatable, Identifiable {
    public let fileID: UInt32
    public let size: UInt32

    public var id: UInt32 { fileID }

    /// Die `file_id` ist der Unix-Timestamp der Aufnahme.
    public var recordedAt: Date { Date(timeIntervalSince1970: TimeInterval(fileID)) }

    public init(fileID: UInt32, size: UInt32) {
        self.fileID = fileID
        self.size = size
    }
}

public extension D3200Recording {
    /// Plausibilitätsfenster aus Spec §4: `file_id` ist ein Aufnahme-Timestamp,
    /// die Größe liegt unter 10 MB.
    static let plausibleFileIDRange: Range<UInt32> = 1_735_000_001 ..< 1_800_000_000
    static let plausibleSizeRange: Range<UInt32> = 1 ..< 10_000_000

    var isPlausible: Bool {
        Self.plausibleFileIDRange.contains(fileID) && Self.plausibleSizeRange.contains(size)
    }

    /// Anzahl Aufnahmen, die die Antwort auf Offset 9/10 angibt (LE16).
    ///
    /// Nur Diagnose: die Einträge werden über das Plausibilitätsfenster erkannt,
    /// nicht über diesen Zähler.
    static func declaredCount(response: Data) -> Int? {
        let bytes = Data(response)
        guard bytes.count >= 11 else { return nil }
        let base = bytes.startIndex + 9
        return Int(UInt16(bytes[base]) | UInt16(bytes[base + 1]) << 8)
    }

    /// Parst die Einträge einer `0e1c`-Antwort: 8-Byte-Paare `file_id ‖ size`
    /// ab Offset 11, gefiltert über das Plausibilitätsfenster aus Spec §4.
    ///
    /// Am Gerät war nur eine Aufnahme vorhanden, daher ist die Schrittweite
    /// nicht abschließend belegt: hinter dem Eintrag standen 8 Nullbytes, die
    /// entweder Reserve des Eintrags (Schrittweite 16) oder Padding der
    /// Antwort sind. Das 8-Byte-Raster plus Filter liefert in beiden Fällen
    /// dasselbe Ergebnis, weil Nullbytes nie plausibel sind.
    static func parseList(response: Data) -> [D3200Recording] {
        let bytes = Data(response)
        var recordings: [D3200Recording] = []
        // Das letzte Byte ist die Checksum und kann nicht Teil eines Eintrags sein.
        var offset = D3200Opcode.fileList.payloadOffset
        while offset + 8 <= bytes.count - 1 {
            guard let fileID = bytes.littleEndianUInt32(at: offset),
                  let size = bytes.littleEndianUInt32(at: offset + 4)
            else { break }
            let recording = D3200Recording(fileID: fileID, size: size)
            if recording.isPlausible { recordings.append(recording) }
            offset += 8
        }
        return recordings
    }
}
