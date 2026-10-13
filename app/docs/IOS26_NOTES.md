# iOS 26 Notes

Running notes on iOS 26 / Xcode 26 specifics relevant to this project.

## Toolchain

- Xcode 26.5 (build 17F42), Swift 6.3.2.
- Swift language mode 6, `SWIFT_STRICT_CONCURRENCY = complete`.
- Foundation Models and SpeechAnalyzer require a **real device** — they do not run in the Simulator. StoreKit Testing does run in the Simulator.

## StoreKit 2 (verified against the Xcode 26.5 SDK)

- `Product.products(for:)` → `[Product]`.
- `product.purchase(options:)` is `@MainActor`, returns `Product.PurchaseResult`: `.success(VerificationResult<Transaction>)` / `.userCancelled` / `.pending`.
- `Transaction.currentEntitlements` and `Transaction.updates` are `Transaction.Transactions` (an `AsyncSequence` of `VerificationResult<Transaction>`); iterate with `for await`.
- `Transaction.finish()` is `async`; every granted transaction must be finished.
- `AppStore.sync()` is `async throws` (backs "restore purchases").
- `VerificationResult`: `.verified(T)` / `.unverified(T, VerificationError)`; only `.verified` grants access.

## StoreKit Testing (important)

- `SKTestSession` only works on an **already-booted** simulator. Under a cold `xcodebuild test` (which boots the sim as part of the run) the StoreKit test daemon is not ready, so `Product.products(for:)` returns empty and purchases fail with `SKInternalErrorDomain` Code 3. Boot first, then test:
  ```sh
  xcrun simctl boot "iPhone 17"
  xcodebuild test -project VoxStudio.xcodeproj -scheme VoxStudio \
    -destination 'platform=iOS Simulator,name=iPhone 17'
  ```
  Running from Xcode handles this automatically.
- Load the config in tests via `SKTestSession(contentsOf:)` with an explicit URL from the **test** bundle. `SKTestSession(configurationFileNamed:)` searches `Bundle.main` (the host app), which does not contain the file, and silently yields an empty session.
- `.storekit` schema for Xcode 26 is **version major 4**; `internalID` values are numeric strings (not UUIDs).
- The scheme's StoreKit configuration (set on the Run action via `project.yml`) drives manual runs. XcodeGen writes it only to the Run/Launch action, not the Test action — tests use the in-code `SKTestSession` instead.
- **Runtime-specific:** StoreKit Testing is **broken on the iOS 26.5 simulator runtime** (`Product.products(for:)` returns empty even on a fresh boot, so purchase tests fail with `.productUnavailable`). The **iOS 26.2** runtime works. CI is therefore pinned to 26.2 (`.github/workflows/ci.yml`, `IOS_SIM_OS`). If 26.2 is later unavailable, retest StoreKit on the chosen runtime before pinning.

## Audio route changes during recording (-10868)

When an audio device connects/disconnects mid-recording (e.g. Bluetooth **HFP mono 16 kHz** ↔ built-in mic 48 kHz), the hardware input format changes. If the tap or `AVAudioConverter` is configured for the old format, re-initializing the input chain fails with `-10868` (`kAudioUnitErr_FormatNotSupported`).

**Do not cache the input format.** Querying `inputNode.inputFormat(forBus: 0)` at the route-change moment is unreliable: the HFP route may still report 16 kHz, and that stale value then propagates to the resume path → `-10868` again seconds later.

**Key gotcha:** `installTap(format: nil)` resolves the tap format **once, at install time**, and does **not** update afterwards. So if the tap was installed over BT (16 kHz), a plain `engine.start()` on resume keeps that stale 16 kHz tap while the HW is now 48 kHz → `-10868` again. `format: nil` alone is not enough.

**The robust pattern:**

1. Install the tap with `format: nil`.
2. On resume (after a route-change pause), **recreate the `AVAudioEngine`** so its input node binds to the *current* hardware format, then reinstall the tap and start. `AudioRecorderEngine.start()` and `resume()` share one `startFreshEngine(writer:)` helper, so the tap format is always current.
3. Rebuild the `AVAudioConverter` from the **live** `buffer.format` in the tap callback (`RecorderConverterFactory`); output stays a constant 48 kHz mono (`converter.outputFormat == target`), so the open `AVAudioFile` remains valid (A6).
4. On `.routeChanged` (both `oldDeviceUnavailable`/`newDeviceAvailable`) the recorder **pauses**; the user resumes, which performs the rebuild when the route is stable.

Recreating the engine on resume is heavier than a bare `start()` but resume is not a hot path, and it eliminates any internally cached graph format.

**Root-cause evidence (device, A3, 2026-06-20).** Every failure logged `AVAudioEngineGraph … Error, formats don't match! Input HW format: 1 ch, 48000 Hz, tap format: 1 ch, 16000 Hz` followed by `-10868` at `AUGraphParser::InitializeActiveNodesInInputChain`. The causal factor was the **stale tap/graph input format**, *not* the audio session. The measure that fixed it was **recreating the `AVAudioEngine` on resume** (fresh input node → current HW format) — that alone made A3 green. Audio-session reactivation was considered as a further fallback but was **not** implemented and **not** needed. Lesson for future audio work: when a route change yields `-10868`, suspect a cached tap/graph format first and recreate the engine; do not assume the session is at fault. (The `fopen failed … errno 2` lines in the console are benign AVFoundation-internal noise.)

## SwiftData store location

`Library/Application Support` is **not** created automatically on iOS (unlike Documents/Caches). Letting SwiftData use the implicit default store there triggers a first-launch CoreData error wall (`errno 2`, sandbox `file-write-create denied`, error 512) that only resolves via internal recovery. Fix: create the directory explicitly with `FileManager.url(for: .applicationSupportDirectory, …, create: true)` and use an explicit `ModelConfiguration(url: …/VoxStudio.store)`. On failure, fall back to an in-memory store and log `Logger.fault` — never `fatalError`. See `PersistenceController`.

## SpeechAnalyzer batch input timestamps

Feeding a file to `SpeechAnalyzer` by chunking it and setting an explicit
`AnalyzerInput(buffer:bufferStartTime:)` per chunk throws *"Audio Input timestamp
overlaps or precedes prior audio input"* — when converting sample rate, the
source-frame-based start time and the converted buffer's implied duration round
inconsistently, so consecutive inputs overlap. Fix: feed `AnalyzerInput(buffer:)`
**without** an explicit start time; the analyzer derives contiguous timing from
the buffer stream (result `range`s come out correct, relative to 0).

## Liquid Glass

- Standard components (tab bar, toolbar) adopt Liquid Glass automatically — do not override. Use `.glassEffect()` only deliberately for overlay controls, after layout/appearance modifiers, inside a `GlassEffectContainer`, gated by `#available(iOS 26, *)` with a `.regularMaterial` fallback.
