# DictationTranscriber Evaluation — Sprechly 1.2, Phase 3

Rohdaten unverändert in
[`benchmarks/2026-10-04-transcriber-comparison.md`](benchmarks/2026-10-04-transcriber-comparison.md).

**Kurzfassung: `DictationTranscriber` erkennt genauso viele Zielbegriffe wie der
heutige `SpeechTranscriber`, produziert dabei aber mehr Textfehler, lässt Inhalt
aus und braucht gut die doppelte Zeit. Kein Ersatz — aber seine Formatierung ist
sichtbar besser.**

---

## API findings

Gegen iPhoneOS 27.0 SDK verifiziert, nicht aus Dokumentation übernommen.

| Eigenschaft | Befund |
|---|---|
| Verfügbarkeit | `@available(anyAppleOS 26, *)` — mit Deployment-Target 26.0 nutzbar |
| Presets | `phrase`, `shortDictation`, `progressiveShortDictation`, `longDictation`, `progressiveLongDictation`, `timeIndexedLongDictation` |
| ContentHints | `shortForm`, `farField`, `atypicalSpeech`, **`customizedLanguage(modelConfiguration:)`** |
| TranscriptionOptions | `punctuation`, `emoji`, `etiquetteReplacements` |
| ReportingOptions | `volatileResults`, `alternativeTranscriptions`, `frequentFinalization` |
| AttributeOptions | `audioTimeRange`, `transcriptionConfidence` |
| Result | `range: CMTimeRange`, `text`, `alternatives`, `resultsFinalizationTime` |
| `isAvailable` | **fehlt** — `SpeechTranscriber` hat es, `DictationTranscriber` nicht |

**Preset-Inhalte zur Laufzeit ausgelesen** (das SDK dokumentiert sie nicht):

| Preset | ContentHints | Transcription | Reporting | Attributes |
|---|---:|---|---|---|
| `phrase` | 1 | — | — | — |
| `shortDictation` | 1 | `punctuation` | — | — |
| `progressiveShortDictation` | 1 | `punctuation` | `volatileResults`, `frequentFinalization` | — |
| `longDictation` | 0 | `punctuation` | — | — |
| `progressiveLongDictation` | 0 | `punctuation` | `volatileResults` | — |
| `timeIndexedLongDictation` | 0 | `punctuation` | — | `audioTimeRange` |

`timeIndexedLongDictation` ist das Gegenstück zu Sprechlys heutigem
`SpeechTranscriber(preset: .transcription)` und wurde für Lauf B gewählt.

**Erwähnenswert für später:** `customizedLanguage(modelConfiguration:)` nimmt
eine `SFSpeechLanguageModel.Configuration` — das ist der klassische Weg für ein
echtes benutzerdefiniertes Sprachmodell. Das ist etwas völlig anderes als die in
Phase 2 widerlegten `contextualStrings` und wurde hier **nicht** gemessen.

## Functional comparison

| Capability | SpeechTranscriber | DictationTranscriber |
|---|---|---|
| Live streaming | ja (`progressiveTranscription`, in Sprechly im Einsatz) | ja (`progressiveLongDictation`) |
| Existing files | ja | ja |
| Partial results | ja (`volatileResults`) | ja (`volatileResults`, zusätzlich `frequentFinalization`) |
| Time ranges | ja (`result.range`) | ja (`result.range` + `audioTimeRange`) |
| Long audio | ja (in Sprechly verifiziert) | Presets vorhanden, **nicht verifiziert** |
| Cancellation | ja (Stream-Termination) | identisch, gleicher Analyzer |
| Interpunktion | keine Option | **`punctuation` eingebaut** |
| Alternativen | `alternativeTranscriptions` | `alternativeTranscriptions` |
| Konfidenz | `transcriptionConfidence` | `transcriptionConfidence` |
| **Installierte Locales (Testgerät)** | **12** (de_AT, de_CH, de_DE, en_AU, en_CA, en_GB, en_IE, en_IN, en_NZ, en_SG, en_US, en_ZA) | **2** (de_DE, en_US) |
| Unterstützte Locales | 45 | 54 |
| `isAvailable`-Prüfung | ja | **nein** |
| iOS 26 / 27 | beide | beide |
| Offline | ja | ja |

**Der Locale-Unterschied ist der funktional schwerste Punkt.** Auf dem Testgerät
hat `SpeechTranscriber` zwölf installierte Sprachen, `DictationTranscriber`
zwei. Sprechly-Nutzer mit `de_AT`, `de_CH` oder britischem Englisch verlören bei
einer Migration ihre bereits installierten Modelle und müssten neu laden — wenn
die Sprache überhaupt bereitsteht.

## Benchmark environment

| | |
|---|---|
| Gerät | iPhone 17 Pro, iOS 27.0.1 |
| Locale | `de-DE` |
| Korpus | unverändert aus Phase 2: 15 Sätze, 31 Zielbegriffe, 5 Kategorien |
| Normalisierung/Metriken | unverändert aus Phase 2 |
| Audio | innerhalb dieses Laufs einmal synthetisiert, von **allen** Engines gelesen |
| Varianten | A `SpeechTranscriber(.transcription)` · B `DictationTranscriber(.timeIndexedLongDictation)` · C B + `contentHints: [.farField]` |

### Wichtige methodische Einschränkung

Die Phase-2-Werte für `SpeechTranscriber` (WER 0,253 · 13/31) und die hier
gemessenen (WER 0,234 · 16/31) **weichen voneinander ab**, obwohl derselbe
Transcriber mit demselben Korpus lief.

Ursache: `AVSpeechSynthesizer` erzeugt zwischen Läufen nicht bitgleiches Audio.
Innerhalb eines Laufs ist der Input für alle Engines identisch — der A/B-Vergleich
ist also valide — **zwischen Läufen sind absolute Zahlen aber nicht
vergleichbar**. Deshalb wurde `SpeechTranscriber` hier erneut mitgemessen und
dient als Referenz; die Phase-2-Zahlen bleiben als eigener Datenpunkt bestehen
und wurden nicht überschrieben.

## Aggregate delta

| Metric | SpeechTranscriber | DictationTranscriber | Delta |
|---|---:|---:|---:|
| WER | **0,234** | 0,292 | **+0,058** (schlechter) |
| CER | **0,062** | 0,094 | **+0,032** (schlechter) |
| Target Term Accuracy | 16/31 | 16/31 | **0** |
| Target Term Recall | 0,516 | 0,516 | **0,000** |
| False Positives | 0 | 0 | 0 |
| Laufzeit (15 Fälle) | **1,380 s** | 3,228 s | **2,3×langsamer** |

Variante C (`farField`) lag dazwischen: WER 0,270, CER 0,089, Recall identisch
0,516, Laufzeit 2,487 s. Der Hint verbessert gegenüber B leicht, bleibt aber
unter A.

## Per-category delta

| Category | Speech | Dictation | Delta |
|---|---:|---:|---:|
| Names | 3/4 | 3/4 | 0 |
| Technical | **2/7** | 1/7 | **−1** |
| Abbreviations | 2/4 | **3/4** | **+1** |
| Numbers | **4/6** | 3/6 | **−1** |
| Mixed | 5/10 | **6/10** | **+1** |
| **Gesamt** | 16/31 | 16/31 | **0** |

Gleiche Summe, aber Verschiebung: besser bei Abkürzungen und gemischten Sätzen,
schlechter bei Fachbegriffen und Zahlen.

## Per-target comparison

Nur die Begriffe, bei denen sich die Engines unterscheiden:

| Target | SpeechTranscriber | DictationTranscriber | Ergebnis |
|---|---|---|---|
| KI (`abbrev-02`) | miss (`K⍰I⍰`) | **hit** | Dictation besser |
| 13:45 (`mixed-01`) | miss (`13.45`) | **hit** | Dictation besser |
| CVAG (`mixed-01`) | miss | **hit** | Dictation besser |
| VPN (`mixed-02`) | miss | **hit** | Dictation besser |
| API (`mixed-02`) | **hit** | miss | Speech besser |
| Markdown (`mixed-03`) | **hit** | miss | Speech besser |
| 10 (`numbers-04`) | **hit** | miss | Speech besser |
| Docker (`technical-01`) | **hit** | miss | Speech besser |

Unverändert verfehlt von **beiden**: `StoreKit`, `CloudKit`, `SwiftUI`,
`SpeechAnalyzer`, `AnalysisContext`, `Chemnitzer Verkehrs-AG`, `192.168.2.4`,
`1.2.0`, `API` (isoliert). Die harten Fachbegriffe löst keine der beiden Engines.

## Performance

Laufzeit je Fall: Speech ~0,09 s, Dictation ~0,22 s. Keine Speicherauffälligkeiten,
keine Fehler, keine zusätzliche Modellvorbereitung — das de_DE-Modell war
installiert. Bei einer Stunden-Aufnahme würde der Faktor 2,3 aber spürbar.

## Regressions / missing capabilities

1. **Textauslassung.** Der schwerste Befund:
   ```
   Referenz:  Der Kauf läuft über StoreKit, die Synchronisierung über CloudKit.
   Speech:    Der Kauf läuft über Store Kit, die Synchronisierung über Cloud Kit.
   Dictation: Der Kauf läuft über die Synchronisierung über Cloud Kit
   ```
   `DictationTranscriber` lässt „StoreKit," ersatzlos weg. Das ist kein
   Erkennungsfehler, sondern **Inhaltsverlust** — für eine App, deren Zweck das
   Festhalten von Gesprochenem ist, gravierender als ein falsch geschriebenes Wort.
2. **Locale-Abdeckung** — 2 statt 12 installierte Sprachen (siehe oben).
3. **Kein `isAvailable`** — die Verfügbarkeitsprüfung müsste anders gelöst werden.
4. **Lange Aufnahmen unverifiziert** — der heutige Pfad ist dafür erprobt.

## Recommendation

**B — teilweise interessant, aber kein Ersatz.**

Gegen eine Migration sprechen: identischer Zielbegriff-Recall bei **höherer** WER
und CER, 2,3-fache Laufzeit, Inhaltsauslassungen, ein Sechstel der installierten
Locales und eine fehlende Verfügbarkeitsprüfung. Das Entscheidungskriterium
„echter Netto-Vorteil" ist klar nicht erfüllt.

**Was aber bemerkenswert ist:** Jeder Punkt, in dem `DictationTranscriber`
gewinnt, ist ein **Formatierungsproblem**, kein Erkennungsproblem:

- `13:45` statt `13.45` — Uhrzeit korrekt gesetzt
- `SharePoint` statt `Sharepoint` — Binnenmajuskel korrekt
- `KI` statt `K⍰I⍰` — Buchstabierung korrekt zusammengefasst
- Sätze enden mit Punkt (die `punctuation`-Option)

Dasselbe Audio, dasselbe akustische Modell — der Unterschied liegt in der
Nachbereitung des erkannten Textes. Genau diese Klasse von Fehlern dominiert
auch die Baseline-Misses des heutigen Transcribers.

## Next recommendation

**Phase 4 — Semantic / Number Formatting**, als konservative Nachbearbeitung im
eigenen Code statt eines Engine-Wechsels.

Belegt durch die Messung lohnende Kandidaten:

| Fehlerbild | Beispiel | Häufigkeit im Korpus |
|---|---|---|
| Uhrzeit mit Punkt statt Doppelpunkt | `13.45` → `13:45` | mehrfach |
| Versionsnummer zerrissen | `1. 2.0` → `1.2.0` | mehrfach |
| Binnenmajuskel bei Produktnamen | `Sharepoint` → `SharePoint` | mehrfach |
| Getrennte Komposita | `Store Kit` → `StoreKit` | mehrfach |
| Buchstabierte Abkürzungen | `K⍰I⍰`, `AP` | mehrfach |

Das wäre deterministisch, testbar mit genau diesem Korpus, ohne
API-Abhängigkeit und ohne Risiko für lange Aufnahmen. **Nicht in dieser Phase
implementiert** — der Vorschlag braucht erst deine Freigabe, und die Regeln
müssten konservativ gefasst sein, damit sie nicht korrekten Text zerstören.

Nicht weiterverfolgt wird `DictationTranscriber` als Ersatz. Offen bleibt
`customizedLanguage(modelConfiguration:)` als eigenständiges Thema.
