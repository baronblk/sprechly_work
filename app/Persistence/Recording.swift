import Foundation
import SwiftData

/// A single recording. Only metadata lives here; the audio is a file in the
/// Documents container, referenced by the **relative** `fileName` (never an
/// absolute URL — the container path changes between launches).
///
/// `TranscriptSegment` and its relationship are intentionally deferred to
/// Phase 3 to avoid an empty migration now (see docs/DECISIONS.md).
@Model
final class Recording {
    // Defaults on every stored property are required for CloudKit sync.
    var id: UUID = UUID()
    var title: String = ""
    var fileName: String = ""
    var duration: TimeInterval = 0
    var createdAt: Date = Date.now
    var isTrashed: Bool = false
    var deletedAt: Date?
    /// AI-suggested title (Foundation Models). A suggestion only — never
    /// overwrites the user-facing `title` unless the user applies it.
    var aiTitle: String?
    /// AI-generated summary of the transcript (Foundation Models).
    var summary: String?
    /// Persisted transcript translation and its target language code (e.g. "en").
    var translation: String?
    var translationLanguageCode: String?
    /// The audio, stored externally and synced via CloudKit as an asset.
    /// Reconciled with the on-disk file (see CloudAudioReconciler).
    @Attribute(.externalStorage) var audioData: Data?
    // Optional for CloudKit (all relationships must be optional). Use
    // `segmentList` for a non-optional view.
    @Relationship(deleteRule: .cascade, inverse: \TranscriptSegment.recording)
    var segments: [TranscriptSegment]? = []

    /// Non-optional convenience over the optional CloudKit relationship.
    var segmentList: [TranscriptSegment] { segments ?? [] }

    init(
        id: UUID = UUID(),
        title: String,
        fileName: String,
        duration: TimeInterval,
        createdAt: Date = .now,
        isTrashed: Bool = false,
        deletedAt: Date? = nil,
        aiTitle: String? = nil,
        summary: String? = nil
    ) {
        self.id = id
        self.title = title
        self.fileName = fileName
        self.duration = duration
        self.createdAt = createdAt
        self.isTrashed = isTrashed
        self.deletedAt = deletedAt
        self.aiTitle = aiTitle
        self.summary = summary
    }

    /// Moves the recording into the trash.
    func moveToTrash(at date: Date = .now) {
        isTrashed = true
        deletedAt = date
    }

    /// Restores a trashed recording.
    func restore() {
        isTrashed = false
        deletedAt = nil
    }

    /// Whether a trashed recording is older than `retention` relative to `now`.
    func isExpired(now: Date, retention: TimeInterval) -> Bool {
        guard isTrashed, let deletedAt else { return false }
        return now.timeIntervalSince(deletedAt) >= retention
    }
}

extension Recording {
    /// Default 30-day trash retention.
    static let trashRetention: TimeInterval = 30 * 24 * 60 * 60

    /// Localized default title, e.g. "Aufnahme 2026-06-19 21:30".
    static func defaultTitle(date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let dateString = formatter.string(from: date)
        return String(localized: "Aufnahme \(dateString)")
    }
}
