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

        /// Erkannte Nachricht, falls Gruppe und Typ bekannt sind.
        public var message: D3200Message? { D3200Message(group: group, type: type) }

        /// Nutzdaten ab dem typspezifischen Offset.
        public func data(from offset: Int) -> Data {
            guard offset < frame.count else { return Data() }
            return Data(frame.dropFirst(offset))
        }
    }
}

/// Nachrichten des Geräts, identifiziert über **Gruppe und Typ**.
///
/// Der Typ allein reicht nicht: `0x01` bedeutet in Gruppe `0x2e` die
/// ECDH-Antwort und in Gruppe `0x01` die Geräte-Info.
public enum D3200Message: Sendable, Hashable, CaseIterable {
    // Gruppe 0x01 – Geräte-Info-Familie
    case deviceInfo
    case battery
    case charging
    case timeSync

    // Gruppe 0x0b
    case auth

    // Gruppe 0x18
    /// Record-Control, in beide Richtungen: als Command Fernsteuerung, als
    /// Nachricht der Aufnahmestatus auf Offset 9.
    case recordControl

    // Gruppe 0x1a
    /// Kündigt eine neu angelegte Aufnahme an – **nicht** der Status.
    case recordingState
    case fileDetail
    case audioChunk
    case transferComplete
    case fileList
    /// Löschen einer Aufnahme auf dem Gerät.
    case deleteFile

    // Gruppe 0x2e
    case keyExchange

    /// Befehlsgruppe (Offset 5 einer Response, `command[1]`).
    public var group: UInt8 {
        switch self {
        case .deviceInfo, .battery, .charging, .timeSync: 0x01
        case .auth: 0x0B
        case .recordControl: 0x18
        case .recordingState, .fileDetail, .audioChunk, .transferComplete, .fileList, .deleteFile: 0x1A
        case .keyExchange: 0x2E
        }
    }

    /// Nachrichtentyp (Offset 6 einer Response, `command[2]`).
    public var type: UInt8 {
        switch self {
        case .deviceInfo: 0x01
        case .battery: 0x03
        case .charging: 0x04
        case .timeSync: 0xA6
        case .auth: 0x03
        case .recordControl: 0x82
        case .recordingState: 0x06
        case .fileDetail: 0x07
        case .audioChunk: 0x08
        case .transferComplete: 0x0A
        case .fileList: 0x0E
        case .deleteFile: 0x10
        case .keyExchange: 0x01
        }
    }

    public init?(group: UInt8, type: UInt8) {
        guard let match = Self.allCases.first(where: { $0.group == group && $0.type == type })
        else { return nil }
        self = match
    }

    /// Offset im Frame, ab dem die Nutzdaten dieses Typs beginnen.
    public var payloadOffset: Int {
        switch self {
        case .audioChunk: 12          // davor: Frame-Zähler auf 9, Füllbytes 10/11
        case .fileList: 11            // davor: Eintragszähler LE16 auf 9/10
        case .transferComplete: 10
        case .recordControl: 9        // Statusbyte; bei einem Stop danach Dauer und file_id
        case .recordingState: 9       // file_id LE32, danach ein Code (immer 2)
        case .deviceInfo, .battery, .charging, .auth, .fileDetail, .keyExchange, .timeSync, .deleteFile: 9
        }
    }
}
