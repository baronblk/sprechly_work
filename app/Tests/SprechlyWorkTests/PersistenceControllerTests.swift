import Foundation
import SwiftData
import Testing
@testable import SprechlyWork

@MainActor
struct PersistenceControllerTests {
    @Test func storeURLCreatesApplicationSupportDirectory() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("voxsupport-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: base) }
        #expect(!FileManager.default.fileExists(atPath: base.path))

        let url = try PersistenceController.storeURL(inApplicationSupport: base)

        #expect(FileManager.default.fileExists(atPath: base.path))
        #expect(url.lastPathComponent == "SprechlyWork.store")
    }

    @Test func explicitURLStorePersistsAcrossInstances() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("voxstore-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("SprechlyWork.store")

        let first = try PersistenceController.container(at: url, cloudKit: false)
        first.mainContext.insert(Recording(title: "Persisted", fileName: "p.m4a", duration: 1))
        try first.mainContext.save()

        let second = try PersistenceController.container(at: url, cloudKit: false)
        let recordings = try second.mainContext.fetch(FetchDescriptor<Recording>())
        #expect(recordings.count == 1)
        #expect(recordings.first?.title == "Persisted")
    }

    @Test func inMemoryFallbackIsUsable() throws {
        let container = PersistenceController.inMemoryContainer()
        container.mainContext.insert(Recording(title: "Temp", fileName: "t.m4a", duration: 1))
        try container.mainContext.save()
        let recordings = try container.mainContext.fetch(FetchDescriptor<Recording>())
        #expect(recordings.count == 1)
    }
}
