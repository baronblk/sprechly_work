# Sprechly — Organic Post Library

Stand: 2026-10-04 · Grundlage: Repository auf Stand `v1.1.1` (Build 10) plus die Messungen im Branch `feature/1.2-transcription-quality` vom selben Tag, App-Store-Seite (live: 1.1.0), `STORE_LISTING.md`, `MONETIZATION.md`, `docs/ROADMAP.md`, `docs/ICLOUD_SYNC.md`, `docs/html/privacy.html`, Quellcode.

Alle Texte sind **Entwürfe für manuelle Veröffentlichung durch Rene**. Nichts hiervon wurde gepostet. Zum Plan siehe [ORGANIC_MARKETING_30_DAYS.md](ORGANIC_MARKETING_30_DAYS.md), zu den Community-Regeln [COMMUNITY_CHECKLIST.md](COMMUNITY_CHECKLIST.md), zur Strategie [ORGANIC_MARKETING_PACKAGE.md](ORGANIC_MARKETING_PACKAGE.md).

## 0. Vor der Verwendung lesen

### 0.1 Platzhalter

| Platzhalter | Bedeutung |
|---|---|
| `[LINK]` | `https://apps.apple.com/app/id6782676748` — aus `STORE_LISTING.md` und `AppInfo.appStoreID`, am 2026-10-04 gegen die Live-Seite geprüft |
| `[PREIS]` / `[PRICE]` | Preis des Einmalkaufs „Sprechly KI“. **Live am 2026-10-04: 6,99 €.** Laut `MONETIZATION.md` mit 1.1.1 geplant: 9,99 €. Erst einsetzen, wenn feststeht, was im Store steht. Außerhalb des Euroraums den Preis weglassen und „one-time purchase“ schreiben — die Storefront-Preise stehen nicht im Repo. |
| `‹…›` | Lücke, die nur Rene wahrheitsgemäß füllen kann (persönlicher Anlass, aktuelle Zahl). Nicht mit Erfundenem füllen. Lieber den Satz streichen. |

### 0.2 Voraussetzung: 1.1.1 ist live

Alle Texte beschreiben den Stand von 1.1.1: neue Store-Beschreibung, neue Screenshots, Eintrag „Sprechly bewerten“. Am 2026-10-04 war 1.1.0 live. Vor dem Livegang von 1.1.1 sind mehrere Aussagen falsch (korrigierte Beschreibung, Screenshots mit Überschriften). Texte, die die Preiserhöhung erwähnen (RD-L4, RD-L5, RD-S5, IH-2, IH-4), gelten nur, wenn der Preis tatsächlich auf 9,99 € gestiegen ist.

### 0.3 Diese Texte stammen von einer KI

Die Entwürfe sind maschinell erstellt und gegen das Repository geprüft. Das hat Folgen, die je Plattform unterschiedlich sind:

- **Hacker News** verbietet generierten und KI-bearbeiteten Text in Beiträgen und Kommentaren. Abschnitt 5 liefert deshalb nur eine Faktengliederung. Den Beitrag schreibt Rene selbst.
- **r/de_EDV** verbietet KI-generierte Postings (Regelstand aus Archiv, siehe Checkliste).
- **mastodon.social** verlangt, den Einsatz generativer KI offenzulegen. **troet.cafe** verlangt eine Kennzeichnung KI-generierter Inhalte.
- Überall sonst gilt: vor dem Posten in die eigene Stimme umschreiben. Ein Beitrag, der „Ich bin der Entwickler“ sagt, sollte auch vom Entwickler formuliert sein.

### 0.4 Faktenbasis — was gesagt werden darf

Jede Aussage in dieser Datei geht auf eine dieser Zeilen zurück.

| Aussage | Beleg im Repo |
|---|---|
| Download kostenlos. Aufnahme, Schnitt, Zusammenführen, Mix, Tempo, Audio-Export unbegrenzt gratis | `STORE_LISTING.md` (Preis), `CHANGELOG.md` 1.1.0 |
| Die ersten 30 Sekunden jeder Aufnahme lassen sich gratis transkribieren. Die Vorschau wird nicht gespeichert | `TranscriptionViewModel.previewLimit = 30`, `CHANGELOG.md` 1.1.0 |
| Ein einmaliger Kauf „Sprechly KI“ schaltet frei: vollständige Transkription, Live-Transkript, Transkript-Export, KI-Titel und -Zusammenfassung, Übersetzung | `Entitlement.swift`, Screenshot `03-usp`, `REVIEW_NOTES.md` |
| Die Sprachmodelle lädt man unter Einstellungen → Sprachmodelle. Der Eintrag ist erst nach dem Kauf sichtbar | `SettingsView.swift` (`if unlocked`) |
| Kein Abo, kein Benutzerkonto, keine Anmeldung | `MONETIZATION.md`, `REVIEW_NOTES.md` |
| Transkription rechnet auf dem Gerät (Apple `SpeechAnalyzer` / `SpeechTranscriber`). Sprachmodell wird einmal geladen, danach offline nutzbar | `SpeechTranscriptionService.swift`, `TranscriptionAssetState.swift` |
| KI (Titel, Zusammenfassung, Protokoll, Stichpunkte, Kernaussagen, Bereinigung, Übersetzung) rechnet auf dem Gerät über Apple Foundation Models | `AISummaryService.swift`, `SummaryStyle.swift` |
| KI-Funktionen brauchen ein Gerät mit Apple Intelligence. Transkription, Live-Transkript und Export nicht | `docs/DECISIONS.md` 2026-06-21, `PaywallView.swift` |
| Kein eigener Server, kein Tracking, keine Werbung, keine Drittanbieter-SDKs, null Drittpakete | `privacy.html`, `project.yml` (keine `packages`) |
| Datenschutzlabel „Data Not Collected“ | `STORE_LISTING.md` → App Privacy |
| iCloud-Sync ist **standardmäßig an**, legt Audio und Transkripte in der privaten iCloud des Nutzers ab (CloudKit), ist in den Einstellungen abschaltbar. Der Entwickler hat keinen Zugriff | `PersistenceController.swift`, `SettingsView.swift`, `docs/ICLOUD_SYNC.md` |
| iOS / iPadOS 26.0 oder neuer, iPhone und iPad | `project.yml` (`TARGETED_DEVICE_FAMILY: "1,2"`) |
| Aufnahme Mono 48 kHz AAC, im Hintergrund und bei gesperrtem Bildschirm, Live Activity / Dynamic Island | `RecordingSettings.swift`, `Info.plist`, `CHANGELOG.md` |
| Zurückspulen und ab dem Cursor neu aufnehmen | `DictationAssembler.swift`, Screenshot `04-record` |
| Tippen auf eine Zeile im Transkript springt zur Stelle im Audio | `CHANGELOG.md` („tappable (seek) segments“), `STORE_LISTING.md` |
| Beim Überschreiben läuft die Aufnahme intern verlustfrei (16-Bit-PCM), gespeichert wird als AAC | `RecordingSettings.losslessSettings` |
| Transkription mehrstündiger Dateien ist verifiziert, eine Prozentanzeige gibt es nicht | `docs/TRANSCRIPTION_PIPELINE.md` §0.5 und §6 |
| Mehr als 160 automatisierte Tests | 171 `@Test`-Funktionen in `Tests/VoxStudioTests`, `docs/ROADMAP.md` nennt 165 |
| Schneiden, Auswahl behalten/entfernen, Stille automatisch entfernen, Tempo 0,5×–3×, Lautstärke normalisieren | `EditorView.swift`, `AudioCutService.swift` |
| Audio-Export M4A (AAC) und WAV. Transkript-Export TXT und Markdown | `ExportFormat.swift`, `TranscriptExporter.swift` |
| Externe Audiodateien importieren und wie eigene Aufnahmen behandeln | `AudioImportService.swift` |
| Übersetzung in 15 Zielsprachen | `TranslationLanguage.common` |
| Bibliothek mit Suche **nach Titel**, Papierkorb mit 30 Tagen Aufbewahrung | `LibraryView.swift` (Filter auf `title`) |
| Oberfläche Deutsch und Englisch | `Localizable.xcstrings`, Live-Store-Seite |
| `contextualStrings` ohne messbare Wirkung: 15 Sätze, 31 Zielbegriffe, 13 erkannt mit und ohne Kontext, Transkripte zeichengleich, Kontext kam nachweislich an, 14/54/104 Begriffe ohne Unterschied. Entscheidung: kein persönliches Wörterbuch auf diesem Weg | `docs/TRANSCRIPTION_CONTEXT_BENCHMARK.md`, `docs/benchmarks/2026-10-04-context-experiment.md` |
| Viele verfehlte Begriffe sind Formatierungsfehler (`13.45`, `1. 2.0`, `Store Kit`). Eine Nachbearbeitung im eigenen Code ist vorgeschlagen, nicht umgesetzt | `docs/TRANSCRIBER_COMPARISON.md` → Next recommendation |
| Kennzahlen aus der 90-Tage-Ansicht von App Store Connect bis 18.08.2026: 9.340 Impressionen, 209 Produktseitenaufrufe (2,2 %), 128 Erst-Downloads, 4 Käufe (3,1 %), 17 $ Erlös, 0 Bewertungen. Die App wurde am 22.06.2026 eingereicht, die Zahlen decken also rund zwei Monate seit dem Start ab. Das genaue Erscheinungsdatum steht nicht im Repo — die Texte sagen deshalb „zwei Monate“ und „Ende Juni“. Rene prüft das. | `docs/ROADMAP.md` → Ist-Stand, Git-Historie |
| Seit 1.1.0: weniger Sichtbarkeit, merklich bessere Conversion — **nur qualitativ, Zahlen fehlen** | `docs/ROADMAP.md` |
| 2 Bewertungen, Durchschnitt 4,0 | Live-Store-Seite DE, abgerufen 2026-10-04 — vor Verwendung aktualisieren |
| Transkription funktioniert im Flugmodus, sobald das Sprachmodell geladen ist | folgt aus der On-Device-Architektur (`SpeechTranscriber`, `AssetInventory`). **Im Repo nicht als Gerätetest protokolliert — vor Verwendung einmal selbst nachstellen** |

### 0.5 Was nicht gesagt wird

| Nicht schreiben | Warum |
|---|---|
| „kein Upload“, „Daten verlassen nie das Gerät“, „deine Stimme verlässt das Gerät nicht“ | iCloud-Sync ist standardmäßig an und lädt Audio in die private iCloud |
| „Transkription gratis“ | Gratis sind 30 Sekunden Vorschau je Aufnahme |
| Export als MP3, AIFF, CAF, PDF, SRT | `ExportFormat` kennt nur M4A und WAV, `TranscriptExportFormat` nur TXT und Markdown |
| Sprechererkennung, Sprecher-Labels | gibt es nicht (`docs/TRANSCRIPTION_PIPELINE.md` §1) |
| Volltextsuche im Transkript | die Bibliothekssuche filtert nur den Titel |
| eine feste Zahl an Transkriptionssprachen | die Liste kommt zur Laufzeit von Apple (`SpeechTranscriber.supportedLocales` in `SpeechTranscriptionService.swift`). Im Repo fest hinterlegt sind nur Deutsch und Englisch |
| „funktioniert gut“, „präzise“ oder ein anderes Urteil über die Erkennungsgüte | Renes Beurteilung auf dem Gerät steht laut `docs/ROADMAP.md` (A3) noch aus. Belegt ist nur: Eigennamen und Fachbegriffe sind die Schwachstelle |
| mehr aus der Messung vom 2026-10-04, als sie hergibt | Gemessen wurde mit synthetischer Sprache, auf Deutsch, auf einem Gerät (iPhone 17 Pro, iOS 27.0.1). Das erlaubt den Vergleich zweier Varianten und kein Urteil über reale Aufnahmen. Die Texte nennen deshalb immer den Aufbau mit |
| Impressionen als „Menschen“ | App Store Connect zählt Einblendungen und Seitenaufrufe, keine Personen |
| „genauer als …“, „besser als Whisper/Otter/…“ | kein Vergleichstest im Repo. Die Erkennungsgüte kommt vollständig aus Apples Modell |
| Umsatz- oder Downloadzahlen nach dem 18.08.2026 | stehen nicht im Repo |
| Läuft auf dem Mac | die Store-Seite listet Macs mit Apple-Chip als kompatibel, im Repo ist das weder getestet noch dokumentiert |

### 0.6 Fragen nach KI-Unterstützung bei der Entwicklung

Das Repository enthält eine `CLAUDE.md`, die App ist also mit einem KI-Assistenten entwickelt worden. Die Texte hier behaupten deshalb an keiner Stelle, Rene habe jede Zeile selbst geschrieben. Sie sagen „ich arbeite allein an der App“ und „kein Team“, und das trifft zu. Wer nach KI-Unterstützung fragt, bekommt eine ehrliche Antwort. Communities mit Regeln gegen „vibe coded apps“ (r/productivityapps) sind entsprechend markiert.

### 0.7 Gespräche aufnehmen

Beiträge zu Meetings, Interviews und Vorlesungen enthalten den Hinweis, vorher das Einverständnis einzuholen. Das nicht öffentlich gesprochene Wort ohne Einwilligung aufzunehmen ist in Deutschland strafbar (§ 201 StGB). Der Hinweis bleibt in den Texten.

### 0.8 Bezeichner

`RD` Reddit · `LI` LinkedIn · `MA` Mastodon · `BS` Bluesky · `HN` Hacker News · `IH` Indie Hackers · `FO` Foren · `P01`–`P15` Content-Säulen (Kurzposts `K1`–`K3`, längerer Post `L`). Die Zeichenzahl steht über jedem Text. Bei Mastodon zählt ein Link 23 Zeichen, sonst wird der volle Link (39 Zeichen) gezählt.

---

## 1. Reddit

**Regelstand:** Reddit hat am 2026-10-04 jeden direkten Abruf blockiert. Kein einziges Subreddit-Regelwerk wurde im Original gelesen. Alle Angaben stammen aus Drittquellen (Stand September/Oktober 2026 bzw. Archiv Januar/Februar 2025). Deshalb ist **kein Subreddit als „geeignet“ markiert**. Jeder Text unten steht unter dem Vorbehalt, dass Rene die Regeln vor dem Posten im Browser liest (Checkliste).

Abweichung vom Auftrag, bewusst: Für **r/productivity** und **r/privacy** gibt es keine Posts. Beide verbieten laut Drittquellen jede Eigenwerbung, r/privacy zusätzlich Closed-Source-Software. Für **r/iphone** und **r/ios** gibt es statt eines Posts eine Modmail-Anfrage (RD-M1), weil r/ios Entwickler ausdrücklich an die Moderation verweist. **r/indieapps** ließ sich nicht als existierendes Subreddit belegen. Ersatz: r/indiehackers, r/iosapps.

Reddit insgesamt erwartet, dass ein Account nicht überwiegend eigene Links postet. Wer in einem Subreddit sonst nie schreibt, sollte dort nicht mit einem App-Post anfangen.

### 1.1 Fünf längere Posts

Englisch: RD-L1 bis RD-L4. Deutsch: RD-L5.

#### RD-L1 · r/apple · Entwickler-Post am Sonntag (EN)

Bedingung laut Drittquelle: nur sonntags (kalifornische Zeit), nur als Textbeitrag, nur mit vorheriger normaler Aktivität im Subreddit. Die dort verlinkten Detailregeln im Wiki wurden nicht gelesen.

Titel:

*Länge: 132 Zeichen (Limit 300)*

```text
I built a voice recorder that transcribes on-device with Apple's new speech framework. No subscription, no account. (Developer post)
```

Text:

*Zielgruppe: Apple-Nutzer, Abo-Müde, Datenschutzbewusste · CTA: App Store + Feedback zur Transkription · Länge: 2328 Zeichen*

```text
Developer here, posting on Sunday as the rules ask.

I'm Rene, a solo developer from Germany. I built Sprechly, a voice recorder for iPhone and iPad that turns recordings into text on the device. It uses the SpeechAnalyzer framework Apple introduced with iOS 26.

**What it does**

- Records in the background and on the lock screen, with a Live Activity in the Dynamic Island
- Lets you rewind and re-record from the cursor, so a slip of the tongue gets overwritten
- Transcribes your recordings and imported audio files on the device, optionally live while you record
- Jumps to the spot in the audio when you tap a line of the transcript
- Writes summaries, meeting minutes, bullet points or key takeaways, and translates the transcript, using Apple's on-device model
- Trims, cuts, removes silence, merges recordings, mixes in a second track
- Exports audio as M4A or WAV and transcripts as TXT or Markdown

**What it costs**

The download is free. Recording, editing, mixing and audio export are free without limits. The first 30 seconds of any recording are transcribed for free, so you can judge the result with your own voice. Full transcripts, the live transcript, transcript export and the AI features are a single one-time purchase. There is no subscription and no account.

**Privacy, stated precisely**

Transcription and AI run on the device. I don't run a server. There is no analytics, no advertising and no third-party SDK, and the privacy label is "Data Not Collected".

One thing I want to be upfront about: iCloud sync is on by default. It stores your recordings and transcripts in your own private iCloud so they appear on your other devices. I can't access that data, and you can switch sync off in Settings.

**Limits you should know about**

- It requires iOS or iPadOS 26.
- Summaries and translation need a device with Apple Intelligence. Recording, editing and transcription don't.
- There are no speaker labels, no MP3 export and no PDF or SRT export.
- Recognition quality is what Apple's model delivers. Names and technical terms are its weak spot, and that is what I'm working on next.

App Store: [LINK]

I'd like to hear where the transcription falls short for you: language, accent, long recordings. I'll answer everything, including the unflattering questions.
```

#### RD-L2 · r/SideProject · Zahlen und Fehler (EN)

Verwendet die echten Kennzahlen aus `docs/ROADMAP.md`. Rene entscheidet, ob er sie veröffentlicht. Setzt voraus, dass 1.1.1 live ist (neue Screenshots, korrigierte Beschreibung).

Titel:

*Länge: 111 Zeichen (Limit 300)*

```text
My on-device transcription app got 128 downloads and 4 sales in its first two months. Here is what I got wrong.
```

Text:

*Zielgruppe: Indie-Entwickler, Side-Project-Community · CTA: Feedback zur Store-Seite · Länge: 2084 Zeichen*

```text
I'm Rene, a solo developer, and Sprechly is my app. So this is self-promotion, but mostly it's a request for feedback.

Sprechly is a voice recorder for iPhone and iPad. It records, transcribes on the device with Apple's speech framework, and can summarize or translate the transcript with Apple's on-device model. Free download, a single one-time purchase, no subscription, no account.

**The numbers (App Store Connect, from launch in late June to 18 August 2026)**

- 9,340 impressions
- 209 product page views (2.2% of impressions)
- 128 first-time downloads
- 4 purchases (3.1% of downloads)
- 17 USD in proceeds
- 0 ratings

**What I got wrong**

1. Nobody saw the result before paying. Transcription sat behind a hard paywall, so people had to trust a feature list.
2. Almost nobody could be asked for a rating. Every trigger for the rating prompt sat behind the purchase. With 4 buyers out of 128 downloads, about 97% of users could never reach it.
3. My store description was wrong in two places. It listed export formats the app doesn't have. And it said your voice stays on the device, although iCloud sync is on by default and stores recordings in your private iCloud. Both are corrected.
4. The real bottleneck is earlier: only 2.2% of impressions turn into a product page view.

**What I changed**

- The first 30 seconds of any recording are now transcribed for free. You see the result with your own voice. The preview isn't saved.
- The paywall now leads with that preview.
- The rating prompt can appear after you save a recording or finish an edit.
- The screenshots now lead with the transcript.

**Where it stands**

Since the update, conversion looks clearly better and visibility is lower than at launch. I don't have a clean 28-day comparison yet, so I won't quote numbers I can't back up. The app now has ‹2› ratings.

**What I'd like from you**

If you have two minutes, open the App Store page and tell me what stops you from tapping "Get": [LINK]

It needs iOS 26, and the AI features need a device with Apple Intelligence.
```

#### RD-L3 · r/iOSProgramming · App Saturday, technischer Beitrag (EN)

Bedingung laut Drittquelle: nur samstags, eine App einmal im Jahr, vorherige Aktivität im Subreddit, bei Bezahl-Apps Beschreibung plus Herausforderungen plus technischer Überblick. Flair „App Saturday“.

Titel:

*Länge: 106 Zeichen (Limit 300)*

```text
App Saturday: Sprechly, and eight things that broke while building on SpeechAnalyzer and Foundation Models
```

Text:

*Zielgruppe: iOS-Entwickler · CTA: Erfahrungen mit contextualStrings · Länge: 3746 Zeichen*

```text
I'm the developer. Sprechly is a voice recorder for iPhone and iPad with on-device transcription and on-device summaries. Free download, a single one-time purchase for the transcription and AI layer, no subscription. [LINK]

The stack is Swift 6 with strict concurrency, SwiftUI, SwiftData with CloudKit, StoreKit 2, and no third-party dependencies. Here is what cost me the most time, in case it saves you some.

**1. SpeechAnalyzer and Foundation Models don't run in the Simulator**

Everything speech- or model-related sits behind a protocol (`TranscriptionProviding`, `AISummarizing`). Unit tests use mocks. Real behaviour is a written checklist I run on a device. CI runs on simulators and never touches the real frameworks.

**2. Explicit buffer timestamps break batch transcription**

I read the file in chunks, converted the sample rate and passed `AnalyzerInput(buffer:bufferStartTime:)`. The analyzer threw "Audio Input timestamp overlaps or precedes prior audio input". The start time computed from source frames and the duration of the converted buffer round differently, so consecutive inputs overlap. The fix is to pass `AnalyzerInput(buffer:)` without a start time and let the analyzer derive timing from the stream.

**3. Route changes during recording end in -10868**

Disconnect a Bluetooth headset mid-recording and the input format changes from 16 kHz to 48 kHz. `installTap(format: nil)` resolves the format once, at install time, and keeps it. A plain `engine.start()` on resume then fails with -10868. What works: pause on the route change and recreate the `AVAudioEngine` on resume.

**4. iOS has no MP3 encoder**

`kAudioFormatProperty_Encoders` reports one encoder for AAC and none for MPEG Layer 3. So export is M4A and WAV.

**5. The on-device model has a small context window**

I split transcripts at sentence boundaries into chunks of at most 800 characters and condense them recursively until the text fits one request. Translation runs chunk by chunk, each in a fresh session.

**6. Default guardrails reject harmless translations**

Translating ordinary transcripts tripped the safety filter. `SystemLanguageModel(guardrails: .permissiveContentTransformations)` is meant for transforming the user's own text and stopped the false positives on ordinary content. A refusal still gets a clear message, and the transcript stays usable.

**7. StoreKit Testing depends on the simulator runtime**

On the iOS 26.5 runtime, `Product.products(for:)` came back empty in tests. On 26.2 it works, so CI is pinned to 26.2. `SKTestSession` also needs a simulator that is already booted.

**8. `.searchable` sits at the bottom in iOS 26**

My tab bar is a `safeAreaInset`, not a `TabView`, and it covered the search field completely. Nobody could search the library until I pinned the field under the title.

**What I measured and couldn't fix**

Recognition of names and technical terms. `AnalysisContext.contextualStrings` looked like the right lever, so I measured it before building a custom vocabulary. The setup: 15 German sentences rendered with the system speech synthesizer on an iPhone, 31 target terms, each sentence transcribed once without and once with the terms as context. The result: 13 of 31 terms in both runs, and the transcripts were identical character for character. A separate test confirmed that the analyzer had received the strings. Lists of 14, 54 and 104 terms made no difference either.

That is one configuration: German, file transcription, the `.transcription` preset, iOS 27.0.1, synthetic speech. If you have seen contextual strings change a `SpeechTranscriber` result anywhere, I'd like to hear how.

Requires iOS 26. The AI features need Apple Intelligence.
```

#### RD-L4 · r/indiehackers · Preisfrage (EN)

Bedingung laut Drittquelle: Eigenwerbung genau einmal, mit Flair „Self Promotion“, zum Zweck von Feedback und Kritik. Der Absatz zur Preiserhöhung steht in der Vergangenheit und gilt nur, wenn der Preis mit 1.1.1 tatsächlich auf 9,99 € gestiegen ist. Sonst streichen.

Titel:

*Länge: 88 Zeichen (Limit 300)*

```text
One-time purchase instead of a subscription for a transcription app: sanity check wanted
```

Text:

*Zielgruppe: Indie Hacker, Gründer · CTA: Kritik am Preismodell · Länge: 1683 Zeichen*

```text
Disclosure: I'm the developer of the app this is about (Sprechly, for iPhone and iPad). I'm after critique of the pricing model.

**The setup**

Sprechly records audio and transcribes it on the device with Apple's speech framework. Summaries and translation use Apple's on-device model. I don't run a server, so nothing gets more expensive for me when you transcribe more.

That is why I sell one non-consumable in-app purchase and no subscription.

**Three models so far**

1. During development: first transcription free, then paywall. On my test device it felt like giving the feature away and taking it back.
2. At launch: purchase only, no trial. Clear, but people had to buy blind. In the first two months that meant 128 downloads and 4 purchases.
3. Since August: the first 30 seconds of every recording are transcribed for free. The preview isn't saved and can't be exported. The paywall shows your own preview text.

Recording, editing and audio export have been free and unlimited the whole time.

**The decision I'm unsure about**

Conversion improved after step 3, while visibility dropped. With the latest update I raised the one-time price from 6.99 EUR to 9.99 EUR and reworked the store page at the same time. I'll compare 28 days before with 28 days after. The number I watch is revenue per download.

**Questions**

- Would you have changed price and store page at the same time, knowing it muddies the comparison?
- Is a 30-second preview enough to judge transcription quality?
- Is there a point where "no subscription" stops being an argument and starts to read as "this won't be maintained"?

App Store page, for context: [LINK]
```

#### RD-L5 · r/StartupDACH · Erfahrungsbericht (DE)

Bedingung laut Archivstand: Produktvorstellung „im Sinne eines fachlichen Austauschs“ erlaubt, übermäßige Eigenwerbung nicht. Die Frage zur Preiserhöhung nur stehen lassen, wenn der Preis tatsächlich gestiegen ist.

Titel:

*Länge: 92 Zeichen (Limit 300)*

```text
Einmalkauf statt Abo bei einer Transkriptions-App: meine Zahlen nach den ersten zwei Monaten
```

Text:

*Zielgruppe: Selbstständige, Gründer im DACH-Raum · CTA: Fachlicher Austausch zum Preismodell · Länge: 1828 Zeichen*

```text
Vorab: Ich bin der Entwickler von Sprechly, um das es hier geht. Ich arbeite allein daran und suche fachlichen Austausch zum Preismodell.

**Worum es geht**

Sprechly ist ein Diktiergerät für iPhone und iPad mit Transkription. Die Spracherkennung rechnet auf dem Gerät, über das Speech-Framework von Apple. Zusammenfassungen und Übersetzungen erzeugt das On-Device-Modell von Apple. Ich betreibe keinen Server.

Daraus folgt das Preismodell: Mir entstehen keine laufenden Kosten pro Minute. Also gibt es einen einmaligen Kauf und kein Abo.

**Die Zahlen (App Store Connect, vom Start Ende Juni bis 18.08.2026)**

- 9.340 Impressionen
- 209 Aufrufe der Produktseite (2,2 %)
- 128 Erst-Downloads
- 4 Käufe (3,1 % der Downloads)
- 17 US-Dollar Erlös
- 0 Bewertungen

**Was ich daraus gelernt habe**

1. Die Transkription lag komplett hinter der Bezahlschranke. Niemand konnte das Ergebnis sehen, bevor er zahlt. Seit August transkribiert die App die ersten 30 Sekunden jeder Aufnahme gratis.
2. Die Frage nach einer Bewertung hing an gekauften Funktionen. Für rund 97 % der Nutzer war sie damit unerreichbar.
3. Der Engpass sitzt vor dem Download: Nur 2,2 % der Einblendungen im Store führen zu einem Aufruf der Seite.

Seit dem Update ist die Conversion merklich besser und die Sichtbarkeit geringer. Belastbare Vergleichszahlen habe ich noch nicht.

**Meine Fragen an euch**

- Ich habe den Einmalpreis von 6,99 € auf 9,99 € angehoben und gleichzeitig den Store-Auftritt geändert. Hättet ihr das getrennt?
- Wirkt „kein Abo“ bei euch als Kaufargument, oder weckt es Zweifel an der Weiterentwicklung?
- Kennt jemand Erfahrungswerte, wie sich ein Einmalkauf bei Werkzeug-Apps über zwei, drei Jahre trägt?

Die App: [LINK] (iOS 26 nötig. Die KI-Funktionen brauchen ein Gerät mit Apple Intelligence.)
```

### 1.2 Modmail statt Post

#### RD-M1 · Anfrage an r/ios und r/iphone (EN)

*Zielgruppe: Moderation · CTA: Erlaubnis einholen · Länge: 631 Zeichen*

```text
Hi mods,

I'm the solo developer of Sprechly, a voice recorder for iPhone and iPad with on-device transcription (free download, one-time purchase, no subscription). Your rules ask developers to contact you before posting about their own app, so I'm asking first.

I'd like to make one text post that describes what the app does, what it costs and where its limits are, clearly marked as coming from the developer, and then stay around to answer questions. No repeat posts and no links in other threads.

Is that acceptable, and is there a format, flair or day you'd prefer? If the answer is no, I'll leave it at that.

Thanks, Rene
```

#### RD-M2 · Anfrage an r/de_EDV oder r/Studium (DE)

*Zielgruppe: Moderation · CTA: Erlaubnis einholen · Länge: 592 Zeichen*

```text
Hallo Mod-Team,

ich bin der Entwickler von Sprechly, einem Diktiergerät für iPhone und iPad mit Transkription auf dem Gerät (kostenloser Download, einmaliger Kauf, kein Abo). Eure Regeln erlauben Eigenwerbung nur nach Absprache, deshalb frage ich vorher.

Ich würde gern einen einzigen Textbeitrag schreiben: was die App kann, was sie kostet, wo ihre Grenzen liegen. Klar gekennzeichnet als Beitrag des Entwicklers, selbst formuliert, und ich bleibe für Rückfragen da. Keine Wiederholung, keine Links in fremden Threads.

Wäre das in Ordnung? Wenn nicht, lasse ich es.

Danke und Grüße, Rene
```

### 1.3 Zehn kurze Varianten

Englisch: RD-S1 bis RD-S8. Deutsch: RD-S9 und RD-S10.

Jede Variante ist für genau ein Subreddit geschrieben. Nicht dieselbe Variante in zwei Subreddits posten. Wo es für dasselbe Subreddit auch eine Langfassung gibt (RD-L1 bis RD-L5), gilt entweder die eine oder die andere, nie beide. r/iOSProgramming lässt eine App einmal im Jahr zu, r/indiehackers einmal überhaupt. Die Titel zu den Kurzfassungen stehen in 1.4.

#### RD-S1 · r/apple, Sonntag (EN)

*Zielgruppe: Apple-Nutzer · CTA: App Store · Länge: 724 Zeichen*

```text
Developer post, on Sunday as the rules ask.

I made Sprechly, a voice recorder for iPhone and iPad that transcribes on the device with Apple's SpeechAnalyzer. Free download. Recording, editing and audio export stay free. The first 30 seconds of any recording are transcribed for free. Full transcripts and on-device summaries are a single one-time purchase. No subscription, no account.

To be exact about privacy: transcription and AI run on the device, and I run no server. iCloud sync is on by default and keeps recordings in your own private iCloud. You can turn it off.

Needs iOS 26. The AI part needs Apple Intelligence.

[LINK]

Tell me where the transcription gets it wrong for you.
```

#### RD-S2 · r/SideProject (EN)

*Zielgruppe: Side-Project-Community · CTA: Feedback zur Store-Seite · Länge: 599 Zeichen*

```text
My side project: Sprechly, a voice recorder for iPhone and iPad with on-device transcription. I'm the developer and I work on it alone.

In its first two months it had 128 downloads, 4 purchases and 0 ratings. The biggest mistake: the rating prompt sat behind the purchase, so almost nobody could ever see it. The second: people couldn't see a transcript before paying. Now the first 30 seconds of every recording are transcribed for free.

Free download, a single one-time purchase, no subscription. Requires iOS 26.

What would stop you from downloading it? [LINK]
```

#### RD-S3 · r/iosapps, ABC-Format (EN)

Das ABC-Format (Answer, Better, Cost) ist nur aus einer Paraphrase bekannt. Vor dem Posten das Original lesen. Zu prüfen ist dort auch die Regel gegen „generative-AI or AI-wrapper apps“: Sprechly ruft keinen fremden KI-Dienst auf, nutzt aber Apples On-Device-Modell für Zusammenfassungen.

*Zielgruppe: iOS-App-Interessierte · CTA: App Store · Länge: 949 Zeichen*

```text
I'm the developer of Sprechly.

**Answer.** You record a meeting, an interview or a lecture and want the text, without sending the audio to a transcription service and without another subscription. Sprechly records and transcribes on the device.

**Better.** The speech recognition and the summaries both run on the iPhone or iPad, using Apple's own frameworks. There is no account. You can rewind and re-record from the cursor, cut, remove silence, merge and mix, and export M4A, WAV, TXT or Markdown. Honest limits: iOS 26 only, no speaker labels, no MP3, and summaries need Apple Intelligence. iCloud sync is on by default and uses your own private iCloud. You can switch it off.

**Cost.** Free download. Recording, editing and audio export are free. 30 seconds of transcription per recording are free. Everything else is a single one-time purchase. No subscription.

[LINK]

Questions and criticism are welcome.
```

#### RD-S4 · r/iOSProgramming, Samstag (EN)

*Zielgruppe: iOS-Entwickler · CTA: Technischer Austausch · Länge: 757 Zeichen*

```text
App Saturday. I'm the developer of Sprechly, a recorder with on-device transcription built on SpeechAnalyzer and Foundation Models.

One finding that may save you an afternoon: if you feed SpeechAnalyzer a file in chunks and set `bufferStartTime` yourself after a sample-rate conversion, you get "Audio Input timestamp overlaps or precedes prior audio input". Pass the buffers without a start time. The result ranges still come out right.

Swift 6 strict concurrency, SwiftData with CloudKit, no third-party packages. Free download, one-time purchase, iOS 26.

[LINK]

I also measured `contextualStrings` on 15 German test sentences: no difference in a single character. Has anyone seen it change a SpeechTranscriber result?
```

#### RD-S5 · r/indiehackers, Flair „Self Promotion“ (EN)

Nur verwenden, wenn der Preis tatsächlich angehoben wurde.

*Zielgruppe: Indie Hacker · CTA: Kritik am Preismodell · Länge: 543 Zeichen*

```text
I'm the developer of Sprechly, an on-device transcription recorder for iPhone and iPad. I'd like critique on one decision.

The app has no server cost, so I sell it as a one-time purchase. After 128 downloads and 4 purchases in two months I added a free 30-second transcription preview. Conversion got better, and with the latest update I raised the price from 6.99 EUR to 9.99 EUR.

Was raising the price of a one-time purchase after four sales reasonable, or am I reading too much into a tiny sample?

[LINK]
```

#### RD-S6 · r/productivityapps (EN)

Bedingung laut Drittquelle: einmal im Monat, 10 Karma in der Community, korrektes Flair, „No Vibe Coded apps“. Sprechly ist mit KI-Unterstützung entwickelt worden (`CLAUDE.md` im Repo). Vor dem Posten nachlesen, wie die Regel das abgrenzt, und im Zweifel nicht posten.

*Zielgruppe: Produktivitäts-Interessierte · CTA: App Store · Länge: 715 Zeichen*

```text
Developer here. Sprechly is a recorder for iPhone and iPad that turns a recording into a transcript and then into meeting minutes or bullet points. Both steps run on the device.

What it is good for: a meeting becomes a transcript and a few lines of summary that you can export as Markdown.

What it isn't: there are no speaker labels and no calendar or task integration. It needs iOS 26, and the summaries need Apple Intelligence.

Free download, 30 seconds of transcription per recording for free, a single one-time purchase for the rest. No subscription. Please ask before you record other people.

[LINK]

What would you want it to do with the transcript that it doesn't do yet?
```

#### RD-S7 · r/studytips (EN)

*Zielgruppe: Studierende · CTA: App Store · Länge: 772 Zeichen*

```text
I'm the developer of this app, so weigh my opinion accordingly.

If you record lectures with permission, the recording is only half the job. Finding the one explanation again is the other half. I built Sprechly for that: it transcribes on the iPhone or iPad, and tapping a line in the transcript jumps to that spot in the audio. You can export the transcript as Markdown for your notes.

Recording is free and unlimited. The first 30 seconds of each recording are transcribed for free, and full transcripts are a one-time purchase. No subscription. It needs iOS 26.

Two limits: it doesn't label speakers, and technical terms are where the recognition struggles most.

[LINK]

How do you find things again in your lecture recordings today?
```

#### RD-S8 · r/podcasting, wöchentlicher Promo-Thread (EN)

Nur als Kommentar im wöchentlichen Produkt-Thread. Der Wochentag ist nicht bekannt.

*Zielgruppe: Podcaster · CTA: App Store · Länge: 568 Zeichen*

```text
Affiliation: I'm the developer.

Sprechly is a recorder for iPhone and iPad for the rough work before the edit: record an idea or an interview, re-record from the cursor when you misspeak, remove silence, and get a transcript on the device to pull quotes and show notes from.

It records mono 48 kHz AAC and exports M4A or WAV. It is a recorder and a transcript tool. It doesn't replace a multitrack editor.

Free download, one-time purchase for full transcripts, no subscription. Needs iOS 26.

[LINK]

Happy to answer questions here.
```

#### RD-S9 · r/de_Apple (DE)

*Zielgruppe: Deutschsprachige Apple-Nutzer · CTA: App Store · Länge: 827 Zeichen*

```text
Ich bin der Entwickler und stelle hier meine App vor.

Sprechly ist ein Diktiergerät für iPhone und iPad, das Aufnahmen direkt auf dem Gerät in Text verwandelt. Die Spracherkennung kommt von Apple (SpeechAnalyzer, neu seit iOS 26), ich betreibe keinen Server.

Kostenlos sind Aufnahme, Schnitt, Mix und Audio-Export. Von jeder Aufnahme lassen sich die ersten 30 Sekunden gratis transkribieren. Vollständige Transkripte, Zusammenfassungen und Übersetzung schaltet ein einmaliger Kauf frei. Kein Abo, kein Konto.

Was ihr wissen solltet: iOS 26 ist Pflicht. Die KI-Zusammenfassung braucht Apple Intelligence. Der iCloud-Sync ist ab Werk an und nutzt eure private iCloud. Er lässt sich abschalten.

[LINK]

Mich interessiert, wie gut die Erkennung bei euch mit Dialekt und Fachbegriffen klarkommt.
```

#### RD-S10 · r/StartupDACH, Kurzfassung (DE)

*Zielgruppe: Selbstständige, Gründer · CTA: Fachlicher Austausch · Länge: 488 Zeichen*

```text
Ich bin Solo-Entwickler und Autor der App, um die es geht.

Sprechly transkribiert Aufnahmen auf dem iPhone, ohne Server. Deshalb verkaufe ich sie als Einmalkauf. Nach zwei Monaten waren es 128 Downloads, 4 Käufe und 0 Bewertungen. Seit ich die ersten 30 Sekunden jeder Aufnahme gratis transkribiere, ist die Conversion besser.

Frage an alle mit Erfahrung: Einmalkauf bei einer Werkzeug-App durchhalten oder früh auf ein zweites Standbein setzen?

[LINK]
```

### 1.4 Zehn Titel

RD-S8 ist ein Kommentar im Wochen-Thread und braucht keinen Titel. Die Titel der Langfassungen stehen bei RD-L1 bis RD-L5. Englisch: RD-T1 bis RD-T8. Deutsch: RD-T9 und RD-T10.

**RD-T1** · Titel zu RD-S1, r/apple

*Länge: 102 Zeichen (Limit 300)*

```text
I built a voice recorder that transcribes on the iPhone. No subscription, no account. (Developer post)
```

**RD-T2** · Titel zu RD-S2, r/SideProject

*Länge: 77 Zeichen (Limit 300)*

```text
128 downloads, 4 sales, 0 reviews: what I got wrong with my transcription app
```

**RD-T3** · Titel zu RD-S3, r/iosapps

*Länge: 84 Zeichen (Limit 300)*

```text
Sprechly: voice recorder with on-device transcription, one-time purchase (developer)
```

**RD-T4** · Titel zu RD-S4, r/iOSProgramming

*Länge: 75 Zeichen (Limit 300)*

```text
App Saturday: a SpeechAnalyzer timestamp pitfall, and the app I found it in
```

**RD-T5** · Titel zu RD-S5, r/indiehackers

*Länge: 57 Zeichen (Limit 300)*

```text
Was raising a one-time price after four sales reasonable?
```

**RD-T6** · Titel zu RD-S6, r/productivityapps

*Länge: 91 Zeichen (Limit 300)*

```text
Developer here: a recorder that turns a meeting into a transcript and minutes on the device
```

**RD-T7** · Titel zu RD-S7, r/studytips

*Länge: 99 Zeichen (Limit 300)*

```text
Recording a lecture is easy, finding the explanation again isn't. What I built for that (developer)
```

**RD-T8** · frei, für einen eigenen Beitrag zur Korrektur der Store-Beschreibung (Material: LI-EN-4)

*Länge: 105 Zeichen (Limit 300)*

```text
I had to correct my own App Store description: "runs on-device" is not the same as "stays on your device"
```

**RD-T9** · Titel zu RD-S9, r/de_Apple

*Länge: 113 Zeichen (Limit 300)*

```text
Ich habe ein Diktiergerät mit Transkription auf dem iPhone gebaut. Kein Abo. Rückmeldungen erwünscht (Entwickler)
```

**RD-T10** · Titel zu RD-S10, r/StartupDACH

*Länge: 79 Zeichen (Limit 300)*

```text
Einmalkauf bei einer Werkzeug-App durchhalten? Erfahrungen gesucht (Entwickler)
```

### 1.5 Zehn Antworten auf typische Rückfragen

Erst alle zehn auf Englisch (für Reddit), dann alle zehn auf Deutsch (für Foren). Als Antwort auf eine echte Frage im eigenen Thread gedacht. Nicht als Einstieg in fremde Threads verwenden.

#### Englisch

**RD-A1-EN** · „Wird wirklich nichts hochgeladen?“

*Länge: 494 Zeichen*

```text
The answer has two parts.

Speech recognition and the AI features run on the device. I don't operate a server, and the app contains no analytics or third-party SDK. Nothing goes to me.

But I don't claim "no upload", because iCloud sync is on by default. It stores your recordings and transcripts in your own private iCloud so your other devices get them. I can't read that data. If you don't want it, switch it off under Settings > iCloud. The change takes effect the next time the app starts.
```

**RD-A2-EN** · „Warum nur iOS 26?“

*Länge: 239 Zeichen*

```text
Because the two frameworks the app is built on have only existed since iOS 26: SpeechAnalyzer for transcription and Foundation Models for summaries. Supporting older versions would mean a second speech engine, and the app doesn't have one.
```

**RD-A3-EN** · „Wie gut ist die Erkennung im Vergleich zu X?“

*Länge: 405 Zeichen*

```text
I haven't run a comparison I could stand behind, so I won't claim one. The recognition is Apple's on-device model. My app doesn't change how well it recognizes words.

What I can say: I have only tested German and English myself, and names and technical terms are the weak spot. That is why the first 30 seconds of every recording are transcribed for free. Try it with the kind of audio you actually have.
```

**RD-A4-EN** · „Welche Sprachen?“

*Länge: 391 Zeichen*

```text
The app offers the languages Apple's on-device speech model supports on your device. After the purchase you find the list under Settings > Language Models and download each model once. I have tested German and English myself and can't vouch for the others.

The interface is in German and English. Translation of a finished transcript covers 15 target languages and needs Apple Intelligence.
```

**RD-A5-EN** · „Warum braucht die KI Apple Intelligence?“

*Länge: 333 Zeichen*

```text
Summaries, titles and translation use Apple's on-device language model, and that only exists on devices with Apple Intelligence. The alternative would have been a server of my own, and I don't run one.

Transcription itself doesn't need Apple Intelligence. The purchase screen shows which features work on your device before you buy.
```

**RD-A6-EN** · „Erkennt die App Sprecher?“

*Länge: 158 Zeichen*

```text
No. The transcript has timestamps but no speaker labels. The app doesn't do speaker recognition. For an interview with two people you get one continuous text.
```

**RD-A7-EN** · „Warum ist die Transkription nicht einfach gratis?“

*Länge: 364 Zeichen*

```text
Because it is the part of the app I earn from. Recording, editing, mixing and audio export are free without limits. There are no ads and there is no subscription.

To let you judge before paying, the first 30 seconds of every recording are transcribed for free. The purchase is one-time and covers full transcripts, the live transcript, export and the AI features.
```

**RD-A8-EN** · „Schafft die App lange Aufnahmen?“

*Länge: 327 Zeichen*

```text
Yes. The file is read and transcribed in a stream, so it is never loaded into memory as a whole. I have run it on recordings of several hours.

One weakness: there is no percentage display. While it runs you only see the number of segments so far, so on a very long file you can't tell how far along it is. I know that's a gap.
```

**RD-A9-EN** · „Gibt es MP3-Export?“

*Länge: 167 Zeichen*

```text
No. iOS can play MP3 but has no built-in MP3 encoder, and I don't ship third-party libraries. Audio exports as M4A (AAC) or WAV. Transcripts export as TXT or Markdown.
```

**RD-A10-EN** · „Ist das Open Source? Woher weiß ich, dass das stimmt?“

*Länge: 449 Zeichen*

```text
The source isn't public, so you can't audit it. Here is what you can check yourself.

- The App Store privacy label says "Data Not Collected". That is a declaration I make to Apple.
- There is no account and no sign-in anywhere in the app.
- Download a language model, switch on airplane mode and transcribe. It works.

The app only talks to Apple: to download the language model, to handle the purchase, and for iCloud sync, which you can turn off.
```

#### Deutsch

**RD-A1-DE** · „Wird wirklich nichts hochgeladen?“

*Länge: 552 Zeichen*

```text
Die Antwort hat zwei Teile.

Spracherkennung und KI laufen auf dem Gerät. Ich betreibe keinen Server, und in der App steckt weder Analyse-Software noch ein Drittanbieter-SDK. Bei mir kommt nichts an.

„Kein Upload“ behaupte ich trotzdem nicht, denn der iCloud-Sync ist ab Werk eingeschaltet. Er legt Aufnahmen und Transkripte in deiner privaten iCloud ab, damit deine anderen Geräte sie bekommen. Ich kann diese Daten nicht lesen. Wer das nicht möchte, schaltet den Sync unter Einstellungen > iCloud ab. Die Änderung greift beim nächsten Start der App.
```

**RD-A2-DE** · „Warum nur iOS 26?“

*Länge: 267 Zeichen*

```text
Weil es die beiden Frameworks, auf denen die App aufbaut, erst ab iOS 26 gibt: SpeechAnalyzer für die Transkription und Foundation Models für die Zusammenfassungen. Ältere Versionen zu unterstützen hieße, eine zweite Spracherkennung einzubauen. Die hat die App nicht.
```

**RD-A3-DE** · „Wie gut ist die Erkennung im Vergleich zu X?“

*Länge: 472 Zeichen*

```text
Einen Vergleich, hinter dem ich stehen könnte, habe ich nicht gemacht. Also behaupte ich auch keinen. Die Erkennung ist Apples On-Device-Modell. Meine App ändert nichts daran, wie gut es Wörter erkennt.

Was ich sagen kann: Selbst getestet habe ich nur Deutsch und Englisch, und Eigennamen und Fachbegriffe sind die Schwachstelle. Genau deshalb lassen sich die ersten 30 Sekunden jeder Aufnahme gratis transkribieren. Probier es mit dem Material aus, das du wirklich hast.
```

**RD-A4-DE** · „Welche Sprachen?“

*Länge: 429 Zeichen*

```text
Die App bietet die Sprachen an, die Apples On-Device-Sprachmodell auf deinem Gerät unterstützt. Nach dem Kauf steht die Liste unter Einstellungen > Sprachmodelle, jedes Modell wird einmal geladen. Selbst getestet habe ich Deutsch und Englisch. Für die anderen kann ich nicht bürgen.

Die Oberfläche gibt es auf Deutsch und Englisch. Die Übersetzung eines fertigen Transkripts kennt 15 Zielsprachen und braucht Apple Intelligence.
```

**RD-A5-DE** · „Warum braucht die KI Apple Intelligence?“

*Länge: 355 Zeichen*

```text
Zusammenfassung, Titel und Übersetzung nutzen Apples Sprachmodell auf dem Gerät, und das gibt es nur auf Geräten mit Apple Intelligence. Die Alternative wäre ein eigener Server gewesen, und den betreibe ich nicht.

Die Transkription selbst braucht Apple Intelligence nicht. Der Kaufbildschirm zeigt vor dem Kauf, welche Funktionen auf deinem Gerät laufen.
```

**RD-A6-DE** · „Erkennt die App Sprecher?“

*Länge: 180 Zeichen*

```text
Nein. Das Transkript hat Zeitmarken, aber keine Sprecher-Zuordnung. Eine Sprechererkennung hat die App nicht. Bei einem Interview mit zwei Personen entsteht ein durchgehender Text.
```

**RD-A7-DE** · „Warum ist die Transkription nicht einfach gratis?“

*Länge: 384 Zeichen*

```text
Weil sie der Teil der App ist, mit dem ich Geld verdiene. Aufnahme, Schnitt, Mix und Audio-Export sind unbegrenzt gratis. Werbung gibt es nicht, ein Abo auch nicht.

Damit du vor dem Kauf urteilen kannst, lassen sich die ersten 30 Sekunden jeder Aufnahme gratis transkribieren. Der Kauf ist einmalig und umfasst vollständige Transkripte, Live-Transkript, Export und die KI-Funktionen.
```

**RD-A8-DE** · „Schafft die App lange Aufnahmen?“

*Länge: 357 Zeichen*

```text
Ja. Die Datei wird Stück für Stück gelesen und transkribiert und nie als Ganzes in den Speicher geladen. Getestet habe ich das mit Aufnahmen von mehreren Stunden.

Eine Schwäche: Es gibt keine Prozentanzeige. Während des Laufs siehst du nur die Zahl der bisherigen Segmente. Bei einer sehr langen Datei ist also unklar, wie weit er ist. Die Lücke kenne ich.
```

**RD-A9-DE** · „Gibt es MP3-Export?“

*Länge: 205 Zeichen*

```text
Nein. iOS kann MP3 abspielen, bringt aber keinen MP3-Encoder mit, und Bibliotheken von Dritten baue ich nicht ein. Audio lässt sich als M4A (AAC) oder WAV exportieren, das Transkript als TXT oder Markdown.
```

**RD-A10-DE** · „Ist das Open Source? Woher weiß ich, dass das stimmt?“

*Länge: 497 Zeichen*

```text
Der Quellcode ist nicht öffentlich, prüfen lässt er sich also nicht. Das hier kannst du selbst nachvollziehen.

- Das Datenschutzlabel im App Store lautet „Keine Daten erfasst“. Das ist eine Erklärung, die ich gegenüber Apple abgebe.
- In der App gibt es kein Konto und keine Anmeldung.
- Sprachmodell laden, Flugmodus einschalten, transkribieren. Es funktioniert.

Die App spricht nur mit Apple: für den Download des Sprachmodells, für den Kauf und für den iCloud-Sync, der sich abschalten lässt.
```

---

## 2. LinkedIn

Fünf deutsche und fünf englische Beiträge. Zusammen decken sie die sieben geforderten Varianten ab: Produktvorstellung (DE-1, EN-1), technische Entstehung (DE-2), Datenschutz und lokale Verarbeitung (DE-3, EN-4), „Warum kein Abo?“ (DE-4, EN-3), Entwicklung einer Indie-App (DE-5), Transkriptionsqualität (EN-2), persönlicher Entwicklerblick (EN-5).

LinkedIn drosselt Beiträge mit externem Link häufig. Wer das umgehen will, setzt den Link in den ersten Kommentar. Die Texte funktionieren in beiden Fällen.

### 2.1 Deutsch

#### LI-DE-1 · Produktvorstellung

*Zielgruppe: Selbstständige, kleine Unternehmen, Meeting-Nutzer · CTA: App Store + Feedback · Hashtags: #iOS #Transkription #IndieDev · Länge: 1318 Zeichen (Limit 3000)*

```text
Ich habe eine App gebaut, die Gesprochenes in Text verwandelt. Auf zwei Dinge habe ich dabei verzichtet: ein Abo und ein Benutzerkonto.

Sprechly ist ein Diktiergerät für iPhone und iPad. Aufnehmen, transkribieren, zusammenfassen, exportieren.

Was die App macht:
→ Aufnahme auch im Hintergrund und bei gesperrtem Bildschirm
→ Transkription direkt auf dem Gerät, auf Wunsch live während der Aufnahme
→ Zusammenfassung, Protokoll oder Stichpunkte per KI, ebenfalls auf dem Gerät
→ Schneiden, Stille entfernen, Aufnahmen zusammenführen und mischen
→ Export als M4A oder WAV, das Transkript als TXT oder Markdown

Was sie kostet: Der Download ist kostenlos. Aufnehmen, Bearbeiten und Audio-Export bleiben unbegrenzt gratis. Die ersten 30 Sekunden jeder Aufnahme lassen sich kostenlos transkribieren. Vollständige Transkripte und die KI-Funktionen schaltet ein einmaliger Kauf frei.

Zwei Einschränkungen gehören dazu: Die App braucht iOS 26. Und die KI-Funktionen laufen nur auf Geräten mit Apple Intelligence. Die Transkription läuft auch ohne.

Ich bin der Entwickler und arbeite allein an Sprechly. Wer Besprechungen, Interviews oder Vorlesungen mitschreibt und die App ausprobiert: Mich interessiert vor allem, wo die Transkription danebenliegt.

[LINK]

#iOS #Transkription #IndieDev
```

#### LI-DE-2 · Technische Entstehung

*Zielgruppe: Entwickler, technisch Interessierte · CTA: Erfahrungsaustausch · Hashtags: #Swift #iOSDev #SpeechAnalyzer · Länge: 1789 Zeichen (Limit 3000)*

```text
Meine App baut auf zwei Frameworks auf, die es erst seit iOS 26 gibt. Keines von beiden läuft im Simulator.

Sprechly ist ein Diktiergerät mit Transkription für iPhone und iPad. Die Spracherkennung übernimmt SpeechAnalyzer von Apple, die Zusammenfassungen das Foundation-Models-Framework. Beides rechnet auf dem Gerät.

Was das beim Bauen bedeutet hat:

1. Kein Test ohne echtes Gerät. Alles, was Sprache oder KI berührt, hängt hinter einer Schnittstelle. Die automatischen Tests arbeiten mit Mocks. Das echte Verhalten prüfe ich nach einer Checkliste auf dem iPhone.

2. Zeitstempel selbst zu setzen war ein Fehler. Ich habe die Audiodatei in Blöcken gelesen und jedem Block eine Startzeit mitgegeben. Nach der Umrechnung der Abtastrate überlappten die Blöcke um Bruchteile, und der Analyzer brach ab. Ohne eigene Startzeiten stimmt alles.

3. iOS kann kein MP3 schreiben. Abspielen ja, kodieren nein. Der Export bietet deshalb M4A und WAV.

4. Das Sprachmodell auf dem Gerät fasst wenig Text auf einmal. Lange Transkripte zerlege ich in Abschnitte von höchstens 800 Zeichen und verdichte sie stufenweise.

Der Code: Swift 6 mit strenger Nebenläufigkeitsprüfung, SwiftUI, SwiftData, keine einzige Fremdbibliothek, mehr als 160 automatisierte Tests.

Ungelöst ist die Erkennung von Eigennamen und Fachbegriffen. Die API bietet dafür eine Begriffsliste an. Bevor ich daraus ein Wörterbuch baue, habe ich gemessen: 15 Testsätze, 31 Zielbegriffe, einmal ohne und einmal mit Liste. Erkannt wurden beide Male 13, die Transkripte waren zeichengleich. Das Wörterbuch baue ich auf diesem Weg nicht.

Ich bin der Entwickler von Sprechly. Wer mit SpeechAnalyzer arbeitet: Welche Erfahrungen habt ihr mit Fachvokabular gemacht?

[LINK]

#Swift #iOSDev #SpeechAnalyzer
```

#### LI-DE-3 · Datenschutz und lokale Verarbeitung

*Zielgruppe: Datenschutzbewusste, IT-Verantwortliche · CTA: Diskussion zu präzisen Datenschutzaussagen · Hashtags: #Datenschutz #AppEntwicklung #iOS · Länge: 1375 Zeichen (Limit 3000)*

```text
In meiner App-Beschreibung stand ein Satz, der nicht stimmte. Geschrieben hatte ich ihn selbst.

Sinngemäß lautete er: Deine Stimme verlässt das Gerät nicht.

Sprechly ist ein Diktiergerät mit Transkription für iPhone und iPad. Richtig ist: Spracherkennung und KI rechnen auf dem Gerät. Ich betreibe keinen Server. Es gibt kein Tracking, keine Werbung und kein Drittanbieter-SDK.

Aber die App hat einen iCloud-Sync, und der ist ab Werk eingeschaltet. Er legt Aufnahmen und Transkripte in der privaten iCloud des Nutzers ab, damit sie auf dem iPad genauso da sind wie auf dem iPhone. Ich komme an diese Daten nicht heran. Trotzdem verlassen sie das Gerät.

„Wird auf dem Gerät verarbeitet“ und „bleibt auf dem Gerät“ sind zwei verschiedene Aussagen. Ich hatte die zweite geschrieben und die erste gemeint.

Der Satz ist gestrichen. Im Store steht jetzt:
→ Kein Abo, kein Konto
→ Transkription und KI rechnen auf dem Gerät
→ iCloud-Sync über die eigene private iCloud, abschaltbar in den Einstellungen

Das klingt weniger griffig. Dafür stimmt es.

Wer Datenschutz als Verkaufsargument nutzt, sollte jeden dieser Sätze gegen den eigenen Code prüfen. Bei mir hat ein einziger Schalter gereicht, der ab Werk eingeschaltet ist, um eine Werbeaussage falsch zu machen.

Ich bin der Entwickler von Sprechly: [LINK]

#Datenschutz #AppEntwicklung #iOS
```

#### LI-DE-4 · Warum kein Abo?

*Zielgruppe: Abo-Müde, Selbstständige · CTA: Meinung zum Preismodell · Hashtags: #KeinAbo #IndieDev #Preismodell · Länge: 1232 Zeichen (Limit 3000)*

```text
Warum meine Transkriptions-App kein Abo hat: weil ich keine Rechnung bekomme, wenn jemand sie benutzt.

Wer Transkription im Rechenzentrum rechnen lässt, hat mit jeder Minute Audio Kosten. Ein Abo ist dann folgerichtig.

Sprechly rechnet auf dem iPhone oder iPad. Die Spracherkennung liefert Apple mit dem Betriebssystem, das Sprachmodell für Zusammenfassungen auch. Bei mir läuft kein Server. Ob jemand zehn Minuten transkribiert oder zehn Stunden: Meine Kosten bleiben gleich.

Also verkaufe ich die App so, wie Werkzeuge früher verkauft wurden. Einmal kaufen, dauerhaft nutzen.

Konkret:
→ Download kostenlos
→ Aufnahme, Schnitt und Audio-Export unbegrenzt gratis
→ 30 Sekunden Transkription je Aufnahme zum Ausprobieren
→ ein einmaliger Kauf für vollständige Transkripte und die KI-Funktionen

Das Modell hat einen Preis, und der liegt bei mir: Ein Einmalkauf bringt keine planbaren Einnahmen. Neue Funktionen muss ich über neue Käufe finanzieren. Ob das auf Dauer trägt, weiß ich noch nicht.

Mich interessiert eure Sicht: Zahlt ihr für ein Werkzeug lieber einmalig mehr oder monatlich wenig?

Ich bin der Entwickler von Sprechly. Die App braucht iOS 26: [LINK]

#KeinAbo #IndieDev #Preismodell
```

#### LI-DE-5 · Entwicklung einer Indie-App

*Zielgruppe: Entwickler, Gründer, Netzwerk · CTA: Erfahrungsaustausch · Hashtags: #IndieDev #AppStore #BuildInPublic · Länge: 1490 Zeichen (Limit 3000)*

```text
128 Downloads, 4 Käufe, 0 Bewertungen. Das war die Bilanz meiner App nach den ersten zwei Monaten im Store.

Ich entwickle Sprechly allein, ein Diktiergerät mit Transkription für iPhone und iPad. Die Zahlen stammen aus App Store Connect, Stand Mitte August.

Die Null bei den Bewertungen hatte eine einfache Ursache, und die war ein Fehler von mir: Die App fragt nur in einem guten Moment nach einer Bewertung. Alle guten Momente, die ich definiert hatte, lagen hinter dem Kauf. Bei 4 Käufern auf 128 Downloads konnten rund 97 % der Nutzer die Frage nie zu sehen bekommen.

Der zweite Fehler: Die Transkription lag komplett hinter der Bezahlschranke. Wer wissen wollte, ob sie etwas taugt, musste erst zahlen.

Was ich geändert habe:
→ Die ersten 30 Sekunden jeder Aufnahme werden gratis transkribiert
→ Der Kaufbildschirm zeigt zuerst dieses eigene Ergebnis
→ Die Bewertungsfrage kann nach einer gespeicherten Aufnahme oder einem fertigen Schnitt kommen

Seitdem ist die Conversion merklich besser. Die Sichtbarkeit ist dagegen gesunken. Der Engpass war von Anfang an ein anderer: 9.340-mal hat der Store die App angezeigt, 209-mal wurde ihre Seite geöffnet.

Was ich mitnehme: Ich habe wochenlang an Funktionen gearbeitet und die Stelle übersehen, an der Menschen entscheiden, ob sie sich die App überhaupt ansehen.

‹Optional: ein Satz dazu, warum du Sprechly gebaut hast.›

Ich bin der Entwickler von Sprechly: [LINK]

#IndieDev #AppStore #BuildInPublic
```

### 2.2 Englisch

#### LI-EN-1 · Product introduction

*Zielgruppe: Professionals, small businesses, meeting users · CTA: App Store + feedback · Hashtags: #iOS #Transcription #IndieDev · Länge: 1145 Zeichen (Limit 3000)*

```text
I built an app that turns speech into text, and I left out two things: a subscription and an account.

Sprechly is a voice recorder for iPhone and iPad. Record, transcribe, summarize, export.

What it does:
→ Records in the background and on the lock screen
→ Transcribes on the device, live while you record if you want
→ Writes a summary, meeting minutes or bullet points with on-device AI
→ Cuts, removes silence, merges and mixes recordings
→ Exports audio as M4A or WAV and transcripts as TXT or Markdown

What it costs: the download is free. Recording, editing and audio export stay free without limits. The first 30 seconds of any recording are transcribed for free. Full transcripts and the AI features unlock with a single one-time purchase.

Two limits belong in this post: the app needs iOS 26, and the AI features only run on devices with Apple Intelligence. Transcription works without it.

I'm the developer and I work on Sprechly alone. If you take notes in meetings, interviews or lectures and try it, I'd like to know where the transcription gets it wrong.

[LINK]

#iOS #Transcription #IndieDev
```

#### LI-EN-2 · Transcription quality

*Zielgruppe: Journalists, interviewers, developers · CTA: Share real-world results · Hashtags: #SpeechRecognition #iOSDev #Transcription · Länge: 1754 Zeichen (Limit 3000)*

```text
The short answer to "how good is the transcription?" is: as good as Apple's model, and I can't change that.

Sprechly, my voice recorder for iPhone and iPad, transcribes with Apple's on-device speech framework. I looked for a setting that improves recognition. There isn't one. The options control how results are reported. They don't control how well words are recognized.

I have only tested German and English myself. Names, company names and technical terms are where it slips.

There is one lever in the API that might help. You can hand the analyzer a list of terms to expect. The SDK doesn't promise that the transcriber uses them.

So before building a "custom vocabulary" feature, I measured. 15 German sentences, rendered with the system speech synthesizer on an iPhone, containing 31 target terms: names, technical terms, abbreviations, numbers. Each sentence was transcribed twice, once without the term list and once with it.

The result: 13 of 31 terms recognized in both runs. The two transcripts were identical character for character. I checked separately that the analyzer had received the list. It had.

So I won't ship that feature. A vocabulary screen would promise something the system doesn't deliver.

The measurement has a limit of its own. Synthetic speech is clean, so it says nothing about a noisy meeting room. It only tells me that the term list changed nothing.

The practical test is yours. The first 30 seconds of every recording are transcribed for free, so you can try it with your own voice and your own vocabulary.

I'm the developer. If you transcribe interviews or meetings, which words does your current tool get wrong most often?

[LINK]

#SpeechRecognition #iOSDev #Transcription
```

#### LI-EN-3 · Why no subscription?

*Zielgruppe: Subscription-fatigued professionals · CTA: Opinion on pricing · Hashtags: #NoSubscription #IndieDev #Pricing · Länge: 1164 Zeichen (Limit 3000)*

```text
My transcription app has no subscription for a simple reason: I don't get a bill when you use it.

A transcription service that runs in a data center has costs for every minute of audio, so a subscription makes sense.

Sprechly runs on the iPhone or iPad. Apple ships the speech recognition with the operating system, and the language model for summaries too. I don't operate a server. Whether you transcribe ten minutes or ten hours, my costs stay the same.

So I sell it the way tools used to be sold. Buy once, keep using it.

In practice:
→ Free download
→ Recording, editing and audio export free without limits
→ 30 seconds of transcription per recording to try it
→ A single one-time purchase for full transcripts and the AI features

The model has a cost, and I carry it. A one-time purchase gives me no predictable income, and new features have to be paid for by new buyers. I don't know yet whether that holds up over years.

I'm curious how you see it: for a tool you use weekly, would you pay more once or a little every month?

I'm the developer of Sprechly. It needs iOS 26: [LINK]

#NoSubscription #IndieDev #Pricing
```

#### LI-EN-4 · Privacy wording

*Zielgruppe: Privacy-minded professionals, product people · CTA: Discussion · Hashtags: #Privacy #AppDevelopment #iOS · Länge: 1219 Zeichen (Limit 3000)*

```text
My App Store description contained a sentence that wasn't true. I wrote it myself.

It said, in effect: your voice never leaves the device.

Sprechly is a voice recorder with transcription for iPhone and iPad. What is true: speech recognition and AI run on the device. I don't operate a server. There is no tracking, no advertising and no third-party SDK.

But the app has iCloud sync, and it is on by default. It stores recordings and transcripts in the user's private iCloud so they show up on the iPad as well as the iPhone. I can't access that data. It still leaves the device.

"Processed on the device" and "stays on the device" are two different claims. I had written the second and meant the first.

The sentence is gone. The store page now says:
→ No subscription, no account
→ Transcription and AI run on the device
→ iCloud sync through your own private iCloud, which you can switch off in Settings

That's less catchy, but it's true.

If you use privacy as a selling point, check each sentence against your own code. In my case one toggle that is on by default was enough to make a marketing claim false.

I'm the developer of Sprechly: [LINK]

#Privacy #AppDevelopment #iOS
```

#### LI-EN-5 · Developer's view

*Zielgruppe: Developers, founders · CTA: Exchange of experience · Hashtags: #IndieDev #AppStore #BuildInPublic · Länge: 1312 Zeichen (Limit 3000)*

```text
For its first two months, 97% of my users could not be asked for a rating. I built it that way without noticing.

I develop Sprechly alone. It is a voice recorder with on-device transcription for iPhone and iPad. After two months in the store it had 128 downloads, 4 purchases and 0 ratings.

The zero had a simple cause, and it was my own logic. The app only asks for a rating at a good moment, and every good moment I had defined came after the purchase: a finished transcript or an AI summary. Four buyers out of 128 downloads means the prompt was unreachable for almost everyone.

The fix was small. A saved recording counts as a good moment now. So does a finished edit. Both are free features.

The second mistake was related. Transcription sat entirely behind the paywall, so people had to pay to find out whether it was any good. Now the first 30 seconds of every recording are transcribed for free, and the purchase screen shows that result.

Conversion has improved noticeably since. Visibility hasn't. The store showed the app 9,340 times, and its page was opened 209 times. That was the bottleneck all along, and I spent those weeks building features.

‹Optional: one sentence on why you built Sprechly.›

I'm the developer: [LINK]

#IndieDev #AppStore #BuildInPublic
```

---

## 3. Mastodon

Fünfzehn deutsche und zehn englische Beiträge, je höchstens 500 Zeichen, mit drei bis fünf Hashtags in CamelCase (Screenreader lesen sie dann wortweise vor). Bilder brauchen eine Bildbeschreibung. Auf chaos.social ist sie für die lokale Timeline Pflicht.

Nicht jeder Beitrag trägt einen Link. Ein Profil, das nur Links postet, liest sich wie Werbung.

### 3.1 Deutsch

#### MA-DE-01 · Vorstellung

*Zielgruppe: Apple-Nutzer, Abo-Müde · CTA: App Store · Hashtags: #iOS #IndieDev #Transkription #KeinAbo · Länge: 395 Zeichen (Limit 500, Link als 23 gezählt)*

```text
Ich bin Rene und entwickle allein Sprechly: ein Diktiergerät für iPhone und iPad, das Aufnahmen direkt auf dem Gerät in Text verwandelt.

Kein Abo, kein Konto, kein Tracking. Aufnahme und Schnitt sind gratis. Die ersten 30 Sekunden jeder Aufnahme transkribiert die App kostenlos, der Rest ist ein einmaliger Kauf.

Braucht iOS 26.

[LINK]

#iOS #IndieDev #Transkription #KeinAbo
```

#### MA-DE-02 · Kein Abo

*Zielgruppe: Abo-Müde · CTA: App Store · Hashtags: #KeinAbo #iOS #IndieDev · Länge: 326 Zeichen (Limit 500, Link als 23 gezählt)*

```text
Warum Sprechly kein Abo hat: Bei mir läuft kein Server. Die Spracherkennung rechnet auf deinem iPhone, also kostet mich deine Nutzung nichts.

Deshalb gilt: einmal kaufen, dauerhaft nutzen. Aufnehmen, Schneiden und Audio-Export bleiben ohnehin gratis.

Ich bin der Entwickler.

[LINK]

#KeinAbo #iOS #IndieDev
```

#### MA-DE-03 · Datenschutz, genau gesagt

*Zielgruppe: Datenschutzbewusste · CTA: Nachfragen erwünscht · Hashtags: #Datenschutz #iOS #Transkription #IndieDev · Länge: 409 Zeichen (Limit 500, Link als 23 gezählt)*

```text
Datenschutz bei Sprechly, genau gesagt:

– Transkription und KI laufen auf dem Gerät
– kein eigener Server, kein Tracking, keine Fremd-SDKs
– kein Konto

Und der Teil, den ich nicht verschweige: Der iCloud-Sync ist ab Werk an und speichert Aufnahmen in deiner privaten iCloud. In den Einstellungen lässt er sich abschalten.

Ich bin der Entwickler. Fragt gern nach.

#Datenschutz #iOS #Transkription #IndieDev
```

#### MA-DE-04 · Versprecher überschreiben

*Zielgruppe: Diktierende, Podcaster · CTA: App Store · Hashtags: #Diktiergerät #iPhone #Podcast #IndieDev · Länge: 367 Zeichen (Limit 500, Link als 23 gezählt)*

```text
Versprecher? In Sprechly spulst du zurück, hörst rein und nimmst ab dem Cursor neu auf. Der Versprecher wird überschrieben, alles davor bleibt.

Damit an der Nahtstelle keine Lücke entsteht, läuft die Aufnahme dabei intern verlustfrei.

Aufnehmen und Schneiden sind kostenlos. Ich bin der Entwickler.

[LINK]

#Diktiergerät #iPhone #Podcast #IndieDev
```

#### MA-DE-05 · 30 Sekunden gratis

*Zielgruppe: Unentschlossene, Abo-Müde · CTA: Ausprobieren · Hashtags: #Transkription #iOS #KeinAbo · Länge: 381 Zeichen (Limit 500, Link als 23 gezählt)*

```text
Bevor du für Transkription zahlst, solltest du das Ergebnis sehen. Mit deiner eigenen Stimme und nicht mit einem Demo-Text.

Sprechly transkribiert deshalb die ersten 30 Sekunden jeder Aufnahme gratis. Die Vorschau wird nicht gespeichert. Das vollständige Transkript schaltet ein einmaliger Kauf frei.

Ich bin der Entwickler.

[LINK]

#Transkription #iOS #KeinAbo
```

#### MA-DE-06 · Vorlesung

*Zielgruppe: Studierende · CTA: App Store · Hashtags: #Studium #Transkription #iPad · Länge: 409 Zeichen (Limit 500, Link als 23 gezählt)*

```text
Vorlesung aufgenommen und die eine Erklärung nicht wiedergefunden?

In Sprechly tippst du im Transkript auf die Zeile, und die Aufnahme springt an diese Stelle. Transkribiert wird auf dem iPhone oder iPad. Für die eigenen Notizen gibt es den Export als Markdown.

Bitte vorher fragen, ob Aufnehmen erlaubt ist.

Ich bin der Entwickler. iOS 26 ist nötig.

[LINK]

#Studium #Transkription #iPad
```

#### MA-DE-07 · Interview

*Zielgruppe: Journalisten, Interviewer · CTA: App Store · Hashtags: #Journalismus #Interview #Transkription #iOS · Länge: 367 Zeichen (Limit 500, Link als 23 gezählt)*

```text
Für alle, die Interviews führen: Sprechly nimmt auf, transkribiert auf dem Gerät und exportiert das Transkript mit Zeitmarken als TXT oder Markdown.

Was fehlt: Sprecher werden nicht unterschieden. Zwei Stimmen ergeben einen durchgehenden Text.

Ich bin der Entwickler und sage das lieber vorher.

[LINK]

#Journalismus #Interview #Transkription #iOS
```

#### MA-DE-08 · Meeting

*Zielgruppe: Meeting-Nutzer, kleine Unternehmen · CTA: App Store · Hashtags: #Meeting #Protokoll #iOS #Transkription · Länge: 431 Zeichen (Limit 500, Link als 23 gezählt)*

```text
Aus 30 Minuten Besprechung werden ein Transkript und ein Protokoll, zum Beispiel mit Themen, Entscheidungen und offenen Punkten. Beides entsteht auf dem iPhone.

Das Protokoll schreibt Apples On-Device-Modell. Dafür braucht es ein Gerät mit Apple Intelligence. Die Transkription läuft auch ohne.

Das Einverständnis der Runde vorausgesetzt.

Ich bin der Entwickler.

[LINK]

#Meeting #Protokoll #iOS #Transkription
```

#### MA-DE-09 · Vorhandene Sprachmemos

*Zielgruppe: Menschen mit vorhandenen Sprachaufnahmen · CTA: App Store · Hashtags: #Sprachmemo #Transkription #iPhone · Länge: 355 Zeichen (Limit 500, Link als 23 gezählt)*

```text
Du hast schon Sprachaufnahmen herumliegen? Sprechly importiert Audiodateien aus der Dateien-App und behandelt sie wie eigene Aufnahmen: abspielen, schneiden, transkribieren.

Der Import ist kostenlos. Von jeder Datei transkribiert die App die ersten 30 Sekunden gratis.

Ich bin der Entwickler.

[LINK]

#Sprachmemo #Transkription #iPhone
```

#### MA-DE-10 · Technik: kein Simulator

*Zielgruppe: iOS-Entwickler · CTA: Erfahrungsaustausch · Hashtags: #iOSDev #SwiftLang #SpeechAnalyzer #IndieDev · Länge: 347 Zeichen (Limit 500, Link als 23 gezählt)*

```text
Notiz aus der Entwicklung von Sprechly: SpeechAnalyzer und Foundation Models laufen nicht im Simulator.

Bei mir hängt deshalb alles, was Sprache oder KI berührt, hinter einer Schnittstelle. Die Tests arbeiten mit Mocks. Das echte Verhalten prüfe ich nach Checkliste auf dem iPhone.

Wie löst ihr das?

#iOSDev #SwiftLang #SpeechAnalyzer #IndieDev
```

#### MA-DE-11 · Technik: kein MP3

*Zielgruppe: Technisch Interessierte · CTA: keiner · Hashtags: #iOSDev #Audio #IndieDev · Länge: 310 Zeichen (Limit 500, Link als 23 gezählt)*

```text
Warum Sprechly kein MP3 exportiert: iOS kann MP3 abspielen, aber nicht erzeugen. Die Abfrage der verfügbaren Encoder liefert für AAC einen Treffer und für MP3 keinen.

Eine Fremdbibliothek wollte ich dafür nicht einbauen. Die App kommt ganz ohne aus. Exportiert wird als M4A oder WAV.

#iOSDev #Audio #IndieDev
```

#### MA-DE-12 · Korrektur der Store-Beschreibung

*Zielgruppe: Datenschutzbewusste, Entwickler · CTA: keiner · Hashtags: #Datenschutz #IndieDev #iOS · Länge: 399 Zeichen (Limit 500, Link als 23 gezählt)*

```text
Ich musste meine eigene App-Beschreibung korrigieren. Dort stand sinngemäß, die Stimme verlasse das Gerät nicht.

Das stimmte nicht. Die Transkription rechnet zwar auf dem Gerät. Aber der iCloud-Sync ist ab Werk an und lädt Aufnahmen in die private iCloud.

„Auf dem Gerät verarbeitet“ ist etwas anderes als „bleibt auf dem Gerät“. Den falschen Satz habe ich gestrichen.

#Datenschutz #IndieDev #iOS
```

#### MA-DE-13 · Der Bewertungs-Fehler

*Zielgruppe: Entwickler, Indie-Szene · CTA: keiner · Hashtags: #IndieDev #AppStore #BuildInPublic · Länge: 333 Zeichen (Limit 500, Link als 23 gezählt)*

```text
128 Downloads, 0 Bewertungen. Die Ursache war mein eigener Code.

Sprechly fragt nur in einem guten Moment nach einer Bewertung. Alle guten Momente lagen hinter dem Kauf. Bei 4 Käufern konnten rund 97 % der Nutzer die Frage nie sehen.

Jetzt zählt auch eine gespeicherte Aufnahme als guter Moment.

#IndieDev #AppStore #BuildInPublic
```

#### MA-DE-14 · Markdown-Export

*Zielgruppe: Notiz-Nerds, Obsidian- und Markdown-Nutzer · CTA: App Store · Hashtags: #Markdown #Transkription #iOS #Notizen · Länge: 341 Zeichen (Limit 500, Link als 23 gezählt)*

```text
Für alle, die in Markdown denken: Sprechly exportiert das Transkript als .md, mit Titel, Datum, Dauer, Zusammenfassung und Zeitmarken vor jedem Abschnitt. Umlaute kommen korrekt an.

Die Datei landet über das Teilen-Menü dort, wo deine Notizen liegen.

Ich bin der Entwickler.

[LINK]

#Markdown #Transkription #iOS #Notizen
```

#### MA-DE-15 · Frage in die Runde

*Zielgruppe: Alle Nutzer von Spracherkennung · CTA: Antworten · Hashtags: #Transkription #iOSDev #IndieDev · Länge: 360 Zeichen (Limit 500, Link als 23 gezählt)*

```text
Frage an alle, die Spracherkennung nutzen: Welche Wörter gehen bei euch regelmäßig schief?

Bei Sprechly sind es Eigennamen und Fachbegriffe. Die Erkennung kommt von Apple. Ob eine Begriffsliste hilft, habe ich gemessen: bei 31 Testbegriffen kein Unterschied.

Beispiele helfen mir beim nächsten Test.

Ich bin der Entwickler.

#Transkription #iOSDev #IndieDev
```

### 3.2 Englisch

#### MA-EN-01 · Introduction

*Zielgruppe: Apple users, subscription-fatigued · CTA: App Store · Hashtags: #iOS #IndieDev #Transcription #NoSubscription · Länge: 376 Zeichen (Limit 500, Link als 23 gezählt)*

```text
I'm Rene, a solo developer. I make Sprechly, a voice recorder for iPhone and iPad that transcribes on the device.

No subscription, no account, no tracking. Recording and editing are free. The first 30 seconds of any recording are transcribed for free, and the rest is a one-time purchase.

Needs iOS 26.

[LINK]

#iOS #IndieDev #Transcription #NoSubscription
```

#### MA-EN-02 · No subscription

*Zielgruppe: Subscription-fatigued · CTA: App Store · Hashtags: #NoSubscription #iOS #IndieDev · Länge: 290 Zeichen (Limit 500, Link als 23 gezählt)*

```text
Why Sprechly has no subscription: I don't run a server. Speech recognition runs on your iPhone, so your usage costs me nothing.

So you buy it once and keep it. Recording, editing and audio export are free anyway.

I'm the developer.

[LINK]

#NoSubscription #iOS #IndieDev
```

#### MA-EN-03 · Privacy, stated precisely

*Zielgruppe: Privacy-minded · CTA: Questions welcome · Hashtags: #Privacy #iOS #Transcription #IndieDev · Länge: 372 Zeichen (Limit 500, Link als 23 gezählt)*

```text
Privacy in Sprechly, stated precisely:

– transcription and AI run on the device
– no server of mine, no tracking, no third-party SDKs
– no account

And the part I won't gloss over: iCloud sync is on by default and stores recordings in your own private iCloud. You can switch it off in Settings.

I'm the developer. Ask me anything.

#Privacy #iOS #Transcription #IndieDev
```

#### MA-EN-04 · Re-record from the cursor

*Zielgruppe: Dictation users, podcasters · CTA: App Store · Hashtags: #VoiceRecorder #iPhone #Podcasting #IndieDev · Länge: 329 Zeichen (Limit 500, Link als 23 gezählt)*

```text
Misspoke? In Sprechly you rewind, listen back and re-record from the cursor. The slip gets overwritten and everything before it stays.

The app captures losslessly while you do this, so the seam has no gap.

Recording and editing are free. I'm the developer.

[LINK]

#VoiceRecorder #iPhone #Podcasting #IndieDev
```

#### MA-EN-05 · Free preview

*Zielgruppe: Undecided, subscription-fatigued · CTA: Try it · Hashtags: #Transcription #iOS #NoSubscription · Länge: 335 Zeichen (Limit 500, Link als 23 gezählt)*

```text
Before you pay for transcription you should see the result. With your own voice, not a demo text.

So Sprechly transcribes the first 30 seconds of every recording for free. The preview isn't saved. A single one-time purchase unlocks the full transcript.

I'm the developer.

[LINK]

#Transcription #iOS #NoSubscription
```

#### MA-EN-06 · Tech: timestamps

*Zielgruppe: iOS developers · CTA: Exchange · Hashtags: #iOSDev #SwiftLang #SpeechAnalyzer · Länge: 376 Zeichen (Limit 500, Link als 23 gezählt)*

```text
SpeechAnalyzer note from building Sprechly: don't set bufferStartTime yourself when you feed a file in chunks after a sample-rate conversion.

Rounding makes consecutive buffers overlap and the analyzer throws "timestamp overlaps or precedes prior audio input". Pass the buffers without a start time. The result ranges still come out right.

#iOSDev #SwiftLang #SpeechAnalyzer
```

#### MA-EN-07 · Tech: route changes

*Zielgruppe: iOS developers · CTA: Exchange · Hashtags: #iOSDev #SwiftLang #AVFoundation #IndieDev · Länge: 330 Zeichen (Limit 500, Link als 23 gezählt)*

```text
AVAudioEngine note from building Sprechly: installTap(format: nil) resolves the format once, at install time.

Disconnect a Bluetooth headset mid-recording and the tap keeps 16 kHz while the hardware is at 48 kHz. Resume then fails with -10868. Recreating the engine on resume fixed it.

#iOSDev #SwiftLang #AVFoundation #IndieDev
```

#### MA-EN-08 · Tech: no MP3

*Zielgruppe: Technically curious · CTA: none · Hashtags: #iOSDev #Audio #IndieDev · Länge: 276 Zeichen (Limit 500, Link als 23 gezählt)*

```text
Why Sprechly doesn't export MP3: iOS can play MP3 but can't create it. Asking the system for available encoders returns one for AAC and none for MP3.

I didn't want to add a third-party library for it. The app ships without any. Export is M4A or WAV.

#iOSDev #Audio #IndieDev
```

#### MA-EN-09 · The rating bug

*Zielgruppe: Developers, indie scene · CTA: none · Hashtags: #IndieDev #AppStore #BuildInPublic · Länge: 306 Zeichen (Limit 500, Link als 23 gezählt)*

```text
128 downloads, 0 ratings. The cause was my own code.

Sprechly only asks for a rating at a good moment. Every good moment I had defined came after the purchase. With 4 buyers, about 97% of users could never see the prompt.

A saved recording counts as a good moment now.

#IndieDev #AppStore #BuildInPublic
```

#### MA-EN-10 · Question to everyone

*Zielgruppe: Anyone using speech recognition · CTA: Replies · Hashtags: #Transcription #iOSDev #IndieDev · Länge: 351 Zeichen (Limit 500, Link als 23 gezählt)*

```text
Question for everyone who uses speech recognition: which words go wrong for you again and again?

In Sprechly it's names and technical terms. The recognition is Apple's. I measured whether a list of expected terms helps: with 31 test terms it made no difference.

Examples help with the next test.

I'm the developer.

#Transcription #iOSDev #IndieDev
```

---

## 4. Bluesky

Fünfzehn kurze Beiträge (acht deutsch, sieben englisch), je höchstens 300 Zeichen mit ausgeschriebenem Link, dazu fünf Thread-Konzepte. Aufbau jedes Beitrags: kurzer Einstieg, ein konkreter Nutzen, Entwicklerperspektive. Die Community-Richtlinien von Bluesky verlangen, kommerzielle Inhalte als solche erkennbar zu machen. Deshalb steht die Entwicklerrolle in jedem Beitrag mit Link.

### 4.1 Deutsch

#### BS-DE-01

*Zielgruppe: Apple-Nutzer, Abo-Müde · CTA: App Store · Länge: 272 Zeichen (Limit 300)*

```text
Ich habe ein Diktiergerät fürs iPhone gebaut, das auf dem Gerät transkribiert. Kein Abo, kein Konto.

Aufnahme und Schnitt gratis, 30 Sekunden Transkription je Aufnahme auch. Der Rest: einmal kaufen.

Entwickler: ich. iOS 26 nötig.

[LINK]
```

#### BS-DE-02

*Zielgruppe: Abo-Müde · CTA: App Store · Länge: 236 Zeichen (Limit 300)*

```text
Kein Server, keine Kosten pro Nutzung, kein Abo.

Sprechly transkribiert auf deinem iPhone. Deine Nutzung kostet mich nichts, also zahlst du einmal und nicht jeden Monat.

Ich bin der Entwickler.

[LINK]
```

#### BS-DE-03

*Zielgruppe: Datenschutzbewusste · CTA: keiner · Hashtags: #Datenschutz #IndieDev · Länge: 268 Zeichen (Limit 300)*

```text
„Verarbeitet auf dem Gerät“ heißt nicht „bleibt auf dem Gerät“.

Das habe ich an meiner eigenen App gelernt: Die Transkription rechnet lokal, aber der iCloud-Sync ist ab Werk an. Den falschen Satz habe ich aus der Store-Beschreibung gestrichen.

#Datenschutz #IndieDev
```

#### BS-DE-04

*Zielgruppe: Diktierende · CTA: App Store · Länge: 203 Zeichen (Limit 300)*

```text
Versprecher? Zurückspulen, reinhören, ab dem Cursor neu aufnehmen. Der Versprecher ist weg, der Rest bleibt.

Das kann Sprechly kostenlos. Ich bin der Entwickler.

[LINK]
```

#### BS-DE-05

*Zielgruppe: Studierende · CTA: App Store · Länge: 238 Zeichen (Limit 300)*

```text
Vorlesung aufgenommen, Stelle nicht wiedergefunden?

In Sprechly tippst du im Transkript auf die Zeile und landest an der Stelle im Audio. Vorher fragen, ob Aufnehmen erlaubt ist.

Entwickler: ich.

[LINK]
```

#### BS-DE-06

*Zielgruppe: Meeting-Nutzer · CTA: App Store · Länge: 248 Zeichen (Limit 300)*

```text
Aus 30 Minuten Besprechung werden 5 Zeilen. Transkript und Zusammenfassung entstehen auf dem iPhone.

Für die Zusammenfassung braucht es Apple Intelligence, für das Transkript nicht.

Ich bin der Entwickler.

[LINK]
```

#### BS-DE-07

*Zielgruppe: Entwickler, Indie-Szene · CTA: keiner · Hashtags: #IndieDev #BuildInPublic · Länge: 227 Zeichen (Limit 300)*

```text
128 Downloads, 0 Bewertungen.

Der Grund: Nur Käufer konnten überhaupt nach einer Bewertung gefragt werden. Das waren 4 von 128.

Seit dem Update zählt auch eine gespeicherte Aufnahme als guter Moment.

#IndieDev #BuildInPublic
```

#### BS-DE-08

*Zielgruppe: Alle Nutzer von Spracherkennung · CTA: Antworten · Hashtags: #Transkription #IndieDev · Länge: 217 Zeichen (Limit 300)*

```text
Welche Wörter versteht eure Spracherkennung nie?

Bei meiner App sind es Namen und Fachbegriffe. Eine Begriffsliste hat im Test nichts geändert. Ich sammle Beispiele für den nächsten Versuch.

#Transkription #IndieDev
```

### 4.2 Englisch

#### BS-EN-01

*Zielgruppe: Apple users, subscription-fatigued · CTA: App Store · Länge: 291 Zeichen (Limit 300)*

```text
I built a voice recorder for iPhone that transcribes on the device. No subscription, no account.

Recording and editing are free, and so are 30 seconds of transcription per recording. The rest is a one-time purchase.

I'm the developer. Needs iOS 26.

[LINK]
```

#### BS-EN-02

*Zielgruppe: Subscription-fatigued · CTA: App Store · Länge: 189 Zeichen (Limit 300)*

```text
No server, no cost per use, no subscription.

Sprechly transcribes on your iPhone. Your usage costs me nothing, so you pay once.

I'm the developer.

[LINK]
```

#### BS-EN-03

*Zielgruppe: Privacy-minded · CTA: none · Hashtags: #Privacy #IndieDev · Länge: 239 Zeichen (Limit 300)*

```text
"Processed on the device" is not the same as "stays on the device".

I learned that from my own app: transcription runs locally, but iCloud sync is on by default. I removed the wrong sentence from the store description.

#Privacy #IndieDev
```

#### BS-EN-04

*Zielgruppe: iOS developers · CTA: none · Hashtags: #iOSDev #SwiftLang · Länge: 236 Zeichen (Limit 300)*

```text
SpeechAnalyzer tip: when you feed a file in chunks, don't set bufferStartTime yourself. After a sample-rate conversion the buffers overlap because of rounding and the analyzer throws.

Pass them without a start time.

#iOSDev #SwiftLang
```

#### BS-EN-05

*Zielgruppe: Developers, indie scene · CTA: none · Hashtags: #IndieDev #BuildInPublic · Länge: 181 Zeichen (Limit 300)*

```text
128 downloads, 0 ratings.

The reason: only buyers could ever be asked for a rating. That was 4 out of 128.

A saved recording counts as a good moment now.

#IndieDev #BuildInPublic
```

#### BS-EN-06

*Zielgruppe: Dictation users · CTA: App Store · Länge: 184 Zeichen (Limit 300)*

```text
Misspoke? Rewind, listen back, re-record from the cursor. The slip is gone and the rest stays.

Sprechly does that for free. I'm the developer.

[LINK]
```

#### BS-EN-07

*Zielgruppe: Anyone using speech recognition · CTA: Replies · Hashtags: #Transcription #IndieDev · Länge: 225 Zeichen (Limit 300)*

```text
Which words does your speech recognition never get right?

In my app it's names and technical terms. A list of expected terms changed nothing in my test. I'm collecting examples for the next attempt.

#Transcription #IndieDev
```

### 4.3 Fünf Thread-Konzepte

Ein Konzept beschreibt den Einstieg im Wortlaut und den Inhalt der Folgebeiträge. Die Folgebeiträge schreibt Rene selbst aus. Das Material steht in den genannten Langfassungen.

#### BS-T1 · „Ich musste meine eigene Store-Beschreibung korrigieren“ (DE)

Zielgruppe: Datenschutzbewusste, Entwickler · CTA: Diskussion · Material: LI-DE-3

1. Einstieg, im Wortlaut: „In meiner App-Beschreibung standen zwei falsche Sätze. Beide hatte ich selbst geschrieben. Ein Thread über Werbeaussagen und Code.“
2. Fehler eins: Exportformate, die es in der App nie gab. Der Code kennt zwei Audioformate, die Beschreibung nannte fünf.
3. Fehler zwei: die Aussage, die Stimme bleibe auf dem Gerät. Der iCloud-Sync ist ab Werk an.
4. Der Unterschied zwischen „auf dem Gerät verarbeitet“ und „bleibt auf dem Gerät“.
5. Was jetzt im Store steht: kein Abo, kein Konto, Verarbeitung auf dem Gerät, iCloud-Sync über die private iCloud, abschaltbar.
6. Was ich seitdem mache: jede Aussage in Store-Text und Screenshots gegen den Code prüfen. Entwicklerhinweis und Link.

#### BS-T2 · "Eight things that broke" (EN)

Zielgruppe: iOS-Entwickler · CTA: Erfahrungsaustausch · Material: RD-L3

1. Einstieg, im Wortlaut: "I built a transcription app on SpeechAnalyzer and Foundation Models. Eight things broke on the way. A thread for anyone about to do the same."
2. Bis 9. Je ein Beitrag pro Befund aus RD-L3: Simulator, Zeitstempel, Route-Wechsel, MP3, Kontextfenster, Guardrails, StoreKit-Testing, `.searchable`.
10. Was die Messung ergab: Eine Begriffsliste änderte bei 31 Testbegriffen nichts. Entwicklerhinweis und Link.

#### BS-T3 · "Why my transcription app has no subscription" (EN)

Zielgruppe: Abo-Müde, Indie-Szene · CTA: Meinung · Material: LI-EN-3

1. Einstieg, im Wortlaut: "My transcription app has no subscription, and the reason is arithmetic."
2. Dienste im Rechenzentrum zahlen pro Minute Audio. Ein Abo ist dort folgerichtig.
3. Sprechly rechnet auf dem Gerät. Kein Server, keine Kosten pro Nutzung.
4. Also Einmalkauf. Was gratis ist, was der Kauf freischaltet.
5. Die Kehrseite: keine planbaren Einnahmen, neue Funktionen müssen neue Käufer bezahlen.
6. Frage an die Leser: einmalig mehr oder monatlich wenig? Entwicklerhinweis und Link.

#### BS-T4 · „128 Downloads, 4 Käufe, 0 Bewertungen“ (DE)

Zielgruppe: Indie-Entwickler · CTA: Erfahrungsaustausch · Material: LI-DE-5, RD-L2

1. Einstieg, im Wortlaut: „Meine App nach zwei Monaten im Store: 128 Downloads, 4 Käufe, 0 Bewertungen. Was ich falsch gemacht habe, in fünf Beiträgen.“
2. Die Zahlen im Trichter: 9.340 Impressionen, 209 Seitenaufrufe, 128 Downloads, 4 Käufe.
3. Fehler eins: die Bewertungsfrage hinter dem Kauf.
4. Fehler zwei: Transkription ohne Vorschau hinter der Bezahlschranke.
5. Was ich geändert habe: 30 Sekunden gratis, Kaufbildschirm mit eigenem Ergebnis, Bewertungsfrage auch für Gratisnutzer.
6. Stand heute: Conversion besser, Sichtbarkeit schlechter, Zahlen folgen nach 28 Tagen. Entwicklerhinweis und Link.

#### BS-T5 · „Vom Gespräch zum Protokoll in vier Schritten“ (DE)

Zielgruppe: Meeting-Nutzer, Selbstständige · CTA: App Store · Material: P04-L

1. Einstieg, im Wortlaut: „Vom Gespräch zum Protokoll in vier Schritten, ohne dass die Aufnahme zu einem Transkriptionsdienst geht. Ein Thread vom Entwickler.“
2. Schritt eins: Einverständnis einholen, aufnehmen. Die Aufnahme läuft auch bei gesperrtem Bildschirm weiter. Bild: `04-record`.
3. Schritt zwei: transkribieren, auf dem Gerät. Bild: `01-transcript`.
4. Schritt drei: Stil „Protokoll“ wählen. Hinweis auf Apple Intelligence. Bild: `02-summary`.
5. Schritt vier: als Markdown exportieren und ablegen. Bild: `05-edit`.
6. Was es kostet und was nicht geht (keine Sprecher-Zuordnung). Entwicklerhinweis und Link.

---

## 5. Hacker News

**Einschätzung: bedingt geeignet.** Die Regeln für „Show HN“ wurden direkt gelesen. Eine iOS-App erfüllt sie („things people can run on their computers or hold in their hands“), und Sprechly lässt sich ohne Anmeldung ausprobieren. Dafür spricht außerdem eine neue Apple-API, die dort wenige produktiv benutzt haben. Dagegen: Die App ist kommerziell, ihr Quellcode nicht öffentlich, und sie setzt iOS 26 voraus. Die Kategorie ist dicht besetzt, Vergleiche mit Whisper sind zu erwarten, und dafür gibt es keine eigenen Messwerte. Der stärkste Aufhänger ist die eigene Messung zu `contextualStrings` mit ihrem Nullergebnis.

Empfehlung: einmal posten, an einem Tag, an dem Rene mehrere Stunden antworten kann. Sonst lassen.

**Regeln, die den Beitrag bestimmen** (news.ycombinator.com/showhn.html und /newsguidelines.html, gelesen am 2026-10-04):

- Generierter oder KI-bearbeiteter Text ist in Beiträgen und Kommentaren nicht erlaubt. **Deshalb steht hier kein fertiger Text.** Rene schreibt Beitrag und Antworten selbst.
- Der Link führt auf etwas, das man ausprobieren kann, also auf die App-Store-Seite. Landingpages sind unerwünscht.
- Niemanden um Upvotes oder Kommentare bitten, auch keine Freunde.
- Neue Versionen („Foo 1.3.1 is out“) sind kein Show HN. Thema ist die App, nicht das Update.
- Titel beginnt mit „Show HN“, ohne Großschreibung zur Betonung und ohne Ausrufezeichen.

### HN-1 · Faktengliederung für den eigenen Text

Titelvorschlag (Rene formuliert selbst, dies zeigt nur Länge und Ton):

*Länge: 70 Zeichen (Limit 80)*

```text
Show HN: Sprechly – iPhone voice recorder with on-device transcription
```

Gliederung für den ersten Kommentar, in der Reihenfolge des Auftrags:

| Abschnitt | Fakten, aus denen Rene formuliert |
|---|---|
| Was ist Sprechly | Diktiergerät für iPhone und iPad. Transkribiert auf dem Gerät mit `SpeechAnalyzer`/`SpeechTranscriber` (iOS 26). Zusammenfassungen und Übersetzung über Foundation Models. Schnitt, Zusammenführen, Mix, Export M4A/WAV und TXT/Markdown. |
| Warum gebaut | ‹Der persönliche Anlass. Nur Rene kennt ihn. Nichts erfinden.› |
| Technische Besonderheit | Swift 6 mit strict concurrency, SwiftData mit CloudKit, StoreKit 2, null Drittpakete. Zwei getrennte Pipelines für Live- und Datei-Transkription. Lange Transkripte werden für das kleine Kontextfenster in Abschnitte von höchstens 800 Zeichen zerlegt und rekursiv verdichtet. |
| Datenschutz, lokale Verarbeitung | Erkennung und KI rechnen auf dem Gerät. Kein eigener Server, keine Analyse, keine SDKs. iCloud-Sync ist standardmäßig an und nutzt die private iCloud des Nutzers. Abschaltbar. Genau so sagen, nicht verkürzen. |
| Kein Abo | Kein Server, also keine Kosten pro Nutzung, also Einmalkauf. Download gratis, Aufnahme und Schnitt gratis, 30 Sekunden Transkription je Aufnahme gratis. |
| Was ich gelernt habe | Die Befunde aus RD-L3: Simulator, Zeitstempel-Überlappung, -10868 bei Route-Wechsel, kein MP3-Encoder, Guardrails bei Übersetzung. Dazu der eigene Fehler in der Store-Beschreibung. |
| Eigene Messung | `AnalysisContext.contextualStrings` am 2026-10-04 gemessen: 15 deutsche Sätze (synthetische Sprache), 31 Zielbegriffe, 13 erkannt mit und ohne Kontext, Transkripte zeichengleich, Kontext kam nachweislich an, auch 104 Begriffe ohne Wirkung. Vergleich mit `DictationTranscriber`: gleich viele Zielbegriffe, höhere Wortfehlerrate, gut doppelte Laufzeit, bessere Formatierung. Quellen: `docs/TRANSCRIPTION_CONTEXT_BENCHMARK.md`, `docs/TRANSCRIBER_COMPARISON.md` |
| Feedbackfrage | Hat jemand `contextualStrings` in einer anderen Sprache oder mit einem anderen Preset wirken sehen? |

Offen ansprechen, bevor jemand fragt: Quellcode nicht öffentlich, iOS 26 Pflicht, KI-Funktionen nur mit Apple Intelligence, keine Sprecher-Zuordnung, kein Vergleich mit Whisper gemessen.

---

## 6. Indie Hackers

**Regelstand:** Eine offizielle Richtlinienseite war am 2026-10-04 nicht abrufbar. Aus zweiter Hand: neue Konten können nicht sofort Beiträge mit Links veröffentlichen, erst einige sachliche Kommentare schreiben. Vor dem ersten Beitrag prüfen.

Alle Zahlen stammen aus `docs/ROADMAP.md`. Umsatz nach dem 18.08.2026 steht nicht im Repo und kommt deshalb nicht vor.

#### IH-1 · Launch post

*Zielgruppe: Indie Hacker · CTA: App Store + Feedback · Länge: 1500 Zeichen*

```text
**Sprechly: a voice recorder that transcribes on the device. Free download, a single one-time purchase.**

I'm Rene, a solo developer from Germany, and this is my app.

**What it is.** A voice recorder for iPhone and iPad. It records, transcribes on the device with Apple's speech framework, and can turn the transcript into a summary, meeting minutes or bullet points with Apple's on-device model. You can cut, merge and mix recordings and export M4A, WAV, TXT or Markdown.

**Who it is for.** People who record meetings, interviews, lectures or their own thoughts and want the text, without paying monthly and without creating an account.

**How it makes money.** The download is free. Recording, editing and audio export are free without limits. The first 30 seconds of each recording are transcribed for free. One non-consumable purchase unlocks full transcripts, the live transcript, transcript export and the AI features.

**Why no subscription.** I run no server, so I have no cost per use.

**What it doesn't do.** No speaker labels, no MP3 export, no Android version. It needs iOS 26, and the AI features need a device with Apple Intelligence. iCloud sync is on by default and uses your own private iCloud. You can turn it off.

**Where it stands.** In its first two months: 128 downloads, 4 purchases, 17 USD in proceeds. I'll write about what I changed after that in a separate post.

[LINK]

What would you want to know before paying for an app like this?
```

#### IH-2 · Building in public

Nur verwenden, wenn der Preis mit 1.1.1 tatsächlich angehoben wurde.

*Zielgruppe: Indie Hacker · CTA: Kritik am Messplan · Länge: 1443 Zeichen*

```text
**I changed my price and my store page at the same time. Here is how I plan to measure it anyway.**

I'm the developer of Sprechly, an on-device transcription recorder for iPhone and iPad.

Version 1.1.1 changed two things at once: the store presence (name, subtitle, keywords, description, six new screenshots) and the price of the one-time purchase, from 6.99 EUR to 9.99 EUR.

That is a bad experiment and I know it. I can't separate the effect of the price from the effect of the page. I decided to do it anyway, because my goal isn't a clean price test. I want a new baseline.

**The plan**

- Compare 28 days before the release with 28 days after it.
- The "before" window has to lie entirely after the previous update, because that update changed conversion.
- Sources are App Store Connect only. The app contains no analytics, and that won't change.

**What I track**

- Impressions and product page views
- Downloads
- Purchases, and conversion from download to purchase
- Revenue per download, which is the number I care about
- Number of ratings and their average

**What counts as success**

Fewer purchases with higher revenue per download is a success. More downloads with lower revenue per download isn't.

**The starting point**

From launch to mid-August: 9,340 impressions, 209 page views, 128 downloads, 4 purchases, 0 ratings.

I'll post the result after the 28 days, whichever way it goes.

Where is the flaw in this plan?
```

#### IH-3 · Pricing learning

*Zielgruppe: Indie Hacker · CTA: Erfahrungen mit Vorschau statt Trial · Länge: 1505 Zeichen*

```text
**A hard paywall got me 4 sales from 128 downloads. A 30-second preview changed that.**

I'm the developer of Sprechly, a voice recorder with on-device transcription.

**The problem.** Transcription was purchase-only. To find out whether it understood your voice, you had to pay first. The paywall listed features.

**What I had tried before.** A classic trial ("first transcription free") was my first idea, and I had built it during development. On my own test device it felt wrong: the app gave the feature away once and then took it back. I removed it before launch.

**What I built.** The first 30 seconds of every recording can be transcribed without the purchase. Three rules make it a preview and not a loophole:

1. The preview is never saved. Close the screen and it is gone.
2. It can't be exported, translated or summarized.
3. The app stops the transcription after 30 seconds. It doesn't process the whole file and hide the rest.

**The paywall changed with it.** If you arrive from a preview, the purchase screen shows your own words. If you arrive from somewhere else, it shows an example that is labelled as an example.

**The result so far.** Conversion is noticeably better. I don't have a clean before-and-after number yet and won't invent one.

**My takeaway so far.** Let people decide with their own material, and never hand over something you then take back.

Has anyone tried the opposite, a time-limited full trial for a one-time purchase?

[LINK]
```

#### IH-4 · ASO learning

Der Satz zur Preisänderung gilt nur, wenn der Preis mit 1.1.1 tatsächlich angehoben wurde.

*Zielgruppe: Indie Hacker, App-Entwickler · CTA: ASO-Erfahrungen · Länge: 1855 Zeichen*

```text
**Only 2.2% of my App Store impressions became page views. What I changed, and what I can't tell you yet.**

I'm the developer of Sprechly, an on-device transcription recorder for iPhone and iPad.

From launch to mid-August the App Store showed my app 9,340 times. The product page was opened 209 times. I had been working on features. The numbers said the problem sat one step earlier.

**What I changed in the listing**

1. **Name and subtitle.** They now say what the app is and what makes it different: a voice recorder with AI, transcription that works offline, no subscription.
2. **The first third of the description.** One-time purchase, no account and on-device processing used to appear in the fourth paragraph. They are at the top now.
3. **Screenshot order.** The transcript leads. The recorder is fourth. Most people only ever see the first one or two screenshots, and a recorder looks like every other recorder.
4. **Headlines on the screenshots.** Each one makes a single claim, and each claim is checked against the code. One caption says "no account" and not "nothing leaves the device", because iCloud sync is on by default.
5. **Two false claims removed.** The old description listed export formats that don't exist in the app.
6. **A script that validates the character limits** of every metadata field before I paste anything into App Store Connect.

**What I can't tell you yet**

Whether it worked. The new listing went live together with a price change, and I'll compare 28 days before and after. I'll report the numbers when I have them.

**What I took from it**

Look at the listing before the feature list. My roadmap now says it in one line: the bottleneck is being found and being understood. Missing features aren't the problem.

What moved your impression-to-page-view rate the most?

[LINK]
```

#### IH-5 · Technical learnings from SpeechAnalyzer

*Zielgruppe: Indie Hacker mit technischem Hintergrund, iOS-Entwickler · CTA: Messergebnisse anderer · Länge: 2428 Zeichen*

```text
**I measured before building a feature. The measurement killed it.**

I'm the developer of Sprechly. It transcribes on the device with Apple's SpeechAnalyzer.

**The starting point.** I went through the transcriber's options looking for a quality setting. There is none. The options control how results are reported. Recognition quality comes entirely from Apple's model.

**The one lever.** You can give the analyzer a list of expected terms (`AnalysisContext.contextualStrings`). That targets exactly the weak spots I see: names and technical terms. The obvious feature was a personal vocabulary. The SDK doesn't promise that the transcriber uses the list, so I measured first.

**The setup.**

1. A corpus of 15 German sentences with 31 target terms in five categories: names, technical terms, abbreviations, numbers, and mixtures.
2. The audio comes from the system speech synthesizer on the device, so the input is identical on every run and no audio file sits in the repository.
3. Each sentence is transcribed twice, once without context and once with the target terms plus decoy terms that are never spoken.
4. The score is how many target terms come out right.

**The result.** 13 of 31 terms in both runs. The transcripts were identical character for character. Lists of 14, 54 and 104 terms changed nothing, neither the result nor the runtime.

**The check on the check.** A null result this clean can also mean the context never arrived. A separate test on the device showed that the analyzer had taken the strings, through the initializer and through `setContext`.

**The decision.** No personal vocabulary on this path. The screen would promise something the system doesn't deliver.

**What the measurement can't say.** Synthetic speech is clean. It has no room echo, no dialect and no crosstalk. The numbers say nothing about a real meeting. They only compare two variants on identical input. And it is one configuration: German, file transcription, iOS 27.0.1.

**What came out of it anyway.** Many misses were formatting errors: `13.45` for `13:45`, `1. 2.0` for `1.2.0`, `Store Kit` for `StoreKit`. Those could be fixed after recognition, in my own code. That is a candidate for the next step.

SpeechAnalyzer doesn't run in the Simulator, so the whole suite runs on a physical iPhone.

Has anyone seen contextual strings change a transcription result, in any language?

[LINK]
```

---

## 7. Apple- und iPhone-Foren

**Regelstand (direkt gelesen am 2026-10-04):** MacRumors erlaubt Entwicklern einen Thread je App im Forum „iOS Apps and Apple Arcade“, wenn sie sich als Entwickler zu erkennen geben und das Profil ausgefüllt ist. macuser.de erlaubt die Vorstellung der eigenen App im Bereich „App Review, Promotion“ mit App-Store-Link, ohne Ref-Links und ohne eigene Website. Das Sir-Apfelot-Forum lädt Entwickler ausdrücklich ein und gibt einen Fragenkatalog vor. Apfeltalk erlaubt es nur im Bereich „App-Promotion“ und erst nach drei Monaten Mitgliedschaft, 50 Beiträgen und 5 Zustimmungen. MacTechNews, iszene.com, die Apple Support Communities und die Apple Developer Forums verbieten es.

In Foren mit Verbot von Referrer-Links steht der einfache Link ohne Kampagnenparameter.

#### FO-DE-1 · macuser.de, Bereich „App Review, Promotion“ (auch Apfeltalk, falls die Hürde erfüllt ist)

*Zielgruppe: Deutschsprachige Apple-Nutzer · CTA: App Store + Rückmeldung · Länge: 2163 Zeichen*

```text
Sprechly – Diktiergerät mit Transkription auf dem Gerät (Vorstellung durch den Entwickler)

Hallo zusammen,

ich bin Rene, der Entwickler von Sprechly, und stelle die App hier selbst vor.

Das Problem
Wer Besprechungen, Interviews oder Vorlesungen aufnimmt, will am Ende den Text. Nicht jeder will dafür ein weiteres Abo abschließen und ein Konto anlegen. Und nicht jeder möchte die Aufnahme zur Verarbeitung an einen Dienst schicken.

Die Lösung
Sprechly nimmt auf und transkribiert direkt auf dem iPhone oder iPad. Die Spracherkennung kommt von Apple (SpeechAnalyzer, seit iOS 26). Aus dem Transkript erzeugt die App auf Wunsch eine Zusammenfassung, ein Protokoll oder Stichpunkte und übersetzt es. Dazu kommen Schnitt, automatisches Entfernen von Stille, Zusammenführen und Mischen von Aufnahmen. Export: Audio als M4A oder WAV, Transkript als TXT oder Markdown.

Die Abgrenzung
- Kein Abo, kein Konto, keine Werbung, kein Tracking.
- Ich betreibe keinen Server. Transkription und KI laufen auf dem Gerät.
- Zurückspulen und ab dem Cursor neu aufnehmen, um Versprecher zu überschreiben.
- Wer nur gelegentlich ein Memo aufnimmt, kommt mit der Sprachmemos-App von Apple gut aus. Sprechly ist für alle gedacht, die mit dem Text weiterarbeiten wollen.

Was die App nicht kann
- Keine Sprecher-Zuordnung, kein MP3-Export.
- iOS oder iPadOS 26 ist Voraussetzung.
- Zusammenfassung und Übersetzung brauchen ein Gerät mit Apple Intelligence. Aufnahme, Schnitt und Transkription nicht.
- Der iCloud-Sync ist ab Werk eingeschaltet und legt Aufnahmen in eurer privaten iCloud ab. Er lässt sich in den Einstellungen abschalten.

Der Preis
Der Download ist kostenlos. Aufnehmen, Bearbeiten, Mischen und Audio-Export sind unbegrenzt gratis. Von jeder Aufnahme lassen sich die ersten 30 Sekunden kostenlos transkribieren. Vollständige Transkripte, Live-Transkript, Transkript-Export und die KI-Funktionen schaltet ein einmaliger Kauf für [PREIS] frei.

Der Link
[LINK]

Fragen beantworte ich hier im Thread. Besonders interessiert mich, wie gut die Erkennung bei euch mit Dialekt, Eigennamen und Fachbegriffen zurechtkommt.

Viele Grüße
Rene
```

#### FO-DE-2 · Sir-Apfelot-Forum, Thread „Stelle deine App der Community vor“

Der Fragenkatalog dort ist Pflicht. Die Überschriften unten folgen den Punkten, die bei der Recherche genannt wurden. Vor dem Posten mit dem Original abgleichen.

*Zielgruppe: Deutschsprachige Apple-Nutzer · CTA: App Store + Rückmeldung · Länge: 1368 Zeichen*

```text
Name der App
Sprechly. Ich bin der Entwickler und arbeite allein daran.

Preis
Der Download ist kostenlos. Ein einmaliger In-App-Kauf für [PREIS] schaltet die Transkription in voller Länge und die KI-Funktionen frei.

Geräte
iPhone und iPad ab iOS bzw. iPadOS 26. Die KI-Funktionen brauchen ein Gerät mit Apple Intelligence.

Welches Problem löst die App?
Sie macht aus einer Aufnahme einen Text, ohne Abo und ohne Konto. Aufnehmen, auf dem Gerät transkribieren, zusammenfassen, exportieren.

Für wen ist sie gedacht?
Für alle, die Besprechungen, Interviews, Vorlesungen oder eigene Gedanken aufnehmen und danach mit dem Text arbeiten.

Was unterscheidet sie von anderen?
Spracherkennung und KI laufen auf dem Gerät, ich betreibe keinen Server. Versprecher lassen sich überschreiben: zurückspulen und ab dem Cursor neu aufnehmen. Schnitt, Zusammenführen und Mix sind eingebaut. Der Export kennt M4A, WAV, TXT und Markdown.

Wie ist das Preismodell?
Kein Abo. Aufnahme, Schnitt, Mix und Audio-Export sind unbegrenzt kostenlos. Die ersten 30 Sekunden jeder Aufnahme lassen sich gratis transkribieren. Alles Weitere deckt der einmalige Kauf ab.

Was sollte man vorher wissen?
Es gibt keine Sprecher-Zuordnung und keinen MP3-Export. Der iCloud-Sync ist ab Werk an und nutzt die eigene private iCloud. Er lässt sich abschalten.

Link
[LINK]
```

#### FO-EN-1 · MacRumors, Forum „iOS Apps and Apple Arcade“

*Zielgruppe: Englischsprachige Apple-Nutzer · CTA: App Store + Rückmeldung · Länge: 1861 Zeichen*

```text
Sprechly – voice recorder with on-device transcription (posted by the developer)

Hi all,

I'm Rene, the developer of Sprechly, and I'm introducing the app myself.

The problem
If you record meetings, interviews or lectures, you want the text afterwards. Not everyone wants another subscription and another account for that, or wants to send the recording to a service for processing.

What Sprechly does
It records and transcribes on the iPhone or iPad, using the SpeechAnalyzer framework Apple introduced with iOS 26. It can turn the transcript into a summary, meeting minutes or bullet points, and translate it. It also trims, cuts, removes silence, merges and mixes recordings. Audio exports as M4A or WAV, transcripts as TXT or Markdown.

How it differs
- No subscription, no account, no ads, no tracking.
- I don't run a server. Transcription and AI run on the device.
- You can rewind and re-record from the cursor to overwrite a slip of the tongue.
- If you only record the occasional memo, Apple's Voice Memos will do. Sprechly is for people who keep working with the text.

What it doesn't do
- No speaker labels and no MP3 export.
- It requires iOS or iPadOS 26.
- Summaries and translation need a device with Apple Intelligence. Recording, editing and transcription don't.
- iCloud sync is on by default and stores recordings in your own private iCloud. You can switch it off in Settings.

Price
The download is free. Recording, editing, mixing and audio export are free without limits. The first 30 seconds of any recording are transcribed for free. A single one-time purchase unlocks full transcripts, the live transcript, transcript export and the AI features.

Link
[LINK]

I'll answer questions in this thread. I'd especially like to hear how the recognition copes with accents, names and technical terms.

Rene
```

---

## 8. Content-Säulen

Fünfzehn Säulen. Jede hat einen Hook, eine Kernbotschaft, einen CTA, drei Kurzposts und einen längeren Post. Die Kurzposts bleiben unter 300 Zeichen und passen damit auf Bluesky und Mastodon. Auf Mastodon kommen drei bis fünf Hashtags dazu. Die längeren Posts sind für LinkedIn, Foren oder einen Mastodon-Thread gedacht. Sprache: Deutsch, der Hauptmarkt der App.

Ein Beitrag mit Link nennt die Entwicklerrolle. Beiträge ohne Link sprechen von „meiner App“.

### P01 · Kein Abo

- **Hook:** Diese App kündigst du nie. Es gibt nichts zu kündigen.
- **Kernbotschaft:** Sprechly bezahlst du einmal. Das geht, weil kein Server mitläuft.
- **CTA:** Im App Store ansehen.

**P01-K1**

*Zielgruppe: Abo-Müde · CTA: App Store · Länge: 182 Zeichen (Limit 300)*

```text
Sprechly bezahlst du einmal und danach nie wieder. Kein Abo, kein Konto, keine Verlängerung, an die du denken musst.

Ich bin der Entwickler.

[LINK]
```

**P01-K2**

*Zielgruppe: Abo-Müde · CTA: keiner · Länge: 178 Zeichen (Limit 300)*

```text
Dauerhaft gratis in meiner App: aufnehmen, schneiden, zusammenführen, mischen, Audio exportieren.

Einmalig zu kaufen: vollständige Transkripte und KI.

Nicht vorhanden: ein Abo.
```

**P01-K3**

*Zielgruppe: Abo-Müde · CTA: keiner · Länge: 171 Zeichen (Limit 300)*

```text
Ein Abo braucht ein Anbieter, der Kosten pro Nutzung hat. Ich habe keine. Meine App transkribiert auf deinem iPhone und nicht in einem Rechenzentrum.

Also: einmal kaufen.
```

**P01-L**

*Zielgruppe: Abo-Müde, Selbstständige · CTA: App Store · Länge: 819 Zeichen*

```text
Diese App kündigst du nie. Es gibt nichts zu kündigen.

Sprechly ist ein Diktiergerät mit Transkription für iPhone und iPad. Ich verkaufe es als Einmalkauf, und der Grund ist schlicht: Bei mir läuft kein Server. Die Spracherkennung rechnet auf deinem Gerät. Ob du zehn Minuten transkribierst oder zehn Stunden, mir entstehen keine Kosten.

So sieht das aus:
– Der Download ist kostenlos.
– Aufnehmen, Schneiden, Mischen und Audio-Export bleiben unbegrenzt gratis.
– Die ersten 30 Sekunden jeder Aufnahme transkribiert die App kostenlos.
– Ein einmaliger Kauf schaltet vollständige Transkripte und die KI-Funktionen frei.

Ein Konto brauchst du nicht. Wechselst du das iPhone, stellst du den Kauf über deine Apple-ID wieder her.

Ich bin der Entwickler. iOS 26 ist Voraussetzung.

[LINK]
```

### P02 · Lokale Verarbeitung

- **Hook:** Deine Aufnahme wird dort zu Text, wo sie entstanden ist.
- **Kernbotschaft:** Spracherkennung und KI rechnen auf dem Gerät. Ich betreibe keinen Server.
- **CTA:** Im Flugmodus ausprobieren.

**P02-K1**

*Zielgruppe: Datenschutzbewusste · CTA: keiner · Länge: 172 Zeichen (Limit 300)*

```text
Deine Aufnahme wird dort zu Text, wo sie entstanden ist: auf deinem iPhone.

Meine App schickt nichts an mich. Ich habe gar keinen Server, an den sie etwas schicken könnte.
```

**P02-K2**

*Zielgruppe: Datenschutzbewusste · CTA: Ausprobieren · Länge: 196 Zeichen (Limit 300)*

```text
Test für meine App: Sprachmodell laden, Flugmodus an, transkribieren.

Es funktioniert. Die Spracherkennung rechnet auf dem Gerät.

Ich bin der Entwickler.

[LINK]
```

**P02-K3**

*Zielgruppe: Datenschutzbewusste · CTA: keiner · Länge: 166 Zeichen (Limit 300)*

```text
Was in meiner App nicht steckt: Analyse-Software, Werbenetzwerke, Bibliotheken von Dritten.

Was drinsteckt: Frameworks von Apple und mein eigener Code. Sonst nichts.
```

**P02-L**

*Zielgruppe: Datenschutzbewusste Apple-Nutzer · CTA: Ausprobieren · Länge: 943 Zeichen*

```text
Deine Aufnahme wird dort zu Text, wo sie entstanden ist.

Sprechly transkribiert auf dem iPhone oder iPad. Die Spracherkennung liefert Apple mit dem Betriebssystem. Das Sprachmodell lädst du einmal herunter, danach arbeitet es ohne Netz. Zusammenfassungen und Übersetzungen erzeugt das Sprachmodell von Apple, ebenfalls auf dem Gerät.

Ich betreibe keinen Server. Die App enthält keine Analyse-Software, keine Werbung und keine Bibliothek von Dritten. Ein Konto gibt es nicht.

Damit das Bild vollständig ist: Der iCloud-Sync ist ab Werk eingeschaltet. Er legt Aufnahmen und Transkripte in deiner eigenen privaten iCloud ab, damit sie auf deinen anderen Geräten erscheinen. Ich habe darauf keinen Zugriff. Wer das nicht will, schaltet den Sync in den Einstellungen ab.

Prüfen kannst du die lokale Verarbeitung selbst: Sprachmodell laden, Flugmodus einschalten, transkribieren.

Ich bin der Entwickler.

[LINK]
```

### P03 · Transkription auf iPhone und iPad

- **Hook:** Sprich. Sprechly schreibt mit.
- **Kernbotschaft:** Aufnehmen und Text bekommen, auf dem Gerät, das du ohnehin dabeihast.
- **CTA:** 30 Sekunden gratis testen.

**P03-K1**

*Zielgruppe: iPhone- und iPad-Nutzer · CTA: Ausprobieren · Länge: 184 Zeichen (Limit 300)*

```text
Sprich. Sprechly schreibt mit.

Die App transkribiert auf dem iPhone. 30 Sekunden je Aufnahme kannst du gratis testen.

Ich bin der Entwickler.

[LINK]
```

**P03-K2**

*Zielgruppe: iPhone- und iPad-Nutzer · CTA: keiner · Länge: 132 Zeichen (Limit 300)*

```text
Im Transkript auf eine Zeile tippen, und die Aufnahme springt an genau diese Stelle.

Nachhören, ohne zu spulen. Das kann meine App.
```

**P03-K3**

*Zielgruppe: iPad-Nutzer · CTA: keiner · Länge: 182 Zeichen (Limit 300)*

```text
Auf dem iPad nutzt meine App die Breite: Seitenleiste, Liste der Aufnahmen und die geöffnete Aufnahme stehen nebeneinander.

Für alle, die am iPad arbeiten und nicht nur konsumieren.
```

**P03-L**

*Zielgruppe: Menschen, die auf iPhone und iPad arbeiten · CTA: 30 Sekunden gratis testen · Länge: 848 Zeichen*

```text
Sprich. Sprechly schreibt mit.

So läuft es ab: Du nimmst auf. Die Aufnahme läuft weiter, wenn du die App verlässt oder den Bildschirm sperrst. Danach tippst du auf „Transkript“, und das iPhone macht aus dem Audio einen Text mit Zeitmarken. Wer mag, schaltet das Live-Transkript ein und sieht den Text schon während der Aufnahme.

Im fertigen Transkript tippst du auf eine Zeile und landest an der Stelle im Audio. Du liest es als Fließtext oder in Abschnitten mit Zeitmarken.

Auf dem iPad stehen die Liste der Aufnahmen und die geöffnete Aufnahme nebeneinander.

Ausprobieren kostet nichts: Die ersten 30 Sekunden jeder Aufnahme transkribiert die App gratis. Vollständige Transkripte und das Live-Transkript schaltet ein einmaliger Kauf frei.

Voraussetzung ist iOS oder iPadOS 26. Ich bin der Entwickler.

[LINK]
```

### P04 · Meetings

- **Hook:** Aus 30 Minuten werden 5 Zeilen.
- **Kernbotschaft:** Aufnahme, Transkript und Protokoll entstehen auf einem Gerät.
- **CTA:** Bei der nächsten Besprechung ausprobieren, mit Einverständnis der Runde.

**P04-K1**

*Zielgruppe: Meeting-Nutzer · CTA: keiner · Länge: 164 Zeichen (Limit 300)*

```text
Aus 30 Minuten werden 5 Zeilen.

Meine App schreibt aus dem Transkript einer Besprechung ein Protokoll. Was besprochen wurde, was entschieden ist, was offen bleibt.
```

**P04-K2**

*Zielgruppe: Meeting-Nutzer · CTA: keiner · Länge: 171 Zeichen (Limit 300)*

```text
Bevor du eine Besprechung aufnimmst: fragen. Ohne Einverständnis der Runde geht es nicht.

Danach macht meine App den Rest: aufnehmen, transkribieren, Protokoll schreiben.
```

**P04-K3**

*Zielgruppe: Selbstständige, kleine Unternehmen · CTA: App Store · Länge: 181 Zeichen (Limit 300)*

```text
Kundengespräch aufgenommen, Protokoll als Markdown exportiert, in die Projektnotizen gelegt.

Das geht mit Sprechly. Ich bin der Entwickler.

[LINK]
```

**P04-L**

*Zielgruppe: Meeting-Nutzer, Selbstständige, kleine Unternehmen · CTA: App Store · Länge: 972 Zeichen*

```text
Aus 30 Minuten werden 5 Zeilen. Vom Gespräch zum Protokoll in vier Schritten:

1. Fragen und aufnehmen. Hol das Einverständnis der Runde ein. Dann starte die Aufnahme. Sie läuft weiter, wenn du das iPhone sperrst, und zeigt die Laufzeit auf dem Sperrbildschirm.

2. Transkribieren. Das iPhone macht aus der Aufnahme einen Text mit Zeitmarken. Das passiert auf dem Gerät.

3. Protokoll schreiben lassen. Wähle den Stil „Protokoll“. Die App gliedert das Gespräch, zum Beispiel in Themen, Entscheidungen und offene Punkte. Wer es knapper mag, nimmt „Stichpunkte“ oder „Kernaussagen“.

4. Exportieren. Als Markdown oder Text, über das Teilen-Menü dorthin, wo deine Notizen liegen.

Zwei Dinge solltest du wissen. Das Protokoll schreibt das Sprachmodell von Apple, dafür braucht es ein Gerät mit Apple Intelligence. Und die App unterscheidet keine Sprecher: Wer was gesagt hat, steht nicht im Text.

Ich bin der Entwickler von Sprechly.

[LINK]
```

### P05 · Interviews

- **Hook:** Das Zitat steht bei Minute 14. Du musst es nicht mehr suchen.
- **Kernbotschaft:** Transkript mit Zeitmarken, jede Zeile führt zurück ins Audio.
- **CTA:** Mit einer eigenen Aufnahme testen.

**P05-K1**

*Zielgruppe: Journalisten, Interviewer · CTA: keiner · Länge: 174 Zeichen (Limit 300)*

```text
Das Zitat steht bei Minute 14. Du musst es nicht mehr suchen.

In meiner App tippst du im Transkript auf den Satz und hörst ihn im Original. Zum Gegenprüfen vor dem Zitieren.
```

**P05-K2**

*Zielgruppe: Journalisten, Interviewer · CTA: keiner · Länge: 160 Zeichen (Limit 300)*

```text
Vorab für alle, die Interviews transkribieren: Meine App unterscheidet keine Sprecher. Frage und Antwort stehen im selben Text.

Zeitmarken hat jeder Abschnitt.
```

**P05-K3**

*Zielgruppe: Journalisten, Interviewer · CTA: App Store · Länge: 204 Zeichen (Limit 300)*

```text
Interview im Café aufgenommen und keine Lust, die Datei bei einem Transkriptionsdienst hochzuladen?

Sprechly transkribiert auf dem iPhone. Ich bin der Entwickler.

[LINK]
```

**P05-L**

*Zielgruppe: Journalisten, Interviewer, Forschende · CTA: Mit eigener Aufnahme testen · Länge: 1053 Zeichen*

```text
Das Zitat steht bei Minute 14. Du musst es nicht mehr suchen.

Wer Interviews führt, kennt die Arbeit danach: abhören, tippen, zurückspulen, noch einmal abhören. Sprechly nimmt dir den ersten Durchgang ab.

Die App nimmt das Gespräch auf und transkribiert es auf dem iPhone oder iPad. Jeder Abschnitt trägt eine Zeitmarke. Tippst du auf einen Satz, springt die Aufnahme dorthin. So prüfst du ein Zitat am Original, bevor du es verwendest.

Vorhandene Aufnahmen aus einem anderen Rekorder importierst du über die Dateien-App. Das Transkript exportierst du als Text oder Markdown, mit Zeitmarken.

Was die App nicht leistet: Sie unterscheidet keine Sprecher. Und Eigennamen und Fachbegriffe sind die Stellen, an denen die Erkennung am ehesten danebenliegt. Gegenlesen bleibt nötig.

Selbstverständlich, aber wichtig: nur mit Einverständnis aufnehmen.

Ob die Erkennung für deine Gespräche reicht, zeigen die ersten 30 Sekunden jeder Aufnahme. Die transkribiert die App gratis.

Ich bin der Entwickler von Sprechly.

[LINK]
```

### P06 · Studium und Vorlesung

- **Hook:** Die Erklärung aus Woche 3, wiedergefunden ohne neunzig Minuten Abhören.
- **Kernbotschaft:** Aufnahme plus Transkript macht eine Vorlesung nachschlagbar.
- **CTA:** Vorher fragen, dann ausprobieren.

**P06-K1**

*Zielgruppe: Studierende · CTA: keiner · Länge: 143 Zeichen (Limit 300)*

```text
Eine Vorlesung aufzunehmen ist leicht. Die eine Erklärung darin wiederzufinden nicht.

Mit einem Transkript, das zurück ins Audio führt, schon.
```

**P06-K2**

*Zielgruppe: Studierende · CTA: keiner · Länge: 178 Zeichen (Limit 300)*

```text
Für Studierende mit wenig Geld: In meiner App sind Aufnahme, Schnitt und Audio-Export kostenlos und unbegrenzt.

Bezahlt wird nur für das vollständige Transkript, und das einmal.
```

**P06-K3**

*Zielgruppe: Studierende · CTA: keiner · Länge: 147 Zeichen (Limit 300)*

```text
Vorlesung mitschneiden? Erst fragen. Ob das erlaubt ist, entscheidet die Lehrperson oder die Hochschule.

Die Technik ist danach der einfache Teil.
```

**P06-L**

*Zielgruppe: Studierende · CTA: App Store · Länge: 1000 Zeichen*

```text
Die Erklärung aus Woche 3, wiedergefunden ohne neunzig Minuten Abhören.

Eine aufgenommene Vorlesung hilft erst, wenn du darin etwas findest. Neunzig Minuten Audio durchzuhören, um einen Satz zu finden, macht niemand.

Sprechly macht aus der Aufnahme einen Text mit Zeitmarken, direkt auf dem iPhone oder iPad. Du liest quer, tippst auf die Stelle und hörst die Erklärung im Original. Mit dem Stil „Stichpunkte“ bekommst du eine Übersicht, und das Transkript exportierst du als Markdown in deine Notizen.

Zum Geld: Aufnehmen, Schneiden und der Audio-Export kosten nichts. Die ersten 30 Sekunden jeder Aufnahme transkribiert die App gratis. Das vollständige Transkript ist ein einmaliger Kauf, kein Abo.

Drei Hinweise. Frag vorher, ob du aufnehmen darfst. Fachbegriffe erkennt die App schlechter als Alltagssprache. Und Zusammenfassungen brauchen ein Gerät mit Apple Intelligence, das Transkript nicht.

Ich bin der Entwickler von Sprechly. iOS 26 ist nötig.

[LINK]
```

### P07 · Sprachmemo zu Text

- **Hook:** Du hast es schon gesagt. Du musst es nicht noch einmal tippen.
- **Kernbotschaft:** Aus gesprochenen Gedanken und vorhandenen Aufnahmen wird lesbarer Text.
- **CTA:** Eine alte Aufnahme importieren und testen.

**P07-K1**

*Zielgruppe: Menschen, die Sprachmemos transkribieren · CTA: keiner · Länge: 181 Zeichen (Limit 300)*

```text
Du hast es schon gesagt. Du musst es nicht noch einmal tippen.

Meine App macht aus der Sprachaufnahme einen Text. Der Stil „Bereinigung“ nimmt Füllwörter und Wiederholungen heraus.
```

**P07-K2**

*Zielgruppe: Menschen mit vorhandenen Aufnahmen · CTA: App Store · Länge: 183 Zeichen (Limit 300)*

```text
Alte Aufnahmen auf dem iPhone? Sprechly importiert Audiodateien aus der Dateien-App und transkribiert sie wie eigene.

Ich bin der Entwickler.

[LINK]
```

**P07-K3**

*Zielgruppe: Diktierende · CTA: keiner · Länge: 141 Zeichen (Limit 300)*

```text
Gedanke beim Spazieren, Aufnahme läuft, Bildschirm ist gesperrt. Auf dem Sperrbildschirm zählt die Zeit mit.

Zu Hause machst du daraus Text.
```

**P07-L**

*Zielgruppe: Menschen, die Sprachmemos transkribieren, Diktierende · CTA: Eine Aufnahme importieren · Länge: 842 Zeichen*

```text
Du hast es schon gesagt. Du musst es nicht noch einmal tippen.

Gesprochen ist ein Gedanke schnell festgehalten. Das Problem kommt danach: Die Aufnahme liegt in einer Liste und bleibt dort ungehört.

Sprechly schließt diese Lücke. Du nimmst auf, die App transkribiert auf dem Gerät, und aus dem Gesprochenen wird Text, den du lesen und weiterverwenden kannst.

Drei Dinge helfen dabei:
– Versprecher? Zurückspulen und ab dem Cursor neu aufnehmen.
– Der Stil „Bereinigung“ entfernt Füllwörter, Wiederholungen und Versprecher aus dem Transkript und lässt den Inhalt unangetastet.
– Vorhandene Audiodateien importierst du aus der Dateien-App und behandelst sie wie eigene Aufnahmen.

Die Bereinigung ist eine KI-Funktion und braucht ein Gerät mit Apple Intelligence.

Ich bin der Entwickler von Sprechly.

[LINK]
```

### P08 · Indie-App-Entwicklung

- **Hook:** Ein Entwickler, kein Budget, eine App im Store.
- **Kernbotschaft:** Sprechly ist das Projekt einer einzelnen Person, und das hat Folgen für Preis und Tempo.
- **CTA:** Fragen stellen.

**P08-K1**

*Zielgruppe: Indie-Szene · CTA: keiner · Länge: 148 Zeichen (Limit 300)*

```text
Hinter meiner App steht kein Team. Entwicklung, Texte, Screenshots, Support: eine Person.

Wer an den Support schreibt, bekommt die Antwort von mir.
```

**P08-K2**

*Zielgruppe: Indie-Szene, Entwickler · CTA: keiner · Länge: 163 Zeichen (Limit 300)*

```text
Meine App hat null Abhängigkeiten von Drittanbietern. Kein Paket, keine Bibliothek, kein SDK.

In der App stecken nur die Frameworks von Apple und der eigene Code.
```

**P08-K3**

*Zielgruppe: Indie-Szene · CTA: keiner · Länge: 112 Zeichen (Limit 300)*

```text
Werbebudget meiner App: 0 €.

Deshalb stelle ich sie hier selbst vor und sage dazu, dass ich der Entwickler bin.
```

**P08-L**

*Zielgruppe: Indie-Szene, Entwickler, Netzwerk · CTA: Fragen stellen · Länge: 945 Zeichen*

```text
Ein Entwickler, kein Budget, eine App im Store.

Ich baue Sprechly allein. Das ist ein Diktiergerät mit Transkription für iPhone und iPad. Hinter der App steht kein Team: Entwicklung, Store-Texte und Support laufen über mich.

Was das für die App bedeutet:

Keine Fremdbibliotheken. Die App besteht aus Apple-Frameworks und dem eigenen Code.

Mehr als 160 automatisierte Tests. Wer allein arbeitet, hat niemanden, der gegenliest. Die Tests übernehmen das.

Kein Werbebudget. Die App wächst über Beiträge wie diesen oder gar nicht.

Ein Preis ohne Abo. Ich betreibe keinen Server, also gibt es keine Serverkosten, die ich weiterreichen müsste.

Und was es für dich bedeutet: Es geht langsamer als bei einem Team. Dafür korrigiere ich die Beschreibung, wenn sie nicht stimmt. Das ist schon vorgekommen. Und wo die App etwas nicht kann, sage ich es.

Fragen zur App oder zur Entwicklung beantworte ich gern.

[LINK]
```

### P09 · Technische Umsetzung mit Apples Speech-APIs

- **Hook:** Zwei neue Frameworks, kein Simulator.
- **Kernbotschaft:** Was beim Bauen auf SpeechAnalyzer und Foundation Models schiefging und wie es gelöst ist.
- **CTA:** Erfahrungen teilen.

**P09-K1**

*Zielgruppe: iOS-Entwickler · CTA: keiner · Länge: 181 Zeichen (Limit 300)*

```text
SpeechAnalyzer liefert die Segmentgrenzen selbst. Meine App übernimmt sie unverändert.

Absätze in der Leseansicht sind reine Darstellung: Umbruch nach mehr als zwei Sekunden Pause.
```

**P09-K2**

*Zielgruppe: iOS-Entwickler · CTA: keiner · Länge: 158 Zeichen (Limit 300)*

```text
Foundation Models fasst wenig Text auf einmal. Lange Transkripte zerlege ich an Satzgrenzen in Stücke von höchstens 800 Zeichen und verdichte sie stufenweise.
```

**P09-K3**

*Zielgruppe: iOS-Entwickler · CTA: Erfahrungen teilen · Hashtags: #iOSDev #SwiftLang · Länge: 177 Zeichen (Limit 300)*

```text
contextualStrings bei SpeechTranscriber: Ich habe es gemessen. 31 Zielbegriffe, mit und ohne Liste, zeichengleiches Ergebnis.

Hat es jemand je wirken sehen?

#iOSDev #SwiftLang
```

**P09-L**

*Zielgruppe: iOS-Entwickler · CTA: Erfahrungen teilen · Länge: 1300 Zeichen*

```text
Zwei neue Frameworks, kein Simulator.

Sprechly baut auf SpeechAnalyzer und Foundation Models auf, beide neu seit iOS 26. Vier Befunde aus der Entwicklung:

Erstens: Beide Frameworks laufen nur auf echten Geräten. Alles, was Sprache oder KI berührt, hängt bei mir hinter einer Schnittstelle. Die Tests arbeiten mit Mocks, das echte Verhalten prüfe ich nach Checkliste auf dem iPhone.

Zweitens: Für die Transkription einer Datei lese ich sie in Blöcken und reiche sie als Strom an den Analyzer. Eigene Startzeiten je Block führen nach einer Umrechnung der Abtastrate zu Überlappungen und zu einem Abbruch. Ohne Startzeiten leitet der Analyzer die Zeitbasis aus dem Strom ab.

Drittens: Die Optionen des Transcribers steuern, wie Ergebnisse gemeldet werden. Die Erkennungsgüte steuern sie nicht. Die kommt vollständig aus Apples Modell.

Viertens: Das On-Device-Sprachmodell lehnt mit den Standard-Schutzeinstellungen auch harmlose Übersetzungen ab. Für die Umformung eigener Texte gibt es eine passendere Einstellung.

Ob sich Eigennamen über eine Begriffsliste besser erkennen lassen, habe ich gemessen: 15 Testsätze, 31 Zielbegriffe, mit und ohne Liste dasselbe Ergebnis. Ein Wörterbuch baue ich auf diesem Weg nicht.

Ich bin der Entwickler von Sprechly. Wer ähnliche Erfahrungen hat: Ich höre zu.
```

### P10 · Datenschutz

- **Hook:** Was meine App über dich weiß: nichts.
- **Kernbotschaft:** Keine Datenerhebung, kein Konto, und eine genaue Aussage zum iCloud-Sync.
- **CTA:** Datenschutzlabel im Store ansehen.

**P10-K1**

*Zielgruppe: Datenschutzbewusste · CTA: keiner · Länge: 135 Zeichen (Limit 300)*

```text
Was meine App über dich weiß: nichts.

Kein Konto, keine Analyse, keine Werbung. Im Store steht beim Datenschutz „Keine Daten erfasst“.
```

**P10-K2**

*Zielgruppe: Datenschutzbewusste · CTA: keiner · Länge: 164 Zeichen (Limit 300)*

```text
Der iCloud-Sync meiner App ist ab Werk an. Das sage ich dazu, weil es zu „Datenschutz“ gehört.

Er nutzt deine private iCloud. Abschalten geht in den Einstellungen.
```

**P10-K3**

*Zielgruppe: Datenschutzbewusste · CTA: keiner · Länge: 147 Zeichen (Limit 300)*

```text
Gelöschte Aufnahmen liegen in meiner App 30 Tage im Papierkorb. Danach sind sie weg, samt Audiodatei.

Du kannst den Papierkorb auch sofort leeren.
```

**P10-L**

*Zielgruppe: Datenschutzbewusste Apple-Nutzer · CTA: Datenschutzlabel ansehen · Länge: 1047 Zeichen*

```text
Was meine App über dich weiß: nichts.

Sprechly erhebt keine Daten. Das steht so im Datenschutzlabel des App Store, und es ist einfach zu erklären:

Es gibt kein Konto. Du meldest dich nirgends an.
Es gibt keine Analyse-Software. Ich sehe nicht, wie du die App benutzt.
Es gibt keine Werbung und keine Bibliotheken von Dritten.
Es gibt keinen Server von mir. Spracherkennung und KI laufen auf deinem Gerät.

Das Mikrofon nutzt die App nur für Aufnahmen und erst, nachdem du zugestimmt hast.

Jetzt der Teil, der zu einer vollständigen Datenschutzaussage gehört: Der iCloud-Sync ist ab Werk eingeschaltet. Er speichert Aufnahmen und Transkripte in deiner privaten iCloud bei Apple, damit sie auf deinen anderen Geräten erscheinen. Ich komme an diese Daten nicht heran. Du kannst den Sync in den Einstellungen abschalten.

Gelöschte Aufnahmen bleiben 30 Tage im Papierkorb und werden dann endgültig entfernt.

Die Käufe wickelt Apple ab. Zahlungsdaten bekomme ich nicht.

Ich bin der Entwickler von Sprechly.

[LINK]
```

### P11 · Produktivität

- **Hook:** Reden ist schneller als Tippen. Lesen ist schneller als Zuhören.
- **Kernbotschaft:** Sprechly verbindet beides: sprechen, dann lesen.
- **CTA:** Den nächsten Gedanken diktieren.

**P11-K1**

*Zielgruppe: Produktivitäts-Interessierte · CTA: keiner · Länge: 130 Zeichen (Limit 300)*

```text
Reden ist schneller als Tippen. Lesen ist schneller als Zuhören.

Meine App verbindet beides: Du sprichst, sie schreibt, du liest.
```

**P11-K2**

*Zielgruppe: Produktivitäts-Interessierte · CTA: keiner · Länge: 166 Zeichen (Limit 300)*

```text
„Stille automatisch entfernen“ ist ein Knopf in meiner App. Aus zwölf Minuten Aufnahme mit Denkpausen wird die Fassung ohne Pausen.

Kostenlos, wie der ganze Schnitt.
```

**P11-K3**

*Zielgruppe: Notiz-Nerds · CTA: App Store · Länge: 166 Zeichen (Limit 300)*

```text
Transkript als Markdown, mit Titel, Datum und Zeitmarken. Direkt ins Notizsystem.

Das kann Sprechly. Ich bin der Entwickler.

[LINK]
```

**P11-L**

*Zielgruppe: Produktivitäts-Interessierte, Selbstständige · CTA: App Store · Länge: 1016 Zeichen*

```text
Reden ist schneller als Tippen. Lesen ist schneller als Zuhören.

Eine Sprachaufnahme nutzt nur die erste Hälfte dieses Satzes. Du hältst den Gedanken schnell fest, aber um ihn wiederzufinden, musst du die ganze Aufnahme abhören.

Sprechly ergänzt die zweite Hälfte. Aus der Aufnahme wird ein Text, den du überfliegen kannst. Aus dem Text werden auf Wunsch Stichpunkte oder Kernaussagen.

Was im Alltag hilft:
– Aufnahme läuft im Hintergrund und bei gesperrtem Bildschirm weiter.
– „Stille automatisch entfernen“ kürzt Denkpausen heraus.
– Im Schnitt lässt sich das Tempo von 0,5-fach bis 3-fach ändern.
– Export als Markdown oder Text in das Notizsystem deiner Wahl.
– Die Bibliothek durchsuchst du nach Titeln. Mit der KI-Funktion bekommt eine Aufnahme auf Wunsch einen passenden Titel.

Was die App nicht macht: Aufgaben anlegen, Kalender füllen, mit anderen Diensten sprechen. Sie liefert den Text. Was du damit tust, bleibt bei dir.

Ich bin der Entwickler von Sprechly.

[LINK]
```

### P12 · KI-Zusammenfassung

- **Hook:** Fünf Arten, ein Transkript zu lesen.
- **Kernbotschaft:** Zusammenfassung, Protokoll, Stichpunkte, Kernaussagen, Bereinigung, erzeugt vom Sprachmodell auf dem Gerät.
- **CTA:** Prüfen, ob das eigene Gerät Apple Intelligence hat.

**P12-K1**

*Zielgruppe: KI-Interessierte · CTA: keiner · Länge: 174 Zeichen (Limit 300)*

```text
Fünf Arten, ein Transkript zu lesen: Zusammenfassung, Protokoll, Stichpunkte, Kernaussagen, Bereinigung.

Meine App erzeugt sie mit dem Sprachmodell von Apple, auf dem Gerät.
```

**P12-K2**

*Zielgruppe: KI-Interessierte · CTA: keiner · Länge: 153 Zeichen (Limit 300)*

```text
Die KI in meiner App läuft nur auf Geräten mit Apple Intelligence. Das steht auf dem Kaufbildschirm, bevor du zahlst.

Die Transkription läuft auch ohne.
```

**P12-K3**

*Zielgruppe: KI-Interessierte · CTA: keiner · Länge: 163 Zeichen (Limit 300)*

```text
Eine Zusammenfassung ist ein Vorschlag. Das Sprachmodell auf dem Gerät ist klein und kann danebenliegen.

Deshalb steht in meiner App das Transkript immer daneben.
```

**P12-L**

*Zielgruppe: KI-Interessierte, Meeting-Nutzer · CTA: App Store · Länge: 1120 Zeichen*

```text
Fünf Arten, ein Transkript zu lesen.

Ein Transkript von dreißig Minuten ist lang. Sprechly bietet fünf Wege, es zu verdichten:

Zusammenfassung: zwei bis vier Sätze zum Inhalt.
Protokoll: gegliedert in Abschnitte, zum Beispiel Themen, Entscheidungen, offene Punkte.
Stichpunkte: die wichtigsten Punkte als Liste.
Kernaussagen: die drei bis fünf zentralen Aussagen.
Bereinigung: derselbe Text ohne Füllwörter, Wiederholungen und Versprecher.

Dazu schlägt die App einen Titel vor und übersetzt das Transkript in 15 Sprachen.

Das alles erzeugt das Sprachmodell von Apple auf dem Gerät. Daraus folgen drei Dinge, die du wissen solltest:

Es braucht ein Gerät mit Apple Intelligence. Auf anderen Geräten zeigt die App die Funktionen als nicht verfügbar an, auch auf dem Kaufbildschirm.

Das Modell ist klein. Es kann etwas übersehen oder falsch gewichten. Das Transkript bleibt die Quelle.

Bei manchen Themen lehnt der Schutzfilter von Apple eine Zusammenfassung ab. Die App sagt das dann klar, und Transkript und Export funktionieren weiter.

Ich bin der Entwickler von Sprechly.

[LINK]
```

### P13 · Einmaliger Kauf statt Abo-Müdigkeit

- **Hook:** Noch ein Abo? Nein.
- **Kernbotschaft:** Wer die Zahl seiner Abos nicht weiter erhöhen will, bekommt hier ein Werkzeug zum Festpreis.
- **CTA:** Im App Store ansehen.

**P13-K1**

*Zielgruppe: Abo-Müde · CTA: keiner · Länge: 76 Zeichen (Limit 300)*

```text
Zähl mal deine App-Abos.

Meine App kommt nicht dazu. Einmal kaufen, fertig.
```

**P13-K2**

*Zielgruppe: Abo-Müde · CTA: keiner · Länge: 167 Zeichen (Limit 300)*

```text
Neues iPhone? Der Kauf meiner App hängt an deiner Apple-ID. „Käufe wiederherstellen“ tippen, weiterarbeiten.

Ein Konto bei mir brauchst du dafür nicht. Es gibt keins.
```

**P13-K3**

*Zielgruppe: Abo-Müde · CTA: App Store · Länge: 194 Zeichen (Limit 300)*

```text
Kein Abo heißt bei Sprechly auch: kein Probeabo, das sich verlängert. 30 Sekunden Transkription je Aufnahme sind einfach gratis.

Ich bin der Entwickler.

[LINK]
```

**P13-L**

*Zielgruppe: Abo-Müde · CTA: App Store · Länge: 951 Zeichen*

```text
Noch ein Abo? Nein.

Für viele Apps ist das Abo der Normalfall geworden. Für eine Transkriptions-App liegt es nahe, wenn die Verarbeitung Rechenzeit in einem Rechenzentrum kostet.

Bei Sprechly ist das anders, und deshalb ist auch der Preis anders. Die App transkribiert auf deinem iPhone oder iPad. Ich zahle nichts dafür, dass du sie benutzt. Also zahlst du nicht monatlich.

Was das praktisch heißt:
– Kein Probeabo, das sich von selbst verlängert. Die ersten 30 Sekunden jeder Aufnahme transkribiert die App gratis, so oft du willst.
– Keine Kündigungsfrist und kein Konto.
– Ein einmaliger Kauf. Auf einem neuen Gerät stellst du ihn über deine Apple-ID wieder her.
– Aufnehmen, Schneiden und Audio-Export bleiben ganz ohne Kauf nutzbar.

Die Kehrseite: Die App finanziert sich über neue Käufe und nicht über Monatsbeiträge. Wie lange sich das trägt, wird sich zeigen.

Ich bin der Entwickler von Sprechly.

[LINK]
```

### P14 · Neue Version und Verbesserungen

- **Hook:** Was sich geändert hat, und warum.
- **Kernbotschaft:** Updates beheben, was Nutzer gebremst hat. Jede Änderung hat einen benennbaren Grund.
- **CTA:** Aktualisieren und Rückmeldung geben.

Die Kurzposts zu 1.1.1 erst verwenden, wenn 1.1.1 im Store ist.

**P14-K1**

*Zielgruppe: Bestandsnutzer · CTA: keiner · Länge: 171 Zeichen (Limit 300)*

```text
Seit Version 1.1.0 transkribiert meine App die ersten 30 Sekunden jeder Aufnahme gratis.

Vorher musste man kaufen, um überhaupt ein Ergebnis zu sehen. Das war ein Fehler.
```

**P14-K2**

*Zielgruppe: Bestandsnutzer · CTA: keiner · Länge: 150 Zeichen (Limit 300)*

```text
Behoben in 1.1.0: Das Suchfeld der Bibliothek lag hinter der unteren Leiste und war nicht zu erreichen.

Ja, wirklich. Jetzt sitzt es unter dem Titel.
```

**P14-K3**

*Zielgruppe: Bestandsnutzer · CTA: Bewerten · Länge: 183 Zeichen (Limit 300)*

```text
Neu in 1.1.1: „Sprechly bewerten“ steht jetzt in den Einstellungen.

Wenn dir die App hilft, hilft mir eine Bewertung. Ich bin der Entwickler.

[LINK]
```

**P14-L**

*Zielgruppe: Bestandsnutzer, Interessierte · CTA: Aktualisieren und Rückmeldung geben · Länge: 1145 Zeichen*

```text
Was sich geändert hat, und warum.

Version 1.1.0 von Sprechly hatte ein Ziel: Wer die App lädt, soll sehen, was sie kann, bevor er zahlt.

Neu war:
– Die ersten 30 Sekunden jeder Aufnahme lassen sich gratis transkribieren. Die Vorschau wird nicht gespeichert.
– Der Kaufbildschirm zeigt zuerst das eigene Ergebnis.
– Der Schalter für das Live-Transkript sitzt direkt auf dem Aufnahmebildschirm.
– Nach dem Stoppen bestätigt die App die gespeicherte Aufnahme und führt in die Bibliothek.

Behoben wurde:
– Das Suchfeld der Bibliothek lag hinter der unteren Leiste.
– Die letzten Zeilen langer Transkripte waren verdeckt.
– Der iCloud-Abgleich lud die ganze Bibliothek in den Arbeitsspeicher.
– Schnitt, Zusammenführen und Mix meldeten „gespeichert“, auch wenn das Speichern fehlgeschlagen war.

Version 1.1.1 ergänzt den Eintrag „Sprechly bewerten“ in den Einstellungen und eine Store-Beschreibung, die genau sagt, was der Kauf umfasst.

Als Nächstes arbeite ich an der Erkennung von Eigennamen und Fachbegriffen.

Ich bin der Entwickler. Rückmeldungen gehen an support@gcng.de oder hier in die Antworten.

[LINK]
```

### P15 · Behind the scenes

- **Hook:** Der Fehler, den ich drei Anläufe lang gejagt habe.
- **Kernbotschaft:** Hinter einer unscheinbaren Funktion steckt oft die meiste Arbeit.
- **CTA:** Eigene Geschichten teilen.

**P15-K1**

*Zielgruppe: Entwickler, Neugierige · CTA: keiner · Länge: 183 Zeichen (Limit 300)*

```text
Der hartnäckigste Fehler meiner App: Bluetooth-Kopfhörer während der Aufnahme trennen.

Drei Anläufe bis zur Lösung. Am Ende half nur, die Audio-Engine beim Fortsetzen neu aufzubauen.
```

**P15-K2**

*Zielgruppe: Entwickler, Neugierige · CTA: keiner · Länge: 182 Zeichen (Limit 300)*

```text
Die Screenshots meiner App im Store entstehen per Skript: Testlauf im Simulator, dann setzt ein zweites Skript die Überschriften darauf.

Jede Überschrift ist gegen den Code geprüft.
```

**P15-K3**

*Zielgruppe: Entwickler, Neugierige · CTA: keiner · Länge: 144 Zeichen (Limit 300)*

```text
Umlaute im exportierten Transkript waren in manchen Editoren kaputt. Die Datei war korrektes UTF-8.

Die Lösung waren drei Bytes am Dateianfang.
```

**P15-L**

*Zielgruppe: Entwickler, technisch Neugierige · CTA: Eigene Geschichten teilen · Länge: 1106 Zeichen*

```text
Der Fehler, den ich drei Anläufe lang gejagt habe.

Sprechly nimmt auf. Das klingt nach der einfachsten Funktion der App. Die meiste Zeit hat mich ein einziger Fall gekostet: Jemand trennt mitten in der Aufnahme den Bluetooth-Kopfhörer.

In dem Moment wechselt das Mikrofon. Das Headset liefert 16 Kilohertz, das eingebaute Mikrofon 48. Die Aufnahme brach mit dem Fehler -10868 ab.

Erster Anlauf: nahtlos auf das neue Mikrofon umschalten. Das System meldete im Moment des Wechsels noch das alte Format.

Zweiter Anlauf: das Format nicht festlegen und dem System überlassen. Es legt das Format aber einmal fest, beim Einrichten, und behält es.

Dritter Anlauf: Die Aufnahme pausiert beim Wechsel. Beim Fortsetzen baut die App die gesamte Audio-Engine neu auf. Das ist aufwendiger, aber das Fortsetzen passiert selten, und der Fehler ist weg.

Die Ursache stand im Geräteprotokoll: Eingang 48.000 Hertz, Tap 16.000 Hertz.

Für den Nutzer sieht das Ergebnis so aus: Kopfhörer ab, Aufnahme pausiert, einmal tippen, weiter.

Ich bin der Entwickler von Sprechly. Welcher Fehler hat euch am längsten beschäftigt?
```
