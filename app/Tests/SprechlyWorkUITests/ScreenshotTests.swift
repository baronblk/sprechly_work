import XCTest

/// Captures App Store screenshots from seeded demo data. Run via
/// `scripts/screenshots.sh`, which iterates the required device sizes and
/// languages. Language is passed through the `SCREENSHOT_LANG` env var.
///
/// Output: XCTest attachments (`.keepAlways`) named `<lang>-NN-screen`, exported
/// from the `.xcresult` by the runner script.
final class ScreenshotTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Captures the marketing set in the order it is uploaded, so the file
    /// numbering matches the App Store ordering: the transcript leads, the
    /// empty recorder does not.
    func testCaptureScreenshots() {
        // xcodebuild only forwards env vars prefixed `TEST_RUNNER_` to the test
        // runner process; accept either form.
        let env = ProcessInfo.processInfo.environment
        let lang = env["SCREENSHOT_LANG"] ?? env["TEST_RUNNER_SCREENSHOT_LANG"] ?? "de"

        let app = XCUIApplication()
        app.launchArguments += ["SEED_DEMO"]
        app.launchArguments += [
            "-AppleLanguages", "(\(lang))",
            "-AppleLocale", lang == "de" ? "de_DE" : "en_US"
        ]
        // Captured in the unlocked state on purpose: the store set should show
        // what the purchase delivers, with the headline carrying the "buy once"
        // message. (A locked run would also need a value passed as a number —
        // `-key NO` lands in UserDefaults as a string and never casts to Bool.)
        app.launch()

        // 06) Library first, while nothing is selected yet. Capturing it here
        // avoids ever needing a back button — on iPad the list stays visible
        // beside the detail and there is none.
        app.buttons["tab.library"].tap()
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 10))
        capture(app, lang, "06-library")

        // The first seeded recording carries a transcript and an AI summary.
        app.cells.firstMatch.tap()
        let transcriptAction = app.buttons["action.transcript"]
        XCTAssertTrue(transcriptAction.waitForExistence(timeout: 10))

        // 01) Transcript — the product's whole point, so it leads.
        //
        // The hero comes from a different screen per device, because the same
        // view is not equally good on both.
        //
        // On iPad the transcript opens as a sheet floating over a dimmed detail
        // screen, with the same text showing through beside it, clipped, and a
        // large dead area underneath. The detail screen there already carries
        // the transcript inline — real, unmodified UI and no modal — so that is
        // what the iPad hero uses.
        //
        // On iPhone the detail screen has no room for it, so the sheet is the
        // right view. It needs no scrolling: the seeded recording carries no AI
        // summary, so it opens straight onto timestamps.
        if isPad(app) {
            capture(app, lang, "01-transcript")
        } else {
            transcriptAction.tap()
            _ = app.navigationBars.firstMatch.waitForExistence(timeout: 10)
            capture(app, lang, "01-transcript")
            dismissSheet(app, "transcript.done")
        }

        // 02) AI summary — a *different* recording: the hero above is seeded
        // without a summary so its transcript starts at the top, which means it
        // has nothing to show here.
        //
        // Relaunching to get back to the library instead of navigating back:
        // the back button exists on iPhone and does not on iPad, where the list
        // stays beside the detail. A relaunch behaves the same on both.
        app.terminate()
        app.launch()
        app.buttons["tab.library"].tap()
        XCTAssertTrue(app.cells.element(boundBy: 1).waitForExistence(timeout: 10))
        app.cells.element(boundBy: 1).tap()
        XCTAssertTrue(transcriptAction.waitForExistence(timeout: 10))
        capture(app, lang, "02-summary")

        // 03) Editor — cut, mix, export.
        app.buttons["action.edit"].tap()
        _ = app.navigationBars.firstMatch.waitForExistence(timeout: 10)
        capture(app, lang, "05-edit")
        dismissSheet(app, "editor.done")

        // 04) A recording in progress — the timer must be past 00:00 and the
        // waveform alive, otherwise the shot reads as an empty app.
        app.buttons["tab.recording"].tap()
        let record = app.buttons["transport.record"]
        XCTAssertTrue(record.waitForExistence(timeout: 10))
        record.tap()
        // Long enough for the timer to move and the waveform to fill.
        Thread.sleep(forTimeInterval: 6)
        capture(app, lang, "04-record")
        app.buttons["transport.stop"].tap()

        // 03) What the one-time purchase covers. Settings carries the feature
        // list without a price — the paywall's price is a StoreKit test value
        // and must not end up on a marketing screenshot.
        app.buttons["tab.library"].tap()
        let settings = app.buttons["settings.open"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()
        _ = app.navigationBars.firstMatch.waitForExistence(timeout: 10)
        capture(app, lang, "03-usp")
    }

    /// IAP review screenshot: paywall with product + price (needs the scheme's
    /// StoreKit configuration so the product loads).
    func testPaywall() {
        let env = ProcessInfo.processInfo.environment
        let lang = env["SCREENSHOT_LANG"] ?? env["TEST_RUNNER_SCREENSHOT_LANG"] ?? "de"

        let app = XCUIApplication()
        app.launchArguments += ["SEED_DEMO", "SHOW_PAYWALL"]
        app.launchArguments += [
            "-AppleLanguages", "(\(lang))",
            "-AppleLocale", lang == "de" ? "de_DE" : "en_US"
        ]
        app.launch()

        // The unlock button only appears once the product (with price) loaded.
        XCTAssertTrue(app.buttons["paywall.unlock"].waitForExistence(timeout: 20))
        capture(app, lang, "iap-paywall")
    }

    /// Closes a presented sheet by its own "Done" button. Addressed by
    /// identifier rather than by position, because `app.navigationBars` spans
    /// the presenting screen's bar too and the index is not stable.
    /// True on the regular-width layouts where the library list stays beside
    /// the detail screen. Measured from the window rather than passed in, so
    /// the flow stays self-contained.
    private func isPad(_ app: XCUIApplication) -> Bool {
        app.windows.firstMatch.frame.width > 1000
    }

    private func dismissSheet(_ app: XCUIApplication, _ identifier: String) {
        let done = app.buttons[identifier]
        XCTAssertTrue(done.waitForExistence(timeout: 10), "missing \(identifier)")
        done.tap()
    }

    private func capture(_ app: XCUIApplication, _ lang: String, _ name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "\(lang)-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
