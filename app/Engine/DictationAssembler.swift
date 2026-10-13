import Foundation

/// Assembles the "committed" audio timeline for dictaphone-style recording:
/// append a freshly recorded run, truncate at a cursor (to record over a
/// mistake), and finalize to an m4a. Reuses the device-verified editing/merge/
/// export services instead of low-level frame surgery.
protocol DictationAssembling: Sendable {
    var committedDuration: TimeInterval { get async }
    /// The current committed audio (playable for review), or nil if empty.
    func committedURL() async -> URL?
    func append(segment: URL, duration: TimeInterval) async throws
    func truncate(to seconds: TimeInterval) async throws
    /// Encodes the committed timeline to an m4a in Caches and returns its URL.
    func finalizeM4A() async throws -> URL
    func cleanup() async
}

actor DictationAssembler: DictationAssembling {
    enum DictationError: Error { case empty }

    private let editing = AudioEditingService()
    private let merge = AudioMergeService()
    private let export = AudioExportService()
    private let fileStore: RecordingFileStore

    private var url: URL?
    private var duration: TimeInterval = 0

    init(fileStore: RecordingFileStore = RecordingFileStore()) {
        self.fileStore = fileStore
    }

    var committedDuration: TimeInterval { duration }
    func committedURL() async -> URL? { url }

    func append(segment: URL, duration runDuration: TimeInterval) async throws {
        if let existing = url {
            let out = fileStore.temporaryURL(pathExtension: "caf")
            let total = try await merge.merge(sources: [existing, segment], to: out)
            fileStore.removeTemporary(existing)
            fileStore.removeTemporary(segment)
            url = out
            duration = total
        } else {
            // First run: the m4a segment is itself readable for trim/merge/export.
            url = segment
            duration = runDuration
        }
    }

    func truncate(to seconds: TimeInterval) async throws {
        guard let existing = url, seconds < duration else { return }
        guard seconds > 0 else {
            fileStore.removeTemporary(existing)
            url = nil
            duration = 0
            return
        }
        let out = fileStore.temporaryURL(pathExtension: "caf")
        let newDuration = try await editing.render(
            source: existing,
            settings: EditSettings(trim: 0...seconds, speed: 1.0, normalize: false),
            to: out
        )
        fileStore.removeTemporary(existing)
        url = out
        duration = newDuration
    }

    func finalizeM4A() async throws -> URL {
        guard let existing = url else { throw DictationError.empty }
        if existing.pathExtension == RecordingSettings.fileExtension {
            return existing // already an m4a run; the caller moves it into Documents
        }
        let target = fileStore.makeTarget(fileExtension: RecordingSettings.fileExtension).temporaryURL
        try await export.export(workingURL: existing, format: .m4a, to: target)
        fileStore.removeTemporary(existing)
        url = nil
        return target
    }

    func cleanup() {
        if let existing = url { fileStore.removeTemporary(existing) }
        url = nil
        duration = 0
    }
}
