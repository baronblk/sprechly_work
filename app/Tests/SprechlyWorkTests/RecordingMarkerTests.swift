import Foundation
import SwiftData
import Testing
@testable import SprechlyWork

/// Tap markers of a Soundcore Work import live on `Recording` (see
/// docs/d3200_protocol_spec.md §6.4a).
@MainActor
struct RecordingMarkerTests {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Recording.self, TranscriptSegment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test func recordingsMadeInTheAppHaveNoMarkers() throws {
        let container = try makeContainer()
        let recording = Recording(title: "R", fileName: "r.m4a", duration: 10)
        container.mainContext.insert(recording)
        try container.mainContext.save()

        #expect(recording.markers.isEmpty)
    }

    @Test func markersSurviveAFetch() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(
            Recording(
                title: "Work",
                fileName: "w.m4a",
                duration: 45,
                markers: [10.54, 12.82, 15.54]
            )
        )
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Recording>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.markers == [10.54, 12.82, 15.54])
    }
}
