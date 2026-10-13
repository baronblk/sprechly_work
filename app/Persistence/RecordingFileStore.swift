import Foundation
import os

/// Owns the on-disk locations for recordings and their waveform sidecars.
/// Final audio lives in Documents (backed up); temporary capture and the
/// regenerable peaks sidecar live in Caches.
struct RecordingFileStore: Sendable {
    let documentsURL: URL
    let cachesURL: URL

    private var fileManager: FileManager { .default }

    init(documentsURL: URL, cachesURL: URL) {
        self.documentsURL = documentsURL
        self.cachesURL = cachesURL
    }

    init() {
        let fm = FileManager.default
        documentsURL = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cachesURL = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }

    /// Resolves a relative `fileName` to its absolute Documents URL.
    func audioURL(forFileName fileName: String) -> URL {
        documentsURL.appendingPathComponent(fileName)
    }

    func sidecarURL(forRecordingID id: UUID) -> URL {
        cachesURL.appendingPathComponent("\(id.uuidString).peaks")
    }

    /// A fresh temporary capture URL in Caches plus the relative file name the
    /// finalized recording will use in Documents.
    func makeRecordingTarget() -> (temporaryURL: URL, fileName: String) {
        makeTarget(fileExtension: RecordingSettings.fileExtension)
    }

    /// A fresh temporary URL in Caches + the relative file name for a finalized
    /// recording with the given extension (used by editing/export).
    func makeTarget(fileExtension: String) -> (temporaryURL: URL, fileName: String) {
        let fileName = "\(UUID().uuidString).\(fileExtension)"
        return (cachesURL.appendingPathComponent(fileName), fileName)
    }

    /// A scratch URL in Caches for an intermediate render (not finalized).
    func temporaryURL(pathExtension: String) -> URL {
        cachesURL.appendingPathComponent("\(UUID().uuidString).\(pathExtension)")
    }

    /// Removes a temporary/intermediate file (no-op if missing).
    func removeTemporary(_ url: URL) {
        remove(url)
    }

    /// Atomically moves a finished capture from Caches into Documents.
    func finalize(temporaryURL: URL, fileName: String) throws {
        try fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        let destination = audioURL(forFileName: fileName)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: temporaryURL, to: destination)
    }

    /// Removes the audio file **and** the waveform sidecar — no orphans.
    func delete(fileName: String, recordingID: UUID) {
        remove(audioURL(forFileName: fileName))
        remove(sidecarURL(forRecordingID: recordingID))
    }

    func loadPeaks(forRecordingID id: UUID) -> [WaveformBucket]? {
        let url = sidecarURL(forRecordingID: id)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([WaveformBucket].self, from: data)
    }

    func savePeaks(_ peaks: [WaveformBucket], forRecordingID id: UUID) {
        guard let data = try? JSONEncoder().encode(peaks) else { return }
        try? fileManager.createDirectory(at: cachesURL, withIntermediateDirectories: true)
        try? data.write(to: sidecarURL(forRecordingID: id), options: .atomic)
    }

    private func remove(_ url: URL) {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try? fileManager.removeItem(at: url)
    }
}
