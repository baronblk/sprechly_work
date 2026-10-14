import Foundation
import Testing

@testable import SoundcoreWorkKit

/// Die echten Antworten des eigenen Geräts auf die Abfragen aus §7b
/// (2026-10-13). Dadurch ist die Feldzuordnung belegt, nicht übernommen.
@Suite("Geräte-Info, Akku und Ladezustand")
struct DeviceInfoTests {
    /// Byte für Byte so, wie das Gerät geantwortet hat.
    static let deviceInfoFrame = Data(hex:
        "09ff00000101014e00" +               // Präfix, Gruppe 01, Typ 01, Länge 78
        "01" +                               // vorangestelltes Byte auf Offset 9
        "09" + "01" +                        // Akku roh 9, lädt
        "30332e3336" +                       // Firmware "03.36"
        "33323030376365393133316432373262" + // Seriennummer, 16 ASCII
        "a0387300" + "a02e7300" +            // Speicher gesamt / frei in KB
        "01" + "312e312e38" + "09" +         // Ladecase: lädt, "1.1.8", Akku 9
        "212121212121" +                     // Case-MAC: Füllbytes
        "31010100000030332e3032010100000000000000000000" + "cb"
    )!

    static let batteryFrame = Data(hex: "09ff0000010103" + "0c" + "00" + "0909" + "2b")!
    static let chargingFrame = Data(hex: "09ff0000010104" + "0c" + "00" + "0101" + "1c")!

    @Test("Der echte Frame ist 78 B und als deviceInfo erkannt")
    func frameShape() throws {
        #expect(Self.deviceInfoFrame.count == 78)
        let response = try #require(RCSPFrame.Response(frame: Self.deviceInfoFrame))
        #expect(response.group == 0x01)
        #expect(response.message == .deviceInfo)
        #expect(response.declaredLength == 78)
        #expect(response.hasConsistentLength)
    }

    @Test("Alle Felder der Geräte-Info")
    func parsesDeviceInfo() throws {
        let info = try D3200DeviceInfo(response: Self.deviceInfoFrame)

        #expect(info.battery.raw == 9)
        #expect(info.battery.percent == 100)
        #expect(info.isCharging)
        #expect(info.firmwareVersion == "03.36")
        #expect(info.serialNumber == "32007ce9131d272b")
        #expect(info.totalStorageKB == 7_551_136)
        #expect(info.freeStorageKB == 7_548_576)
        // 2560 KB belegt – passend zu den kurzen Aufnahmen auf dem Gerät,
        // bei 7,20 GiB Gesamtspeicher.
        #expect(info.usedStorageKB == 2560)
        #expect(info.usedStorageBytes == 2560 * 1024)
        #expect(info.caseIsCharging)
        #expect(info.caseFirmwareVersion == "1.1.8")
        #expect(info.caseBattery.percent == 100)
        // 21 21 … sind Füllbytes, keine MAC.
        #expect(info.caseMACAddress == nil)
    }

    /// Die Felder hinter der Ladecase-MAC. `autoPowerOffIndex` stand auf 1,
    /// und die Hersteller-App zeigte zur selben Zeit „24 Stunden".
    @Test("Zusatzfelder: Ruhezustand, Aufnahme-Bit, WLAN-Firmware")
    func parsesExtendedFields() throws {
        let info = try D3200DeviceInfo(response: Self.deviceInfoFrame)

        #expect(info.autoPowerOffEnabled)
        #expect(info.autoPowerOff == .twentyFourHours)
        #expect(info.autoPowerOff?.hours == 24)
        // Das Gerät nahm zum Zeitpunkt der Abfrage nicht auf.
        #expect(!info.isRecording)
        #expect(info.wifiFirmwareVersion == "03.02")
        #expect(!info.pickupIndicatorLightOn)
        #expect(!info.caseIndicatorLightOn)
    }

    /// Dieselbe Rechnung wie die Hersteller-App: Sie zeigt für dieses Gerät
    /// „268h 14m" – das entspricht 8000 Byte je Sekunde, also der reinen
    /// Audio-Nutzlast ohne den 166-Byte-Geräteframe.
    @Test("Verbleibende Aufnahmezeit folgt der Anzeige der Hersteller-App")
    func remainingRecordingTime() throws {
        let info = try D3200DeviceInfo(response: Self.deviceInfoFrame)

        #expect(D3200DeviceInfo.bytesPerSecond == 8000)
        let stunden = info.remainingRecordingTime / 3600
        #expect(stunden > 268 && stunden < 269)
        // Gegenprobe mit dem Frame-Takt wären nur ~259 h.
        #expect(Double(info.freeStorageBytes) / 8300 / 3600 < 260)
    }

    @Test("Ältere Antworten ohne Zusatzfelder stürzen nicht ab")
    func shortResponseWithoutExtendedFields() throws {
        // Auf die Pflichtfelder gekürzt.
        let kurz = Self.deviceInfoFrame.prefix(D3200DeviceInfo.minimumLength)
        let info = try D3200DeviceInfo(response: Data(kurz))

        #expect(info.firmwareVersion == "03.36")
        #expect(info.autoPowerOff == nil)
        #expect(!info.isRecording)
        #expect(info.wifiFirmwareVersion.isEmpty)
    }

    @Test("Akku-Stufen werden zu Prozent", arguments: [
        (UInt8(0), 10), (1, 20), (4, 50), (8, 90), (9, 100),
    ])
    func batteryPercent(raw: UInt8, expected: Int) {
        #expect(D3200BatteryLevel(raw: raw).percent == expected)
    }

    @Test("Akku-Abfrage: beide Stände auf Offset 9")
    func parsesBattery() throws {
        let status = try #require(D3200PowerStatus(response: Self.batteryFrame))
        #expect(status.device == 9)
        #expect(status.chargingCase == 9)
        #expect(status.batteryLevels.device.percent == 100)
        #expect(status.batteryLevels.chargingCase.percent == 100)
        // Deckt sich mit dem Akkufeld der vollen Geräte-Info.
        #expect(try D3200DeviceInfo(response: Self.deviceInfoFrame).battery.raw == status.device)
    }

    @Test("Lade-Abfrage: beide Flags auf Offset 9")
    func parsesCharging() throws {
        let status = try #require(D3200PowerStatus(response: Self.chargingFrame))
        #expect(status.chargingFlags.device)
        #expect(status.chargingFlags.chargingCase)
    }

    @Test("Echte MAC wird formatiert, Nullbytes gelten als Füllung")
    func macHandling() throws {
        func frame(mac: String) -> Data {
            let hex = Self.deviceInfoFrame.hexString
            let macStart = (D3200DeviceInfo.payloadOffset + 38) * 2
            return Data(hex: hex.prefix(macStart) + mac + hex.dropFirst(macStart + 12))!
        }
        #expect(try D3200DeviceInfo(response: frame(mac: "a1b2c3d4e5f6")).caseMACAddress
            == "A1:B2:C3:D4:E5:F6")
        #expect(try D3200DeviceInfo(response: frame(mac: "000000000000")).caseMACAddress == nil)
    }

    @Test("Zu kurze Antwort wird abgewiesen")
    func rejectsShortResponse() {
        #expect(throws: D3200DeviceInfo.Failure.tooShort(20)) {
            try D3200DeviceInfo(response: Data(repeating: 0, count: 20))
        }
        #expect(D3200PowerStatus(response: Data(repeating: 0, count: 10)) == nil)
    }
}
