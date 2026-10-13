# App Review Notes — Sprechly 1.2.0 (11)

Paste into App Store Connect → App Review Information → Notes. No account or
login is required to use the app.

The reviewer contact fields (name, phone, email) live in App Store Connect, not
in this repository — nothing here to carry over.

**What changed in 1.2.0:** transcript text only. Recording, editing, export
formats, the paywall, the purchase and the privacy model are unchanged from
1.1.1, so the review surface is the same.

## Notes for the reviewer

```
No login or account is required. All features are reachable immediately.

HOW TO TEST
• Record: open the app, tap the record button, speak, tap stop. The recording
  appears in the Library tab.
• Transcribe: open a recording → "Transkript"/"Transcript". The first time, a
  language model is downloaded (Settings → Language Models); on Wi-Fi this takes
  a moment. Transcription is on-device.
• Free preview: without the purchase, the button reads "30
  Sekunden gratis testen" / "Try 30 seconds free". It runs a real transcription
  of the first 30 seconds and shows the result, then offers the purchase. This
  preview is intentionally not saved — it cannot be exported, translated or
  summarised, and it is gone when the screen is closed. Full-length
  transcription requires the in-app purchase below.
• Import: Library → "Importieren"/"Import" → pick any audio file. It becomes a
  normal recording you can play, transcribe and edit.
• Live Activity / Dynamic Island: start a recording, then lock the screen — the
  running recording with its timer appears on the lock screen / Dynamic Island.
• In-app purchase: one-time non-consumable "Sprechly AI"
  (de.gcng.sprechly.ai) unlocks full-length transcription, transcript export,
  AI title/summary and translation. Use the provided Sandbox tester to purchase.
  After purchase, "KI/AI → Erstellen" generates a title and summary;
  "Übersetzung/Translation" translates the text. "Käufe wiederherstellen" /
  "Restore Purchases" is on the purchase screen.

PRIVACY
• Recording, transcription and AI run 100% on-device (Apple Speech + Foundation
  Models). No audio or text is uploaded to any server. No tracking, no ads.
• Optional iCloud sync uses the user's own private CloudKit database.

DEVICE REQUIREMENT FOR AI
• AI features (titles, summaries, translation) require a device with Apple
  Intelligence. On devices without it, the app transparently marks these
  features as unavailable and the paywall states the requirement. Recording,
  editing, audio export and transcription itself work on all supported devices.
• Please review the AI purchase on an Apple-Intelligence-capable device so the
  unlocked features are visible.

NEW IN 1.2.0
• Transcripts are tidied after recognition: times appear as 13:45, version
  numbers stay together, letter-by-letter abbreviations are joined, and a short
  fixed list of product names is spelled correctly. This is formatting only —
  recognition itself is unchanged. Transcripts saved by an earlier version are
  cleaned up once on first launch.

KNOWN BEHAVIOUR
• Apple's on-device safety filter may decline some AI summaries/translations for
  sensitive topics; the app shows a clear message and the transcript/export
  still work.
```

## IAP review screenshot

App Review requires a screenshot for the IAP. Provide the paywall with the
product name and price visible:

```
scripts/paywall_shot.sh           # dedicated script; injects the StoreKit config
# Result: Screenshots/<de|en>/iPhone 17 Pro Max/iap-paywall.png
```

Attach the German or English `iap-paywall.png` to the IAP in App Store Connect.

**For 1.2.0 no new IAP screenshot is needed.** The paywall is untouched in this
release — no commit in 1.2.0 changes `Features/`, `DesignSystem/` or any
localisation — so the screenshot supplied with 1.1.1 still shows the current
product name and price. The regeneration steps below stay documented for the
next time the paywall does change.

If ASC rejects the 6.9" shot as the wrong format — the IAP field is stricter than
the marketing screenshot fields — use one of the derived sizes in
`Screenshots/iap-review/` (5.5" `1242x2208` first, then 3.5" `640x920`).
Regenerate them with `scripts/iap_review_sizes.py`; see that folder's README.

## Demo data

Screenshots use seeded demo recordings via the launch argument `SEED_DEMO`
(DEBUG only). The reviewer does not need this; the app works empty and any
real recording exercises all features.
