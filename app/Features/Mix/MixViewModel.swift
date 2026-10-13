import Foundation
import Observation
import SwiftData
import os

/// Drives the mix screen: overlays a chosen second recording on the main one,
/// with a single mix volume, a frame-accurate position offset, and an optional
/// trim of the mix track. The result is a new recording (non-destructive).
@MainActor
@Observable
final class MixViewModel {
    enum Phase: Equatable {
        case idle, rendering, done, failed
    }

    let mainTitle: String
    let mainFileName: String
    let mainDuration: TimeInterval

    private(set) var mainBuckets: [WaveformBucket] = []
    private(set) var mixBuckets: [WaveformBucket] = []

    private(set) var mixDuration: TimeInterval = 0
    private(set) var selectedMixTitle: String?

    var volume: Double = 0.5
    var offset: TimeInterval = 0
    var mixTrimStart: TimeInterval = 0
    var mixTrimEnd: TimeInterval = 0
    var format: ExportFormat = .m4a

    private(set) var phase: Phase = .idle
    private(set) var progress: Double = 0
    private(set) var exportedURL: URL?
    var errorMessage: String?

    var hasMixTrack: Bool { mixURL != nil }
    var canRender: Bool { mixURL != nil && phase != .rendering }
    var mixTrimRange: ClosedRange<TimeInterval> {
        TrimBounds.clamp(start: mixTrimStart, end: mixTrimEnd, duration: mixDuration)
    }

    private let mainID: UUID
    private var mixID: UUID?
    /// Resolved audio source of the chosen mix track — a library recording or an
    /// imported (transcoded) external file.
    private var mixURL: URL?
    /// A transcoded external import to clean up when replaced.
    private var importedTempURL: URL?
    private let mix = AudioMixService()
    private let export = AudioExportService()
    private let importer = AudioImportService()
    private let fileStore: RecordingFileStore
    private let logger = Logger(subsystem: "de.gcng.sprechly.work", category: "MixVM")
    private var modelContext: ModelContext?

    init(recording: Recording, fileStore: RecordingFileStore = RecordingFileStore()) {
        self.mainTitle = recording.title
        self.mainFileName = recording.fileName
        self.mainDuration = recording.duration
        self.mainID = recording.id
        self.fileStore = fileStore
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func loadMainWaveform() async {
        mainBuckets = await peaks(forRecordingID: mainID, fileName: mainFileName)
    }

    func selectMix(_ recording: Recording) async {
        clearImportedTemp()
        mixURL = fileStore.audioURL(forFileName: recording.fileName)
        mixDuration = recording.duration
        mixID = recording.id
        selectedMixTitle = recording.title
        mixTrimStart = 0
        mixTrimEnd = recording.duration
        offset = 0
        mixBuckets = await peaks(forRecordingID: recording.id, fileName: recording.fileName)
    }

    /// Imports an external audio file (Files/Music) as the mix track, transcoding
    /// it to the recording format (48 kHz mono) so the mixer accepts it.
    func importExternal(url: URL) async {
        guard phase != .rendering else { return }
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        let temp = fileStore.temporaryURL(pathExtension: "caf")
        do {
            let duration = try await importer.importToRecordingFormat(url, to: temp)
            clearImportedTemp()
            importedTempURL = temp
            mixURL = temp
            mixID = nil
            mixDuration = duration
            selectedMixTitle = url.deletingPathExtension().lastPathComponent
            mixTrimStart = 0
            mixTrimEnd = duration
            offset = 0
            mixBuckets = await Task.detached(priority: .utility) {
                (try? WaveformGenerator.peaks(forFileAt: temp, columns: 300)) ?? []
            }.value
        } catch {
            fileStore.removeTemporary(temp)
            logger.error("Import failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    private func clearImportedTemp() {
        if let old = importedTempURL { fileStore.removeTemporary(old); importedTempURL = nil }
    }

    func render() async {
        guard let mixURL, phase != .rendering else { return }
        phase = .rendering
        progress = 0
        exportedURL = nil

        let mainURL = fileStore.audioURL(forFileName: mainFileName)
        let working = fileStore.temporaryURL(pathExtension: "caf")
        let target = fileStore.makeTarget(fileExtension: format.fileExtension)

        let range = mixTrimRange
        let trim = TrimBounds.isFullRange(range, duration: mixDuration) ? nil : range
        let settings = MixSettings(volume: volume, offset: offset, mixTrim: trim)

        let (stream, continuation) = AsyncStream<Double>.makeStream()
        let progressTask = Task { [weak self] in
            for await value in stream { self?.progress = value }
        }

        do {
            let duration = try await mix.mix(main: mainURL, mix: mixURL, settings: settings, to: working, progress: continuation)
            try await export.export(workingURL: working, format: format, to: target.temporaryURL)
            try fileStore.finalize(temporaryURL: target.temporaryURL, fileName: target.fileName)

            let recording = Recording(
                title: String(localized: "\(mainTitle) (Mix)"),
                fileName: target.fileName,
                duration: duration
            )
            modelContext?.insert(recording)
            do {
                try modelContext?.save()
            } catch {
                // The audio file is already in Documents at this point. A
                // swallowed save would report success while the recording never
                // appears in the library, leaving an invisible orphan file — so
                // roll both back and surface the failure.
                modelContext?.rollback()
                fileStore.delete(fileName: target.fileName, recordingID: recording.id)
                throw error
            }
            await generateSidecar(for: recording)

            exportedURL = fileStore.audioURL(forFileName: target.fileName)
            phase = .done
        } catch {
            logger.error("Mix failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            phase = .failed
            fileStore.removeTemporary(target.temporaryURL)
        }

        fileStore.removeTemporary(working)
        continuation.finish()
        progressTask.cancel()
    }

    private func generateSidecar(for recording: Recording) async {
        let url = fileStore.audioURL(forFileName: recording.fileName)
        let store = fileStore
        let id = recording.id
        let peaks = await Task.detached(priority: .utility) {
            (try? WaveformGenerator.peaks(forFileAt: url, columns: 300)) ?? []
        }.value
        if !peaks.isEmpty { store.savePeaks(peaks, forRecordingID: id) }
    }

    private func peaks(forRecordingID id: UUID, fileName: String) async -> [WaveformBucket] {
        if let cached = fileStore.loadPeaks(forRecordingID: id) { return cached }
        let url = fileStore.audioURL(forFileName: fileName)
        return await Task.detached(priority: .utility) {
            (try? WaveformGenerator.peaks(forFileAt: url, columns: 300)) ?? []
        }.value
    }
}
