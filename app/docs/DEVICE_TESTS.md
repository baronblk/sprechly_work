# Device Tests

Verification log for behaviours that the Simulator cannot fully exercise
(audio routing, interruptions, real-device persistence, VoiceOver, long-run
memory). Each entry records status, date and the commit it was verified at.

Status: ✅ green · ◑ partly verified (automated half green, taps open) · ⏳ pending · ❌ failed

| ID | Scenario | Status | Date | Commit | Notes |
|----|----------|--------|------|--------|-------|
| A3 | Route change during recording: BT/wired disconnect → pause → resume records cleanly at 48 kHz; reconnect likewise; resulting file gapless, duration correct | ✅ | 2026-06-20 | `3b9cacc` | Fixed by recreating the `AVAudioEngine` on resume (fresh input node binds current HW format). Root cause was a stale tap/graph format (`-10868`), not the session. See IOS26_NOTES.md. |
| A6 | Long recording (≥30 min) with pause/resume **plus** a route change mid-recording, optional call interruption | ✅ | 2026-06-20 | `ffbef30` | Physical iPhone · iOS 26. The continuous `AVAudioFile` survived the route change incl. engine-recreate — gapless playback to end, duration = active recording time (pauses not counted), flat memory. **Single-file architecture proven; no segment+merge needed.** |
| FL | Fresh first launch (delete app first) → zero CoreData errors in log; record → relaunch → recording still present | ✅ | 2026-06-20 | `ffbef30` | Physical iPhone · iOS 26. Clean first launch, no CoreData error wall; recording persisted across relaunch. Closes the explicit Application Support + named-store fix. |
| 2a | Editor/merge/mix render of a long (≥30 min) file on device: progress smooth, memory flat, Share sheet yields a valid file | ✅ | 2026-10-05 | `e77105e` | **Renderers verified on device, 30-min source.** Editor (trim + 1.25× + normalize) out 1344.000 s = expected, 19 689 monotonic progress ticks, peak 0.89 — not silence. Merge 3144.000 s = exact sum. Mix truncated to main (1800.000 s). Export M4A 46.5 MB and WAV 301.8 MB, both full length, both non-silent. Edit 10.9 s, mix 10.3 s, merge 1.0 s — no memory anomaly. `LongFileEditingDeviceTests`, raw data in docs/benchmarks/. The Share-sheet half is gate 3e. |
| 3a | Transcription assets on device (iPhone 17 Pro, iOS 26): de+en availability, model download with progress, persistence across relaunch | ✅ | 2026-06-20 | `1128aa0` | Availability ✅, download ✅ (de+en, ≤30 s), **persistence ✅** (recording survived relaunch, no CoreData errors). Abort/offline not reproducible once installed (no app-side delete API) → failure mapping stays code-verified only. Migration is a non-event (bundle-id rename → fresh app born with the `TranscriptSegment` schema). Gate to 3b open. |
| 3b | On device: transcribe a recording (de+en) → timestamped segments, tap-to-seek; gating: first free → paywall → purchase unlocks; restore | ✅ | 2026-10-05 | `b55bfbc` | **Green, automated plus a real fresh purchase.** Automated: product resolves against the real App Store (the `.storekit` config sits on the scheme's launch action, not its test action) — one product, `de.gcng.sprechly.ai`, Non-Consumable, `displayPrice` from StoreKit, and no price literal anywhere in the release binary. **Manual, by Rene on an iPhone 12 Pro (`00008101-001A0C623E43003A`), Release build 1.2.0 (11) launched from the home screen:** the account there did not own the product, so this was a genuine first purchase — paywall showed 6,99 €, the purchase completed, and premium unlocked immediately. The iPhone 17 Pro could not serve for this: its account already held the entitlement, which would only ever have exercised restore. |
| 3c | Live-during-recording transcription on device: unlocked → running volatile caption above the waveform updates in real time, finalized segments persist on stop; locked → toggle shows paywall, recording still runs without live | ✅ | 2026-06-20 | `b12a4a8` | Live caption runs and persists; occasional brief catch-up lag is the progressive transcriber's volatile-result cadence, not a hang (it recovers). Paywall path not re-verified on device (already unlocked) — covered by 3b + unit tests. Live captions are premium (unlock-only, no trial). |
| 3d | AI post-processing on device (Foundation Models): from a transcript, generate a title + summary; card shows result; "Titel übernehmen" applies the AI title; locked → paywall; availability hint when Apple Intelligence is off | ✅ | 2026-06-20 | `0f38bae` | Title + summary generate on device, "Titel übernehmen" updates the library title, re-generate is free. Foundation Models runs only on device (not Simulator). Unlock-only (no trial). Title is a suggestion — never auto-overwrites the user title. Also fixed: library scope switch moved out of the toolbar (was collapsing into a broken glass circle under iOS 26). |
| 3e | Transcript export on device: transcript screen → Export menu → TXT/Markdown → share sheet opens with a valid named file; locked → paywall | ✅ | 2026-10-05 | `9789969` | **Green, automated plus manual.** Automated: `TranscriptionViewModel.exportFile` — the exact call handed to `ShareLink` — produces both files with the UTF-8 BOM, correct timestamps, umlauts intact, no `\letter`; locked yields no file. **Manually confirmed on device by Rene (real recording "Route zum Schneeberg", 02:52):** share sheet opens for both formats, both saved to Files, umlauts correct, UTF-8 correct, timestamps and summary present, Markdown correctly structured, no visible `\letter`. |
| DCT | Dictaphone overwrite on device: record → pause → scrub/−10/+10 + "Anhören" → continue recording from the cursor overwrites the tail → stop saves a gapless take with correct duration; multiple rewrites in one take work | ✅ | 2026-10-05 | `65333d2` | **Verified manually by Rene on device**, 1.2.0 (11) release build. The audio path had only ever been covered by view-model unit tests. Not touched by 1.2; run because the release asks for it. Note on the UI: there is no "Überarbeiten" button — pausing enters the review mode directly. |
| VO | VoiceOver on recording / playback / library screens | ✅ | 2026-10-05 | `65333d2` | **Release blocker cleared.** Verified manually by Rene on device against the 1.2.0 (11) release build: every interactive element reachable by swipe and sensibly labelled across the recording screen (idle and running), the paused transport, the waveform, library, playback, transcript and paywall; states announced. Open since the Phase-2 go — this is the first time it has been run on hardware. |

## Continuous integration

`.github/workflows/ci.yml` runs the full test suite on every push/PR on a
self-hosted macOS runner (the dev MacBook; simulator, **iOS 26.2** — StoreKit Testing
is broken on the 26.5 runtime). First live run **green** (34 tests,
[run 27851451628](https://github.com/baronblk/voxstudio/actions/runs/27851451628)).
The runner (`macbook-renesuss`, labels `self-hosted`/`macOS`/`macbook`) is installed
as a launchd service (`~/actions-runner/svc.sh`), so it survives logout/reboot.

## Foundation gate

**Gate OPEN (2026-06-20):** A3, A6 and FL are all green on device — the recording
foundation is proven and Phase 2 may start. VoiceOver (VO) remains a release
blocker but does not gate the foundation; run it in parallel.

## Release gate — 1.2.0 (11)

**All rows green (2026-10-05).** The three release gates were closed for this
version: `2a` (renderers on a half-hour file), `3e` (transcript export through
the share sheet) and `3b` (a real first purchase on an iPhone 12 Pro). The two
long-standing rows were closed with them: **`VO`, carried as a release blocker
since the Phase-2 go**, and `DCT`, whose audio path had only ever been covered
by view-model tests.

Nothing device-side is outstanding for 1.2.0. The two known issues that remain
are pre-existing and documented as maintenance items, not as gates: the AAC
container finalising asynchronously after `stop()` and the CloudKit failure in
the full on-device test suite.
