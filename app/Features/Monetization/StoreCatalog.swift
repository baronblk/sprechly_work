import Foundation

/// Maps App Store products to the capabilities they unlock. Keeping this mapping
/// in one place makes the store **bundle-ready**: a single product can grant
/// several `Entitlement`s, and new products (e.g. a "Pro" bundle that unlocks
/// everything) are one line here — no call-site changes.
enum StoreCatalog {
    static let aiProductID = "de.gcng.sprechly.ai"
    /// Reserved for a future "everything" bundle.
    static let proBundleProductID = "de.gcng.sprechly.pro"

    /// What each product grants. A bundle would map to several entitlements.
    static let grants: [String: Set<Entitlement>] = [
        aiProductID: [.ai],
        // Enable when these ship:
        // proBundleProductID: Set(Entitlement.allCases),
        // "de.gcng.sprechly.translation": [.translation],
        // "de.gcng.sprechly.video": [.video],
    ]

    /// Product ids to load from the store.
    static var productIDs: [String] { Array(grants.keys) }

    /// Capabilities unlocked by owning `productID`.
    static func entitlements(forProductID productID: String) -> Set<Entitlement> {
        grants[productID] ?? []
    }

    /// The product that sells `entitlement` (for the paywall / purchase action).
    static func productID(selling entitlement: Entitlement) -> String? {
        grants.first { $0.value.contains(entitlement) }?.key
    }
}
