import Foundation
import SoundcoreWorkKit
import Testing

@testable import SprechlyWork

/// Was passiert, wenn die App sich zu einer Aufnahme dazuverbindet, die schon
/// läuft. Das Start-Ereignis ist dann längst vorbei; der einzige Hinweis ist
/// `isRecording` aus der Geräte-Info.
///
/// Die Byte-Folgen sind echte `deviceInfo`-Antworten des Geräts, nur im
/// Aufnahme-Byte (Offset 49 der Nutzlast) verändert.
@Suite("Work: vorgefundene Aufnahme")
@MainActor
struct WorkOpenRecordingTests {
    /// Echte 78-B-Antwort des Geräts, Aufnahme-Byte (Nutzlast-Offset 49,
    /// absolut 59) auf 0.
    private static let infoIdle =
        "09ff00000101014e0001090130332e333633323030376365393133316432373262a0387300a02e730001312e312e380921212121212131010100000030332e3032010100000000000000000000cb"
    /// Dieselbe Antwort mit gesetztem Aufnahme-Byte.
    private static let infoRecording =
        "09ff00000101014e0001090130332e333633323030376365393133316432373262a0387300a02e730001312e312e380921212121212131010100000130332e3032010100000000000000000000cb"
    /// Auf 60 B gekürzt: lang genug zum Parsen, zu kurz für die Zusatzfelder.
    private static let infoShort =
        "09ff00000101013c0001090130332e333633323030376365393133316432373262a0387300a02e730001312e312e3809212121212121310101000000"

    private func deviceInfo(recording: Bool) throws -> D3200DeviceInfo {
        let hex = recording ? Self.infoRecording : Self.infoIdle
        return try D3200DeviceInfo(response: try #require(Data(hex: hex)))
    }

    private func shortDeviceInfo() throws -> D3200DeviceInfo {
        try D3200DeviceInfo(response: try #require(Data(hex: Self.infoShort)))
    }

    @Test("Eine laufende Aufnahme wird beim Verbinden erkannt")
    func openRecordingIsPickedUp() throws {
        let viewModel = WorkDeviceViewModel()
        #expect(viewModel.liveActivity == .idle)

        let jetzt = Date.now
        viewModel.reconcileLiveActivity(with: try deviceInfo(recording: true), now: jetzt)

        #expect(viewModel.liveActivity == .openRecording(detectedAt: jetzt))
        #expect(viewModel.liveActivity.isRecording)
        // Die Laufzeit ist unbekannt – die Anzeige muss das kennzeichnen.
        #expect(!viewModel.liveActivity.hasKnownStart)
    }

    /// Der wichtigste Befund der Messung: Das Bit bleibt in der Pause auf true.
    /// Ein Abgleich, der daraus „läuft" machte, würde eine pausierte Aufnahme
    /// jede 15 Sekunden in den laufenden Zustand zurückwerfen.
    @Test("Eine pausierte Aufnahme bleibt pausiert")
    func pausedStaysPaused() throws {
        let viewModel = WorkDeviceViewModel()
        viewModel.liveActivity = .paused(elapsed: 42)

        viewModel.reconcileLiveActivity(with: try deviceInfo(recording: true))

        #expect(viewModel.liveActivity == .paused(elapsed: 42))
    }

    @Test("Eine laufende Aufnahme behält ihren bekannten Beginn")
    func knownStartIsNotOverwritten() throws {
        let viewModel = WorkDeviceViewModel()
        let beginn = Date.now.addingTimeInterval(-90)
        viewModel.liveActivity = .recording(since: beginn)

        viewModel.reconcileLiveActivity(with: try deviceInfo(recording: true))

        #expect(viewModel.liveActivity == .recording(since: beginn))
    }

    @Test("Meldet das Gerät keine Aufnahme mehr, hört die Anzeige auf zu laufen")
    func aMissedStopClearsTheDisplay() throws {
        let viewModel = WorkDeviceViewModel()
        viewModel.liveActivity = .recording(since: .now.addingTimeInterval(-30))
        viewModel.runningDuration = 30

        viewModel.reconcileLiveActivity(with: try deviceInfo(recording: false))

        #expect(viewModel.liveActivity == .idle)
        #expect(viewModel.runningDuration == 0)
    }

    /// Eine kurze Antwort heißt „weiß ich nicht", nicht „nimmt nicht auf".
    @Test("Eine Antwort ohne Zusatzfelder ändert nichts")
    func aShortAnswerChangesNothing() throws {
        let viewModel = WorkDeviceViewModel()
        let beginn = Date.now.addingTimeInterval(-10)
        viewModel.liveActivity = .recording(since: beginn)

        let info = try shortDeviceInfo()
        #expect(!info.reportsRecordingState)
        viewModel.reconcileLiveActivity(with: info)

        #expect(viewModel.liveActivity == .recording(since: beginn))
    }

    @Test("Ohne Aufnahme bleibt es bei Bereit")
    func idleStaysIdle() throws {
        let viewModel = WorkDeviceViewModel()
        viewModel.reconcileLiveActivity(with: try deviceInfo(recording: false))
        #expect(viewModel.liveActivity == .idle)
    }

    /// Eine fertige Aufnahme ist kein laufender Zustand – die Bestätigung
    /// „Aufnahme fertig" darf der Abgleich nicht wegräumen.
    @Test("Die Fertig-Meldung bleibt stehen")
    func finishedIsLeftAlone() throws {
        let viewModel = WorkDeviceViewModel()
        viewModel.liveActivity = .finished(fileID: 0x6ACF_9147, duration: 14.9)

        viewModel.reconcileLiveActivity(with: try deviceInfo(recording: false))

        #expect(viewModel.liveActivity == .finished(fileID: 0x6ACF_9147, duration: 14.9))
    }

    @Test("Nach dem Verbinden gefunden, dann gestoppt: der Zustand fällt zurück")
    func foundThenStopped() throws {
        let viewModel = WorkDeviceViewModel()
        viewModel.reconcileLiveActivity(with: try deviceInfo(recording: true))
        #expect(viewModel.liveActivity.isRecording)

        viewModel.reconcileLiveActivity(with: try deviceInfo(recording: false))
        #expect(viewModel.liveActivity == .idle)
    }
}

private extension Data {
    /// Hex-String → Data; nur für die Testdaten aus dem Gerätemitschnitt.
    init?(hex: String) {
        guard hex.count.isMultiple(of: 2) else { return nil }
        var bytes = [UInt8]()
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index ..< next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        self = Data(bytes)
    }
}
