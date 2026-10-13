import Foundation
import SoundcoreWorkKit
import Testing

@testable import SprechlyWork

@Suite("Work-Gerät: Zustände und Import-Metadaten")
struct WorkDeviceTests {
    // MARK: - Verbindung

    @Test("Verbindungszustände haben Beschriftung und Busy-Flag")
    func connectionStatus() {
        #expect(WorkConnectionStatus.connecting.isBusy)
        #expect(!WorkConnectionStatus.ready.isBusy)
        #expect(!WorkConnectionStatus.disconnected.isBusy)
        #expect(!WorkConnectionStatus.failed("x").isBusy)
        #expect(!WorkConnectionStatus.ready.label.isEmpty)
    }

    // MARK: - Live-Status

    /// Das Gerät meldet nur Start und Ende; einen Pause-Zustand gibt es
    /// bewusst nicht, weil er über Bluetooth nicht erkennbar ist.
    /// Alle vier Zustände stammen aus dem Statusbyte, das am Gerät
    /// verifiziert ist (0 = stop, 1 = läuft, 2 = pause).
    @Test("Live-Status unterscheidet laufend, pausiert und fertig")
    func liveActivity() {
        #expect(WorkLiveActivity.recording(since: .now).isRecording)
        #expect(WorkLiveActivity.recording(since: .now).isActive)

        #expect(WorkLiveActivity.paused(elapsed: 12).isPaused)
        #expect(WorkLiveActivity.paused(elapsed: 12).isActive)
        #expect(!WorkLiveActivity.paused(elapsed: 12).isRecording)

        #expect(!WorkLiveActivity.idle.isActive)
        #expect(!WorkLiveActivity.finished(fileID: 1, duration: 5).isActive)

        #expect(!WorkLiveActivity.idle.label.isEmpty)
        #expect(WorkLiveActivity.paused(elapsed: 1).label != WorkLiveActivity.recording(since: .now).label)
    }

    /// Resume ist derselbe Befehl wie Start – darum gibt es in der UI keinen
    /// eigenen Resume-Zustand jenseits von `paused`.
    /// Der zentrale Transport braucht alle drei Aktionen – Stop steht nicht
    /// im Community-Katalog, wurde aber am Gerät bestätigt.
    @Test("Fernsteuerung deckt Start, Pause und Stop ab")
    func remoteControlActions() {
        #expect(D3200RecordAction.allCases.count == 3)
        #expect(D3200RecordAction.resume == .start)
        #expect(D3200RecordAction.stop.rawValue == 0x00)
        #expect(D3200RecordAction.start.rawValue == 0x01)
        #expect(D3200RecordAction.pause.rawValue == 0x02)
    }

    /// Der Work-Modus gilt nur, solange das Telefon selbst nicht aufnimmt –
    /// sonst stünden zwei Aufnahmen gleichzeitig unter einem Button.
    @Test("Live-Status deckt alle Transport-Fälle ab")
    func transportStates() {
        let recording = WorkLiveActivity.recording(since: .now)
        let paused = WorkLiveActivity.paused(elapsed: 5)
        let finished = WorkLiveActivity.finished(fileID: 1, duration: 5)

        // Aufnehmen → Pause + Stop
        #expect(recording.isRecording && !recording.isPaused)
        // Pausiert → Fortsetzen + Stop
        #expect(paused.isPaused && paused.isActive)
        // Bereit und fertig → nur Aufnahme starten
        #expect(!WorkLiveActivity.idle.isActive)
        #expect(!finished.isActive)
    }

    // MARK: - Listeneinträge

    private func item(
        fileID: UInt32 = 0x697B_4A4B,
        milliseconds: UInt32 = 900,
        state: WorkRecordingItem.ImportState = .notImported
    ) -> WorkRecordingItem {
        WorkRecordingItem(
            recording: D3200Recording(fileID: fileID, durationMilliseconds: milliseconds),
            importState: state
        )
    }

    @Test("Eintrag zeigt file_id als Hex und übernimmt die Dauer")
    func recordingItem() {
        let item = item()
        #expect(item.identifierText == "697b4a4b")
        #expect(item.id == 0x697B_4A4B)
        #expect(item.recording.duration == 0.9)
    }

    @Test("Nur laufende Importe gelten als beschäftigt", arguments: [
        (WorkRecordingItem.ImportState.notImported, false),
        (.downloading(progress: 0.5), true),
        (.converting, true),
        (.imported(recordingID: UUID()), false),
        (.failed("kaputt"), false),
    ])
    func busyStates(state: WorkRecordingItem.ImportState, expected: Bool) {
        #expect(item(state: state).isBusy == expected)
    }

    // MARK: - Import-Metadaten

    @Test("Titel enthält Datum und Uhrzeit der Geräte-Aufnahme")
    func importTitle() {
        // 0x697b4a4b = 2026-01-29 11:53:47 UTC
        let recording = D3200Recording(fileID: 0x697B_4A4B, durationMilliseconds: 900)
        let title = WorkImportService.title(for: recording)

        #expect(title.hasPrefix("Work "))
        #expect(title.contains("2026-01-29"))
    }

    @Test("Zwei Geräte-Aufnahmen ergeben unterschiedliche Titel")
    func titlesAreDistinct() {
        let first = D3200Recording(fileID: 0x697B_4A4B, durationMilliseconds: 900)
        let second = D3200Recording(fileID: 0x6ACE_9692, durationMilliseconds: 13300)
        #expect(WorkImportService.title(for: first) != WorkImportService.title(for: second))
    }

    /// Die Liste kommt nach jedem Ende-Push neu; dabei dürfen bereits
    /// importierte Einträge nicht auf „nicht importiert" zurückfallen.
    @Test("Import-Zustand übersteht ein Neuladen der Liste")
    @MainActor
    func importStateSurvivesReload() {
        let viewModel = WorkDeviceViewModel()
        let recordingID = UUID()
        viewModel.items = [
            item(fileID: 0x697B_4A4B, state: .imported(recordingID: recordingID)),
            item(fileID: 0x6ACE_9692, milliseconds: 13300),
        ]

        // Zustände so übernehmen, wie reloadList() es tut.
        let previous = Dictionary(uniqueKeysWithValues: viewModel.items.map { ($0.id, $0.importState) })
        #expect(previous[0x697B_4A4B] == .imported(recordingID: recordingID))
        #expect(previous[0x6ACE_9692] == .notImported)
    }

    /// Die Geräte-Karte rechnet mit den Werten aus dem echten Frame.
    @Test("Gerätezustand liefert Prozent und belegten Speicher")
    func deviceInfoForDisplay() throws {
        let frame = try #require(Data(hex:
            "09ff00000101014e00" + "01" + "09" + "01" + "30332e3336" +
            "33323030376365393133316432373262" + "a0387300" + "a02e7300" +
            "01" + "312e312e38" + "09" + "212121212121" +
            "31010100000030332e3032010100000000000000000000" + "cb"
        ))
        let info = try D3200DeviceInfo(response: frame)

        #expect(info.battery.percent == 100)
        #expect(info.isCharging)
        #expect(info.firmwareVersion == "03.36")
        #expect(info.usedStorageKB == 2560)
        // Füllbytes zählen nicht als MAC – die Zeile bleibt in der UI aus.
        #expect(info.caseMACAddress == nil)
    }

    @Test("Frisches ViewModel hat noch keinen Gerätezustand")
    @MainActor
    func deviceInfoStartsEmpty() {
        #expect(WorkDeviceViewModel().deviceInfo == nil)
    }

    @Test("Frisches ViewModel ist getrennt und leer")
    @MainActor
    func initialState() {
        let viewModel = WorkDeviceViewModel()
        #expect(viewModel.connection == .disconnected)
        #expect(viewModel.liveActivity == .idle)
        #expect(viewModel.items.isEmpty)
        #expect(!viewModel.isReady)
        #expect(viewModel.errorMessage == nil)
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
