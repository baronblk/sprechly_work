import AVFoundation
import Foundation
import Observation
import SwiftData
import os

/// Drives the editor: an **iterative, non-destructive** cut workflow. The user
/// keeps a selection, removes a middle range, or auto-removes silence — each op
/// produces a new working file and updates the waveform. Saving exports the
/// working result (with optional speed/normalization) as a **new** recording;
/// the original is never touched.
@MainActor
@Observable
final class EditorViewModel {
    enum Phase: Equatable {
        case idle, working, done, failed
    }

    let sourceTitle: String

    private(set) var duration: TimeInterval
    var trimStart: TimeInterval = 0
    var trimEnd: TimeInterval
    private(set) var buckets: [WaveformBucket] = []
    private(set) var hasEdits = false

    // Save options.
    var speed: Double = 1.0
    var normalize: Bool = true
    var format: ExportFormat = .m4a

    private(set) var phase: Phase = .idle
    private(set) var exportedURL: URL?
    var errorMessage: String?

    /// The clamped, valid selection (min length, ordered, within source).
    var trimRange: ClosedRange<TimeInterval> {
        TrimBounds.clamp(start: trimStart, end: trimEnd, duration: duration)
    }

    private let recordingID: UUID
    private let originalFileName: String
    /// The current edited audio (a working file), or nil while still the original.
    private var workingURL: URL?

    private let cut = AudioCutService()
    private let editing = AudioEditingService()
    private let export = AudioExportService()
    private let fileStore: RecordingFileStore
    private let logger = Logger(subsystem: "de.gcng.sprechly.work", category: "EditorVM")
    private var modelContext: ModelContext?

    private var currentSource: URL { workingURL ?? fileStore.audioURL(forFileName: originalFileName) }

    init(recording: Recording, fileStore: RecordingFileStore = RecordingFileStore()) {
        self.sourceTitle = recording.title
        self.originalFileName = recording.fileName
        self.duration = recording.duration
        self.trimEnd = recording.duration
        self.recordingID = recording.id
        self.fileStore = fileStore
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func loadWaveform() async {
        if workingURL == nil, let cached = fileStore.loadPeaks(forRecordingID: recordingID) {
            buckets = cached
            return
        }
        await reloadWaveform(currentSource)
    }

    // MARK: - Cut operations

    func keepSelection() async {
        let range = trimRange
        await apply { try await self.cut.keep(range: range, from: self.currentSource) }
    }

    func removeSelection() async {
        let range = trimRange
        let dur = duration
        await apply { try await self.cut.remove(range: range, from: self.currentSource, duration: dur) }
    }

    func removeSilence() async {
        await apply { try await self.cut.removeSilence(from: self.currentSource) }
    }

    private func apply(_ op: @escaping () async throws -> (URL, TimeInterval)) async {
        guard phase != .working else { return }
        phase = .working
        do {
            let (url, newDuration) = try await op()
            if let old = workingURL { fileStore.removeTemporary(old) }
            workingURL = url
            duration = newDuration
            trimStart = 0
            trimEnd = newDuration
            hasEdits = true
            await reloadWaveform(url)
            phase = .idle
        } catch {
            logger.error("Cut failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            phase = .failed
        }
    }

    // MARK: - Save

    /// Exports the working result (with speed/normalization) as a new recording.
    func save() async {
        guard phase != .working else { return }
        phase = .working
        exportedURL = nil

        let source = currentSource
        let needsRender = speed != 1.0 || normalize
        let working = fileStore.temporaryURL(pathExtension: "caf")
        let target = fileStore.makeTarget(fileExtension: format.fileExtension)

        do {
            let exportSource: URL
            let finalDuration: TimeInterval
            if needsRender {
                finalDuration = try await editing.render(
                    source: source,
                    settings: EditSettings(trim: nil, speed: speed, normalize: normalize),
                    to: working
                )
                exportSource = working
            } else {
                exportSource = source
                finalDuration = duration
            }
            try await export.export(workingURL: exportSource, format: format, to: target.temporaryURL)
            try fileStore.finalize(temporaryURL: target.temporaryURL, fileName: target.fileName)

            let recording = Recording(
                title: String(localized: "\(sourceTitle) (bearbeitet)"),
                fileName: target.fileName,
                duration: finalDuration
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
            if let old = workingURL { fileStore.removeTemporary(old); workingURL = nil }
            phase = .done
        } catch {
            logger.error("Save failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            phase = .failed
            fileStore.removeTemporary(target.temporaryURL)
        }
        fileStore.removeTemporary(working)
    }

    private func reloadWaveform(_ url: URL) async {
        buckets = await Task.detached(priority: .utility) {
            (try? WaveformGenerator.peaks(forFileAt: url, columns: 300)) ?? []
        }.value
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
}
