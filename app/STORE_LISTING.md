# App Store Listing — Sprechly 1.2.0

**Unverändert seit 1.1.1:** Name, Untertitel, Werbetext, Beschreibung, Keywords,
Screenshots, Preis und IAP. 1.2.0 ändert ausschließlich Transkripttext, kein
Feature und keine Format-Zusage — neu zu setzen ist deshalb **nur** „Was ist
neu" (DE + EN) und die Review-Notiz.

Die 1.1.1-Blöcke bleiben unten stehen: diese Version ist in App Store Connect
noch `WAITING_FOR_REVIEW`, ihr Text wird also möglicherweise noch gebraucht.

Copy/paste source for App Store Connect. Two locales: **German (primary)** and
**English (U.S.)**. Character limits noted; counts checked against ASC maxima.
Set the real **price = Free**, IAP per `MONETIZATION.md`.

- **Bundle ID:** `de.gcng.sprechly`
- **SKU:** `de.gcng.sprechly`
- **Apple ID (App Store):** `6782676748` · App Store URL: https://apps.apple.com/app/id6782676748
- **Primary category:** Productivity · **Secondary:** Utilities
- **Age rating:** 4+
- **Copyright:** © 2026 Rene Süß
- **Support URL:** https://support.gcng.de
- **Marketing URL:** https://www.gcng.de/sprechly/  *(landing page — `docs/html/index.html`)*
- **Privacy Policy URL:** https://www.gcng.de/sprechly/privacy.html  *(host `docs/html/privacy.html`)*
- **Marketing site source:** `docs/html/` (landing, privacy, impressum; DE/EN, dark/light) — see `docs/html/SECURITY-HEADERS.md` for deploy
- **EULA:** Apple Standard EULA (the paywall links it). No custom EULA needed.

---

## Deutsch (Primärsprache)

**App-Name** (max 30): `Sprechly: Diktiergerät & KI`

**Untertitel** (max 30): `Transkription offline ohne Abo`

**Werbetext / Promotional Text** (max 170, jederzeit änderbar):
`Aufnehmen, transkribieren, zusammenfassen – direkt auf deinem Gerät. Kein Abo, kein Konto. Teste die Transkription 30 Sekunden gratis an jeder Aufnahme.`

**Keywords** (max 100, kommagetrennt, ohne Leerzeichen):
`sprachmemo,transkribieren,meeting,protokoll,interview,zusammenfassung,aufnahme,recorder,sprache,text`

**Beschreibung** (max 4000):
```
Sprechly verwandelt Gesprochenes in Text – direkt auf deinem iPhone. Aufnehmen, transkribieren, zusammenfassen, exportieren.

EINMAL KAUFEN, KEIN ABO
Kein Monatsbeitrag, kein Konto, keine Anmeldung. Transkription und KI rechnen vollständig auf deinem Gerät – deine Aufnahmen werden weder an uns noch an Dritte übertragen.

Teste die Transkription 30 Sekunden lang gratis an jeder Aufnahme, bevor du dich entscheidest.

AUFNAHME WIE EIN PROFI-DIKTIERGERÄT
• Glasklare Aufnahme in Mono 48 kHz AAC, auch im Hintergrund und bei gesperrtem Bildschirm
• Live-Pegel und mitlaufende Wellenform
• Live Activity & Dynamic Island: laufende Aufnahme mit Timer direkt auf dem Sperrbildschirm
• Zurückspulen, anhören und ab dem Cursor neu aufnehmen – Versprecher einfach überschreiben
• Lückenloser Schnitt dank verlustfreier Aufnahme

TRANSKRIPTION – ON-DEVICE (30 Sekunden gratis testen)
• Wandle jede Aufnahme in präzisen Text um, komplett offline
• Teste die Transkription an jeder Aufnahme 30 Sekunden lang kostenlos
• Live-Transkript schon während der Aufnahme
• Externe Audiodateien importieren (aus Dateien oder Musik) und wie eigene Aufnahmen transkribieren und bearbeiten
• Viele Sprachen, Sprachmodelle einmalig laden und offline nutzen
• Tippe auf eine Stelle im Transkript und springe direkt zur Audioposition
• Komfortable Leseansicht oder Segmente mit Zeitmarken

KI – KOMPLETT AUF DEM GERÄT (einmaliger Kauf)
• Automatische Titel und Zusammenfassungen
• Verschiedene Stile: Zusammenfassung, Protokoll, Stichpunkte, Kernaussagen, Bereinigung
• Übersetzung deines Transkripts in viele Sprachen
• Angetrieben von Apple Intelligence – nichts wird hochgeladen

BEARBEITEN, MISCHEN, EXPORTIEREN
• Trimmen und Schneiden, unnötige Pausen und Stille automatisch entfernen
• Mehrere Aufnahmen zusammenführen, zweite Spur überlagern (Mix) – auch mit importierten Dateien
• Geschwindigkeit und Lautstärke anpassen
• Export als M4A (AAC) oder WAV – und Transkript als TXT oder Markdown (UTF-8, korrekte Umlaute)
• Teilen über die System-Freigabe

DEINE DATEN BLEIBEN BEI DIR
• Transkription und KI laufen zu 100 % on-device
• Kein Tracking, keine Werbung, keine Weitergabe an Dritte
• Der optionale iCloud-Sync läuft ausschließlich über deine eigene private iCloud – abschaltbar in den Einstellungen

PREIS
Sprechly ist kostenlos: Aufnehmen, Bearbeiten, Schneiden, Mischen und der Audio-Export sind unbegrenzt gratis. Die Transkription testest du an jeder Aufnahme 30 Sekunden lang kostenlos. Vollständige Transkripte, Transkript-Export und die KI-Funktionen (Titel, Zusammenfassung, Übersetzung) schaltest du mit einem einmaligen Kauf frei – kein Abo.

Hinweis: Die KI-Funktionen erfordern ein Gerät mit Apple Intelligence. Aufnahme, Bearbeitung und Audio-Export funktionieren auf allen unterstützten Geräten.
```

**Was ist neu / What's New** (1.2.0, max 4000) — **noch nicht in ASC gesetzt**:
`Aufgeräumte Transkripte.

BEHOBEN
• Wenn du Buchstaben einzeln gesprochen hast, landete im Transkript interner technischer Text statt der Abkürzung. Das ist behoben – im Transkript, in der Live-Anzeige während der Aufnahme und in den Export-Dateien.
• Transkripte, die noch mit diesem Fehler gespeichert wurden, werden beim ersten Start einmalig bereinigt.

VERBESSERT
• Uhrzeiten stehen jetzt als 13:45 im Text statt mit Punkt.
• Versionsnummern bleiben zusammen, statt auseinanderzufallen.
• Einzeln gesprochene Abkürzungen werden zusammengezogen.
• Bekannte Fachbegriffe wie StoreKit, CloudKit, SwiftUI, SharePoint und Markdown werden korrekt geschrieben.

Das betrifft die Schreibweise, nicht die Worterkennung selbst. Die Regeln sind absichtlich vorsichtig gehalten: lieber eine Stelle unverändert lassen, als richtigen Text zu verschlimmern.

Zur Erinnerung: Transkription und KI laufen vollständig auf deinem iPhone. Kein Abo, kein Konto. Die ersten 30 Sekunden jeder Aufnahme transkribierst du gratis.

Feedback jederzeit an support@gcng.de.`

---

### Vorherige Version (1.1.1 — in Review, Text ggf. noch nötig)

**Was ist neu / What's New** (1.1.1, max 4000):
`Sprechly bewerten – und ein aufgeräumter Auftritt.

NEU
• „Sprechly bewerten" direkt in den Einstellungen: Du kannst jetzt jederzeit eine Bewertung hinterlassen, nicht nur wenn die App danach fragt.

VERBESSERT
• Die App-Beschreibung im Store sagt jetzt genau, was Sprechly kann – und was der einmalige Kauf umfasst.

Zur Erinnerung: Transkription und KI laufen vollständig auf deinem iPhone. Kein Abo, kein Konto. Die ersten 30 Sekunden jeder Aufnahme transkribierst du gratis.

Feedback jederzeit an support@gcng.de.`

---

## English (U.S.)

**App Name** (max 30): `Sprechly: Voice Recorder & AI`

**Subtitle** (max 30): `Private offline transcription`

**Promotional Text** (max 170):
`Record, transcribe, summarize — right on your device. No subscription, no account. Try transcription free for 30 seconds on any recording.`

**Keywords** (max 100):
`memo,transcribe,meeting,minutes,notes,interview,lecture,dictation,speech,text,audio,summary,record`

**Description** (max 4000):
```
Sprechly turns speech into text — right on your iPhone. Record, transcribe, summarize, export.

BUY ONCE, NO SUBSCRIPTION
No monthly fee, no account, no sign-up. Transcription and AI run entirely on your device — your recordings are never sent to us or to any third party.

Try transcription free for 30 seconds on any recording before you decide.

RECORD LIKE A PRO DICTAPHONE
• Crisp mono 48 kHz AAC recording, even in the background and on the lock screen
• Live level meter and running waveform
• Live Activity & Dynamic Island: your active recording with a timer right on the lock screen
• Rewind, listen back and re-record from the cursor — just overwrite slip-ups
• Gapless editing thanks to lossless capture

TRANSCRIPTION — ON-DEVICE (try 30 seconds free)
• Turn any recording into accurate text, fully offline
• Try transcription free on any recording for 30 seconds
• Live transcript while you record
• Import external audio files (from Files or Music) and transcribe and edit them like your own recordings
• Many languages; download a language model once and use it offline
• Tap anywhere in the transcript to jump to that audio position
• Comfortable reading view or timestamped segments

AI — FULLY ON-DEVICE (one-time purchase)
• Automatic titles and summaries
• Different styles: summary, meeting minutes, bullet points, key takeaways, clean-up
• Translate your transcript into many languages
• Powered by Apple Intelligence — nothing is uploaded

EDIT, MIX, EXPORT
• Trim and cut, remove unwanted pauses and silence automatically
• Merge multiple recordings, overlay a second track (mix) — including imported files
• Adjust speed and volume
• Export as M4A (AAC) or WAV — and transcripts as TXT or Markdown (UTF-8, correct umlauts)
• Share via the system share sheet

YOUR DATA STAYS WITH YOU
• Transcription and AI run 100% on-device
• No tracking, no ads, nothing shared with third parties
• Optional iCloud sync uses only your own private iCloud — switch it off in Settings

PRICING
Sprechly is free: recording, editing, cutting, mixing and audio export are unlimited and free. Transcription is free to try for 30 seconds on any recording. Full transcripts, transcript export and the AI features (titles, summaries, translation) unlock with a single one-time purchase — no subscription.

Note: AI features require a device with Apple Intelligence. Recording, editing and audio export work on all supported devices.
```

**What's New** (1.2.0, max 4000) — **not yet set in ASC**:
`Tidier transcripts.

FIXED
• Speaking letters one by one put internal technical text into the transcript instead of the abbreviation. That is fixed — in the transcript, in the live caption while recording, and in exported files.
• Transcripts already saved with that problem are cleaned up once, on first launch.

IMPROVED
• Times now read as 13:45 instead of using a period.
• Version numbers stay together instead of breaking apart.
• Abbreviations spoken letter by letter are joined up.
• Known technical names such as StoreKit, CloudKit, SwiftUI, SharePoint and Markdown are spelled correctly.

This affects how words are written, not the recognition itself. The rules are deliberately cautious: better to leave something as it is than to make correct text worse.

A reminder: transcription and AI run entirely on your iPhone. No subscription, no account. The first 30 seconds of any recording transcribe for free.

Feedback any time: support@gcng.de.`

---

### Previous version (1.1.1 — in review, text may still be needed)

**What's New** (1.1.1, max 4000):
`Rate Sprechly — and a clearer store presence.

NEW
• "Rate Sprechly" right in Settings: leave a review whenever you like, not only when the app asks.

IMPROVED
• The App Store description now states exactly what Sprechly does — and what the one-time purchase covers.

A reminder: transcription and AI run entirely on your iPhone. No subscription, no account. The first 30 seconds of any recording transcribe for free.

Feedback any time: support@gcng.de.`

---

## App Privacy (Nutrition Label)

Declare in ASC → App Privacy:

- **Data Not Collected.** Sprechly collects no data. Recordings, transcripts and
  AI results stay on the device (and in the user's private iCloud, if enabled).
- No tracking, no third-party SDKs, no analytics, no ads.
- `ITSAppUsesNonExemptEncryption = false` (already set / declare "No" for export
  compliance — uses only standard Apple encryption).
- Permissions used: **Microphone** (recording). Speech/AI run on-device.

## TestFlight — „What to Test" (Build 1.1.1 (10))

**Deutsch:**
```
Build 10 – Schwerpunkt: Store-Auftritt und Bewertungseintrag.

Bitte testen (ohne gekauften KI-Zugang):
• „30 Sekunden gratis testen" auf dem Transkript-Bildschirm: Es läuft eine echte Transkription der ersten 30 Sekunden. Danach erscheint „Vorschau endet hier".
• „Vollständig freischalten" antippen: Die Kaufansicht muss deinen eigenen Vorschautext zeigen, nicht ein Beispiel.
• Die Vorschau darf nirgends gespeichert werden – schließe den Bildschirm und öffne ihn neu: es darf kein Transkript zurückbleiben.
• Aufnahme starten und stoppen: Es muss „Aufnahme gespeichert" mit dem Weg zur Bibliothek erscheinen.
• Live-Transkript direkt auf dem Aufnahmebildschirm ein-/ausschalten.

Bitte testen (mit KI-Zugang):
• Transkription in voller Länge, KI-Zusammenfassung, Übersetzung, Transkript-Export.

Außerdem behoben – bitte gegenprüfen:
• Suche in der Bibliothek ist sichtbar und bedienbar (war hinter der unteren Leiste).
• Bei einer Aufnahme mit langem Transkript bis ganz nach unten scrollen – die letzte Zeile muss vollständig lesbar sein.

Hinweis: KI-Funktionen laufen nur auf Geräten mit Apple Intelligence.
```

**English:**
```
Build 10 – focus: store presence and the rating entry.

Please test (without the AI purchase):
• "Try 30 seconds free" on the transcript screen: a real transcription of the first 30 seconds runs, then "Preview ends here" appears.
• Tap "Unlock everything": the purchase screen must show your own preview text, not a canned example.
• The preview must never be saved – close the screen and reopen it: no transcript may remain.
• Start and stop a recording: "Recording saved" must appear, with a way into the library.
• Switch the live transcript on and off right on the recording screen.

Please test (with the AI purchase):
• Full-length transcription, AI summary, translation, transcript export.

Also fixed – please verify:
• Library search is visible and usable (it used to sit behind the bottom bar).
• On a recording with a long transcript, scroll all the way down – the last line must be fully readable.

Note: AI features require a device with Apple Intelligence.
```

## Screenshots (ASC)

Upload from **`Screenshots/store/<lang>/<device>/`** — those carry the headline.
The raw captures in `Screenshots/<lang>/<device>/` are the input to the composer,
not the upload. The file numbering already is the upload order:

| # | File | Headline (DE) |
|---|---|---|
| 1 | `01-transcript` | Sprich. Sprechly schreibt mit. |
| 2 | `02-summary` | Aus 30 Minuten werden 5 Zeilen |
| 3 | `03-usp` | Kein Abo. Kein Konto. |
| 4 | `04-record` | Versprecher? Einfach überschreiben |
| 5 | `05-edit` | Schneiden, mischen, exportieren |
| 6 | `06-library` | Alle Aufnahmen, sofort gefunden |

The first one or two are what most people ever see, so the transcript leads and
the recorder comes fourth.

`iap-paywall` is the **IAP review screenshot** and belongs on the in-app
purchase, not in the marketing set (fallback sizes: `Screenshots/iap-review/`).

**Caption claims are checked against the app**, not written freely:
`05-edit` names M4A/WAV/TXT/Markdown because that is exactly what `ExportFormat`
and `TranscriptExportFormat` support, and `03-usp` says "kein Konto" rather than
"kein Upload" because iCloud sync is on by default and does upload audio to the
user's private database.

Regenerate:

```
scripts/screenshots.sh                      # raw captures, DE + EN, iPhone + iPad
python3 scripts/compose_store_screenshots.py # adds the headlines
```

---

## Pre-submission checklist (ASC, by Rene)

Done (per `docs/ROADMAP.md`):
- [x] Trademark check "Sprechly" (DPMA/EUIPO)
- [x] App record created (Apple ID 6782676748), categories, age rating 4+
- [x] IAP `de.gcng.sprechly.ai` created + submitted (price stays **6,99 €**; the raise is deferred, see `MONETIZATION.md`)
- [x] Paid Apps Agreement active; Sandbox tester; Sandbox/TestFlight purchase verified
- [x] Screenshots 6.9" iPhone + 13" iPad, DE + EN; preview video
- [x] Privacy Policy URL entered; App Privacy = Data Not Collected
- [x] **CloudKit Production schema deployed** (incl. `translation` + `translationLanguageCode`) — no CKError 2

Remaining for this release — **1.1.1 (10)**:

- [ ] ~~Raise the IAP price to 9,99 €~~ — **deferred (2026-10-05)**, not part of 1.1.1 or 1.2.0. Preconditions in `MONETIZATION.md` →
      "Release checklist 1.1.1". Schedule it to take effect with the release so
      price and store presence change together.
- [ ] Create the **1.1.1** version in ASC
- [ ] Build and upload the IPA (archive + export, as for 1.1.0)
- [ ] Select build 10; paste "What to Test" (above)
- [ ] **Replace name, subtitle, keywords, promo text and description** (DE + EN)
      — the live description still contains the two wrong claims
- [ ] Paste What's New (DE + EN) from this file
- [ ] Upload the six screenshots per language from `Screenshots/store/<lang>/…`
- [ ] Submit 1.1.1 (10) for App Review → on "Approved", release

Previous release 1.1.0 (9): submitted 2026-08-20, live.
