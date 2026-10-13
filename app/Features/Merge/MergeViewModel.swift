import Foundation
import Observation
import SwiftData
import os

/// Drives the merge screen. Holds the **ordered** list of recordings to merge
/// (reorder state, separate from the library's selection), renders them through
/// the streaming merge → export pipeline, and saves the result as a new recording.
@MainActor
@Observable
final class MergeViewModel {
    enum Phase: Equatable {
        case idle, rendering, done, failed
    }

    private(set) var ordered: [Recording]
    var format: ExportFormat = .m4a

    private(set) var phase: Phase = .idle
    private(set) var progress: Double = 0
    private(set) var exportedURL: URL?
    var errorMessage: String?

    var canMerge: Bool { ordered.count >= 2 }

    private let merge = AudioMergeService()
    private let export = AudioExportService()
    private let fileStore: RecordingFileStore
    private let logger = Logger(subsystem: "de.gcng.sprechly.work", category: "MergeVM")
    private var modelContext: ModelContext?

    init(recordings: [Recording], fileStore: RecordingFileStore = RecordingFileStore()) {
        self.ordered = recordings
        self.fileStore = fileStore
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func move(fromOffsets: IndexSet, toOffset: Int) {
        ordered.move(fromOffsets: fromOffsets, toOffset: toOffset)
    }

    func render() async {
        guard phase != .rendering, canMerge else { return }
        phase = .rendering
        progress = 0
        exportedURL = nil

        let sources = ordered.map { fileStore.audioURL(forFileName: $0.fileName) }
        let working = fileStore.temporaryURL(pathExtension: "caf")
        let target = fileStore.makeTarget(fileExtension: format.fileExtension)

        let (stream, continuation) = AsyncStream<Double>.makeStream()
        let progressTask = Task { [weak self] in
            for await value in stream { self?.progress = value }
        }

        do {
            let duration = try await merge.merge(sources: sources, to: working, progress: continuation)
            try await export.export(workingURL: working, format: format, to: target.temporaryURL)
            try fileStore.finalize(temporaryURL: target.temporaryURL, fileName: target.fileName)

            let recording = Recording(
                title: Self.mergeTitle(),
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
            logger.error("Merge failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            phase = .failed
            fileStore.removeTemporary(target.temporaryURL)
        }

        fileStore.removeTemporary(working)
        continuation.finish()
        progressTask.cancel()
    }

    static func mergeTitle(date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let dateString = formatter.string(from: date)
        return String(localized: "Zusammenführung \(dateString)")
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
