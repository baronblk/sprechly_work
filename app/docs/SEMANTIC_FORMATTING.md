# Conservative Semantic Formatting — Sprechly 1.2, Phase 4

Rohdaten unverändert in
[`benchmarks/2026-10-04-semantic-formatting.md`](benchmarks/2026-10-04-semantic-formatting.md),
Fehlerklassen in [`TRANSCRIPTION_ERROR_TAXONOMY.md`](TRANSCRIPTION_ERROR_TAXONOMY.md).

**Kurzfassung: deterministische Nachbearbeitung hebt die Zielbegriff-Trefferzahl
von 13/31 auf 20/31 und die Formatting Accuracy von 0,619 auf 0,909, bei
WER −0,095, CER −0,025 und einem False Correction Count von 0. Empfehlung A —
integrieren.**

Der schwerste Einzelbefund ist kein Qualitätsgewinn, sondern ein Produktfehler:
der heutige Pfad schreibt Engine-Markup wörtlich in die Transkripte der Nutzer.

---

## Messaufbau

| | |
|---|---|
| Gerät | iPhone 17 Pro, iOS 27.0.1 |
| Locale | `de-DE` |
| Engine | `SpeechTranscriber(preset: .transcription)` — **unverändert** |
| Audio | `Tests/Fixtures/Transcription`, 15 Dateien, SHA-256 festgenagelt |
| Korpus/Normalisierung | unverändert aus Phase 2 |
| Variable | ausschließlich `TranscriptSemanticFormatter` und seine Regelmenge |

Audio, Pipeline, `contextualStrings`, `DictationTranscriber` und Monetarisierung
sind nicht angetastet. Der Transkriptionslauf findet **einmal** statt; alle
Varianten bewerten denselben Rohtext, damit keine Erkennungsvarianz in die
Vorher/Nachher-Differenz leckt.

### Neue Metriken

- **Formatting Accuracy** — Anteil der Zielbegriffe, die das Modell *gehört*
  hat und die auch die richtige Form tragen. Erkennungsfehler sind
  herausgerechnet: sie sind durch Formatierung nicht beeinflussbar und würden
  den Effekt unter einer Konstante verstecken. Gepoolt über den Lauf, nicht als
  Mittel der Fallquoten.
- **False Correction Count** — Zielbegriffe, die vorher Treffer waren und
  nachher nicht mehr. Muss 0 sein.

Die Trennung „gehört" / „falsch gehört" läuft über Buchstaben-Ziffern-Skelette
auf token-ausgerichteten Fenstern (`13.45` und `13:45` → `1345`). Die
Verankerung an Tokengrenzen ist nötig, damit `KI` nicht in `Paketkiste` gefunden
wird. Beide Metriken sind in `BenchmarkFormattingMetricTests` definiert und
geprüft, inklusive der bekannten Grenze, dass das Skelett das Dezimalkomma
verwirft.

## Aggregat

| Metrik | Vorher | Nachher | Delta |
|---|---:|---:|---:|
| Zielbegriffe | 13/31 | **20/31** | **+7** |
| Target Term Recall | 0,419 | **0,645** | +0,226 |
| **Formatting Accuracy** | 0,619 | **0,909** | **+0,290** |
| WER | 0,250 | **0,155** | **−0,095** |
| CER | 0,067 | **0,042** | −0,025 |
| Formatierungs-Verfehler | 8 | **2** | −6 |
| Erkennungs-Verfehler | 10 | 9 | −1 ¹ |
| False Positives | 0 | **0** | 0 |
| **False Correction Count** | — | **0** | — |

¹ `KI` wandert aus den Erkennungsfehlern heraus: die Metrik hatte den Fall nur
deshalb dort eingeordnet, weil das eingefügte `letter` das Skelett zerstörte.

Die zwei verbleibenden Formatierungs-Verfehler sind `Chemnitzer Verkehrs-AG` und
`192.168.2.4` — beide bewusst nicht behandelt (siehe Taxonomie).

## Wirkung je Regel

Jede Regel allein gegen dieselbe Baseline:

| Regel | Zielbegriffe | WER-Delta | Fmt-Acc-Delta | False Corrections |
|---|---:|---:|---:|---:|
| `knownCompounds` | 13 → **16** | −0,044 | +0,143 | 0 |
| `clockTimes` | 13 → **15** | −0,013 | +0,095 | 0 |
| `versionNumbers` | 13 → **14** | −0,010 | +0,048 | 0 |
| `spelledLetterMarkup` | 13 → 13 | −0,013 | **−0,028** | 0 |
| `spelledLetterMarkup` + `spelledAcronyms` | 13 → **14** | −0,027 | +0,017 | 0 |
| `spelledAcronyms` allein | 13 → 13 | 0,000 | 0,000 | 0 |
| `canonicalSpellings` | 13 → 13 | 0,000 | 0,000 | 0 |
| **alle zusammen** | 13 → **20** | **−0,095** | **+0,290** | **0** |

Die Einzelgewinne (3 + 2 + 1 + 1) summieren sich genau auf die 7 des
Gesamtlaufs — die Regeln überschneiden sich nicht.

**Drei Befunde sind erklärungsbedürftig und werden nicht weggerundet:**

1. **`spelledAcronyms` allein wirkt exakt null.** Die Regel war gegen `A P I`
   geschrieben, aber die Engine liefert nie Leerzeichen zwischen buchstabierten
   Zeichen — sie liefert `K\letter I\letter`. Ohne die Markup-Bereinigung sieht
   die Regel nie einen Lauf. Erst zusammen tragen die beiden einen Treffer.
2. **`spelledLetterMarkup` allein senkt die Formatting Accuracy** um 0,028.
   Das ist korrekt und kein Widerspruch: die Bereinigung macht `KI` erst als
   *Form*problem sichtbar und verschiebt den Fall aus den Erkennungs- in die
   Formatierungsfehler — Nenner plus eins, Zähler unverändert. Der CER-Gewinn
   von 0,018 bei null Treffergewinn ist der eigentliche Punkt dieser Regel:
   sie entfernt Zeichen, die nie hätten erscheinen dürfen.
3. **`canonicalSpellings` bewegt nichts**, weil die Begriffsprüfung
   kleinschreibt und `Sharepoint` deshalb schon vorher als Treffer zählte. Die
   Regel ist über zwei belegte Vorkommen begründet, nicht über die Kennzahl.

## Geänderte Texte

Sieben der 15 Fälle wurden verändert, alle sieben zum Besseren:

| Fall | Vorher | Nachher |
|---|---|---|
| `technical-01` | `… liegt in Sharepoint, der Container …` | `… liegt in SharePoint, der Container …` |
| `technical-02` | `… über Store Kit, … über Cloud Kit.` | `… über StoreKit, … über CloudKit.` |
| `abbrev-02` | `… die K\letter I\letter läuft …` | `… die KI läuft …` |
| `numbers-02` | `… 2026 um 13.45 Uhr.` | `… 2026 um 13:45 Uhr.` |
| `mixed-01` | `… bis 13.45 Uhr in Sharepoint ab.` | `… bis 13:45 Uhr in SharePoint ab.` |
| `mixed-02` | `Für Version 1. 2.0 prüfen wir …` | `Für Version 1.2.0 prüfen wir …` |
| `mixed-03` | `… Export geht nach Mark Down.` | `… Export geht nach Markdown.` |

Die übrigen acht Fälle sind **zeichenidentisch** durchgelaufen. Das ist die
wichtigere Hälfte des Ergebnisses: der Formatter ist auf gewöhnlicher Prosa ein
No-op.

## Markup-Bereinigung

### Was belegt ist

```
FORMAT MARKUP abbrev-02 found=\letter \letter
FORMAT MARKUP AUDIT \letter=2
```

**Zwei Vorkommen von `\letter`, in einem von 15 Fällen. Keine weiteren
Marker** — kein `\number`, kein `\spell`, keine andere Escape-Sequenz. Das
Benchmark meldet jede Backslash-Sequenz im Rohoutput, sodass ein zusätzlicher
Marker als Messbefund auftaucht, bevor eine Regel dafür entsteht. Nicht belegte
Marker werden nicht behandelt.

### Wie sie funktioniert

Deterministisch, ein einziges Muster: `\letter` mit Wortgrenze dahinter wird
entfernt, eine dadurch entstehende Doppel-Leerstelle auf eine zusammengezogen.
Enthält der Text keinen Backslash, kehrt die Funktion unverändert zurück. Die
Regel läuft **vor** dem Akronym-Zusammenzug, weil sie erst den Lauf `K I`
sichtbar macht.

### Welche Backslash-Fälle bewusst unangetastet bleiben

Durch negative Tests abgesichert:

| Eingabe | Verhalten |
|---|---|
| `C:\Users\rene\Dokumente` | unverändert — Windows-Pfad |
| `Ein Zeilenumbruch ist \n im Code.` | unverändert — Escape-Sequenz im Nutzertext |
| `Schreib \begin{document} an den Anfang.` | unverändert — LaTeX |
| `Die \letters sind gemeint.` | unverändert — Wortgrenze schützt |
| `Im \letterbox lag Post.` | unverändert — Wortgrenze schützt |

Nur das exakte Token ist Markup. Alles andere mit Backslash ist Text des
Nutzers.

### Warum das mehr als Kosmetik ist

[`SpeechTranscriptionService.swift:86`](../Transcription/SpeechTranscriptionService.swift#L86)
extrahiert den Text in Produktion mit demselben
`String(result.text.characters)` wie das Benchmark und bereinigt nichts. Das
Markup landet damit im persistierten `TranscriptSegment` und in jedem TXT-/
Markdown-Export. Ein Nutzer, der Buchstaben einzeln spricht, findet `\letter`
wörtlich in seinem Transkript. Das ist ein sichtbarer Produktfehler, nicht eine
verfehlte Kennzahl — und er besteht in der ausgelieferten Version.

## Konservativität

Entwurfsregel: **lieber einen Formatierungsfehler stehen lassen als korrekten
Text falsch verändern.** Umgesetzt durch:

- `clockTimes` verlangt eine gültige 24-Stunden-Lesung **und** einen folgenden
  Zeit-Marker. `Kapitel 3.2`, `12.50 Dollar`, `13.45 Prozent`, `25.70 Uhr` und
  `13.99 Uhr` bleiben unberührt.
- `versionNumbers` verlangt ein Kontextwort und eine vollständige
  dreiteilige Version. `Der Wert 1. 2.0` bleibt stehen.
- `spelledAcronyms` lehnt einen überlangen Lauf **ganz** ab, statt dessen erste
  fünf Buchstaben zusammenzuziehen, und lässt Läufe aus ausschließlich
  eigenständigen Einbuchstabenwörtern (`A I`) unberührt.
- `knownCompounds` und `canonicalSpellings` arbeiten über explizite,
  dokumentierte Listen. Kein Fuzzy-Matching; `Power Point` und `Team Viewer`
  werden nicht erfunden. Das führende Wort bleibt case-sensitiv, damit
  `im store kit lag nichts` gewöhnliche Prosa bleibt.
- Eigennamen-Korrektur findet nicht statt (`Verkehrs-AG`).
- Erkennungsfehler werden nicht angetastet (`Rrene` bleibt `Rrene`).

32 Unit-Tests, bei jeder Regel negative und Ambiguitätsfälle vor den positiven.
Der Formatter ist rein, synchron, ohne I/O und ohne Speech-Abhängigkeit.

## Empfehlung

**A — integrieren.**

Das Entscheidungskriterium ist erfüllt und nicht knapp: +7 Zielbegriffe,
Formatting Accuracy +0,290, WER −0,095, CER −0,025, **False Correction Count 0**,
keine neuen False Positives, acht von 15 Transkripten zeichenidentisch.

Unabhängig davon ist die Markup-Bereinigung unverzichtbar, auch wenn man den
Qualitätsgewinn ignoriert: sie behebt sichtbaren Müll im ausgelieferten
Produkt.

### Nicht integrieren würde ich

`spelledAcronyms` **nicht als eigenständige Regel** ausliefern. Sie wirkt nur
in Verbindung mit der Markup-Bereinigung; allein ist sie eine ungenutzte Regel
mit eigenem Risiko. Entweder beide oder keine.

### Offene Punkte für die Integration

Noch **nicht** verdrahtet — kein Produktionspfad ruft den Formatter. Vor der
Integration zu klären:

1. **Wo?** Nahe an `SpeechTranscriptionService`, bevor ein `TranscriptSegment`
   persistiert wird — dann sind Live-Transkript, Persistenz und Export
   konsistent. Alternativ erst beim Export, was Markup in der Datenbank ließe.
   Empfehlung: an der Quelle.
2. **Live-Transkription.** Der Formatter arbeitet auf Satzebene. Bei
   partiellen `volatileResults` darf er nicht auf einem halben Satz
   Uhrzeiten raten. Vorschlag: nur auf finalisierte Segmente anwenden.
3. **Bestandsdaten.** Bereits gespeicherte Transkripte enthalten `\letter`.
   Eine einmalige Migration wäre möglich, ist aber eine eigene Entscheidung.
4. **Locale.** Nur `de-DE` gemessen. Die Uhrzeit-Regel ist locale-abhängig und
   für `en` vorbereitet, aber unvermessen.

Keine dieser Punkte ist in Phase 4 angefasst worden.

---

# Production Integration (freigegeben 2026-10-04)

Rohdaten in
[`benchmarks/2026-10-04-production-integration.md`](benchmarks/2026-10-04-production-integration.md).

## Integrationspunkt

Beide Speech-Services formatieren an der Stelle, durch die **jeder** Transkripttext
läuft:

```
Apple-Speech-Ergebnis
  → String(result.text.characters)
  → TranscriptSemanticFormatter        (nur result.isFinal)
  → TranscriptDraft
  → TranscriptSegment (SwiftData)
  → View / TXT / Markdown / KI-Zusammenfassung
```

- [`SpeechTranscriptionService`](../Transcription/SpeechTranscriptionService.swift) — Datei-Transkription
- [`SpeechLiveTranscriber`](../Transcription/SpeechLiveTranscriber.swift) — Live-Transkription

**Genau einmal angewendet.** Keine zweite Formatierung in View, Persistenz oder
Export: beide Persistenz-Stellen (`TranscriptionViewModel.persistAtomically`,
`RecordingViewModel`) schreiben die Service-Drafts unverändert, `TranscriptExporter`
und `AISummaryViewModel.transcriptText` lesen `segment.text`.

Ein Idempotenztest sichert das zusätzlich ab: `format(format(x)) == format(x)`,
für den vollen Regelsatz und für jede Regel allein.

## Volatile vs. Final

| | Semantische Regeln | Markup-Bereinigung |
|---|---|---|
| `volatileResults` (Live-Zeile) | **nein** | **ja** |
| finalisiertes Ergebnis | ja | ja |

Gesteuert über `result.isFinal` (`SpeechModuleResult`-Extension, SDK-verifiziert).
Belegt, dass der Dateipfad ausschließlich finale Ergebnisse sieht:

```
PRESET transcription reporting=[]
PRESET timeIndexedProgressiveTranscription reporting=[fastResults, volatileResults]
```

**Abweichung von der Vorgabe, bewusst und belegt.** Die Vorgabe lautete
„volatileResults bleiben roh". Der erste Gerätetest zeigte damit:

```
LIVE VOLATILE: Die AP ist dokumentiert, die K\letter I\letter läuft auf dem Gerät
LIVE VOLATILE: Die AP ist dokumentiert, die KI läuft auf dem Gerät   ← erst final
```

Der Nutzer sieht das Markup also sekundenlang live auf dem Bildschirm — genau der
Defekt, den dieses Release beseitigen soll. Die Markup-Bereinigung ist keine
Heuristik: sie rät nichts und ist auf einem Teilsatz exakt so sicher wie auf
einem ganzen. Die Live-Zeile wird daher bereinigt, **nur** bereinigt; die
semantischen Regeln bleiben wie gefordert von volatilem Text fern. Danach:

```
LIVE VOLATILE: Die AP ist dokumentiert, die K I läuft auf dem Gerät
LIVE VOLATILE: Die AP ist dokumentiert, die KI läuft auf dem Gerät   ← final
```

## Migration des Altbestands

[`TranscriptMarkupRepair`](../Persistence/TranscriptMarkupRepair.swift), aufgerufen
im Launch-Maintenance-Pass neben `purgeExpiredTrash` — das bestehende Mechanismus
des Projekts, keine zweite Migrationsarchitektur.

Ausschließlich der Marker-Bug. Der entscheidende Test:

```
vorher:  Um 13.45 Uhr per K\letter I\letter über Store Kit, Version 1. 2.0, in Sharepoint.
nachher: Um 13.45 Uhr per KI       über Store Kit, Version 1. 2.0, in Sharepoint.
```

Nur das Markup wird aufgelöst. Uhrzeit, Version, Komposita und Schreibweise
bleiben unangetastet — bereits gespeicherter Nutzertext wird nicht rückwirkend
durch neue Heuristiken verändert.

**Der Zusammenzug folgt dem Marker, nicht einer Form** (Präzisierung 2026-10-04).
`K\letter I\letter` → `KI`, `V\letter P\letter N\letter` → `VPN`: Apples
eigener Marker zeichnet diese Zeichen als buchstabiert aus, die Buchstabenfolge
ist also vom Recognizer identifiziert und nicht von uns geraten. Damit ist dies
**keine** allgemeine Akronym-Heuristik über den Altbestand — eine unmarkierte
Folge bleibt unverändert:

| Alttext | Ergebnis |
|---|---|
| `K\letter I\letter` | `KI` |
| `V\letter P\letter N\letter` | `VPN` |
| `K I` (ohne Marker) | `K I` |
| `A B C` (ohne Marker) | `A B C` |
| `A P I` (ohne Marker) | `A P I` |
| `K\letter I` (nur erster markiert) | `K I` — der Zusammenzug reicht nicht über den Marker hinaus |

Implementiert als eigene Transformation in `TranscriptMarkupRepair.repair(_:)`,
**nicht** als Formatter-Regel: der gemessene Regelsatz des Formatters bleibt
dadurch unverändert, und die Migration kann nicht versehentlich mehr tun als
dieses eine. Idempotent (nach dem Lauf existiert kein Marker mehr, den der
Filter finden könnte) und mit denselben Backslash-Negativtests abgesichert.

Gefiltert über den Marker statt über ein Einmal-Flag: CloudKit kann ein
betroffenes Segment von einem anderen Gerät liefern, lange nachdem ein Flag
gesetzt worden wäre. Jedes Segment wird dadurch trotzdem genau einmal angefasst,
und ein Lauf ohne Treffer kostet einen indizierten Fetch.

## Locale

| Regel | Scope | Abdeckung |
|---|---|---|
| `spelledLetterMarkup` | locale-independent | alle |
| `knownCompounds` | locale-independent | alle |
| `canonicalSpellings` | locale-independent | alle |
| `clockTimes` | **locale-specific** | de (`Uhr`), en (`o'clock`) — andere Sprachen **übersprungen** |
| `versionNumbers` | locale-specific | de + en (gemeinsame Schlüsselwörter) |
| `spelledAcronyms` | locale-specific | Guard als de/en-Vereinigung |

`ruleScopes` ist maschinenlesbar, ein Test erzwingt Vollständigkeit — eine neue
Regel kann nicht ohne Klassifikation hinzukommen. Für eine nicht gelistete
Sprache greift die Uhrzeit-Regel **nicht** (locale-gated statt verallgemeinert;
Test mit `fr-FR`).

## en-US-Benchmark

15 eingefrorene en-US-Fixtures (Stimme Samantha), gleiche fünf Kategorien.

| Metrik | Vorher | Nachher | Delta |
|---|---:|---:|---:|
| Zielbegriffe | 20/31 | **21/31** | +1 |
| Formatting Accuracy | 0,800 | **0,840** | +0,040 |
| WER | 0,195 | **0,173** | −0,022 |
| CER | 0,065 | **0,064** | −0,001 |
| False Positives | 0 | 0 | 0 |
| **False Correction Count** | — | **0** | — |

**Keine Regression.** Genau ein Transkript geändert:
`Speech Analyzer` → `SpeechAnalyzer`.

Marker-Audit en-US: **`none`** — der `\letter`-Marker tritt im englischen Korpus
nicht auf.

Drei englische Befunde, die der Bericht nicht glättet:

1. **Die Uhrzeit-Regel feuert in en-US nicht** (+0,000). Die Engine liefert
   `1345 o'clock`, nicht `13.45 o'clock` — alle Trennzeichen fehlen, das ist
   Klasse C (Tokenisierung), kein Formatierungsfehler. Eine Regel „vier Ziffern
   vor Zeit-Marker → `hh:mm`" wäre messbar (+2 Begriffe), rät aber Ziffergrenzen.
   **Nicht implementiert** — außerhalb des freigegebenen Scope, Entscheidung offen.
2. **`AnalysisContext` wird in en-US nicht korrigiert.** Die Engine liefert
   `analysis context` klein, und das führende Wort ist case-sensitiv. Richtig so:
   „analysis context" *ist* im Englischen eine gewöhnliche Wortfolge.
3. **`AI` wird nicht zusammengezogen.** `A` und `I` sind beide eigenständige
   Wörter, der Ambiguitäts-Guard lehnt den Lauf ab. Das Markup verschwindet
   trotzdem — der Nutzer sieht `A I`, nie `A\letter I\letter`. Dokumentierte
   Grenze, kein Versehen.

## Performance

`PERF formatter 1200 segments in 0.135s (0.112ms per segment)` — auf dem Gerät
gemessen, 1200 Segmente entsprechen etwa einer Stunde Aufnahme. Sechs
Regex-Durchläufe je Segment, vernachlässigbar gegen die Transkription selbst
(~0,08 s pro Satz).

## Bekannte Grenzen (Stand 1.2)

Bewusst offen gelassen, jeweils gemessen und begründet:

| Grenze | Klasse | Entscheidung |
|---|---|---|
| `Chemnitzer Verkehrs AG` → `-AG` | B | Eigennamen-Korrektur ohne generische Grundlage — **nein** |
| `19216824` → `192.168.2.4` | C | Trennzeichen verloren, mehrere gleich gute Lesungen — **nein** |
| en-US `1345 o'clock` → `13:45` | C | Dieselbe Klasse. Messbar +2 Begriffe, würde aber Ziffergrenzen erraten — **nicht implementiert** (Entscheidung 2026-10-04) |
| en-US `AI` bleibt `A I` | D | `A` und `I` sind eigenständige Wörter, Ambiguitäts-Guard greift. Markup verschwindet trotzdem |
| en-US `analysis context` | B | Führendes Wort case-sensitiv; im Englischen eine gewöhnliche Wortfolge |
| Erkennungsfehler (`SwiftOE`, `AP`, `Analizer`) | A | Außerhalb der Reichweite jeder Nachbearbeitung |

## Separater Wartungspunkt (nicht Teil dieses Scope)

Die **vollständige** Testsuite auf echtem Gerät bricht ab: 16 Suites scheitern
mit `NSInternalInconsistencyException: "No eligible connection available"` beim
Anlegen des CloudKit-Containers im Test-Host (AISummaryViewModel,
CloudAudioReconciler, EditorViewModel, Merge, Mix, LibraryImport,
RecordingViewModel, TranscriptSegment, TranscriptionGating/Preview/ViewModel).

**Pre-existing, gemessen nicht vermutet:** in einem Worktree auf `2f41f3b` —
dem Stand vor jeder Phase-4-Arbeit — tritt derselbe Fehler auf. Die
transkriptionsrelevanten Suites laufen auf dem Gerät vollständig grün; die
übrigen laufen im Simulator grün. Im Rahmen der Transkriptionsarbeit wurde
daran bewusst **nichts** geändert.
