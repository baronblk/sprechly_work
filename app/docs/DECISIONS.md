# Decisions

Architecture decision log. Newest first. Each entry records the decision and its rationale.

## 2026-06-20 — UI/UX + purchase polish is a dedicated slice after Phase 3

- **Decision:** the large UI/UX + paywall polish and full **de/en localization** happen as one dedicated slice **after** Phase 3 is functionally complete (3c live transcription + 3d AI title/summary), before release. Polishing now would mean re-polishing as 3c/3d add screens.
- Localization will also fix the app-level `Locale.current == en` issue (the app currently ships en-only); the 3b transcript default already works around it via `Locale.preferredLanguages`.

## 2026-06-20 — Phase 3b: batch transcription + monetization Teil B

- **Trial flag in SwiftData** (`TrialState` model behind a `TrialTracking` protocol), **not** UserDefaults: UserDefaults is trivially editable and rides along in iCloud backups/device transfers (a restore could lose or duplicate the "trial used" state); the trial belongs to app state, not settings. The protocol seam keeps it testable (mock in tests, SwiftData in production).
- **Gate before render:** check entitlement/trial first, start the (expensive) transcription only if allowed.
- **Trial is consumed only on successful, persisted completion** — never at start (an aborted run must not burn the free try) — and **only for the first NEW transcription**; re-transcribing an already-transcribed recording consumes nothing.
- **Atomic segment replace:** re-transcription accumulates drafts and persists them in one transaction (delete old + insert new + save, rollback on error). An aborted re-transcription leaves the old segments fully intact — never half old / half new.
- **One shared player:** the transcript screen reuses the existing `AudioPlaybackEngine`/`PlaybackViewModel` for tap-to-seek — never a second player competing for the audio session (cf. the A3 route-change saga).
- **Live segments** stream from `transcriber.results` (already an AsyncSequence) but are persisted only on success. **Own transcript screen** (not the playback screen).
- **Language picker:** default = device language, falling back to an installed language if the device language is not installed; only installed languages are selectable.

## 2026-06-20 — Phase 3a: transcription foundation

- **Data-driven locales** (`TranscriptionLocale.supported`: `de-DE`, `en-US`) — a list, not hardwired branches; a third language is one entry plus its asset download, no code change.
- **The language-model download is an explicit state machine** (`TranscriptionAssetState`: `unsupported`/`notInstalled`/`downloading(progress)`/`installed`/`failed`/`insufficientStorage`), not a Bool. Every state — including a mid-download failure and a full disk — has defined UI/error behavior.
- **`TranscriptionProviding` is the protocol seam**; `SpeechTranscriptionService` (Speech framework) runs only on a real device. Unit tests use a mock; device behavior is verified via DEVICE_TESTS "3a".
- **`TranscriptSegment` + the `Recording.segments` cascade relationship** are added now as an **additive lightweight SwiftData migration** (the part deferred from Phase 1).
- **Phase 3d starts with title + summary only**; key-points and filler-word cleanup are additive later. Foundation Models output is non-deterministic and needs per-output prompt/`@Guide` tuning — calibrating two cleanly beats four at once.

## 2026-06-20 — Final app name: Sprechly (resolves the placeholder)

- **Decision:** The app ships as **Sprechly** (icon/display name). This resolves the earlier "name not locked" placeholder.
- **Store name + subtitle are NOT hardwired in the repo** — they are set in App Store Connect only. Suggested subtitle: "Aufnahme & Transkript". Deliberately **no "Diktat"** (most crowded sub-market; raises confusion with Speechly/Spokenly that the trademark check must clear) and **no "Pro" in the app name** ("Pro" belongs to the IAP tier, not the name).
- **Trademark check first:** the permanent step (creating the IAP product id `de.gcng.sprechly.ai` in ASC) should only happen after a DPMA/EUIPO check (class 9/42) clears "Sprechly". An ASC product id cannot be recycled.
- **Identifiers:** bundle id **`de.gcng.sprechly`**; non-consumable IAP **`de.gcng.sprechly.ai`** (kept in sync between `Entitlement.ai` and `Configuration/VoxStudio.storekit`).
- **Internal name kept:** the Xcode target/module/`.xcodeproj`/folder and the `VoxStudioApp`/`VoxStudioTests`/`@testable import VoxStudio` symbols stay "VoxStudio" — internal, invisible to users, low-risk. Only product-facing identifiers and display strings changed. The `.storekit` file name (`VoxStudio.storekit`) is an internal artifact and is unchanged.

## 2026-06-20 — Phase 2d: mix sums in float, limits via the normalizer seam

- **Mixing sums two tracks in float** (`out = main + volume·mix`), never Int16. Clipping is prevented not by hard-clamping but with a new **`PeakLimiter: LoudnessNormalizer`** (the 2a seam): the summed peak is attenuated to the ceiling (−1 dBFS) only when it would exceed it, never boosted. Reuses the existing abstraction.
- **One volume control (mix track), main fixed at 1.0.** A second fader for the main is mixing-desk thinking, not a voice-recorder case; additive later (just stop fixing the main factor at 1.0).
- **Overhang = truncate.** The result is exactly the main recording's duration, independent of the mix track's position/length; an overhanging mix is cut. The recording is the measure of the result. Covered by a test.
- **Mix-track trim carried in 2d** (`MixSettings.mixTrim`) and **frame-accurate position** (`offset`) via the pure `TrimGeometry`. **Streaming two-track render** — both sources block by block, never fully in memory. Pre-flight validates both sources before any write (no orphan); non-destructive.

## 2026-06-20 — Phase 2c: merge assumes homogeneous library sources

- **Merge concatenates homogeneous library sources (48 kHz mono); no resampling/channel-mapping** — guaranteed by the Phase-1 recording default. A **pre-flight validates format + readability of ALL sources before any write**, so the common "one source doesn't fit" case throws *before* the output file is created — no partial output, no cleanup needed. The runtime cleanup path stays as a safety net for a source that becomes unreadable mid-render. Heterogeneous/imported sources are deferred to **2e** (import with normalization).
- **No crossfade, hard seam, no gap (default).** Crossfade smears speech at word boundaries; an optional defined inter-segment silence would be additive later, on request only.
- **Merge title:** `"Zusammenführung <yyyy-MM-dd HH:mm>"` — consistent with the recording default, always unique, and privileges no single source (unlike `"<first title> + N"`).
- **Memory:** merge streams segment by segment into the output; it never decodes all sources into memory at once.

## 2026-06-20 — Phase 2b: trim re-renders (no AAC stream cut)

- **Trim flows through the same render pipeline as 2a** (`EditSettings.trim`), not a separate stream-cutting path: **one decode, one encode** per edit. Cutting an AAC stream at an arbitrary point forces re-encoding anyway and is frame-inexact; re-rendering keeps trim frame-accurate and composable with speed/normalize in a single pass. Because edits are non-destructive (always from the original), every result is **one generation** from the source, not N — repeated editing does not degrade quality. Order: **trim → speed → normalize**.
- **Minimum trim length = 250 ms**, itself clamped to the source duration (a sub-250 ms recording stays valid). Below ~200 ms a speech clip is a single phoneme and degenerate zero/one-frame ranges could trip TimePitch/the encoder.
- **Editor UI hierarchy:** trim is the primary, visually dominant interaction (large waveform + handles); speed/normalize/format are secondary, compact options below. Keeps the editor from sprawling as 2c/2d add controls.
- **Time↔pixel mapping (`TrimGeometry`) and range clamping (`TrimBounds`) are pure, unit-tested functions** — handle math is verified without UI tests.

## 2026-06-20 — Phase 2a: normalization = peak (LUFS later), render order, defaults

- **Peak normalization for 2a (not LUFS).** Normalize by scaling so the peak hits a target (default **−1 dBFS**). **Known tradeoff:** peak is set by a single transient (a cough, a door slam), so quiet speech can stay quiet — a real weakness for a voice recorder. Chosen as the pragmatic start because true LUFS (ITU-R BS.1770 K-weighting + gating) is meaningfully more work; **loudness-based normalization (RMS → LUFS) is a planned additive follow-up**. Bonus: peak normalization cannot clip (output peak = target ≤ 0 dBFS), so no limiter is needed yet.
- **Normalization sits behind a swappable seam** (`LoudnessNormalizer` protocol; `PeakNormalizer` today) injected into `AudioEditingService` — the render/export pipeline measures nothing itself. So RMS/LUFS is a **new conforming type added alongside**, not surgery in the editing service. This is what makes deferring the better algorithm risk-free.
- **Render-order invariant:** in `AudioEditingService`, **speed/time-stretch is rendered first, then the peak is measured on that result and normalized.** Normalizing before stretching would invalidate the target level (time-stretch changes the waveform/peak). Covered by a test: normalized output hits the same target peak at 1× and 2×.
- **Normalization toggle default = ON** (solves the "had to turn it up" case).
- **Speed/duration tests use a tolerance** (±1 % / ±50 ms), never exact equality — `AVAudioUnitTimePitch` is a time-stretch algorithm (frame rounding + latency), so exact-equality assertions would be flaky in CI.

## 2026-06-20 — No MP3 export (no native encoder on iOS 26)

- **Decision:** MP3 is **excluded** from the export formats. Verified against the iOS 26 SDK (queried `kAudioFormatProperty_Encoders` on the simulator): AAC and ALAC each report 1 encoder, `kAudioFormatMPEGLayer3` reports **0** — iOS can decode but not encode MP3.
- **Consequence:** Phase-2 export offers AAC (`.m4a`) and PCM containers (WAV/AIFF/CAF), optionally ALAC. No LAME/third-party MP3 encoder is added without an explicit instruction from Rene.

## 2026-06-19 — Explicit named SwiftData store

- **Decision:** Use an explicit `ModelConfiguration(url: …/Application Support/VoxStudio.store)` instead of the implicit default store, and create Application Support up front. Deterministic, testable, and a clean basis for CloudKit (§9). Pre-release with no production data, so the move off `default.store` needs **no migration path**.

## 2026-06-19 — Route changes pause, then resume cleanly (revised)

- **Decision:** On an audio route change mid-recording the recorder **pauses**; the user resumes, which restarts the engine cleanly. **Revises** the earlier "continue seamlessly" decision: seamless re-route at the notification moment re-read a stale HFP format (16 kHz) and kept hitting `-10868`.
- **Mechanism:** the converter is rebuilt from the live `buffer.format` (`RecorderConverterFactory`), and **resume recreates the `AVAudioEngine`** so the input node binds to the current hardware format. `installTap(format: nil)` alone is insufficient — it resolves the tap format once at install time and does not update, so a stale 16 kHz tap survived into resume. Engine recreation on resume (the documented escalation) is the bulletproof fix; it is not a hot path. Output stays a constant 48 kHz mono (A6 invariant). Seamless re-route could return later as its own slice by deferring the rebuild until the first stable buffer.

## 2026-06-19 — Phase-1 audio core decisions

- **Recording format:** Mono **48 kHz** AAC (`.m4a`), ~128 kbps. Supersedes the earlier 44.1 kHz default. Variable format selection (rate/bitrate) is deferred to a later slice.
- **Pause/resume:** single continuous `AVAudioFile` + `engine.pause()/start()` with a state-flag guard in the tap. No segment merge (that is Phase 2); duration equals written frames, so it stays exact. An `AVAudioConverter` normalizes tap buffers to the recording format.
- **Engines are persistence-agnostic:** `AudioRecorderEngine`/`AudioPlaybackEngine` work with file URLs and state streams only — no SwiftData, no `RecordingFileStore`. The view model orchestrates the atomic move and persistence (keeps the §3 layering clean).
- **`Recording` model now, `TranscriptSegment` later:** `Recording` is modeled fully (incl. `deletedAt: Date?`); `TranscriptSegment` and the `@Relationship` are added in Phase 3 to avoid an empty migration.
- **Soft-delete retention:** trash with `deletedAt`; auto-purge older than 30 days on launch + manual empty. Delete/purge removes the Documents audio file **and** the Caches waveform sidecar (no orphaned files). The flag is named `isTrashed` (not `isDeleted` as in §8) to avoid clashing with framework delete semantics.
- **Background recording:** `UIBackgroundModes: audio` enabled so recording survives backgrounding/lock.
- **Waveform peaks:** cached as a sidecar in Caches (key = recording id); regenerated on miss (Caches is purgeable; audio stays in Documents).

## 2026-06-19 — App name is a placeholder

- **Decision:** Develop under the working name *VoxStudio* (bundle id `de.gcng.voxstudio`); the final name is **not** locked yet.
- **Rationale:** Unblocks development; the name must be confirmed against App Store Connect availability before release.

## 2026-06-19 — Generate the Xcode project with XcodeGen

- **Decision:** The project is defined in `project.yml`; the `.xcodeproj` is generated via `xcodegen generate` and is git-ignored.
- **Rationale:** Human-readable, diff-friendly project definition; no pbxproj merge conflicts. XcodeGen is a dev-time tool, not an app/runtime dependency, so it stays within the "SPM only, minimal deps" rule.
- **Consequence:** A fresh clone must run `xcodegen generate` before opening in Xcode.

## 2026-06-19 — Monetization: full-price app + one non-consumable

- **Decision:** A single non-consumable IAP `de.gcng.voxstudio.ai` unlocks the AI layer. StoreKit 2 only — no subscriptions, no external payment, no receipt parsing, no server validation.
- **Rationale:** See CLAUDE.md §9a.

## 2026-06-19 — Recording defaults are configurable

- **Decision:** Recording format is user-configurable in Settings; default **Mono 44.1 kHz AAC (M4A)**.

## 2026-06-19 — Soft-delete retention

- **Decision:** Deleted recordings go to a trash and are automatically purged after **30 days**.

## 2026-06-20 — Phase-3 finish before the polish slice

- **Decision:** Finish Phase 3 first (3d Foundation-Models title+summary, 3e transcript export), then a dedicated polish slice (design-system, library/empty-states/transport, deliberate Liquid Glass, a real Settings screen with Impressum/Datenschutz, toolbar-button labeling, onboarding, app icon).
- **Rationale:** Polish a feature-complete surface once instead of re-touching screens that still change. Device feedback flagged the app feels unpolished and that no Settings screen exists yet (CLAUDE.md §10/§11) — both go into the polish slice.

## 2026-06-20 — External audio import for the mixer is Phase 4

- **Decision:** The mixer keeps overlaying existing recordings only; importing external audio (Files/Music) as a second track moves to Phase 4 with the advanced platform features.
- **Rationale:** Device feedback: the mixer is only truly useful with external import, but that is Phase-4 scope, not a Phase-3 blocker.

## 2026-06-21 — Premium is purchase-only (free transcription trial removed)

- **Decision:** All premium (AI) features — transcription, live transcript, AI styles, transcript export, language-model download — execute **only** when the `.ai` purchase is unlocked. The previous "first transcription free" trial is removed (TrialState/TrialTracking deleted, dropped from the SwiftData schema). Premium entry points stay **visible** but are marked with a gold crown; tapping a locked one opens the paywall instead of running.
- **Rationale:** Device feedback — transcription ran without purchase (the trial), which felt like the feature was being given away then taken back. Cleaner to gate strictly and signal premium honestly. Supersedes the trial in CLAUDE.md §9a.

## 2026-06-21 — Premium on devices without Apple Intelligence

- **Decision:** Sell the AI purchase transparently everywhere; the paywall and the Settings premium list show per-device availability. Transcription, live transcript and export (Speech framework) work without Apple Intelligence and are marked available; KI title/summary/translation (Foundation Models) are marked "nicht verfügbar" on devices without Apple Intelligence. The buy button stays (the purchase still delivers transcription).
- **Rationale:** Device feedback (iPad without Apple Intelligence). Blocking the purchase entirely would deny the working transcription features; there is no on-device fallback for the AI part and a server would break the on-device/no-upload promise. Transparency over blocking.
