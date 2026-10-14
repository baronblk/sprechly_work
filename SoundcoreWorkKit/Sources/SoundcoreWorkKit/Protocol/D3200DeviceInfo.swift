import Foundation

/// Akkustand des Geräts.
///
/// Das Gerät meldet **0–9-Stufen**, nicht Prozent. Am eigenen Gerät beobachtet
/// wurde bisher nur die Stufe 9; die Umrechnung stammt aus dem Community-Repo.
public struct D3200BatteryLevel: Sendable, Equatable, Hashable {
    /// Rohwert, wie das Gerät ihn meldet.
    public let raw: UInt8

    public init(raw: UInt8) { self.raw = raw }

    /// Stufe → Prozent: `(raw + 1) * 10`, also 0 → 10 %, 9 → 100 %.
    /// Werte über 9 werden unverändert als Prozent gelesen.
    public var percent: Int { raw <= 9 ? (Int(raw) + 1) * 10 : Int(raw) }
}

/// Zustand des Soundcore Work, wie ihn die Geräte-Info liefert (Spec §7b).
///
/// Am eigenen Gerät gegen den echten 78-Byte-Frame verifiziert (2026-10-13).
public struct D3200DeviceInfo: Sendable, Equatable {
    /// Nutzdaten beginnen hier; auf Offset 9 steht ein vorangestelltes Byte.
    static let payloadOffset = 10
    /// Kürzester Frame, der alle Pflichtfelder trägt.
    static let minimumLength = payloadOffset + 44
    /// Ab hier stehen die Zusatzfelder; ältere Firmware liefert sie evtl. nicht.
    static let extendedLength = payloadOffset + 60

    public let battery: D3200BatteryLevel
    public let isCharging: Bool
    /// Firmware des Geräts, z. B. `03.36`.
    public let firmwareVersion: String
    public let serialNumber: String
    /// Gesamter Speicher in Kilobyte.
    public let totalStorageKB: UInt32
    /// Freier Speicher in Kilobyte.
    public let freeStorageKB: UInt32
    public let caseIsCharging: Bool
    public let caseFirmwareVersion: String
    public let caseBattery: D3200BatteryLevel
    /// MAC des Ladecase – `nil`, wenn das Gerät nur Füllbytes liefert.
    public let caseMACAddress: String?

    /// Ob auf dem Gerät eine Aufnahme **offen** ist – direkt aus der Geräte-Info.
    ///
    /// Verlässlicher als die Pushes: Wer sich mitten in eine laufende Aufnahme
    /// verbindet, hat deren Start-Push nie gesehen.
    ///
    /// Am Gerät gemessen (2026-10-14): Das Bit steht während der Aufnahme
    /// **und während einer Pause** auf 1. Es heißt also „eine Aufnahme ist
    /// offen", nicht „sie läuft gerade" – die beiden sind darüber nicht zu
    /// unterscheiden.
    public let isRecording: Bool
    /// Ob die Antwort überhaupt lang genug war, um `isRecording` zu enthalten.
    ///
    /// Ohne diese Unterscheidung wäre eine kurze Antwort nicht von „nimmt
    /// nicht auf" zu trennen – und ein Abgleich würde eine laufende Aufnahme
    /// aus der Anzeige werfen.
    public let reportsRecordingState: Bool
    /// Ob der Ruhezustand eingeschaltet ist.
    public let autoPowerOffEnabled: Bool
    /// Zeit bis zum Ruhezustand.
    public let autoPowerOff: D3200AutoPowerOff?
    /// Firmware des WLAN-Moduls.
    public let wifiFirmwareVersion: String
    public let pickupIndicatorLightOn: Bool
    public let caseIndicatorLightOn: Bool

    /// Wie lange noch aufgenommen werden kann, bei 160 Byte Audio je 20 ms.
    ///
    /// Dieselbe Rechnung wie die Hersteller-App: Sie zeigt für 7,19 GB frei
    /// „268h 14m", was 8000 Byte je Sekunde entspricht – also der reinen
    /// Audio-Nutzlast, nicht dem 166-Byte-Geräteframe.
    public static let bytesPerSecond: Double = 160 / D3200Recording.secondsPerFrame

    public var remainingRecordingTime: TimeInterval {
        Double(freeStorageBytes) / Self.bytesPerSecond
    }

    /// Belegter Speicher in Kilobyte.
    public var usedStorageKB: UInt32 { totalStorageKB >= freeStorageKB ? totalStorageKB - freeStorageKB : 0 }

    public var totalStorageBytes: Int64 { Int64(totalStorageKB) * 1024 }
    public var freeStorageBytes: Int64 { Int64(freeStorageKB) * 1024 }
    public var usedStorageBytes: Int64 { Int64(usedStorageKB) * 1024 }

    public enum Failure: Error, LocalizedError, Equatable {
        case tooShort(Int)

        public var errorDescription: String? {
            switch self {
            case .tooShort(let length):
                "Geräte-Info braucht mindestens \(D3200DeviceInfo.minimumLength) Byte (war \(length))."
            }
        }
    }

    /// Parst die Antwort auf `D3200Commands.deviceInfo()`.
    public init(response: Data) throws {
        guard response.count >= Self.minimumLength else {
            throw Failure.tooShort(response.count)
        }
        let bytes = Data(response)
        let base = bytes.startIndex + Self.payloadOffset

        func byte(_ offset: Int) -> UInt8 { bytes[base + offset] }
        func ascii(_ offset: Int, _ length: Int) -> String {
            let slice = bytes[base + offset ..< base + offset + length]
            return String(decoding: slice, as: UTF8.self)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\0 "))
        }

        battery = D3200BatteryLevel(raw: byte(0))
        isCharging = byte(1) != 0
        firmwareVersion = ascii(2, 5)
        serialNumber = ascii(7, 16)
        totalStorageKB = bytes.littleEndianUInt32(at: Self.payloadOffset + 23) ?? 0
        freeStorageKB = bytes.littleEndianUInt32(at: Self.payloadOffset + 27) ?? 0
        caseIsCharging = byte(31) != 0
        caseFirmwareVersion = ascii(32, 5)
        caseBattery = D3200BatteryLevel(raw: byte(37))

        // Zusatzfelder hinter der Ladecase-MAC. Sie fehlen bei kürzeren
        // Antworten, deshalb nur lesen, wenn der Frame lang genug ist.
        let hasExtended = bytes.count >= Self.extendedLength
        autoPowerOffEnabled = hasExtended && byte(45) != 0
        autoPowerOff = hasExtended ? D3200AutoPowerOff(rawValue: byte(46)) : nil
        pickupIndicatorLightOn = hasExtended && byte(47) != 0
        caseIndicatorLightOn = hasExtended && byte(48) != 0
        isRecording = hasExtended && byte(49) != 0
        reportsRecordingState = hasExtended
        wifiFirmwareVersion = hasExtended ? ascii(50, 5) : ""

        let mac = Array(bytes[base + 38 ..< base + 44])
        // Füllbytes: das Gerät meldet 21 21 … bzw. 00 00 …, wenn kein Case da ist.
        let isPadding = mac.allSatisfy { $0 == 0x21 } || mac.allSatisfy { $0 == 0x00 }
        caseMACAddress = isPadding
            ? nil
            : mac.map { String(format: "%02X", $0) }.joined(separator: ":")
    }
}

/// Antwort auf `D3200Commands.battery()` bzw. `charging()` – zwei Bytes ab Offset 9.
public struct D3200PowerStatus: Sendable, Equatable {
    static let payloadOffset = 9

    public let device: UInt8
    public let chargingCase: UInt8

    public init?(response: Data) {
        let bytes = Data(response)
        guard bytes.count >= Self.payloadOffset + 2 else { return nil }
        let base = bytes.startIndex + Self.payloadOffset
        device = bytes[base]
        chargingCase = bytes[base + 1]
    }

    /// Als Akkustände gelesen.
    public var batteryLevels: (device: D3200BatteryLevel, chargingCase: D3200BatteryLevel) {
        (D3200BatteryLevel(raw: device), D3200BatteryLevel(raw: chargingCase))
    }

    /// Als Lade-Flags gelesen.
    public var chargingFlags: (device: Bool, chargingCase: Bool) {
        (device != 0, chargingCase != 0)
    }
}


/// Zeit, nach der das Gerät in den Ruhezustand wechselt.
///
/// Am Gerät abgeglichen: Index 1 stand auf „24 Stunden", wie die
/// Hersteller-App zur selben Zeit anzeigte. Im Ruhezustand funkt das Gerät
/// nicht mehr – es wacht durch Schütteln oder die Aufnahmetaste auf.
public enum D3200AutoPowerOff: UInt8, Sendable, CaseIterable {
    case eightHours = 0
    case twentyFourHours = 1
    case fortyEightHours = 2

    public var hours: Int {
        switch self {
        case .eightHours: 8
        case .twentyFourHours: 24
        case .fortyEightHours: 48
        }
    }
}
