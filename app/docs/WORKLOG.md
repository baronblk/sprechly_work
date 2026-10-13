# Work Log

Reverse-chronological log of implementation slices.

## 2026-06-20 — Slice 3b: Batch transcription + monetization Teil B

- **3b-i:** `transcribe(fileAt:locale:)` on the Speech service (`SpeechAnalyzer` + `SpeechTranscriber.results`, device-only) → `TranscriptDraft` stream; `TranscriptionViewModel` persists drafts as `TranscriptSegment` **atomically** (delete+insert+save, rollback on error); `TranscriptView` (own screen) with live segments + tap-to-seek using the **shared** `PlaybackViewModel` (one player). Locale picker: installed-only, device-language default with fallback.
- **3b-ii:** `TrialState` (`@Model`) + `TrialTracking` protocol (`SwiftDataTrialTracking`). Gate **before** render: re-transcription is free (no trial), unlocked is free, else first-free consumes the trial **only on success**, else paywall. `PaywallView` (price from `Product`, prominent restore, dismiss on unlock).
- **Bugfix:** two test helpers returned a `ModelContext` while letting its `ModelContainer` deallocate → SwiftData crash; fixed by keeping the container alive.
- **Tests (co-located):** persist/sorted, idempotent replace, aborted-keeps-old, default-locale; gating (paywall when locked+trial-used, first-free-consumes-on-success, aborted-doesn't-consume, re-transcription-doesn't-consume, unlocked-doesn't-consume), SwiftData trial round-trip. 96 tests total. Real ASR + sandbox purchase = device (DEVICE_TESTS "3b").

## 2026-06-20 — Slice 3a: Transcription foundation

- **Scope:** `TranscriptSegment` (`@Model`) + `Recording.segments` cascade relationship (additive lightweight migration); data-driven `TranscriptionLocale` (de/en); explicit `TranscriptionAssetState` machine (unsupported/notInstalled/downloading/installed/failed/insufficientStorage); `TranscriptionProviding` seam + `SpeechTranscriptionService` (Speech framework: `AssetInventory` + `SpeechTranscriber`, device-only); transcription setup screen + library entry to download models with progress.
- **API verified** against the iOS 26 SDK (`SpeechAnalyzer`, `SpeechTranscriber(locale:preset:.transcription)`, `AssetInventory.status/assetInstallationRequest/reserve`, `AssetInstallationRequest.downloadAndInstall()`).
- **Tests (co-located):** segment links + cascade delete, data-driven locale list, asset-state mapping from `AssetInventory.Status`, setup VM transitions (download → installed; failure surfaces) via mock. 86 tests total. Real ASR is device-only → DEVICE_TESTS "3a" gates 3b.
- **Decisions:** explicit state enum (not Bool); 3d starts title+summary; migration is lightweight. See DECISIONS.md.

## 2026-06-20 — Slice 2d: Mix (Phase 2 complete)

- **Scope:** `AudioMixService` (actor) streams a float two-track sum (main + volume·mix at a frame-accurate offset, optional mix trim), truncated to the main duration, then limits the summed peak via `PeakLimiter` (the 2a `LoudnessNormalizer` seam) — no hard clipping. Pre-flight validates both sources before any write. Mix screen (`MixViewModel`/`MixView`): main waveform with a `TrimGeometry` position marker, mix source picker, `TrimmableWaveformView` for mix trim, volume + position controls; result saved as `"<main> (Mix)"` + sidecar. Reachable from the playback overflow menu.
- **Decisions:** float sum + limiter via the seam; one volume control (mix track); overhang = truncate; mix trim carried; streaming two-track render. See DECISIONS.md.
- **Tests (co-located):** limiter attenuates-only (no boost), **clipping prevented** (two near-full tracks → peak ≤ ceiling), quiet mix untouched, **overhang truncates to main duration**, offset places the mix, mix-trim mixes only the range, format-mismatch/missing rejected before any write, mix VM creates a new recording truncated to main, non-destructive, no orphans. 77 tests total.
- **Phase 2 functionally complete** (speed/gain/export, trim, merge, mix). Out of scope: import/heterogeneous (2e), video-mix, RMS/LUFS loudness — all additive later.

## 2026-06-20 — Slice 2c: Merge

- **Scope:** `AudioMergeService` (actor) streams homogeneous library sources segment by segment into one output; **pre-flight validates all sources (format + readability) before any write** → mismatched/missing source aborts with no partial output; runtime cleanup as safety net. Merge screen (`MergeViewModel`/`MergeView`) with reorder (`.onMove`) as its own state, library multi-select (`Set<UUID>`) → merge entry; result saved as a new `Recording` ("Zusammenführung …") + sidecar.
- **Decisions:** homogeneous library sources (48 kHz mono) + guard; pre-flight before write; no crossfade/hard seam; timestamp title; streaming. See DECISIONS.md.
- **Tests (co-located):** merge duration = sum (tolerance), order respected (first-segment peak), format-mismatch and missing-source rejected **before any output file is created**, reorder independent of selection, merge VM creates a new recording non-destructively without orphans. 67 tests total.
- **Out of scope (next):** Mix-audio (2d), import/heterogeneous (2e), video-mix (later).

## 2026-06-20 — Slice 2b: Trim

- **Scope:** non-destructive trim via `EditSettings.trim` through the 2a render pipeline (one decode/one encode; `copyRange` for frame-exact cuts at 1×, `scheduleSegment` for trim+speed). Draggable handles (`TrimmableWaveformView`), pure `TrimGeometry`/`TrimBounds` helpers, editor restructured (trim dominant, speed/normalize/format secondary).
- **Decisions:** trim re-renders (no AAC stream cut); min length 250 ms clamped to source duration; see DECISIONS.md.
- **Tests (co-located):** trim duration, **identity trim** (0…full, off-by-one guard), trim+speed, re-trim of a trimmed file, min-length clamp incl. sub-250 ms source, time↔pixel round-trip + clamping, editor VM produces a trimmed recording non-destructively without orphans. 61 tests total.
- **Out of scope (next):** Merge (2c), Mix-audio (2d), video-mix (later).

## 2026-06-20 — Slice 2a: Editor (speed + gain + export)

- **Scope:** non-destructive offline edit — `AudioEditingService` (pitch-preserving speed via `AVAudioUnitTimePitch`, peak normalization), `AudioExportService` (M4A/WAV transcode), `ExportFormat`, editor screen (`EditorViewModel`/`EditorView`) reachable from playback, result saved as a new `Recording` + sidecar, shareable via `ShareLink`.
- **Decisions:** peak normalization (LUFS later), render order speed→normalize, normalize default ON, MP3 excluded (no iOS encoder). See DECISIONS.md.
- **Tests (co-located):** export-format settings, editing normalization-hits-target, equal-peak-across-speeds (render-order proof), speed-duration with tolerance, normalize-off unchanged, source untouched, export valid file per format, editor VM creates a new recording non-destructively with no orphans. 44 tests total, green on CI (iOS 26.2).
- **Out of scope (next):** Trim (2b), Merge (2c), Mix-audio (2d), video-mix (later).

## 2026-06-20 — CI on self-hosted runner

- Added `.github/workflows/ci.yml` for a self-hosted macOS runner (the dev MacBook): defensive sim boot (`bootstatus -b`), pinned destination, isolated `-derivedDataPath`, `-resultBundlePath` artifact, 30-min timeout, fork-PR guard. Locks in the current 34 tests before the Phase-2 suite grows.
- **Finding:** StoreKit Testing is broken on the **iOS 26.5** simulator runtime (products empty even on a fresh boot); the suite is green on **26.2**. CI pinned to 26.2 (`IOS_SIM_OS`). Verified locally: shutdown→fresh boot→`xcodebuild test` on 26.2 = 34 green; same on 26.5 = 2 StoreKit failures.

## 2026-06-19 — Foundation fixes (pre Phase 2)

- **Route-change (-10868), v3:** v2's `format: nil` tap still kept a stale 16 kHz format (the tap format is fixed at install time). Fix: `resume()` recreates the `AVAudioEngine` so the input node binds to the current hardware format; converter still rebuilt from the live `buffer.format`. Route change pauses; resume restarts cleanly. **Verified green on device (A3, 2026-06-20):** BT disconnect → pause → resume records cleanly at 48 kHz, no `-10868`. (The `fopen failed … errno 2` console lines are benign AVFoundation-internal noise, unrelated to the app/store.)
- **SwiftData store:** explicit `PersistenceController` creates Application Support (not auto-created on iOS) and uses a named `VoxStudio.store` URL; in-memory fallback, no `fatalError`. Removes first-launch CoreData recovery noise.

## 2026-06-19 — Slice 2: Phase-1 audio core

- **Scope:** standalone record/playback/library core — `AVAudioSession` config, `AudioRecorderEngine`/`AudioPlaybackEngine` (actors, persistence-agnostic), `WaveformGenerator`, `WaveformView` (Canvas), `Recording` (`@Model`, incl. `deletedAt`), `RecordingFileStore` (atomic move + sidecar peaks), recording/playback/library screens, real navigation, 30-day trash purge.
- **Out of scope:** trim/merge/mix/speed/gain/export (Phase 2), transcription/AI + IAP gating (Phase 3).
- **Decisions:** 48 kHz mono AAC; pause via `engine.pause()/start()` on one file; engines URL-based; delete/purge removes audio + sidecar. See DECISIONS.md.
- **Device verification required (release blockers):** interruptions (call), route changes (unplug), VoiceOver on all three screens, ≥30 min recording without UI jank or RAM growth — not fully verifiable in the Simulator.

## 2026-06-19 — Slice 1: App shell + monetization scaffold (Teil A)

- **Scope:** App shell (XcodeGen project, app entry, app state, routing, design-system theme, placeholder root view) + StoreKit 2 monetization scaffold (`Entitlement`, `EntitlementProviding`, `StoreManager`, reusable entitlement gate) + tests (mock-based gating + StoreKit Testing purchase integration).
- **Out of scope (next slice, separate plan + go):** Phase-1 audio core — recording engine, playback, waveform, library, persistence.
- **Notes:** StoreKit 2 signatures verified against the Xcode 26.5 SDK before implementation. In DEBUG, `UNLOCK_ALL=1` (set on the run scheme) unlocks all entitlements so app-shell development is not blocked by the store.
