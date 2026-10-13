import Foundation

/// File-Header aus der `0761`-Response – siehe `docs/d3200_protocol_spec.md` §5.
public struct D3200FileHeader: Sendable, Equatable {
    public static let minimumLength = 97

    /// Aufnahme-ID; entspricht dem Unix-Timestamp der Aufnahme.
    /// Bytes, die das Gerät pro Audio-Frame abrechnet. Am Gerät verifiziert:
    /// `fileSize` ist immer ein exaktes Vielfaches davon (45 × 166 = 7470,
    /// 665 × 166 = 110390), während über BLE 164 B pro Frame ankommen.
    public static let deviceBytesPerFrame: UInt32 = 166

    public let fileID: UInt32
    /// Größenangabe des Geräts: `frameCount * 166`.
    public let fileSize: UInt32
    /// 16 Byte; Basis für den AES-CTR-Zähler der Audio-Pakete.
    public let nonce: Data
    /// 46 Byte; enthält verpackt `"soundcored3200" ‖ fileKey`.
    public let encryptedFileKey: Data
    /// 16 Byte; IV zum Entpacken von `encryptedFileKey`.
    public let sessionNonce: Data
    public let status: UInt8
    public let checksum: UInt8

    /// Anzahl Audio-Frames der Aufnahme, aus `fileSize` abgeleitet.
    public var frameCount: Int { Int(fileSize / Self.deviceBytesPerFrame) }

    /// Bytes, die der Roh-Stream über BLE haben muss: `frameCount * 164`.
    public var expectedRawBytes: Int { frameCount * D3200Crypto.rawFrameSize }

    /// Spieldauer der Aufnahme (ein Opus-Paket = 20 ms).
    public var duration: TimeInterval {
        Double(frameCount) * D3200Recording.secondsPerFrame
    }

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
///
/// Das zweite Feld eines Eintrags ist die **Spieldauer in Millisekunden**, nicht
/// die Dateigröße. Am Gerät verifiziert: 45 Pakete ⇒ 900 ms und 665 Pakete
/// ⇒ 13300 ms, beides deckungsgleich mit `ffprobe`. Die Liste liefert damit
/// alles für die Anzeige, ohne vorher herunterzuladen.
public struct D3200Recording: Sendable, Equatable, Identifiable {
    /// Ein Opus-Paket deckt 20 ms ab.
    public static let secondsPerFrame: TimeInterval = 0.02

    public let fileID: UInt32
    /// Spieldauer in Millisekunden.
    public let durationMilliseconds: UInt32

    public var id: UInt32 { fileID }

    /// Die `file_id` ist der Unix-Timestamp der Aufnahme.
    public var recordedAt: Date { Date(timeIntervalSince1970: TimeInterval(fileID)) }

    /// Spieldauer als Sekunden.
    public var duration: TimeInterval { TimeInterval(durationMilliseconds) / 1000 }

    /// Erwartete Anzahl Audio-Frames – nützlich, um den Download abzuschätzen.
    public var frameCount: Int { Int(duration / Self.secondsPerFrame) }

    public init(fileID: UInt32, durationMilliseconds: UInt32) {
        self.fileID = fileID
        self.durationMilliseconds = durationMilliseconds
    }
}

public extension D3200Recording {
    /// Plausibilitätsfenster: `file_id` ist ein Aufnahme-Timestamp, die Dauer
    /// liegt zwischen 1 ms und 24 h. Trennt die echten Einträge vom Padding
    /// hinter der Liste, das immer aus Nullbytes besteht.
    static let plausibleFileIDRange: Range<UInt32> = 1_735_000_001 ..< 1_800_000_000
    static let plausibleDurationRange: Range<UInt32> = 1 ..< 86_400_000

    var isPlausible: Bool {
        Self.plausibleFileIDRange.contains(fileID)
            && Self.plausibleDurationRange.contains(durationMilliseconds)
    }

    /// Anzahl Aufnahmen, die die Antwort auf Offset 9/10 angibt (LE16).
    static func declaredCount(response: Data) -> Int? {
        let bytes = Data(response)
        guard bytes.count >= 11 else { return nil }
        let base = bytes.startIndex + 9
        return Int(UInt16(bytes[base]) | UInt16(bytes[base + 1]) << 8)
    }

    /// Parst die Einträge einer Dateilisten-Antwort: 8-Byte-Paare
    /// `file_id ‖ size` (je LE32) ab Offset 11.
    ///
    /// Am Gerät mit zwei Aufnahmen verifiziert (2026-10-13): Die Einträge
    /// liegen direkt hintereinander auf 11 und 19, danach folgen 8 Nullbytes
    /// als Padding. Die Schrittweite ist also 8, nicht 16.
    static func parseList(response: Data) -> [D3200Recording] {
        let bytes = Data(response)
        let declared = declaredCount(response: bytes)
        var recordings: [D3200Recording] = []
        var offset = D3200Message.fileList.payloadOffset

        while offset + 8 <= bytes.count {
            if let declared, recordings.count >= declared { break }
            guard let fileID = bytes.littleEndianUInt32(at: offset),
                  let duration = bytes.littleEndianUInt32(at: offset + 4)
            else { break }
            let recording = D3200Recording(fileID: fileID, durationMilliseconds: duration)
            // Das Padding hinter den Einträgen ist nie plausibel.
            if recording.isPlausible { recordings.append(recording) }
            offset += 8
        }
        return recordings
    }
}
