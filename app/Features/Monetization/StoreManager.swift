import Observation
import StoreKit
import os

/// Single source of truth for in-app purchase entitlements, backed by StoreKit 2.
///
/// Entitlements are derived live from `Transaction.currentEntitlements` and kept
/// current through a long-lived `Transaction.updates` listener, so access works
/// offline and survives reinstalls and Family Sharing.
@MainActor
@Observable
final class StoreManager: EntitlementProviding {
    private(set) var products: [Product] = []
    private(set) var owned: Set<Entitlement> = []

    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private let logger = Logger(
        subsystem: "de.gcng.sprechly.work",
        category: "StoreManager"
    )

    #if DEBUG
    /// DEBUG-only device unlock (Teil A): real purchases need the IAP in App
    /// Store Connect, which doesn't exist yet, and `devicectl` installs carry
    /// neither the StoreKit config nor the scheme's `UNLOCK_ALL` env var — so
    /// dev builds would otherwise be permanently locked. Defaults to ON; a
    /// Settings toggle flips it OFF to exercise the real paywall/gating.
    private(set) var debugUnlockAll: Bool

    init() {
        debugUnlockAll = UserDefaults.standard.object(forKey: "debugUnlockAll") as? Bool ?? true
    }

    func setDebugUnlockAll(_ on: Bool) {
        debugUnlockAll = on
        UserDefaults.standard.set(on, forKey: "debugUnlockAll")
    }
    #else
    init() {}
    #endif

    /// Starts the transaction listener and loads the current state. Idempotent.
    func start() async {
        observeTransactionUpdates()
        await load()
        await refreshEntitlements()
    }

    func load() async {
        do {
            // App Store product IDs come from the catalog — NOT Entitlement
            // rawValues, which are decoupled capability names ("ai", …).
            products = try await Product.products(for: StoreCatalog.productIDs)
            if products.isEmpty {
                logger.error("No products returned for \(StoreCatalog.productIDs, privacy: .public) — check the IAP exists and the Paid Apps Agreement is active")
            }
        } catch {
            logger.error("Product load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func isUnlocked(_ entitlement: Entitlement) -> Bool {
        if unlockAllOverride { return true }
        return owned.contains(entitlement)
    }

    @discardableResult
    func purchase(_ entitlement: Entitlement) async throws -> Bool {
        guard let productID = StoreCatalog.productID(selling: entitlement),
              let product = products.first(where: { $0.id == productID }) else {
            throw StoreError.productUnavailable(entitlement.rawValue)
        }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try verify(verification)
            owned.formUnion(StoreCatalog.entitlements(forProductID: transaction.productID))
            await transaction.finish()
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    func restore() async throws {
        do {
            try await AppStore.sync()
        } catch {
            logger.error("AppStore sync failed: \(error.localizedDescription, privacy: .public)")
            throw StoreError.syncFailed
        }
        await refreshEntitlements()
    }

    /// Recomputes `owned` from the current verified entitlements.
    func refreshEntitlements() async {
        var current: Set<Entitlement> = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            current.formUnion(StoreCatalog.entitlements(forProductID: transaction.productID))
        }
        owned = current
    }

    private func observeTransactionUpdates() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.process(update)
            }
        }
    }

    private func process(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        owned.formUnion(StoreCatalog.entitlements(forProductID: transaction.productID))
        await transaction.finish()
    }

    private func verify<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw StoreError.failedVerification
        }
    }

    private var unlockAllOverride: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.environment["UNLOCK_ALL"] == "1" { return true }
        return debugUnlockAll
        #else
        return false
        #endif
    }
}
