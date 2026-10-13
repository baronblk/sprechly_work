import Foundation
import Testing
@testable import VoxStudio

@MainActor
struct RatingPromptControllerTests {
    /// A throwaway, isolated UserDefaults so tests never touch real prefs.
    private func makeDefaults() -> (UserDefaults, String) {
        let name = "rating-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        return (defaults, name)
    }

    @Test func promptsAfterThresholdThenStaysSilentOnSameVersion() {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let c = RatingPromptController(defaults: defaults, appVersion: "1.0.1", threshold: 3)

        c.registerDelight(); #expect(c.pendingRequest == false)
        c.registerDelight(); #expect(c.pendingRequest == false)
        c.registerDelight(); #expect(c.pendingRequest)        // 3rd positive moment → eligible

        c.consume(); #expect(c.pendingRequest == false)

        // Already asked on this version → never again until the next update.
        c.registerDelight(); c.registerDelight(); c.registerDelight()
        #expect(c.pendingRequest == false)
    }

    @Test func newVersionRequiresFreshEngagement() {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }

        let v1 = RatingPromptController(defaults: defaults, appVersion: "1.0.1", threshold: 2)
        v1.registerDelight(); v1.registerDelight()
        #expect(v1.pendingRequest)                            // asked on 1.0.1
        v1.consume()

        // Same persisted storage, new version: needs the threshold again.
        let v2 = RatingPromptController(defaults: defaults, appVersion: "1.0.2", threshold: 2)
        v2.registerDelight(); #expect(v2.pendingRequest == false)
        v2.registerDelight(); #expect(v2.pendingRequest)
    }
}
