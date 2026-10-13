import Foundation
import Observation
import SoundcoreWorkKit
import SwiftData
import os

/// Steuert Verbindung, Aufnahmeliste und Import des Soundcore Work.
///
/// Die Live-Anzeige speist sich aus `D3200Client.events()`: sobald am Gerät
/// selbst eine Aufnahme startet oder endet, schickt es einen Push. Nach dem
/// Ende wird die Liste automatisch neu geladen, damit die neue Aufnahme
/// ohne Zutun auftaucht.
@MainActor
@Observable
final class WorkDeviceViewModel {
    var connection: WorkConnectionStatus = .disconnected
    var liveActivity: WorkLiveActivity = .idle
    var items: [WorkRecordingItem] = []
    var errorMessage: String?
    /// Läuft, während die Liste geladen wird.
    var isLoadingList = false

    /// Verstrichene Zeit der laufenden Aufnahme, für die Anzeige.
    var runningDuration: TimeInterval = 0
    /// Zuletzt abgefragter Gerätezustand; `nil`, solange keiner vorliegt.
    var deviceInfo: D3200DeviceInfo?
    /// Läuft, solange ein Steuerbefehl unterwegs ist – die Transport-Tasten
    /// sperren sich so lange, damit ein zweiter Tipp nicht denselben Befehl
    /// nochmal schickt.
    private(set) var isSendingCommand = false

    private let importService: WorkImportService
    private let fileStore: RecordingFileStore
    private let logger = Logger(subsystem: "de.gcng.sprechly.work", category: "WorkDeviceVM")

    /// Für den automatischen Import nach einer Aufnahme. Wird beim App-Start
    /// gesetzt; ohne ihn bleibt der Import manuell.
    var modelContainer: ModelContainer?
    /// Ob eine am Gerät beendete Aufnahme von selbst in die Bibliothek wandert.
    var importsAutomatically = true

    private var client: D3200Client?
    private var eventTask: Task<Void, Never>?
    private var tickTask: Task<Void, Never>?
    private var infoTask: Task<Void, Never>?
    private var confirmationTask: Task<Void, Never>?
    /// Während eines Downloads ruht das Polling – der Client lässt nur einen
    /// Leser gleichzeitig zu.
    private var isTransferring = false

    init(fileStore: RecordingFileStore = RecordingFileStore()) {
        self.fileStore = fileStore
        importService = WorkImportService(fileStore: fileStore)
    }

    /// Ob überhaupt eine Aktion am Gerät möglich ist.
    var isReady: Bool { connection == .ready }

    /// Die Aufnahme, die gerade geholt wird – für die Anzeige im
    /// Aufnahme-Screen, wo die Dateiliste nicht offen ist.
    var activeImport: WorkRecordingItem? { items.first { $0.isBusy } }

    /// Zuletzt fertig importierte Aufnahme; wird kurz bestätigt und dann
    /// wieder ausgeblendet, damit die Karte nicht dauerhaft zugestellt ist.
    private(set) var recentlyImported: WorkRecordingItem?

    /// Ein Import, der schiefging – bleibt stehen, bis er erneut versucht wird.
    var failedImport: WorkRecordingItem? {
        items.first { if case .failed = $0.importState { return true } else { return false } }
    }

    // MARK: - Verbindung

    /// Verbindet beim Öffnen der App, sofern eingeschaltet.
    ///
    /// Scheitert still: Ein automatischer Versuch, der das Gerät nicht findet
    /// – weil es im Case liegt oder am Handy hängt –, ist der Normalfall und
    /// kein Anlass für eine Fehlermeldung.
    func connectAutomatically() async {
        guard connection != .connecting, connection != .ready else { return }
        await connect(automatically: true)
    }

    func connect(automatically: Bool = false) async {
        guard connection != .connecting, connection != .ready else { return }
        connection = .connecting
        errorMessage = nil

        let client = D3200Client(transport: BLETransport())
        do {
            try await client.connect()
            try await client.authenticate()
            try await client.syncTime()
            self.client = client
            connection = .ready
            observeEvents(from: client)
            await refreshDeviceInfo()
            startPollingDeviceInfo()
            await reloadList()
        } catch {
            logger.error("Verbinden fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            connection = .failed(error.localizedDescription)
            // Nur ein selbst ausgelöster Versuch rechtfertigt einen Hinweis.
            if !automatically { errorMessage = error.localizedDescription }
            await client.disconnect()
        }
    }

    func disconnect() async {
        eventTask?.cancel()
        eventTask = nil
        infoTask?.cancel()
        infoTask = nil
        confirmationTask?.cancel()
        confirmationTask = nil
        recentlyImported = nil
        stopTicking()
        await client?.disconnect()
        client = nil
        connection = .disconnected
        liveActivity = .idle
        deviceInfo = nil
        items = []
    }

    // MARK: - Live-Ereignisse

    private func observeEvents(from client: D3200Client) {
        eventTask?.cancel()
        eventTask = Task { [weak self] in
            for await event in await client.events() {
                guard let self else { return }
                await handle(event)
            }
            // Der Strom endet, wenn die Verbindung wegfällt – etwa weil
            // Bluetooth abgeschaltet wurde. Ohne das bliebe „Verbunden" stehen.
            guard let self, !Task.isCancelled else { return }
            await handleConnectionLost()
        }
    }

    /// Die Verbindung ist von außen weggefallen (Bluetooth aus, Gerät weg).
    private func handleConnectionLost() async {
        guard connection != .disconnected else { return }
        logger.info("Verbindung zum Work verloren")
        infoTask?.cancel()
        infoTask = nil
        stopTicking()
        await client?.disconnect()
        client = nil
        connection = .disconnected
        liveActivity = .idle
        deviceInfo = nil
        items = []
    }

    private func handle(_ event: D3200Event) async {
        switch event {
        case .recordStatus(let status, let seconds, let fileID):
            await apply(status: status, seconds: seconds, fileID: fileID)

        case .recordingState(let fileID, let state):
            // Kündigt nur eine neu angelegte Aufnahme an – kein Status.
            logger.info("Neue Aufnahme \(String(format: "%08x", fileID), privacy: .public) (Code \(state.rawValue))")

        case .unknown(let group, let type, _):
            logger.info("Unbekanntes Ereignis grp=\(group) typ=\(type)")
        }
    }

    private func apply(status: D3200RecordStatus, seconds: UInt32?, fileID: UInt32?) async {
        switch status {
        case .recording:
            if let since = Self.recordingStart(from: liveActivity, now: .now) {
                liveActivity = .recording(since: since)
            }
            startTicking()

        case .paused:
            stopTicking()
            liveActivity = .paused(elapsed: runningDuration)

        case .stopped:
            stopTicking()
            runningDuration = 0
            liveActivity = .finished(
                fileID: fileID,
                duration: seconds.map(TimeInterval.init) ?? 0
            )
            // Die Aufnahme steht jetzt in der Liste.
            await reloadList()
            if let fileID { await autoImport(fileID: fileID) }

        default:
            logger.info("Unbekannter Aufnahmestatus \(status.rawValue)")
        }
    }

    // MARK: - Fernsteuerung

    /// Startet eine Aufnahme am Gerät. Nach einer Pause setzt derselbe
    /// Befehl sie fort – das Gerät leitet das aus seinem Status ab.
    func startRecording() async {
        await sendRecordControl(.start)
    }

    func pauseRecording() async {
        await sendRecordControl(.pause)
    }

    /// Beendet die Aufnahme am Gerät. Der Work meldet danach Dauer und
    /// `file_id`, und die Liste wird neu geladen.
    func stopRecording() async {
        await sendRecordControl(.stop)
    }

    /// Schickt einen Steuerbefehl und zeigt die erwartete Wirkung sofort an.
    ///
    /// Das Gerät bestätigt erst nach einem Rundlauf über BLE. Ohne die
    /// vorweggenommene Anzeige wirkt die Taste tot und man tippt erneut –
    /// und schickt dabei denselben Befehl mehrfach.
    private func sendRecordControl(_ action: D3200RecordAction) async {
        guard let client, !isSendingCommand else { return }
        isSendingCommand = true
        defer { isSendingCommand = false }

        applyOptimisticState(for: action)
        do {
            try await client.sendRecordControl(action)
        } catch {
            logger.error("Record-Control fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    /// Startzeitpunkt für „läuft" – oder `nil`, wenn der bisherige gilt.
    ///
    /// Zwei Dinge auf einmal: Nach einer Pause wird so zurückdatiert, dass die
    /// Anzeige weiterläuft statt bei null zu beginnen. Und läuft die Aufnahme
    /// in der Anzeige bereits, bleibt ihr Startzeitpunkt unangetastet – sonst
    /// setzte die Bestätigung des Geräts die Uhr zurück, die das optimistische
    /// Umschalten gerade erst richtig gestellt hat.
    static func recordingStart(from previous: WorkLiveActivity, now: Date) -> Date? {
        switch previous {
        case .recording: nil
        case .paused(let elapsed): now.addingTimeInterval(-elapsed)
        case .idle, .finished: now
        }
    }

    /// Nimmt die Wirkung des Befehls vorweg. Die Meldung des Geräts
    /// überschreibt das gleich darauf – sie bleibt maßgeblich.
    private func applyOptimisticState(for action: D3200RecordAction) {
        switch action {
        case .start:
            if let since = Self.recordingStart(from: liveActivity, now: .now) {
                liveActivity = .recording(since: since)
            }
            startTicking()
        case .pause:
            stopTicking()
            liveActivity = .paused(elapsed: runningDuration)
        case .stop:
            stopTicking()
            liveActivity = .finished(fileID: nil, duration: runningDuration)
        }
    }

    /// Zählt die laufende Aufnahme hoch. Nur Anzeige – maßgeblich ist die
    /// Dauer, die das Gerät am Ende meldet.
    private func startTicking() {
        stopTicking()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                // Die Anzeige zeigt Hundertstel – bei 500 ms wirkte sie hakelig.
                try? await Task.sleep(for: .milliseconds(50))
                guard let self, case .recording(let since) = liveActivity else { return }
                runningDuration = Date.now.timeIntervalSince(since)
            }
        }
    }

    private func stopTicking() {
        tickTask?.cancel()
        tickTask = nil
    }

    // MARK: - Gerätezustand

    /// Holt Akku, Speicher, Firmware und Ladecase-Zustand.
    func refreshDeviceInfo() async {
        guard let client, !isTransferring else { return }
        do {
            deviceInfo = try await client.fetchDeviceInfo()
        } catch {
            logger.error("Geräte-Info fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Manche Firmwares aktualisieren den Zustand nur auf Abfrage, daher
    /// regelmäßig nachfragen – so wie es die Hersteller-App tut.
    private func startPollingDeviceInfo(every interval: Duration = .seconds(15)) {
        infoTask?.cancel()
        infoTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard let self, !Task.isCancelled else { return }
                await refreshDeviceInfo()
            }
        }
    }

    // MARK: - Aufnahmeliste

    func reloadList() async {
        guard let client else { return }
        isLoadingList = true
        defer { isLoadingList = false }
        do {
            let recordings = try await client.listRecordings()
            // Bestehende Import-Zustände behalten, damit die Liste nicht zurückfällt.
            let previous = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.importState) })
            items = recordings
                .sorted { $0.recordedAt > $1.recordedAt }
                .map { WorkRecordingItem(recording: $0, importState: previous[$0.fileID] ?? .notImported) }
        } catch {
            logger.error("Liste laden fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Löschen

    /// Löscht eine Aufnahme auf dem Gerät. **Unwiderruflich.**
    ///
    /// Die Ansicht fragt vorher nach. Bereits importierte Aufnahmen bleiben
    /// in der Bibliothek – gelöscht wird nur die Kopie auf dem Work.
    func deleteRecording(_ item: WorkRecordingItem) async {
        guard let client, !item.isBusy else { return }
        do {
            try await client.deleteRecording(fileID: item.id)
            items.removeAll { $0.id == item.id }
            logger.info("Aufnahme \(item.identifierText, privacy: .public) gelöscht")
            await refreshDeviceInfo()
        } catch {
            logger.error("Löschen fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    /// Löscht mehrere Aufnahmen nacheinander.
    ///
    /// Bewusst sequenziell: Das Gerät bearbeitet Befehle ohnehin einzeln, und
    /// so bleibt bei einem Fehler nachvollziehbar, was weg ist und was nicht.
    /// Gibt zurück, wie viele tatsächlich gelöscht wurden.
    @discardableResult
    func deleteRecordings(_ items: [WorkRecordingItem]) async -> Int {
        var deleted = 0
        for item in items {
            let before = self.items.count
            await deleteRecording(item)
            if self.items.count < before { deleted += 1 }
        }
        return deleted
    }

    // MARK: - Automatischer Import

    /// Holt die gerade beendete Aufnahme von selbst in die Bibliothek.
    ///
    /// Das Gerät nennt im Stop-Ereignis die `file_id`; genau diese wird
    /// importiert – nicht einfach die neueste, damit nichts Falsches landet,
    /// wenn die Liste noch nicht aktuell ist.
    private func autoImport(fileID: UInt32) async {
        guard importsAutomatically, let modelContainer else { return }
        guard let item = Self.autoImportCandidate(fileID: fileID, in: items) else { return }

        logger.info("importiere \(String(format: "%08x", fileID), privacy: .public) automatisch")
        await importRecording(item, context: modelContainer.mainContext)

        // Kurze Bestätigung in der Karte, dann wieder weg.
        if let fertig = items.first(where: { $0.id == fileID }),
           case .imported = fertig.importState {
            recentlyImported = fertig
            confirmationTask?.cancel()
            confirmationTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(8))
                guard let self, !Task.isCancelled else { return }
                recentlyImported = nil
            }
        }
    }

    /// Welche Aufnahme nach einem Stop automatisch importiert wird.
    ///
    /// Genau die `file_id` aus dem Stop-Ereignis, und nur, wenn sie noch nicht
    /// in der Bibliothek liegt. Bewusst nicht „die neueste": Wenn die Liste
    /// noch nicht aktuell ist, landete sonst die falsche Aufnahme.
    static func autoImportCandidate(
        fileID: UInt32,
        in items: [WorkRecordingItem]
    ) -> WorkRecordingItem? {
        guard let item = items.first(where: { $0.id == fileID }) else { return nil }
        return item.importState == .notImported ? item : nil
    }

    // MARK: - Import

    func importRecording(_ item: WorkRecordingItem, context: ModelContext) async {
        guard let client else { return }
        guard !item.isBusy else { return }

        update(item.id) { $0.importState = .downloading(progress: 0) }
        isTransferring = true
        defer { isTransferring = false }
        do {
            if await !client.hasSessionKey {
                try await client.performKeyExchange()
            }

            let fileID = item.id
            let download = try await client.download(fileID: fileID) { [weak self] done, total in
                guard total > 0 else { return }
                let fraction = Double(done) / Double(total)
                Task { @MainActor [weak self] in
                    self?.update(fileID) { $0.importState = .downloading(progress: fraction) }
                }
            }

            update(fileID) { $0.importState = .converting }
            let converted = try await importService.convert(download)

            let recording = Recording(
                title: WorkImportService.title(for: item.recording),
                fileName: converted.fileName,
                duration: converted.duration,
                createdAt: item.recording.recordedAt
            )
            context.insert(recording)
            try context.save()
            await generateSidecar(for: recording)

            update(fileID) { $0.importState = .imported(recordingID: recording.id) }
            logger.info("Import fertig: \(recording.title, privacy: .public)")
        } catch {
            logger.error("Import fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            update(item.id) { $0.importState = .failed(error.localizedDescription) }
            errorMessage = error.localizedDescription
        }
    }

    /// Importiert alles, was noch nicht in der Bibliothek liegt.
    func importAll(context: ModelContext) async {
        for item in items where item.importState == .notImported {
            await importRecording(item, context: context)
        }
    }

    private func update(_ fileID: UInt32, _ change: (inout WorkRecordingItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == fileID }) else { return }
        change(&items[index])
    }

    /// Wellenform-Sidecar wie beim normalen Import erzeugen.
    private func generateSidecar(for recording: Recording) async {
        let url = fileStore.audioURL(forFileName: recording.fileName)
        let store = fileStore
        let id = recording.id
        let peaks = await Task.detached(priority: .utility) {
            (try? WaveformGenerator.peaks(forFileAt: url, columns: 300)) ?? []
        }.value
        guard !peaks.isEmpty else { return }
        store.savePeaks(peaks, forRecordingID: id)
    }
}
