import Testing
@testable import VoxStudio

/// The cross-promotion link points at a different app than this one, so a wrong
/// id would send users to a stranger's product rather than fail visibly.
struct SiblingAppTests {
    @Test func whisperScribeProURLUsesTheConfirmedAppID() throws {
        let url = try #require(SiblingApp.whisperScribeProURL)
        #expect(SiblingApp.whisperScribeProID == "6761129645")
        #expect(
            url.absoluteString
                == "https://apps.apple.com/app/whisperscribe-pro/id6761129645"
        )
    }

    /// Sprechly's own id must never be reused for the sibling link.
    @Test func siblingIDIsNotThisApp() {
        #expect(SiblingApp.whisperScribeProID != AppInfo.appStoreID)
    }
}
