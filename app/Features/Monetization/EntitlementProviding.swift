import Foundation

/// Abstraction over the entitlement store so view models and tests depend on a
/// protocol, never the concrete `StoreManager`.
@MainActor
protocol EntitlementProviding {
    /// Entitlements currently owned, derived from verified transactions.
    var owned: Set<Entitlement> { get }

    /// Whether the given entitlement grants access right now.
    func isUnlocked(_ entitlement: Entitlement) -> Bool

    /// Loads products from the App Store.
    func load() async

    /// Starts a purchase. Returns `true` when access was granted, `false` for
    /// user-cancelled or pending purchases. Throws on verification failure.
    @discardableResult
    func purchase(_ entitlement: Entitlement) async throws -> Bool

    /// Restores previous purchases (required for non-consumables).
    func restore() async throws
}
