import Foundation
import SwiftData
import Testing
@testable import SprechlyWork

@MainActor
struct TranscriptSegmentTests {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Recording.self, TranscriptSegment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test func segmentLinksToRecording() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let recording = Recording(title: "R", fileName: "r.m4a", duration: 10)
        context.insert(recording)
        context.insert(TranscriptSegment(text: "hallo", startTime: 0, endTime: 1, recording: recording))
        try context.save()

        #expect(recording.segmentList.count == 1)
        #expect(recording.segmentList.first?.text == "hallo")
    }

    @Test func deletingRecordingCascadesSegments() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let recording = Recording(title: "R", fileName: "r.m4a", duration: 10)
        context.insert(recording)
        context.insert(TranscriptSegment(text: "a", startTime: 0, endTime: 1, recording: recording))
        context.insert(TranscriptSegment(text: "b", startTime: 1, endTime: 2, recording: recording))
        try context.save()

        context.delete(recording)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<TranscriptSegment>()).isEmpty)
    }
}
