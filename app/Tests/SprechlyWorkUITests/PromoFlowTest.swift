import XCTest

/// Drives an energetic, continuous walkthrough for the **social promo** video
/// (TikTok/Reels/Shorts). Run while `scripts/promo_video.sh` records the screen.
/// Pacing is deliberate so the b-roll reads well; this is not a correctness test.
final class PromoFlowTest: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    func testPromo() {
        let env = ProcessInfo.processInfo.environment
        let lang = env["SCREENSHOT_LANG"] ?? env["TEST_RUNNER_SCREENSHOT_LANG"] ?? "de"

        let app = XCUIApplication()
        app.launchArguments += ["SEED_DEMO"]
        app.launchArguments += [
            "-AppleLanguages", "(\(lang))",
            "-AppleLocale", lang == "de" ? "de_DE" : "en_US"
        ]
        app.launch()

        pause(2.2) // hero / recording screen

        // Library
        app.buttons["tab.library"].tap()
        _ = app.cells.firstMatch.waitForExistence(timeout: 10)
        pause(1.2)
        app.swipeUp(velocity: .slow); pause(0.8)
        app.swipeDown(velocity: .slow); pause(0.8)

        // Detail + playback (the moving cursor + counting timecode is the hero motion)
        app.cells.firstMatch.tap()
        let play = app.buttons["transport.play"]
        if play.waitForExistence(timeout: 10) {
            pause(0.8)
            play.tap()           // start playback
            pause(4.5)           // let the cursor sweep
            play.tap()           // pause
        } else {
            pause(2.0)
        }

        // AI summary
        app.swipeUp(velocity: .slow); pause(2.2)
        app.swipeDown(velocity: .slow); pause(0.4)

        // Transcript
        let transcript = app.buttons["action.transcript"]
        if transcript.waitForExistence(timeout: 5) {
            transcript.tap()
            _ = app.navigationBars.firstMatch.waitForExistence(timeout: 10)
            pause(1.6)
            app.swipeUp(velocity: .slow); pause(1.8)
        }
        pause(0.6)
    }

    private func pause(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }
}
