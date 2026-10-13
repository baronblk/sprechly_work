import Foundation
import Testing
@testable import VoxStudio

struct RecordingTests {
    @Test func moveToTrashSetsFlagAndTimestamp() {
        let recording = Recording(title: "A", fileName: "a.m4a", duration: 1)
        let when = Date(timeIntervalSince1970: 1_000)
        recording.moveToTrash(at: when)
        #expect(recording.isTrashed)
        #expect(recording.deletedAt == when)
    }

    @Test func restoreClearsTrashState() {
        let recording = Recording(title: "A", fileName: "a.m4a", duration: 1)
        recording.moveToTrash()
        recording.restore()
        #expect(!recording.isTrashed)
        #expect(recording.deletedAt == nil)
    }

    @Test func notTrashedIsNeverExpired() {
        let recording = Recording(title: "A", fileName: "a.m4a", duration: 1)
        #expect(!recording.isExpired(now: .now, retention: 0))
    }

    @Test func expiresAfterRetention() {
        let recording = Recording(title: "A", fileName: "a.m4a", duration: 1)
        let deleted = Date(timeIntervalSince1970: 0)
        recording.moveToTrash(at: deleted)
        let day = TimeInterval(24 * 60 * 60)
        #expect(!recording.isExpired(now: deleted.addingTimeInterval(29 * day), retention: Recording.trashRetention))
        #expect(recording.isExpired(now: deleted.addingTimeInterval(31 * day), retention: Recording.trashRetention))
    }

    @Test func defaultTitleHasExpectedShape() {
        let date = Date(timeIntervalSince1970: 0)
        let title = Recording.defaultTitle(date: date)
        #expect(title.hasPrefix("Aufnahme "))
    }

    @Test func translationFieldsDefaultToNil() {
        let recording = Recording(title: "A", fileName: "a.m4a", duration: 1)
        #expect(recording.translation == nil)
        #expect(recording.translationLanguageCode == nil)
    }
}
