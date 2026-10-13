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

    private let importService: WorkImportService
    private let fileStore: RecordingFileStore
    private let logger = Logger(subsystem: "de.gcng.sprechly.work", category: "WorkDeviceVM")

    private var client: D3200Client?
    private var eventTask: Task<Void, Never>?
    private var tickTask: Task<Void, Never>?

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
        stopTicking()
        await client?.disconnect()
        client = nil
        connection = .disconnected
        liveActivity = .idle
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
        case .recordingState(let fileID, let state) where state.isRecording:
            liveActivity = .recording(fileID: fileID, startedAt: .now)
            startTicking()

        case .recordingState(let fileID, let state):
            // Unbekannter Code – nicht raten, nur protokollieren.
            logger.info("Statuscode \(state.rawValue) für \(fileID, privacy: .public)")

        case .recordingFinished(let fileID, let seconds):
            stopTicking()
            liveActivity = .finished(fileID: fileID, duration: TimeInterval(seconds))
            // Die Aufnahme steht jetzt in der Liste.
            await reloadList()

        case .unknown(let group, let type, _):
            logger.info("Unbekanntes Ereignis grp=\(group) typ=\(type)")
        }
    }

    /// Zählt die laufende Aufnahme hoch. Nur Anzeige – maßgeblich ist die
    /// Dauer, die das Gerät am Ende meldet.
    private func startTicking() {
        stopTicking()
        runningDuration = 0
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self, case .recording(_, let startedAt) = liveActivity else { return }
                runningDuration = Date.now.timeIntervalSince(startedAt)
            }
        }
    }

    private func stopTicking() {
        tickTask?.cancel()
        tickTask = nil
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
