import Foundation

/// RCSP-Framing des Soundcore Work (D3200) – siehe `docs/d3200_protocol_spec.md` §2.
public enum RCSPFrame {
    /// Präfix eines Commands (App → Gerät).
    public static let commandPrefix = Data([0x08, 0xEE, 0x00, 0x00])
    /// Präfix einer Response/eines Events (Gerät → App).
    public static let responsePrefix = Data([0x09, 0xFF, 0x00, 0x00])

    /// Absoluter Offset des Opcodes in einer Response.
    public static let opcodeOffset = 6

    /// XOR aller Payload-Bytes (ohne Präfix).
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

    /// Opcode einer Response: die zwei Bytes auf Offset 6/7, big-endian.
    ///
    /// Kurze Bestätigungs-Frames (Auth, Time-Sync) tragen hier keinen der in
    /// `D3200Opcode` gelisteten Werte – sie werden nur als „angekommen" gewertet.
    public static func opcode(of frame: Data) -> UInt16? {
        guard frame.count >= opcodeOffset + 2 else { return nil }
        let base = frame.startIndex + opcodeOffset
        return UInt16(frame[base]) << 8 | UInt16(frame[base + 1])
    }
}

/// Bekannte Response-Opcodes (Spec §2).
public enum D3200Opcode: UInt16, Sendable, CaseIterable {
    /// File-Detail-Antwort, enthält den File-Header (§5).
    case fileDetail = 0x0761
    /// Audio-Daten-Chunk. Ab Offset 12 steht ein vollständiger 164-Byte-Frame
    /// des Rohformats; Offset 9 trägt den Frame-Zähler.
    case audioChunk = 0x08B0
    /// Transfer abgeschlossen; `total = LE32(frame[10..<14])`.
    case transferComplete = 0x0A13
    /// Metadaten-Push – zu überspringen.
    case metadataPush = 0x0612
    /// Transfer-Init.
    case transferInit = 0x1882
    /// Antwort auf den ECDH-Handshake (`014b`); enthält den Geräte-Public-Key.
    case keyExchange = 0x016B
    /// Leere Folgeseite der Dateiliste – markiert das Listenende.
    case fileListEnd = 0x0E14
    /// Antwort auf die Dateilisten-Abfrage.
    ///
    /// Spec §4 nennt `0e0c` – das sind die Bytes des *Commands*. Am Gerät
    /// verifiziert antwortet die Liste mit `0e1c`.
    case fileList = 0x0E1C
}

public extension D3200Opcode {
    /// Offset, ab dem die Nutzdaten dieses Opcodes beginnen.
    var payloadOffset: Int {
        switch self {
        case .audioChunk: 12
        // Die Liste trägt auf 9/10 einen Eintragszähler, die Einträge beginnen
        // erst auf 11 (am Gerät verifiziert; §4 nennt 10).
        case .fileList: 11
        case .transferComplete: 10
        case .fileDetail, .metadataPush, .transferInit, .keyExchange, .fileListEnd: 8
        }
    }
}
