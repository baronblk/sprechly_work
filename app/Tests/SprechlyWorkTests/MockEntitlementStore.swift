import Foundation
@testable import VoxStudio

/// Configurable test double for `EntitlementProviding`.
@MainActor
final class MockEntitlementStore: EntitlementProviding {
    var owned: Set<Entitlement>
    var unlockAll: Bool
    var purchaseSucceeds: Bool = true
    var restorableEntitlements: Set<Entitlement> = []

    private(set) var loadCallCount = 0
    private(set) var purchaseCallCount = 0
    private(set) var restoreCallCount = 0

    init(owned: Set<Entitlement> = [], unlockAll: Bool = false) {
        self.owned = owned
        self.unlockAll = unlockAll
    }

    func isUnlocked(_ entitlement: Entitlement) -> Bool {
        unlockAll || owned.contains(entitlement)
    }

    func load() async {
        loadCallCount += 1
    }

    @discardableResult
    func purchase(_ entitlement: Entitlement) async throws -> Bool {
        purchaseCallCount += 1
        guard purchaseSucceeds else { return false }
        owned.insert(entitlement)
        return true
    }

    func restore() async throws {
        restoreCallCount += 1
        owned.formUnion(restorableEntitlements)
    }
}
