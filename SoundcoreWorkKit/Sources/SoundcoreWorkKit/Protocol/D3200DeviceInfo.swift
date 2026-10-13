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
