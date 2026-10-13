# Sprechly 1.2 Release Candidate Plan

Erstellt 2026-10-04 nach dem Scope Freeze, abgeschlossen 2026-10-05.

## Status: **release-bereit, keine offene Bedingung mehr**

Alle Gerätegates grün, Regression grün, Benchmarks zifferngleich, Version auf
1.2.0 (11) gebumpt, Changelog, Review Notes und „Was ist neu" fertig.

**Die ASC-Abhängigkeit ist aufgelöst (2026-10-05):** 1.1.1 ist durch die Review
und freigegeben — `READY_FOR_SALE`. Der Zwischenstand war
`PENDING_DEVELOPER_RELEASE`, weil 1.1.1 als einzige Version bisher
`releaseType=MANUAL` trägt (1.0.0 bis 1.1.0 liefen auf `AFTER_APPROVAL` und
gingen automatisch live). Eine 1.2.0-Version lässt sich jetzt anlegen, Build 11
ist weiterhin frei.

**Für 1.2.0 die Freigabeart bewusst wählen:** `AFTER_APPROVAL` veröffentlicht
sofort nach der Genehmigung, `MANUAL` wartet auf einen Klick. Bei `MANUAL`
bleibt die Version sonst unbemerkt stehen — genau das ist bei 1.1.1 passiert.

Noch nicht ausgeführt: Merge nach `main`, Tag, Einreichung zur Review.

---

## Frozen Scope

**Sprechly 1.2 — Transcription Quality & Smart Formatting**

Enthalten:

- konservativer `TranscriptSemanticFormatter`
- Bereinigung des belegten `\letter`-Markup-Bugs
- sichere Behandlung marker-geführter Akronyme
- Uhrzeitformatierung
- Versionsformatierung
- belegte technische Schreibweisen
- gezielte Migration alter `\letter`-Segmente
- eingefrorene DE- und EN-Benchmarks
- Entfernung der drei unnötigen `@unchecked Sendable`-Wrapper
- unveränderte Audioarchitektur nach gemessener Performanceanalyse

Nicht enthalten: Personal Vocabulary · `contextualStrings` ·
`DictationTranscriber`-Migration · generative Autokorrektur · Apple Watch ·
Siri/Shortcuts · große Audio-Pipeline-Migration · weitere Performanceforschung.

Codeumfang gegenüber `main` (ohne Tests/Docs): **7 Dateien, +448/−32 Zeilen.**

## Known Non-Blocking Issues

Dokumentiert, nicht Teil von 1.2:

| # | Befund | Status |
|---|---|---|
| 1 | AAC-Dateifinalisierung nach `AudioRecorderEngine.stop()` nicht synchron; `finalizeCurrentFile()`-Kommentar zu stark formuliert | pre-existing, auf `a5cc2e2` reproduziert, < 100 ms, `docs/LIVE_AUDIO_PIPELINE.md` |
| 2 | 16 Suites der vollständigen Gerätesuite scheitern mit `No eligible connection available` (CloudKit-Container des Test-Hosts) | pre-existing, auf `2f41f3b` reproduziert, `docs/SEMANTIC_FORMATTING.md` |

## Version / Build

**Konvention verifiziert, nicht angenommen:**

- `project.yml` hält `MARKETING_VERSION` und `CURRENT_PROJECT_VERSION` je
  **zweimal** (App-Target Zeile 44/45, Test-Target Zeile 75/76).
- `App/Info.plist` referenziert beide über `$(MARKETING_VERSION)` /
  `$(CURRENT_PROJECT_VERSION)` — dort ist **nichts** zu ändern.
- `.xcodeproj` wird von XcodeGen erzeugt; nach dem Bump `xcodegen generate`.
- Bump-Commit-Muster: `chore(release): bump to 1.1.1 (10)` — berührte **nur**
  `project.yml`, 4 Zeilen.
- Tag-Muster: annotiert, `v1.1.1`, Betreff
  `Sprechly 1.1.1 (build 10) — Growth & Value Release`, danach Begründungstext.

**Ist:** 1.1.1 (10) · **Ziel:** **1.2.0 (11)**

Build-Historie im Repo: 1.0.1 → 7, 1.1.0 → 9, 1.1.1 → 10. **11 ist die
Fortsetzung, aber ASC führt die tatsächlich belegten Build-Nummern** — vor dem
Upload in ASC gegenprüfen, nicht aus dem Repo schließen. Noch nicht geändert.

## Required Code Changes

**Keine.** Der Scope ist eingefroren und vollständig implementiert. Für den RC
fällt genau eine mechanische Änderung an:

| Datei | Änderung |
|---|---|
| `project.yml` | `MARKETING_VERSION` 1.1.1 → 1.2.0, `CURRENT_PROJECT_VERSION` 10 → 11, **je zweimal** |

Danach `xcodegen generate`, dann Build.

## Required Documentation Changes

| Datei | Was | Warum |
|---|---|---|
| `CHANGELOG.md` | **1.1.1 fehlt vollständig** — jüngster Eintrag ist 1.1.0. Nachtragen **und** 1.2.0 ergänzen | Keep-a-Changelog-Format, SemVer; eine Version ohne Eintrag bricht die Kette |
| `REVIEW_NOTES.md` | Titel lautet „Sprechly 1.1.0 (9)" — auf 1.2.0 (11) ziehen; Hinweis zum `\letter`-Fix für den Reviewer ergänzen | Stale, geht sonst falsch an Review |
| `docs/ROADMAP.md` | A3/1.2-Abschnitt von „Scope eingefroren" auf „RC" bzw. nach Release auf „Released" | Statuspflege |
| `docs/WORKLOG.md` | Slice-Eintrag für 1.2 (Phasen 1–6, inkl. der beiden Negativergebnisse) | Projektkonvention, rückwärts-chronologisch |
| `docs/DEVICE_TESTS.md` | Zeilen für die 1.2-Gerätetests nachtragen (Formatter, Migration, Export, Lange Aufnahme 5/30 min) | Konvention: ID · Szenario · Status · Datum · Commit · Notiz |
| `MONETIZATION.md` | **nichts für 1.2** — Preis bleibt 6,99 €, die Anhebung ist aufgeschoben (2026-10-05) | 1.2 ändert Monetarisierung nicht |

## Store Metadata Impact

| Feld | Änderung nötig? | Begründung |
|---|---|---|
| App-Name / Untertitel | **nein** | unverändert |
| Beschreibung | **nein, nicht zwingend** | 1.2 bringt kein neues Feature und keine neue Format-Zusage; die Claims zu M4A/WAV/TXT/Markdown bleiben korrekt |
| Keywords | **nein** | kein neues Suchfeld |
| Preis / IAP | **nein** | 6,99 € unverändert; Anhebung aufgeschoben |
| Datenschutz / `PrivacyInfo` | **nein** | keine neue Datenerhebung, weiter rein on-device |
| **„Neu in dieser Version"** | **ja — zwingend** | ASC verlangt Release Notes für jede neue Version |
| Review-Notizen | **ja** | aktuell auf 1.1.0 ausgestellt |

Vorschlag für „Neu in dieser Version" (Entwurf, DE, noch nicht gesetzt):

> Transkripte werden jetzt sauber formatiert. Buchstabierte Abkürzungen stehen
> nicht länger mit internem Markup im Text, Uhrzeiten erscheinen als 13:45,
> Versionsnummern bleiben zusammen, und bekannte Produktnamen werden korrekt
> geschrieben. Bestehende Transkripte werden einmalig bereinigt.

Bewusst ohne Zahlenversprechen: die Messwerte gelten für synthetisches
Benchmark-Audio und sind keine Zusage für echte Sprache.

## Screenshot Impact

**Keine neuen Screenshots.** Belegt, nicht geschätzt: von den 23 Commits
berührt **keiner** `Features/`, `DesignSystem/`, `Resources/` oder eine
Lokalisierungsdatei. 1.2 ändert ausschließlich den *Inhalt* von
Transkripttexten, kein Layout, kein Control, keine Beschriftung.

Die Screenshot-Transkripte stammen aus `App/DemoSeed.swift` und werden direkt
als `TranscriptSegment` eingefügt, laufen also nicht durch den Formatter — und
enthalten kein `\letter`, die Migration greift dort nicht. Die 1.1.1-Sets für
6,9" und iPad bleiben gültig.

## Final Test Matrix

| Lauf | Ziel | Erwartung |
|---|---|---|
| Simulator, volle Suite ohne `StoreManagerPurchaseTests` | iOS 27 Sim | 253 Tests / 54 Suites grün, 0 Warnungen |
| Gerät, relevante Suites | iPhone 17 Pro | 85 Tests / 10 Suites grün |
| DE-Benchmark (eingefroren) | Gerät | WER 0,250 → 0,155 · 13/31 → 20/31 · fmt-acc 0,619 → 0,909 · FCC 0 |
| EN-Benchmark (eingefroren) | Gerät | WER 0,195 → 0,173 · 20/31 → 21/31 · fmt-acc 0,800 → 0,840 · FCC 0 |
| Fixture-Manifest | überall | 30 SHA-256-Hashes unverändert |
| Idempotenz + Migration | überall | grün, `K\letter I\letter` → `KI`, `K I` unverändert |
| Lange Aufnahme 5 / 30 min | Gerät | Drift 0,000 s, kein Frame-Verlust |

`StoreManagerPurchaseTests` bleibt im Simulator ausgeschlossen (bekannte
Limitierung, in 1.1.1 bewusst nicht behoben).

## Device Test

Für 1.2 neu zu protokollieren (automatisiert, alle schon einmal grün gelaufen):
Formatter-Wirkung auf den Fixtures · `\letter`-Bereinigung bis in TXT/Markdown ·
Migration eines Altsegments · Live volatile/final ohne Markup · 5- und
30-Minuten-Aufnahme.

**Drei offene Verpflichtungen aus `docs/DEVICE_TESTS.md`, die das Projekt sich
selbst gesetzt hat — nicht von 1.2 verursacht, aber vor einem Release fällig:**

| ID | Offen | Vermerk im Dokument |
|---|---|---|
| `2a` | Editor/Merge/Mix-Render einer ≥30-min-Datei auf Gerät | „**Pre-release obligation** … must be green before release" |
| `3e` | Transkript-Export auf Gerät bis zum Share Sheet | ⏳ — meine Phase-5-Tests deckten Renderer und Dateiinhalt ab, **nicht** das Share Sheet |
| `3b` | Echter Sandbox-Kauf des IAP `de.gcng.sprechly.ai` | „re-verify before release" |
| `VO` | VoiceOver auf Aufnahme-, Wiedergabe- und Bibliotheksbildschirm | „**Release blocker**, not a foundation gate" |
| `DCT` | Diktiergerät-Überschreiben auf Gerät | VM-Logik unit-getestet, Audiopfad auf Gerät offen |

**Stand 2026-10-05: alle fünf Zeilen grün, nichts mehr offen.**

| Gate | Status | Belegt durch |
|---|---|---|
| `2a` Editor/Merge/Mix/Export ≥30 min | ✅ | automatisiert auf Gerät, exakte Dauern, keine stumme Stufe |
| `3e` Transkript-Export | ✅ | automatisiert **plus** echter Export einer 02:52-Aufnahme |
| `3b` Kauf | ✅ | automatisierte Produktauflösung **plus echter Erstkauf** (iPhone 12 Pro, Release-Build, 6,99 €) |
| `VO` VoiceOver | ✅ | manuell auf Release-Build — **der bisherige Release-Blocker** |
| `DCT` Diktiergerät-Überschreiben | ✅ | manuell auf Release-Build |

Tap-Listen und Belege: **`docs/MANUAL_DEVICE_CHECKLIST_1.2.0.md`**.

Keiner ist ein Scope-Thema, alle sind Release-Arbeit.

**Preis:** Der Store liefert **6,99 €**, und dabei bleibt es. Die Anhebung auf
9,99 € ist **aufgeschoben** (Entscheidung 2026-10-05) — sie gehört weder zu
1.1.1 noch zu 1.2.0 und erfolgt später als eigene Änderung, sobald der Funnel
sich stabilisiert hat. Begründung und Bedingungen in `MONETIZATION.md`. Im Code
steht ohnehin kein Preis; die Paywall liest `Product.displayPrice`.

## Archive / Validate / Upload

**Erst nach ausdrücklicher Freigabe.** Reihenfolge, wenn freigegeben:

1. `project.yml` bumpen (1.2.0 / 11 nach ASC-Gegenprüfung) → `xcodegen generate`
2. Finale Regression (Matrix oben) auf dem gebumpten Stand
3. Offene Gerätetests `2a`, `3e`, `3b` abschließen und in `DEVICE_TESTS.md` eintragen
4. `CHANGELOG.md` (1.1.1 + 1.2.0), `REVIEW_NOTES.md`, `WORKLOG.md`, `ROADMAP.md`
5. Archiv bauen, **validieren**
6. Upload nach ASC, Version 1.2.0 anlegen, „Neu in dieser Version" setzen, Review-Notizen setzen
7. **Keine** Einreichung, keine Veröffentlichung ohne gesonderte Freigabe

Screenshots und Store-Beschreibung sind in diesem Ablauf unberührt.

## Git Strategy

Ist-Stand: `feature/1.2-transcription-quality` = `origin`, 23 Commits über
`main` (`741407b`), Working Tree sauber bis auf `docs/marketing/` (untracked).

Vorgeschlagener Ablauf, analog zum 1.1.1-Abschluss:

1. Bump- und Doku-Commits auf dem Feature-Branch
2. Release-Branch `release/1.2.0-transcription-quality` davon abzweigen (optional;
   1.1.1 lief über einen Release-Branch)
3. Annotierter Tag `v1.2.0`, Betreff
   `Sprechly 1.2.0 (build 11) — Transcription Quality & Smart Formatting`
4. `--no-ff`-Merge nach `main`, `main` pushen, Release-Branch behalten
5. Keine AI-Attribution, Conventional Commits, Englisch (CLAUDE.md §13)

Schritte 2–4 **erst nach Freigabe**.

## Rollback / Hotfix Strategy

Was 1.2 riskiert, ist eng begrenzt — und genau das macht den Rollback einfach:

| Risiko | Rückweg |
|---|---|
| Formatter verändert Text falsch | `TranscriptSemanticFormatter.Rules` ist ein `OptionSet`; eine einzelne Regel lässt sich an den beiden Aufrufstellen abschalten, ohne Code zu entfernen. FCC ist in beiden Sprachen 0, aber der Schalter existiert |
| Formatter unerwünscht insgesamt | Zwei Zeilen in `SpeechTranscriptionService` und `SpeechLiveTranscriber` — Patch-Release 1.2.1 |
| **Migration** verändert Altbestand falsch | **Nicht umkehrbar** — sie schreibt gespeicherten Nutzertext. Einzige echte Einbahnstraße des Releases. Abgesichert durch 11 Tests, Marker-Filter und Beschränkung auf `\letter`; ein Rückweg bestünde nur über iCloud/Backup des Nutzers |
| Audio-Regression | Audioarchitektur ist unverändert; die Sendable-Vereinfachung ist verhaltensgleich und per 5-/30-min-Lauf verifiziert |
| Build-Nummer in ASC belegt | Nur `CURRENT_PROJECT_VERSION` erhöhen und neu hochladen; kein Code betroffen |

Hotfix-Pfad: Branch von `v1.2.0`, Patch, `1.2.1 (12)`, derselbe Ablauf.

**Der einzige Punkt, der echte Aufmerksamkeit verdient, ist die Migration.**
Sie ist der einzige Teil von 1.2, der bestehende Nutzerdaten schreibt.

---

## Ausgeführt am 2026-10-05

| Schritt | Ergebnis |
|---|---|
| Archiv | `ARCHIVE SUCCEEDED` — am Artefakt geprüft: 1.2.0 (11), `de.gcng.sprechly`, keine Debug-Sektion, keine `.storekit` |
| Export | `app-store-connect`, IPA 2,9 MB |
| Validierung | `VERIFY SUCCEEDED with no errors` |
| Upload | `UPLOAD SUCCEEDED`, Delivery UUID `6b82ba8d-d176-4708-abdc-2a6575727eb3` |
| Build 11 | `state=VALID`, hochgeladen 2026-10-05 |
| Version 1.2.0 | angelegt, `461b315b-50df-48b6-afe9-6eb20107d9a0`, `PREPARE_FOR_SUBMISSION` |
| Build-Zuweisung | Build 11 der Version 1.2.0 zugewiesen |
| „Was ist neu" | de-DE 1049 Zeichen, en-US 955 Zeichen — gesetzt und zurückgelesen |
| Review-Notizen | 2737 Zeichen — gesetzt und zurückgelesen |
| Beschreibung / Keywords / Screenshots | **unberührt**, aus 1.1.1 übernommen |
| IAP / Preis | **unberührt**, `de.gcng.sprechly.ai` bei 6,99 € |

**`releaseType = MANUAL`** bewusst gesetzt: die Veröffentlichung nach der
Genehmigung bleibt eine menschliche Entscheidung. Bei 1.1.1 hat genau das dazu
geführt, dass die genehmigte Version unbemerkt in
`PENDING_DEVELOPER_RELEASE` stand — das ist kein Fehler der Einstellung,
sondern ein Grund, nach der Genehmigung aktiv nachzusehen.

**Nicht ausgeführt:** Einreichung zur Review, Merge nach `main`, Tag `v1.2.0`,
Preisänderung.

## Eingereicht am 2026-10-05

Review-Submission `c1a0cb0d-a5cf-47b2-8d2d-65a1a1d12fc8`, Status nach dem
Absenden aus ASC zurückgelesen:

```
VERSION string=1.2.0 state=WAITING_FOR_REVIEW releaseType=MANUAL
BUILD   version=11 processing=VALID expired=false encryption=false
LOC de-DE whatsNew=1049 desc=2799(unchanged) keywords=100(unchanged) promo=152
LOC en-US whatsNew=955  desc=2434(unchanged) keywords=98(unchanged)  promo=138
REVIEWDETAIL notes=2737 contact=set demoRequired=false
IAP de.gcng.sprechly.ai state=APPROVED
```

Screenshots: je 6 für `APP_IPHONE_67` und `APP_IPAD_PRO_3GEN_129`, in beiden
Sprachen — identische Anzahl wie 1.1.1, keine fehlende Gerätegröße.

### Beim Preflight gefunden und behoben: Werbetext

ASC überträgt **Promotional Text nicht** in eine neue Version, anders als
Beschreibung, Keywords und Screenshots. 1.2.0 stand mit 0 Zeichen da, während
1.1.1 in beiden Sprachen Werbetext führt (152 / 138 Zeichen). Beim Release
wäre dieser Text aus dem Store verschwunden — still, ohne Fehlermeldung.

Der Text aus 1.1.1 wurde unverändert übernommen und gegengelesen. **Für
künftige Releases:** Promotional Text ist der eine Teil der Store-Texte, der
beim Anlegen einer Version nicht mitkommt, und gehört in jede Preflight-Liste.

### Was bewusst nicht passiert ist

Keine Veröffentlichung (`releaseType=MANUAL`, die Freigabe nach der Genehmigung
bleibt eine menschliche Entscheidung), keine Preisänderung, keine IAP-Änderung,
kein neuer Build, kein Merge nach `main`, kein Tag.
