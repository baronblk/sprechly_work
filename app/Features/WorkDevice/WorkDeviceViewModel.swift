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

    private let importService: WorkImportService
    private let fileStore: RecordingFileStore
    private let logger = Logger(subsystem: "de.gcng.sprechly.work", category: "WorkDeviceVM")

    private var client: D3200Client?
    private var eventTask: Task<Void, Never>?
    private var tickTask: Task<Void, Never>?
    private var infoTask: Task<Void, Never>?
    /// Während eines Downloads ruht das Polling – der Client lässt nur einen
    /// Leser gleichzeitig zu.
    private var isTransferring = false

    init(fileStore: RecordingFileStore = RecordingFileStore()) {
        self.fileStore = fileStore
        importService = WorkImportService(fileStore: fileStore)
    }

    /// Ob überhaupt eine Aktion am Gerät möglich ist.
    var isReady: Bool { connection == .ready }

    // MARK: - Verbindung

    func connect() async {
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
            errorMessage = error.localizedDescription
            await client.disconnect()
        }
    }

    func disconnect() async {
        eventTask?.cancel()
        eventTask = nil
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

    // MARK: - Live-Ereignisse

    private func observeEvents(from client: D3200Client) {
        eventTask?.cancel()
        eventTask = Task { [weak self] in
            for await event in await client.events() {
                guard let self else { return }
                await handle(event)
            }
        }
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
            // Nach einer Pause dort weiterzählen, wo sie begann.
            let offset = if case .paused(let elapsed) = liveActivity { elapsed } else { TimeInterval(0) }
            liveActivity = .recording(since: Date.now.addingTimeInterval(-offset))
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

    private func sendRecordControl(_ action: D3200RecordAction) async {
        guard let client else { return }
        do {
            try await client.sendRecordControl(action)
        } catch {
            logger.error("Record-Control fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    /// Zählt die laufende Aufnahme hoch. Nur Anzeige – maßgeblich ist die
    /// Dauer, die das Gerät am Ende meldet.
    private func startTicking() {
        stopTicking()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
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
