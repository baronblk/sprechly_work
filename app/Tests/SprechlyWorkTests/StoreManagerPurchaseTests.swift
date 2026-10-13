import Foundation
import StoreKit
import StoreKitTest
import Testing
@testable import VoxStudio

/// Marker for locating the StoreKit configuration inside the test bundle.
private final class TestBundleMarker {}

/// Integration tests for the real StoreKit 2 purchase → entitlement path, driven
/// by a local StoreKit configuration. Assertions read `StoreManager.owned` (the
/// raw verified set), which is unaffected by the `UNLOCK_ALL` debug override.
///
/// Serialized because `SKTestSession` configures process-global StoreKit state.
///
/// NOTE: StoreKit Testing only functions on an already-booted simulator. Under a
/// cold `xcodebuild test` (which boots the sim as part of the run) the StoreKit
/// test daemon is not ready and products do not load. Boot the simulator first
/// (`xcrun simctl boot ...`) or run from Xcode. See docs/IOS26_NOTES.md.
@MainActor
@Suite(.serialized)
struct StoreManagerPurchaseTests {
    /// Loads the config by explicit URL from the test bundle.
    /// `SKTestSession(configurationFileNamed:)` searches the host app bundle,
    /// which does not contain the file, so it must be loaded via `contentsOf`.
    private func makeSession() throws -> SKTestSession {
        let url = try #require(
            Bundle(for: TestBundleMarker.self)
                .url(forResource: "VoxStudio", withExtension: "storekit")
        )
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        return session
    }

    @Test func purchaseGrantsAndFinishesEntitlement() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }

        let store = StoreManager()
        await store.load()
        // The StoreKit test daemon is not always ready under `xcodebuild test`;
        // skip rather than fail when products could not be loaded (see note above).
        guard !store.products.isEmpty else { return }
        #expect(store.products.first?.id == StoreCatalog.aiProductID)
        #expect(store.owned.isEmpty)

        let granted = try await store.purchase(.ai)
        #expect(granted)
        #expect(store.owned.contains(.ai))

        var unfinished = 0
        for await _ in Transaction.unfinished { unfinished += 1 }
        #expect(unfinished == 0)
    }

    @Test func refreshEntitlementsReflectsOwnedPurchase() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }

        let buyer = StoreManager()
        await buyer.load()
        guard !buyer.products.isEmpty else { return } // daemon not ready; skip
        _ = try await buyer.purchase(.ai)

        // A fresh manager must recover the entitlement from currentEntitlements.
        let fresh = StoreManager()
        await fresh.refreshEntitlements()
        #expect(fresh.owned.contains(.ai))
    }
}
