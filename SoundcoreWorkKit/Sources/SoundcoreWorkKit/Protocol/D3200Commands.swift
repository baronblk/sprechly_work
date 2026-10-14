import Foundation

/// Command-Payloads des Soundcore Work (D3200) – siehe `docs/d3200_protocol_spec.md` §4.
///
/// Alle Funktionen liefern sendefertige Frames inklusive Präfix und XOR-Checksum.
public enum D3200Commands {
    /// Statischer Auth-Token. Das Gerät validiert ihn nicht, erwartet ihn aber.
    ///
    /// Der Base64-String aus Spec §4 dekodiert zu **19** Byte
    /// (`0190f151b0b4c444cd002f47d7a69c5efb4b79`); die Spec-Prosa nennt 20.
    /// Maßgeblich ist die mitgeschnittene Byte-Folge – am Gerät gegenprüfen,
    /// falls Auth je fehlschlägt.
    static let authToken = Data(base64Encoded: "AZDxUbC0xETNAC9H16acXvtLeQ==")!

    /// Auth – statischer Token.
    public static func auth() -> Data {
        var payload = Data([0x00, 0x0B, 0x03, 0x27, 0x00, 0x1C])
        payload.append(authToken)
        payload.append(0x15)
        return RCSPFrame.command(payload: payload)
    }

    /// Time-Sync – Unix-Sekunden als LE32.
    public static func timeSync(date: Date = Date()) -> Data {
        let timestamp = UInt32(truncatingIfNeeded: Int(date.timeIntervalSince1970))
        var payload = Data([0x00, 0x01, 0xA6, 0x14, 0x00])
        payload.append(littleEndian: timestamp)
        payload.append(contentsOf: [0x0A, 0x90, 0xFF, 0xE6, 0x6A, 0x08])
        return RCSPFrame.command(payload: payload)
    }

    /// Dateiliste – paginiert, Seiten ab 0 bis zur ersten leeren Seite.
    public static func listFiles(page: UInt8) -> Data {
        RCSPFrame.command(payload: Data([0x00, 0x1A, 0x0E, 0x0C, 0x00, page, 0x00, 0x2A]))
    }

    /// Transfer-Anforderung für eine Aufnahme.
    ///
    /// Nutzlast nach Referenz-Layout:
    /// `already_transferred u32 ‖ file_id u32 ‖ realtimeFlag u8`.
    ///
    /// - `alreadyTransferred` setzt den Startpunkt – damit lässt sich ein
    ///   abgebrochener Download fortsetzen statt neu zu beginnen.
    /// - `realtime` fordert den laufenden Mitschnitt an. **Ohne** das Byte ist
    ///   die Anforderung per Definition „offline"; genau deshalb hat jeder
    ///   frühere Realtime-Versuch nichts geliefert.
    public static func fileTransfer(
        fileID: UInt32,
        alreadyTransferred: UInt32 = 0,
        realtime: Bool? = nil
    ) -> Data {
        // Länge steht als LE16 auf Offset 7/8 und zählt den ganzen Frame.
        let length = UInt16(4 + 5 + 8 + (realtime == nil ? 0 : 1) + 1)
        var payload = Data([0x00, 0x1A, 0x07])
        payload.append(littleEndian: length)
        payload.append(littleEndian: alreadyTransferred)
        payload.append(littleEndian: fileID)
        if let realtime { payload.append(realtime ? 0x01 : 0x00) }
        return RCSPFrame.command(payload: payload)
    }

    /// Die am Gerät erprobte Offline-Anforderung (18 B, ohne Flag-Byte).
    public static func fileDetail(fileID: UInt32) -> Data {
        fileTransfer(fileID: fileID)
    }

    /// Fragt eine Nachricht ohne Nutzdaten ab (Gruppe/Typ aus `message`).
    ///
    /// Alle Abfragen der Geräte-Info-Familie haben dasselbe Format:
    /// `08 ee 00 00 | 00 <gruppe> <typ> 0a 00 | xor`, 10 Byte.
    public static func query(_ message: D3200Message) -> Data {
        RCSPFrame.command(payload: Data([0x00, message.group, message.type, 0x0A, 0x00]))
    }

    /// Volle Geräte-Info: Firmware, Seriennummer, Speicher, Ladecase (§7b).
    public static func deviceInfo() -> Data { query(.deviceInfo) }

    /// Akkustände von Gerät und Ladecase (§7b).
    public static func battery() -> Data { query(.battery) }

    /// Ladezustand von Gerät und Ladecase (§7b).
    public static func charging() -> Data { query(.charging) }

    /// Löscht eine Aufnahme auf dem Gerät – **unwiderruflich**.
    ///
    /// Gruppe `0x1a`, Typ `0x10` mit der `file_id` als LE32
    /// (`docs/d3200_protocol_spec.md` §4), 14 Byte.
    ///
    /// Am Gerät verifiziert, mit einer Eigenheit: Das Gerät bestätigt sofort,
    /// aber die **Dateiliste zeigt die Aufnahme noch eine Weile weiter**. Wer
    /// direkt nach der Bestätigung neu auflistet, sieht sie unverändert –
    /// gelöscht ist sie trotzdem. Die Oberfläche darf sich daher nicht auf ein
    /// sofortiges Neuladen verlassen, sondern entfernt die Zeile selbst.
    public static func deleteRecording(fileID: UInt32) -> Data {
        var payload = Data([0x00, 0x1A, 0x10, 0x0E, 0x00])
        payload.append(littleEndian: fileID)
        return RCSPFrame.command(payload: payload)
    }

    /// Fernsteuerung der Aufnahme am Gerät.
    ///
    /// Gruppe `0x18`, Typ `0x82` mit einem Nutzbyte – aus dem Community-Repo
    /// (siehe `docs/d3200_protocol_spec.md` §7a). Das Gerät meldet auf
    /// derselben Gruppe/Typ seinen Status zurück.
    ///
    /// Es gibt dort **kein** Stop-Command; Stop läuft über die Hardwaretaste.
    public static func recordControl(_ action: D3200RecordAction) -> Data {
        // Offset 7 trägt die Framelänge, wie bei den übrigen Commands.
        var payload = Data([0x00, 0x18, 0x82, 0x0B, 0x00])
        payload.append(action.rawValue)
        return RCSPFrame.command(payload: payload)
    }

    /// ECDH-Handshake – eigener Public Key als 64 Byte `X‖Y` big-endian.
    public static func keyExchange(publicKey: Data) -> Data {
        precondition(publicKey.count == 64, "P-256-Public-Key muss 64 Byte X‖Y sein")
        var payload = Data([0x00, 0x2E, 0x01, 0x4B, 0x00, 0x04])
        payload.append(publicKey)
        return RCSPFrame.command(payload: payload)
    }
}

extension Data {
    mutating func append(littleEndian value: UInt32) {
        append(contentsOf: [
            UInt8(truncatingIfNeeded: value),
            UInt8(truncatingIfNeeded: value >> 8),
            UInt8(truncatingIfNeeded: value >> 16),
            UInt8(truncatingIfNeeded: value >> 24),
        ])
    }

    /// Liest ein LE32 ab `offset` (relativ zum Anfang der Daten).
    func littleEndianUInt32(at offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= count else { return nil }
        let base = startIndex + offset
        return UInt32(self[base])
            | UInt32(self[base + 1]) << 8
            | UInt32(self[base + 2]) << 16
            | UInt32(self[base + 3]) << 24
    }
}
