import Testing
@testable import VoxStudio

struct AppInfoTests {
    @Test func formatsVersionWithBuild() {
        #expect(AppInfo.format(short: "1.2.3", build: "45") == "1.2.3 (45)")
    }

    @Test func omitsBuildWhenMissing() {
        #expect(AppInfo.format(short: "1.0", build: nil) == "1.0")
        #expect(AppInfo.format(short: "1.0", build: "") == "1.0")
    }

    /// The rating entry in Settings is only as good as this URL — a typo here
    /// sends users to a blank App Store page.
    @Test func reviewURLTargetsThisAppsReviewSheet() throws {
        let url = try #require(AppInfo.reviewURL)
        #expect(url.absoluteString == "https://apps.apple.com/app/id6782676748?action=write-review")
    }

    @Test func storeURLWithoutActionIsThePlainProductPage() throws {
        let url = try #require(AppInfo.storeURL())
        #expect(url.absoluteString == "https://apps.apple.com/app/id6782676748")
    }

    @Test func fallsBackWhenVersionMissing() {
        #expect(AppInfo.format(short: nil, build: "45") == "— (45)")
        #expect(AppInfo.format(short: "", build: nil) == "—")
    }
}
