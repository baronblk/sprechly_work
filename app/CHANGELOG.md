# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/), and this project adheres to
[Semantic Versioning](https://semver.org/).

## [1.2.1] - 2026-10-12

Store release. **The app itself is unchanged from 1.2.0** — the only difference
in the source is the marketing version and the build number. It exists because
App Store previews and custom product pages attach to an App Store version, and
every version needs a build.

### Changed

- New App Store app previews for iPhone, German and English: 28 s, 886 × 1920,
  H.264 High 4.0, 30 fps, with a silent audio track. They replace the videos from
  21 June, which used the device resolution 1320 × 2868 — a size Apple lists for
  reference only and does not accept as a preview.
- Three custom product pages (`cpp-privacy`, `cpp-meetings`, `cpp-dictation`)
  were set up separately in App Store Connect, reusing the approved screenshot
  set and the same preview. They are not part of this build.

## [1.2.0] - 2026-10-10

### Fixed

- Transcripts no longer contain the recogniser's internal markup. When a character was spoken letter by letter, `SpeechTranscriber` emitted a literal backslash token, so "K I" arrived — and was saved — as the visible text `K\letter I\letter`. It reached the stored transcript, the live caption while dictating, and every TXT and Markdown export. Only the one marker observed in measured output is removed; a Windows path, a dictated escape sequence and the words `\letters` or `\letterbox` are left untouched.
- Transcripts already saved with that markup are repaired once, in the launch pass that also empties expired trash. Strictly the marker: a segment carrying it alongside a split version number, a split product name and a dotted clock time comes out with only the marker resolved. Text already on the device is not reformatted retroactively because a new rule shipped.

### Added

- Finished transcripts are tidied where the wording was already right and only the shape was wrong: a time spoken as "quarter to two" is written `13:45` rather than `13.45`, a version number stays together as `1.2.0` instead of breaking across `1. 2.0`, letter-by-letter abbreviations are joined, and a short documented list of product names — StoreKit, CloudKit, SwiftUI, SharePoint, Markdown — is spelled the way they are actually written.
- Every rule is deliberately narrow, because the risk is not missing a correction but inventing one. A time needs an explicit marker after it, so `Kapitel 3.2`, `12.50 Dollar` and `13.45 Prozent` keep their period; a version number needs a preceding keyword; an ambiguous or over-long run of capitals is left alone rather than partly joined; an unlisted product name is never guessed at. Measured on fixed German and English audio, the formatting left correct text untouched in every case.
- The live caption now also drops that markup while you speak. The tidying rules themselves stay off it: a half-spoken sentence would otherwise be guessed at and visibly corrected a word later.

### Changed

- Internal: the three near-identical helper types that existed only to hand a buffer to `AVAudioConverter` are gone, since the framework declares that callback as neither escaping nor Sendable. The recorder's equivalent instance property became a local, removing shared mutable state from the realtime path. No behaviour change.
- The audio pipeline is deliberately unchanged. The duplicate live conversion noted earlier was measured rather than assumed: one conversion is required because the speech analyzer accepts only 16 kHz, and the other costs 6.2µs against the 147.9µs the file write of the same buffer costs. Rebuilding the realtime path to save 0.26 seconds of CPU per recorded hour was not worth the risk.

## [1.1.1] - 2026-10-04

Submitted to App Store Connect as build 10 on 2026-10-04.

### Added

- Settings carries a permanent **"Sprechly bewerten"** entry. The automatic prompt fires at most once per version, which left no way back for anyone who dismissed it. The link is built from the app's real Apple ID and covered by a test, so a typo cannot ship a dead link.
- A quiet entry for the sibling app WhisperScribe Pro on macOS, under "Weitere Apps" — one line, no popup, no banner.

### Fixed

- The transcript screen printed "the AI model is still preparing" above a summary that was already on screen, which reads as a malfunction. The hint now appears only when there is nothing to show.
- The privacy line in Settings claimed no server transfer at all, while iCloud sync is on by default.

### Changed

- The store listing leads with what actually distinguishes the app — buy once, no account, on-device — instead of reaching it in the fourth paragraph. **Two claims were untrue and were corrected rather than reworded:** the listing offered export "as M4A, AAC, WAV, AIFF, CAF" while only M4A and WAV exist, and it promised the voice "never leaves your device" while iCloud sync is on by default and uploads the audio to the user's private database.
- A new six-shot captioned screenshot set per language and device, with per-device wording so an iPad shot no longer claims the transcript runs "on your iPhone".

## [1.1.0] - 2026-08-19

### Added

- Transcription can be tried before buying: a locked run transcribes the first 30 seconds of a recording and shows the result. The preview is never persisted, so it cannot be exported, translated, AI-summarised or kept, and leaving the draft loop tears the transcription stream down rather than quietly processing the whole file.
- The paywall argues with the result instead of a feature list: reached from a preview it shows the user's own transcript, otherwise a clearly labelled example transcript and the AI summary made from it. Layout moved to a scroll area with a pinned purchase bar.
- The idle recording screen now carries the live-transcript switch (previously buried in Settings, crowned when locked) and names what a recording enables; a saved take confirms itself and offers the way straight to the library.
- The App Store rating prompt is reachable without buying: a saved take, and a finished edit, merge or mix now count as positive moments. Every trigger previously sat behind the AI purchase, so the vast majority of users could never reach it.

### Fixed

- Library search was completely hidden behind the app's own tab bar: iOS 26 places `.searchable` at the bottom edge by default, which the custom bar (a `safeAreaInset`, not a native `TabView`) covered. The field is now pinned under the title.
- The end of every playback screen sat behind the tab bar, so the last lines of a transcript could never be read — the `NavigationSplitView` detail column does not inherit the bar's safe-area inset. The bar now publishes its measured height through the environment.
- The CloudKit reconciler no longer holds the whole library in memory. It ran on every launch, foreground and remote change, reading each recording fully onto the heap and keeping every blob alive until a single save at the end, which could exhaust memory on a multi-hour library. Files are mapped rather than copied, each recording is saved individually, and a failed row rolls back instead of aborting the sweep. Adds the first tests for both sync directions.
- Editor, merge and mix reported "saved to library" even when the SwiftData save failed, leaving the recording missing and the audio file behind as an invisible orphan. The save now propagates, rolling back both the pending insert and the file.

### Changed

- Store description corrected: it claimed recording *and transcription* were free, while transcription has been purchase-only since the trial was removed. It now states what actually applies — recording, editing and audio export are free, transcription is free to try for 30 seconds.

### Removed

- Dead `RecordingSettings.processingFormat` (unused, and the only force-unwrap in a production path). The build is now free of warnings under strict concurrency.

## [1.0.1] - 2026-06-23

### Fixed

- Playback: only one recording is ever audible. A process-wide `NowPlaying` coordinator stops the previously playing recording when a new one starts, and playback stops on returning to the list (selection-driven) — replacing the fragile per-view `onDisappear` teardown that caused overlapping audio and prevented the second recording from playing. The `.playback` audio session is now activated before the player is prepared. Verified on device via the unified log (clean alternating AudioQueue start/stop).
- AI translation no longer false-positives on Apple's on-device safety filter for benign content: AI sessions use `SystemLanguageModel(guardrails: .permissiveContentTransformations)`.
- Transcript export (TXT/Markdown) is written with a UTF-8 BOM so German umlauts/ß render correctly in editors that would otherwise assume Latin-1.
- iCloud trash count and editor cut/"keep selection" corrected; CloudKit background-task identifier permitted in Info.plist.
- Recording no longer hits `-10868` on audio route changes: resume recreates the audio engine so the tap binds to the current hardware format (a `format: nil` tap alone kept a stale 16 kHz format), and the converter is rebuilt from the live buffer format. Route changes pause recording; resume restarts cleanly on the new route.
- First launch no longer logs a CoreData error wall; Application Support is created explicitly and the store uses a named URL with an in-memory fallback.

### Added

- Live Activity & Dynamic Island for the active recording: a `SprechlyWidgets` widget extension renders the running/paused state with an on-device counting timer on the lock screen and in the Dynamic Island; updates only on state transitions.
- External audio import into the Library: pick any audio file (`.fileImporter`), transcode it to the recording format (48 kHz mono, CAF→m4a) and save it as a first-class recording that can be played, transcribed and edited. Also usable as the second track in the mixer.
- More AI styles: key takeaways (Kernaussagen) and clean-up (Bereinigung), alongside summary, meeting minutes and bullet points.
- Transcript translation persisted on the recording (`translation` + `translationLanguageCode`); requires the matching CloudKit Production schema (deployed).
- German/English localization via String Catalogs; iPad top-level sidebar (3-pane), transcript reading view, warm empty states.

- Phase-3b batch transcription: transcribe a recording into timestamped, tappable (seek) segments on a dedicated screen sharing the playback engine; live segments stream in; result persists atomically (an aborted run keeps the old transcript). Gated behind the AI entitlement with a free first transcription (SwiftData trial), and a paywall (`PaywallView`) with localized price and prominent restore.
- Phase-3a transcription foundation: `TranscriptSegment` model + cascade relationship (lightweight migration), data-driven locales (de/en), an explicit asset-download state machine, the `SpeechTranscriptionService` (Speech framework, behind a protocol), and a transcription setup screen to download language models with progress.
- Phase-2d mix: overlay a second library recording on the main one with a mix-volume control, a frame-accurate position, and an optional trim of the mix track. Float summation with a peak limiter (no hard clipping); the result is truncated to the main recording's duration. Completes Phase 2.
- Phase-2c merge: select multiple library recordings and concatenate them in a reorderable order into a new recording. Streaming (one segment in memory at a time); all sources are pre-flight validated (format + readability) before any write, so a mismatched/missing source aborts with no partial output. Hard seams, no crossfade.
- Phase-2b trim: non-destructive trim with draggable waveform handles (250 ms minimum), routed through the same render pipeline (one decode, one encode) so repeated edits do not degrade quality; combinable with speed/normalization in one pass.
- Phase-2a editor: non-destructive speed (pitch-preserving) and peak-normalization render, export to M4A/WAV, save as a new recording, and share. Offline render runs off the main actor with a progress indicator. MP3 excluded (no iOS encoder).
- Phase-1 audio core: AVAudioSession config with interruption/route handling, `AudioRecorderEngine` and `AudioPlaybackEngine` (actors, persistence-agnostic), `WaveformGenerator`, Canvas `WaveformView`, `Recording` SwiftData model, `RecordingFileStore` (atomic move + sidecar peaks, orphan-free delete).
- Recording, playback and library screens with real tab navigation; trash with restore, manual empty and 30-day auto-purge; background recording.
- XcodeGen project definition (`project.yml`), app shell (entry point, app state, routing), and design-system theme tokens.
- StoreKit 2 monetization scaffold: `Entitlement`, `EntitlementProviding`, `StoreManager`, and a reusable entitlement gate.
- Tests: entitlement gating via a mock store and a StoreKit Testing purchase integration test.
- Project memory under `docs/` and a changelog.
- App icon (indigo→blue gradient with a glowing waveform) and a reproducible CoreGraphics generator script.
