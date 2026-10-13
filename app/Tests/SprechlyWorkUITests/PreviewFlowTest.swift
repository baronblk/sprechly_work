import XCTest

/// Drives the walkthrough for the App Store **app preview video**, recorded by
/// `scripts/preview_video.sh` while this runs.
///
/// Every step is paced deliberately and every navigation has a purpose: the
/// earlier version wandered to the library and swiped up and down again without
/// showing anything, and never started a recording at all — which for a
/// dictation app wastes the seconds that decide whether anyone watches.
///
/// The story, 28 seconds after the cut:
///
/// 1. 0.0–4.0   recording starts, timer and waveform run
/// 2. 4.0–8.0   recording keeps running, timer past five seconds
/// 3. 8.0–13.5  finished transcript with timestamps
/// 4. 13.5–19.0 AI summary
/// 5. 19.0–24.0 the stored translation
/// 6. 24.0–28.0 library, with the closing line over the last three seconds
///
/// ## Why this prints timestamps
///
/// A single take of this walkthrough runs about 46 seconds, and only about 26
/// of those are the six scenes. The rest is XCUITest getting from one to the
/// next: it waits for the app to go quiescent before every interaction, and
/// after each transcript sheet is dismissed it sits on the detail view for
/// roughly three seconds before the next tap lands. Those waits are not pauses
/// this test asks for, so they cannot be shortened here — the only way to keep
/// them out of a 28-second preview is to cut them out afterwards.
///
/// So each scene announces when it begins, `scripts/preview_video.sh` reads
/// the marks out of the xcodebuild log, and ffmpeg takes one slice per scene
/// and concatenates them. Every frame of the result is still captured app
/// footage; only the dead time between scenes is gone.
///
/// The marks are wall-clock and the simulator shares the Mac's clock, but they
/// are used **relatively**, against the `launch` mark, so the delay between
/// starting the screen recording and the app appearing never enters the sum.
///
/// Each hold below runs 2.5 seconds longer than the slice the script takes
/// from it. That margin is not padding: the `launch` mark cannot be placed on
/// the exact frame the app appeared on, so every scene's computed position
/// carries the same small constant error, and the slice has to survive it from
/// either side. Measured once at 1.9 s with the mark after the first element
/// query; moving it ahead of that query is what the margin now covers.
///
/// Pacing is wall-clock, not assertions: this is a recording, not a test. It
/// still fails loudly if an element is missing, because a preview of the wrong
/// screen is worse than no preview.
final class PreviewFlowTest: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    func testWalkthrough() {
        let env = ProcessInfo.processInfo.environment
        let lang = env["SCREENSHOT_LANG"] ?? env["TEST_RUNNER_SCREENSHOT_LANG"] ?? "de"

        let app = XCUIApplication()
        app.launchArguments += ["SEED_DEMO"]
        app.launchArguments += [
            "-AppleLanguages", "(\(lang))",
            "-AppleLocale", lang == "de" ? "de_DE" : "en_US"
        ]
        app.launch()

        // ── Scenes 1–2: a recording actually running ──────────────────────
        // The longest single block, because it is the one that has to read in
        // the first second of an autoplaying, muted preview: a running timer
        // and a moving waveform are legible as an action, a list is not.
        mark("launch")

        let record = app.buttons["transport.record"]
        XCTAssertTrue(record.waitForExistence(timeout: 15))
        pause(0.4)
        record.tap()
        mark("recording")
        pause(10.5)
        app.buttons["transport.stop"].tap()

        // Stopping **saves** the take, which pushes every seeded recording down
        // one row. Waiting for that row to appear makes the indices below
        // deterministic instead of a race: 0 is the take just made, 1 is the
        // transcript-only recording, 2 is the one with summary and translation.
        app.buttons["tab.library"].tap()
        XCTAssertTrue(app.cells.element(boundBy: 5).waitForExistence(timeout: 10))

        // ── Scene 3: the finished transcript ──────────────────────────────
        app.cells.element(boundBy: 1).tap()
        let transcript = app.buttons["action.transcript"]
        XCTAssertTrue(transcript.waitForExistence(timeout: 10))
        transcript.tap()
        _ = app.navigationBars.firstMatch.waitForExistence(timeout: 10)
        mark("transcript")
        pause(4.0)
        app.swipeUp(velocity: .slow)
        pause(4.0)
        dismissIfPresent(app, "transcript.done")

        // ── Scenes 4–5: summary and translation ───────────────────────────
        // A different recording: the one above has neither. Navigated with the
        // app's own back button rather than a relaunch — a relaunch puts a
        // blank launch frame into the middle of the video, which a preview
        // cannot have. That makes this flow iPhone-shaped; an iPad preview
        // would need its own, because there is no back button beside a split
        // view.
        goBack(app)
        XCTAssertTrue(app.cells.element(boundBy: 2).waitForExistence(timeout: 10))
        app.cells.element(boundBy: 2).tap()
        XCTAssertTrue(transcript.waitForExistence(timeout: 10))
        mark("summary")
        pause(8.0)
        transcript.tap()
        _ = app.navigationBars.firstMatch.waitForExistence(timeout: 10)
        mark("translation")
        pause(7.5)
        dismissIfPresent(app, "transcript.done")

        // ── Scene 6: library, under the closing line ──────────────────────
        goBack(app)
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 10))
        mark("library")
        pause(6.5)
    }

    /// Announces the start of a scene, where `preview_video.sh` picks it up out
    /// of the xcodebuild log. Test-only output for the marketing capture chain;
    /// nothing in the app writes to a console.
    ///
    /// Written to stderr rather than printed: stdout is block-buffered once it
    /// is a pipe rather than a terminal, and a whole run's marks were lost that
    /// way — the test passed and the log carried not one of them. stderr is
    /// unbuffered, so each mark is in the log the moment it is taken.
    private func mark(_ name: String) {
        let line = "PREVIEWMARK \(name) \(Date().timeIntervalSince1970)\n"
        FileHandle.standardError.write(Data(line.utf8))
    }

    /// Taps the navigation bar's leading button. There is no accessibility
    /// identifier on it — it is the system back button of the navigation stack.
    private func goBack(_ app: XCUIApplication) {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.waitForExistence(timeout: 5), back.isHittable { back.tap() }
    }

    private func pause(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private func dismissIfPresent(_ app: XCUIApplication, _ identifier: String) {
        let button = app.buttons[identifier]
        if button.waitForExistence(timeout: 3) { button.tap() }
    }
}
