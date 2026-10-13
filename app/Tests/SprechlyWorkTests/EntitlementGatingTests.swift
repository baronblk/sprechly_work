import Testing
@testable import VoxStudio

@MainActor
struct EntitlementGatingTests {
    @Test func lockedWithoutEntitlementTriggersPaywall() {
        let store = MockEntitlementStore(owned: [])
        var paywallShown = false
        var actionRan = false

        store.gate(.ai, onLocked: { paywallShown = true }, action: { actionRan = true })

        #expect(paywallShown)
        #expect(!actionRan)
        #expect(!store.isUnlocked(.ai))
    }

    @Test func purchaseUnlocksEntitlement() async throws {
        let store = MockEntitlementStore(owned: [])

        let granted = try await store.purchase(.ai)

        #expect(granted)
        #expect(store.isUnlocked(.ai))

        var actionRan = false
        store.gate(
            .ai,
            onLocked: { Issue.record("Gate should not lock after a successful purchase") },
            action: { actionRan = true }
        )
        #expect(actionRan)
    }

    @Test func failedPurchaseLeavesLocked() async throws {
        let store = MockEntitlementStore(owned: [])
        store.purchaseSucceeds = false

        let granted = try await store.purchase(.ai)

        #expect(!granted)
        #expect(!store.isUnlocked(.ai))
    }

    @Test func restoreRestoresAccess() async throws {
        let store = MockEntitlementStore(owned: [])
        store.restorableEntitlements = [.ai]
        #expect(!store.isUnlocked(.ai))

        try await store.restore()

        #expect(store.isUnlocked(.ai))
        #expect(store.restoreCallCount == 1)
    }

    @Test func unlockAllOverrideGrantsAccess() {
        let store = MockEntitlementStore(owned: [], unlockAll: true)
        #expect(store.isUnlocked(.ai))
    }
}
