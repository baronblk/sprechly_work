import Foundation

/// RCSP-Framing des Soundcore Work (D3200) – siehe `docs/d3200_protocol_spec.md` §2.
public enum RCSPFrame {
    /// Präfix eines Commands (App → Gerät).
    public static let commandPrefix = Data([0x08, 0xEE, 0x00, 0x00])
    /// Präfix einer Response/eines Events (Gerät → App).
    public static let responsePrefix = Data([0x09, 0xFF, 0x00, 0x00])

    /// XOR aller Payload-Bytes (ohne Präfix). Gilt nur für Commands –
    /// Responses tragen keinen Checksum-Trailer.
    public static func checksum(_ payload: Data) -> UInt8 {
        payload.reduce(UInt8(0)) { $0 ^ $1 }
    }

    /// Baut ein sendefertiges Command: Präfix ‖ Payload ‖ XOR-Checksum.
    public static func command(payload: Data) -> Data {
        var frame = commandPrefix
        frame.append(payload)
        frame.append(checksum(payload))
        return frame
    }

    /// Prüft, ob `frame` das Response-Präfix trägt.
    public static func isResponse(_ frame: Data) -> Bool {
        frame.count >= responsePrefix.count && frame.prefix(responsePrefix.count) == responsePrefix
    }

    /// Kopf einer Gerät→App-Nachricht.
    ///
    /// Am Gerät verifiziert (2026-10-13): Offset 5 trägt die Befehlsgruppe,
    /// Offset 6 den Nachrichtentyp und **Offset 7 die Framelänge**. Die
    /// ursprüngliche Lesart „16-Bit-Opcode auf 6/7" funktioniert nur bei
    /// Nachrichten fester Länge – die Dateiliste wächst mit der Anzahl
    /// Einträge und wechselt dadurch scheinbar den Opcode
    /// (`0e14`/`0e1c`/`0e24` sind dieselbe Nachricht mit 20/28/36 Byte).
    public struct Response: Sendable, Equatable {
        /// Kleinste Nachricht: Präfix, Flag, Gruppe, Typ, Länge.
        public static let headerLength = 8

        /// Befehlsgruppe (Offset 5), spiegelt `command[1]`.
        public let group: UInt8
        /// Nachrichtentyp (Offset 6), spiegelt `command[2]`.
        public let type: UInt8
        /// Vom Gerät angegebene Framelänge (Offset 7).
        public let declaredLength: UInt8
        /// Der vollständige Frame.
        public let frame: Data

        public init?(frame: Data) {
            guard RCSPFrame.isResponse(frame), frame.count >= Self.headerLength else { return nil }
            let base = frame.startIndex
            group = frame[base + 5]
            type = frame[base + 6]
            declaredLength = frame[base + 7]
            self.frame = frame
        }

        /// Ob die angegebene Länge zur tatsächlichen passt. Ersetzt die
        /// Integritätsprüfung, die Responses mangels Checksum nicht haben.
        public var hasConsistentLength: Bool { Int(declaredLength) == frame.count }

        /// Erkannter Nachrichtentyp, falls bekannt.
        public var message: D3200Message? { D3200Message(rawValue: type) }

        /// Nutzdaten ab dem typspezifischen Offset.
        public func data(from offset: Int) -> Data {
            guard offset < frame.count else { return Data() }
            return Data(frame.dropFirst(offset))
        }
    }
}

/// Nachrichtentypen des Geräts (Offset 6 einer Response) – am Gerät verifiziert.
public enum D3200Message: UInt8, Sendable, CaseIterable {
    /// Antwort auf den ECDH-Handshake; enthält den Geräte-Public-Key.
    case keyExchange = 0x01
    /// Auth bestätigt.
    case auth = 0x03
    /// Unaufgeforderter Status-Push der Aufnahme (Gruppe 0x1a): trägt die
    /// `file_id` und einen Statuscode. Am Gerät beim **Start** einer Aufnahme
    /// beobachtet. Die Spec nannte ihn „Metadaten-Push (überspringen)".
    case recordingState = 0x06
    /// File-Detail-Antwort, enthält den File-Header (§5).
    case fileDetail = 0x07
    /// Audio-Daten-Chunk.
    case audioChunk = 0x08
    /// Transfer abgeschlossen.
    case transferComplete = 0x0A
    /// Dateilisten-Antwort; Länge wächst mit der Anzahl Einträge.
    case fileList = 0x0E
    /// Record-Control (Gruppe 0x18): in beide Richtungen.
    ///
    /// Als Command steuert sie die Aufnahme fern, als Nachricht meldet das
    /// Gerät seinen Aufnahmestatus auf Offset 9. Am Gerät verifiziert:
    /// Start → `01`, Pause → `02`, Ende an der Hardwaretaste → `00` plus
    /// Dauer und `file_id`.
    ///
    /// Die Spec führte dies als „`18 82` Transfer-Init" – eine Fehldeutung:
    /// `0x18` ist die Gruppe, `0x82` der Typ.
    case recordControl = 0x82
    /// Time-Sync bestätigt.
    case timeSync = 0xA6
}

public extension D3200Message {
    /// Offset im Frame, ab dem die Nutzdaten dieses Typs beginnen.
    var payloadOffset: Int {
        switch self {
        case .audioChunk: 12          // davor: Frame-Zähler auf 9, Füllbytes 10/11
        case .fileList: 11            // davor: Eintragszähler LE16 auf 9/10
        case .transferComplete: 10
        case .recordingState: 9       // file_id LE32, danach ein Code (immer 2)
        case .recordControl: 9        // Statusbyte, bei einem Stop danach Dauer und file_id
        case .keyExchange, .auth, .fileDetail, .timeSync: 8
        }
    }
}
