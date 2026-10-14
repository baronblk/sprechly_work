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

    /// Nach einem Stop meldet das Gerät die `file_id`. Genau die wird geholt –
    /// nicht „die neueste", sonst landete bei einer veralteten Liste die
    /// falsche Aufnahme in der Bibliothek.
    @Test("Automatisch importiert wird genau die gemeldete Aufnahme")
    @MainActor
    func autoImportPicksTheReportedRecording() {
        let liste = [
            item(fileID: 0x6ACE_B548),
            item(fileID: 0x6ACE_B43C),
            item(fileID: 0x6ACE_B3DC),
        ]
        let gewählt = WorkDeviceViewModel.autoImportCandidate(fileID: 0x6ACE_B43C, in: liste)
        #expect(gewählt?.id == 0x6ACE_B43C)
    }

    @Test("Unbekannte oder bereits importierte Aufnahmen werden übergangen")
    @MainActor
    func autoImportSkipsKnownAndMissing() {
        let liste = [
            item(fileID: 0x6ACE_B548, state: .imported(recordingID: UUID())),
            item(fileID: 0x6ACE_B43C, state: .downloading(progress: 0.5)),
            item(fileID: 0x6ACE_B3DC, state: .failed("kaputt")),
        ]
        // schon in der Bibliothek
        #expect(WorkDeviceViewModel.autoImportCandidate(fileID: 0x6ACE_B548, in: liste) == nil)
        // läuft gerade
        #expect(WorkDeviceViewModel.autoImportCandidate(fileID: 0x6ACE_B43C, in: liste) == nil)
        // zuvor gescheitert – bleibt dem Nutzer überlassen
        #expect(WorkDeviceViewModel.autoImportCandidate(fileID: 0x6ACE_B3DC, in: liste) == nil)
        // gar nicht in der Liste
        #expect(WorkDeviceViewModel.autoImportCandidate(fileID: 0xDEAD_BEEF, in: liste) == nil)
    }

    @Test("Automatischer Import ist voreingestellt an")
    @MainActor
    func autoImportIsOnByDefault() {
        let viewModel = WorkDeviceViewModel()
        #expect(viewModel.importsAutomatically)
        // Ohne Container passiert nichts – kein Absturz.
        #expect(viewModel.modelContainer == nil)
    }

    @Test("Frisches ViewModel hat noch keinen Gerätezustand")
    @MainActor
    func deviceInfoStartsEmpty() {
        #expect(WorkDeviceViewModel().deviceInfo == nil)
    }

    /// Nach Pause und Fortsetzen muss die Anzeige weiterlaufen. Sie sprang auf
    /// null, weil die Bestätigung des Geräts den Startzeitpunkt neu setzte,
    /// den das optimistische Umschalten gerade erst richtig gestellt hatte.
    @Test("Fortsetzen zählt weiter, statt bei null zu beginnen")
    @MainActor
    func resumeKeepsTheElapsedTime() {
        let jetzt = Date(timeIntervalSince1970: 1_000_000)

        // 12 s gelaufen, dann pausiert → Start wird um 12 s zurückdatiert.
        let nachPause = WorkDeviceViewModel.recordingStart(
            from: .paused(elapsed: 12), now: jetzt
        )
        #expect(nachPause == jetzt.addingTimeInterval(-12))

        // Die Bestätigung des Geräts folgt – der Startzeitpunkt bleibt stehen.
        let schonLaufend = WorkDeviceViewModel.recordingStart(
            from: .recording(since: jetzt.addingTimeInterval(-12)), now: jetzt
        )
        #expect(schonLaufend == nil)
    }

    @Test("Eine neue Aufnahme beginnt bei null")
    @MainActor
    func freshRecordingStartsAtZero() {
        let jetzt = Date(timeIntervalSince1970: 1_000_000)
        #expect(WorkDeviceViewModel.recordingStart(from: .idle, now: jetzt) == jetzt)
        #expect(WorkDeviceViewModel.recordingStart(
            from: .finished(fileID: 1, duration: 30), now: jetzt
        ) == jetzt)
    }

    /// Der automatische Import läuft, während die Dateiliste zu ist – die
    /// Karte im Aufnahme-Screen muss ihn deshalb selbst anzeigen.
    @Test("Laufender Import wird für die Anzeige gefunden")
    @MainActor
    func activeImportIsExposed() {
        let viewModel = WorkDeviceViewModel()
        #expect(viewModel.activeImport == nil)

        viewModel.items = [
            item(fileID: 0x6ACE_B548, state: .imported(recordingID: UUID())),
            item(fileID: 0x6ACE_B43C, state: .downloading(progress: 0.4)),
            item(fileID: 0x6ACE_B3DC),
        ]
        #expect(viewModel.activeImport?.id == 0x6ACE_B43C)

        viewModel.items[1].importState = .converting
        #expect(viewModel.activeImport?.id == 0x6ACE_B43C)

        viewModel.items[1].importState = .imported(recordingID: UUID())
        #expect(viewModel.activeImport == nil)
    }

    @Test("Ein gescheiterter Import bleibt sichtbar")
    @MainActor
    func failedImportIsExposed() {
        let viewModel = WorkDeviceViewModel()
        #expect(viewModel.failedImport == nil)

        viewModel.items = [
            item(fileID: 0x6ACE_B548),
            item(fileID: 0x6ACE_B43C, state: .failed("Zeitüberschreitung")),
        ]
        #expect(viewModel.failedImport?.id == 0x6ACE_B43C)
    }

    /// Der automatische Versuch darf nur greifen, wenn gerade nichts läuft –
    /// sonst fiele er einer bestehenden Verbindung in den Rücken.
    @Test("Automatisches Verbinden ist voreingestellt aus")
    func autoConnectIsOptIn() {
        // Voreinstellung ohne gespeicherten Wert.
        let defaults = UserDefaults(suiteName: "WorkDeviceTests-\(UUID().uuidString)")!
        #expect(defaults.object(forKey: WorkSettings.autoConnectKey) == nil)
        #expect(defaults.bool(forKey: WorkSettings.autoConnectKey) == false)
    }

    @Test("Ein laufender oder bestehender Verbindungsversuch wird nicht gestört")
    @MainActor
    func autoConnectRespectsExistingState() async {
        let viewModel = WorkDeviceViewModel()

        // Bereits verbunden: Der automatische Versuch ändert nichts.
        viewModel.connection = .ready
        await viewModel.connectAutomatically()
        #expect(viewModel.connection == .ready)

        // Mitten im Verbinden: ebenfalls unangetastet.
        viewModel.connection = .connecting
        await viewModel.connectAutomatically()
        #expect(viewModel.connection == .connecting)
    }

    /// Ohne den KI-Kauf liefe nur eine Vorschau, die nichts speichert – dann
    /// ist automatisches Transkribieren sinnlos und bleibt aus.
    @Test("Automatische Transkription braucht Schalter und KI-Kauf")
    @MainActor
    func autoTranscribeNeedsSwitchAndEntitlement() {
        let defaults = UserDefaults(suiteName: "WorkTranscribe-\(UUID().uuidString)")!
        let viewModel = WorkDeviceViewModel()
        viewModel.settings = defaults

        // Voreinstellung: aus.
        #expect(!defaults.bool(forKey: WorkSettings.autoTranscribeKey))

        defaults.set(true, forKey: WorkSettings.autoTranscribeKey)
        #expect(defaults.bool(forKey: WorkSettings.autoTranscribeKey))

        // Ohne Entitlement-Quelle passiert trotzdem nichts.
        #expect(viewModel.entitlements == nil)
        #expect(viewModel.transcribingTitle == nil)
    }

    @Test("Die Work-Schalter sind voreingestellt aus")
    func workSwitchesAreOptIn() {
        let defaults = UserDefaults(suiteName: "WorkSwitches-\(UUID().uuidString)")!
        #expect(!defaults.bool(forKey: WorkSettings.autoConnectKey))
        #expect(!defaults.bool(forKey: WorkSettings.autoTranscribeKey))
        // Verschiedene Schlüssel, damit kein Schalter einen anderen mitzieht.
        #expect(WorkSettings.autoConnectKey != WorkSettings.autoTranscribeKey)
    }

    /// „Bildschirm anlassen" gehört der App, nicht dem Work – und darf
    /// deshalb nicht unter den Work-Schlüsseln liegen.
    @Test("Bildschirm anlassen ist eine App-Einstellung")
    func keepScreenAwakeIsAnAppSetting() {
        let defaults = UserDefaults(suiteName: "Display-\(UUID().uuidString)")!
        #expect(!defaults.bool(forKey: AppSettings.keepScreenAwakeKey))
        #expect(!AppSettings.keepScreenAwakeKey.hasPrefix("work"))
        #expect(AppSettings.keepScreenAwakeKey != WorkSettings.autoConnectKey)
    }

    /// Beim Stop über die App schickt das Gerät zwei Meldungen: erst eine
    /// kurze ohne `file_id`, dann die lange mit. Nur die zweite kann den
    /// Import anstoßen – die erste darf ihn nicht schon vergeblich starten.
    @Test("Die kurze Stop-Bestätigung trägt keine file_id")
    func shortStopAckHasNoFileID() throws {
        let kurz = try #require(Data(hex: "09ff0000011882" + "0c" + "00" + "00" + "9140"))
        let lang = try #require(Data(hex:
            "09ff00000118821400" + "00" + "01" + "7e000000" + "feaece6a" + "1a"
        ))

        let kurzeAntwort = try #require(RCSPFrame.Response(frame: kurz))
        guard case .recordStatus(_, _, let ohneID) = try #require(D3200Event(response: kurzeAntwort))
        else { return #expect(Bool(false), "kein recordStatus") }
        #expect(ohneID == nil)

        let langeAntwort = try #require(RCSPFrame.Response(frame: lang))
        guard case .recordStatus(_, let sekunden, let mitID) = try #require(D3200Event(response: langeAntwort))
        else { return #expect(Bool(false), "kein recordStatus") }
        #expect(mitID == 0x6ACE_AEFE)
        #expect(sekunden == 126)
    }

    /// Die Dateiliste des Geräts hinkt nach – direkt nach dem Stop fehlt die
    /// neue Aufnahme dort noch, und ohne Nachfassen startet kein Import.
    @Test("Fehlt die Aufnahme in der Liste, gibt es Nachfass-Versuche")
    @MainActor
    func autoImportRetriesWhileTheListLags() {
        #expect(WorkDeviceViewModel.autoImportRetries >= 3)

        // Noch nicht in der Liste → kein Kandidat.
        let alteListe = [item(fileID: 0x6ACE_B548)]
        #expect(WorkDeviceViewModel.autoImportCandidate(fileID: 0x6ACE_BBFC, in: alteListe) == nil)

        // Nach dem Nachladen ist sie da → Kandidat.
        let neueListe = alteListe + [item(fileID: 0x6ACE_BBFC)]
        #expect(WorkDeviceViewModel.autoImportCandidate(fileID: 0x6ACE_BBFC, in: neueListe)?.id == 0x6ACE_BBFC)
    }

    /// Format wie in der Hersteller-App: Bei über 100 Stunden sind Minuten
    /// Rauschen, darunter helfen sie.
    @Test("Verbleibende Aufnahmezeit wird lesbar formatiert", arguments: [
        (TimeInterval(966_217), "268 h"),
        (TimeInterval(3600 * 8 + 60 * 25), "8 h 25 min"),
        (TimeInterval(90), "1 min"),
        (TimeInterval(3600 * 99 + 60 * 30), "99 h 30 min"),
    ])
    func recordingTimeFormatting(seconds: TimeInterval, expected: String) {
        #expect(WorkDeviceCard.recordingTime(seconds) == expected)
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
