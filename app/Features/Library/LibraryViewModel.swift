import Foundation
import Observation
import SwiftData
import os

/// Mutations for the library and trash. The list itself is driven by `@Query`
/// in the view; this type performs renames, trashing, restore and deletion,
/// always removing the audio file and waveform sidecar on permanent delete.
@MainActor
@Observable
final class LibraryViewModel {
    /// True while one or more external files are being imported.
    var isImporting = false
    /// Surfaced to the view as an alert; cleared on dismiss.
    var errorMessage: String?

    private let fileStore: RecordingFileStore
    private let importer = AudioImportService()
    private let exporter = AudioExportService()
    private let logger = Logger(subsystem: "de.gcng.sprechly.work", category: "LibraryVM")

    init(fileStore: RecordingFileStore = RecordingFileStore()) {
        self.fileStore = fileStore
    }

    func rename(_ recording: Recording, to title: String, context: ModelContext) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        recording.title = trimmed
        save(context)
    }

    func trash(_ recording: Recording, context: ModelContext) {
        recording.moveToTrash()
        save(context)
    }

    func restore(_ recording: Recording, context: ModelContext) {
        recording.restore()
        save(context)
    }

    func permanentlyDelete(_ recording: Recording, context: ModelContext) {
        fileStore.delete(fileName: recording.fileName, recordingID: recording.id)
        context.delete(recording)
        save(context)
    }

    func emptyTrash(_ recordings: [Recording], context: ModelContext) {
        for recording in recordings where recording.isTrashed {
            fileStore.delete(fileName: recording.fileName, recordingID: recording.id)
            context.delete(recording)
        }
        save(context)
    }

    /// Permanently removes trashed recordings older than the retention window.
    func purgeExpired(_ recordings: [Recording], now: Date = .now, context: ModelContext) {
        let expired = recordings.filter { $0.isExpired(now: now, retention: Recording.trashRetention) }
        guard !expired.isEmpty else { return }
        for recording in expired {
            fileStore.delete(fileName: recording.fileName, recordingID: recording.id)
            context.delete(recording)
        }
        save(context)
    }

    /// Imports external audio files (Files/Music) as first-class recordings:
    /// each is transcoded to the recording format and saved to the library so it
    /// can be played, transcribed and edited like any other recording.
    func importRecordings(from urls: [URL], context: ModelContext) async {
        guard !urls.isEmpty else { return }
        isImporting = true
        defer { isImporting = false }

        var failures = 0
        for url in urls {
            do {
                try await importOne(url, context: context)
            } catch {
                failures += 1
                logger.error("Import failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        if failures > 0 {
            errorMessage = failures == urls.count
                ? String(localized: "Der Import ist fehlgeschlagen.")
                : String(localized: "Einige Dateien konnten nicht importiert werden.")
        }
    }

    private func importOne(_ sourceURL: URL, context: ModelContext) async throws {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer { if didAccess { sourceURL.stopAccessingSecurityScopedResource() } }

        // Lossless intermediate (CAF) → final AAC/m4a in Documents, mirroring the
        // normal recording save path so encoder seams stay clean.
        let working = fileStore.temporaryURL(pathExtension: "caf")
        let target = fileStore.makeRecordingTarget()
        do {
            let duration = try await importer.importToRecordingFormat(sourceURL, to: working)
            try await exporter.export(workingURL: working, format: .m4a, to: target.temporaryURL)
            try fileStore.finalize(temporaryURL: target.temporaryURL, fileName: target.fileName)
            fileStore.removeTemporary(working)

            let baseName = sourceURL.deletingPathExtension().lastPathComponent
            let title = baseName.isEmpty ? Recording.defaultTitle() : baseName
            let recording = Recording(title: title, fileName: target.fileName, duration: duration)
            context.insert(recording)
            try context.save()
            await generateSidecar(for: recording)
        } catch {
            fileStore.removeTemporary(working)
            fileStore.removeTemporary(target.temporaryURL)
            throw error
        }
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

    private func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            logger.error("Save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
