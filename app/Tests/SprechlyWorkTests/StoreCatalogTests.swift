import Testing
@testable import VoxStudio

struct StoreCatalogTests {
    @Test func aiProductGrantsAI() {
        #expect(StoreCatalog.entitlements(forProductID: StoreCatalog.aiProductID) == [.ai])
    }

    @Test func sellingLookupFindsProduct() {
        #expect(StoreCatalog.productID(selling: .ai) == StoreCatalog.aiProductID)
        // Not sold yet → no product, but the capability exists (bundle-ready).
        #expect(StoreCatalog.productID(selling: .video) == nil)
        #expect(StoreCatalog.productID(selling: .translation) == nil)
    }

    @Test func unknownProductGrantsNothing() {
        #expect(StoreCatalog.entitlements(forProductID: "de.gcng.sprechly.unknown").isEmpty)
    }

    @Test func productIDsMatchGrants() {
        #expect(StoreCatalog.productIDs.contains(StoreCatalog.aiProductID))
    }
}
