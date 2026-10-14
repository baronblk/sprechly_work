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
    /// Für die automatische Transkription – sie ist an den KI-Kauf gebunden.
    var entitlements: (any EntitlementProviding)?
    /// Woher die Schalter gelesen werden; in Tests ersetzbar.
    var settings: UserDefaults = .standard
    /// Aufnahme, die gerade transkribiert wird – für die Anzeige in der Karte.
    private(set) var transcribingTitle: String?

    /// Wie oft nach dem Stop auf die nachhinkende Dateiliste gewartet wird.
    static let autoImportRetries = 5

    /// Verhindert, dass die beiden Stop-Meldungen des Geräts den Import
    /// zweimal anstoßen: Beim Stop über die App kommt zuerst eine kurze
    /// Bestätigung ohne `file_id` und danach die lange mit.
    private var isAutoImporting = false

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
            if case .openRecording = liveActivity {
                // Beim Pausieren erscheint die bis dahin unsichtbare Aufnahme
                // in der Dateiliste (am Gerät gemessen). Sie ist genau der
                // Eintrag, den es vorher nicht gab – und trägt die echte
                // bisherige Dauer. Bleibt die Liste zurück, bleibt es bei der
                // Untergrenze, statt eine falsche Zahl zu übernehmen.
                let bekannt = Set(items.map(\.id))
                await reloadList()
                if let neu = items.first(where: { !bekannt.contains($0.id) }) {
                    runningDuration = neu.recording.duration
                    logger.info("Laufzeit der vorgefundenen Aufnahme nachgeholt: \(self.runningDuration) s")
                }
            }
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
        // Läuft schon – der Startzeitpunkt darf nicht zurückgesetzt werden.
        // Bei einer vorgefundenen Aufnahme kennen wir ihn gar nicht, dann
        // bleibt der Zustand lieber ehrlich unbestimmt.
        case .recording, .openRecording: nil
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
                guard let self else { return }
                switch liveActivity {
                case .recording(let since):
                    runningDuration = Date.now.timeIntervalSince(since)
                case .openRecording(let detectedAt):
                    // Untergrenze: so lange läuft sie mindestens noch.
                    runningDuration = Date.now.timeIntervalSince(detectedAt)
                default:
                    return
                }
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
            let info = try await client.fetchDeviceInfo()
            deviceInfo = info
            reconcileLiveActivity(with: info)
        } catch {
            logger.error("Geräte-Info fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Gleicht die Anzeige mit dem ab, was das Gerät über sich sagt.
    ///
    /// Nötig, weil der Live-Zustand sonst allein aus Push-Ereignissen kommt:
    /// Lief die Aufnahme schon, bevor die App verbunden war, ist deren
    /// Start-Ereignis längst vorbei und die App hielte das Gerät für untätig.
    ///
    /// `isRecording` ist am Gerät gemessen auch während einer **Pause** true,
    /// heißt also „eine Aufnahme ist offen". Deshalb wird daraus nie auf
    /// „läuft gerade" geschlossen, sondern nur eine offene Aufnahme angezeigt.
    func reconcileLiveActivity(with info: D3200DeviceInfo, now: Date = .now) {
        // Eine zu kurze Antwort weiß nichts über den Aufnahmezustand – dann
        // darf sie auch nichts zurücksetzen.
        guard info.reportsRecordingState else { return }

        if info.isRecording {
            guard !liveActivity.isActive else { return }
            liveActivity = .openRecording(detectedAt: now)
            runningDuration = 0
            startTicking()
        } else if liveActivity.isActive {
            // Das Gerät kennt keine offene Aufnahme mehr: ein verpasstes
            // Stop-Ereignis darf die Anzeige nicht ewig laufen lassen.
            stopTicking()
            runningDuration = 0
            liveActivity = .idle
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
            let library = libraryRecordings()
            items = recordings
                .sorted { $0.recordedAt > $1.recordedAt }
                .map { recording in
                    let match = Self.libraryMatch(for: recording, in: library)
                    // Importe von vor diesem Feld nachtragen, damit die
                    // Zuordnung danach über die file_id läuft.
                    if let match, match.workFileID == nil {
                        match.workFileID = Int(recording.fileID)
                        logger.info("workFileID nachgetragen: \(match.title, privacy: .public)")
                    }
                    return WorkRecordingItem(
                        recording: recording,
                        importState: Self.importState(
                            previous: previous[recording.fileID],
                            libraryMatch: match?.id
                        )
                    )
                }
            if let context = modelContainer?.mainContext, context.hasChanges {
                try? context.save()
            }
        } catch {
            logger.error("Liste laden fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Zuordnung Bibliothek ↔ Gerät

    /// Wie weit Aufnahmezeitpunkt und Dauer auseinanderliegen dürfen, damit ein
    /// Import ohne gespeicherte `file_id` noch als dieselbe Aufnahme gilt.
    static let matchTimeTolerance: TimeInterval = 1
    static let matchDurationTolerance: TimeInterval = 2

    /// Findet den Bibliothekseintrag zu einer Aufnahme auf dem Gerät.
    ///
    /// Zuerst über die beim Import gespeicherte `workFileID`. Importe aus der
    /// Zeit davor haben sie nicht – die erkennt der Aufnahmezeitpunkt, den der
    /// Import als `createdAt` übernimmt, zusammen mit der Dauer. Aufnahmen im
    /// Papierkorb zählen nicht, damit man sie erneut holen kann.
    static func libraryMatch(
        for recording: D3200Recording,
        in library: [Recording]
    ) -> Recording? {
        let fileID = Int(recording.fileID)
        if let exact = library.first(where: { !$0.isTrashed && $0.workFileID == fileID }) {
            return exact
        }
        return library.first { candidate in
            !candidate.isTrashed
                && candidate.workFileID == nil
                && abs(candidate.createdAt.timeIntervalSince(recording.recordedAt)) <= matchTimeTolerance
                && abs(candidate.duration - recording.duration) <= matchDurationTolerance
        }
    }

    /// Listenzustand einer Geräte-Aufnahme: ein laufender oder gescheiterter
    /// Import dieser Sitzung hat Vorrang, danach entscheidet die Bibliothek.
    static func importState(
        previous: WorkRecordingItem.ImportState?,
        libraryMatch: UUID?
    ) -> WorkRecordingItem.ImportState {
        if let previous {
            switch previous {
            case .downloading, .converting, .failed: return previous
            case .notImported, .imported: break
            }
        }
        if let libraryMatch { return .imported(recordingID: libraryMatch) }
        return .notImported
    }

    /// Bibliothek für die Zuordnung. Ohne Container bleibt die Liste bei
    /// „nicht importiert" – dann fehlt nur die Markierung, sonst nichts.
    private func libraryRecordings() -> [Recording] {
        guard let modelContainer else { return [] }
        let descriptor = FetchDescriptor<Recording>(predicate: #Predicate { !$0.isTrashed })
        return (try? modelContainer.mainContext.fetch(descriptor)) ?? []
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
        guard !isAutoImporting else { return }
        isAutoImporting = true
        defer { isAutoImporting = false }

        // Die Dateiliste des Geräts hinkt nach – dieselbe Eigenheit wie beim
        // Löschen (Spec §7d). Direkt nach dem Stop fehlt die neue Aufnahme
        // dort noch, deshalb ein paar Mal nachfassen statt aufzugeben.
        var item = Self.autoImportCandidate(fileID: fileID, in: items)
        var versuch = 0
        while item == nil, versuch < Self.autoImportRetries {
            versuch += 1
            try? await Task.sleep(for: .seconds(2))
            await reloadList()
            item = Self.autoImportCandidate(fileID: fileID, in: items)
        }

        guard let item else {
            logger.info("""
            Aufnahme \(String(format: "%08x", fileID), privacy: .public)             nach \(versuch) Versuchen nicht in der Liste
            """)
            return
        }

        logger.info("importiere \(String(format: "%08x", fileID), privacy: .public) automatisch")
        await importRecording(item, context: modelContainer.mainContext)

        // Kurze Bestätigung in der Karte, dann wieder weg.
        if let fertig = items.first(where: { $0.id == fileID }),
           case .imported(let recordingID) = fertig.importState {
            recentlyImported = fertig
            await autoTranscribe(recordingID: recordingID, title: WorkImportService.title(for: fertig.recording))
            confirmationTask?.cancel()
            confirmationTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(8))
                guard let self, !Task.isCancelled else { return }
                recentlyImported = nil
            }
        }
    }

    /// Transkribiert die eben importierte Aufnahme, wenn eingeschaltet.
    ///
    /// Nutzt denselben Weg wie der Transkript-Bildschirm, damit es genau ein
    /// Verfahren gibt. Ohne den KI-Kauf liefe dort nur eine Vorschau, die
    /// nichts speichert – dann bleibt es aus.
    private func autoTranscribe(recordingID: UUID, title: String) async {
        guard settings.bool(forKey: WorkSettings.autoTranscribeKey),
              let entitlements, entitlements.isUnlocked(.ai),
              let modelContainer
        else { return }

        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<Recording>(
            predicate: #Predicate { $0.id == recordingID }
        )
        guard let recording = try? context.fetch(descriptor).first else {
            logger.error("Aufnahme für die Transkription nicht gefunden")
            return
        }

        logger.info("transkribiere \(title, privacy: .public) automatisch")
        transcribingTitle = title
        defer { transcribingTitle = nil }

        let transcription = TranscriptionViewModel(recording: recording)
        transcription.configure(modelContext: context, store: entitlements)
        await transcription.loadInstalledLocales()
        await transcription.transcribe()

        if let fehler = transcription.errorMessage {
            logger.error("Transkription fehlgeschlagen: \(fehler, privacy: .public)")
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
                createdAt: item.recording.recordedAt,
                // Klopfmarkierungen des Geräts, nur bis zur tatsächlichen
                // Dauer – die Umwandlung kann minimal kürzen.
                markers: download.markers.filter { $0 <= converted.duration },
                workFileID: Int(fileID)
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
