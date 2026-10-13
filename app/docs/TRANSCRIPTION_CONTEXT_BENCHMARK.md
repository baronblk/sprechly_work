# AnalysisContext Benchmark — Sprechly 1.2

Ergebnis des A/B-Experiments aus Phase 2. Rohdaten unverändert in
[`benchmarks/2026-10-04-context-experiment.md`](benchmarks/2026-10-04-context-experiment.md).

**Kurzfassung: `AnalysisContext.contextualStrings` hat in Sprechlys Pipeline
keine messbare Wirkung — die Transkripte sind mit und ohne Kontext zeichengleich
identisch.**

---

## Environment

| | |
|---|---|
| Gerät | iPhone 17 Pro, iOS 27.0.1 |
| App | Branch `feature/1.2-transcription-quality`, Deployment-Target 26.0 |
| SDK | iPhoneOS 27.0 (Xcode 27.0) |
| Locale | `de-DE` |
| Transcriber | `SpeechTranscriber(preset: .transcription)` — der Datei-Pfad der App |
| Fälle | 15 Sätze, 31 Zielbegriffe, 5 Kategorien |
| Datum | 2026-10-04 |

## Method

1. Jeder Satz wird auf dem Gerät mit `AVSpeechSynthesizer` (de-DE) in eine Datei
   gerendert. Beide Läufe lesen **dieselbe Datei** — der Input ist bitgleich.
2. **Lauf A (Baseline):** die unveränderte Pipeline, kein Kontext.
3. **Lauf B (Context):** identische Pipeline, identisches Audio, zusätzlich
   `AnalysisContext.contextualStrings[.general]` mit den Zielbegriffen des Falls
   **plus Köderbegriffen, die im Satz nicht vorkommen** (False-Positive-Test).
4. Einzige Variable ist der Kontext. Keine weitere Pipelineänderung.

**Normalisierung** (bewusst eng, in `BenchmarkMetrics`): Kleinschreibung,
Whitespace, bedeutungslose Satzzeichen. Komma, Punkt, Doppelpunkt, Bindestrich
und `&` bleiben erhalten, damit `9,99` vs. `999`, `1.2.0` vs. `1. 2.0` und
`13:45` vs. `13.45` sichtbare Fehler bleiben. Es gibt **keine** fallbezogene
Sonderbehandlung und keine Ersetzung der getesteten Begriffe. Mehrwort-Begriffe
müssen als zusammenhängende Token-Folge auftreten.

**Einschränkung, die für alle Zahlen hier gilt:** Synthetische Sprache ist
sauber artikuliert, ohne Raumakustik, Nebengeräusche, Dialekt oder Versprecher.
Diese Messung erlaubt **nur** den Vergleich zweier Varianten bei identischem
Input — keine Aussage über reale Transkriptionsqualität.

---

## Aggregate Results

| Metric | Baseline | Context | Difference |
|---|---:|---:|---:|
| WER | 0,253 | 0,253 | **0,000** |
| CER | 0,069 | 0,069 | **0,000** |
| Target Term Accuracy | 13/31 | 13/31 | **0** |
| Target Term Recall | 0,419 | 0,419 | **0,000** |
| False Positives | 0 | 0 | 0 |
| Laufzeit gesamt | 1,545 s | 1,340 s | −0,205 s |

Die Transkripte beider Läufe sind **zeichengleich identisch** (per `diff`
geprüft). Kein einziger Begriff wechselte von „miss" zu „hit" oder umgekehrt.

## Per-category Results

| Kategorie | Terms Baseline | Terms Context | WER Baseline | WER Context |
|---|---:|---:|---:|---:|
| Names | 0/4 | 0/4 | 0,417 | 0,417 |
| Technical | 2/7 | 2/7 | 0,292 | 0,292 |
| Abbreviations | 2/4 | 2/4 | 0,250 | 0,250 |
| Numbers | 4/6 | 4/6 | 0,205 | 0,205 |
| Mixed | 5/10 | 5/10 | 0,159 | 0,159 |

## Per-target Results

Alle 16 verfehlten Begriffe blieben mit Kontext verfehlt:

| Term | Baseline | Context | Improved? |
|---|---|---|---|
| René | miss (`Rrene`) | miss | **nein** |
| Jacqueline | miss (`Ja,quelene`) | miss | **nein** |
| Hanning | miss (`Henning`) | miss | **nein** |
| Chemnitzer Verkehrs-AG | miss (`Chemnitzer Verkehrs AG`) | miss | **nein** |
| StoreKit | miss | miss | **nein** |
| CloudKit | miss | miss | **nein** |
| SwiftUI | miss | miss | **nein** |
| SpeechAnalyzer | miss | miss | **nein** |
| AnalysisContext | miss | miss | **nein** |
| CVAG | miss | miss | **nein** |
| API | miss (`AP`) | miss | **nein** |
| KI | miss (`K⍰I⍰`) | miss | **nein** |
| VPN | miss | miss | **nein** |
| 13:45 | miss (`13.45`) | miss | **nein** |
| 1.2.0 | miss (`1. 2.0`) | miss | **nein** |
| 192.168.2.4 | miss | miss | **nein** |

Getroffen wurden ohne Kontext und unverändert mit Kontext: `SharePoint`,
`Docker`, `VPN`/`MDM` (in `abbrev-01`), `9,99`, `4. Oktober 2026`, `10`,
`Markdown`, `René`/`CVAG` im Mixed-Satz (dort anders erkannt als isoliert).

## False Positives

**Keine.** In beiden Läufen tauchte kein Köderbegriff auf, der nicht gesprochen
wurde. Das ist allerdings kein Qualitätsnachweis des Kontexts — es folgt
zwangsläufig daraus, dass der Kontext überhaupt nichts verändert hat.

## Performance

Keine messbare Verschlechterung. Der Kontextlauf war mit 1,340 s sogar minimal
schneller als die Baseline (1,545 s); bei Laufzeiten um 0,1 s je Fall ist das
Rauschen, kein Effekt. Auch 104 Kontextbegriffe kosteten nichts.

## Skalierung (0 / 10 / 50 / 100 Begriffe)

| Context-Größe | Terms | WER | Laufzeit |
|---:|---:|---:|---:|
| 0 | 2/4 | 0,100 | 0,109 s |
| 14 | 2/4 | 0,100 | 0,107 s |
| 54 | 2/4 | 0,100 | 0,103 s |
| 104 | 2/4 | 0,100 | 0,100 s |

Identisch über alle Größen — weder Wirkung noch Nebenwirkung, weder
Performanceeinbruch noch False Positives.

## Verifikation des Messaufbaus

Ein Null-Ergebnis dieser Sauberkeit kann zwei Ursachen haben: Das Feature wirkt
nicht — oder der Kontext kam nie an. Ein separater Gerätelauf
(`AnalysisContextWiringTests`) schließt Letzteres aus:

```
WIRING setContext:   before=0 after=3 values=["Proxmox", "CloudKit", "Chemnitzer Verkehrs-AG"]
WIRING initializer:  count=3      values=["Proxmox", "CloudKit", "Chemnitzer Verkehrs-AG"]
```

Der Analyzer hat die Begriffe nachweislich übernommen — über `setContext` wie
über den Initializer. Der Messaufbau war korrekt.

## Conclusion

**C — keine belastbare Wirkung.**

`AnalysisContext.contextualStrings` wird von `SpeechTranscriber` in dieser
Konfiguration (de-DE, `.transcription`-Preset, Datei-Transkription, iOS 27.0.1)
nachweislich entgegengenommen, verändert das Ergebnis aber in keinem einzigen
Zeichen. Die Vermutung aus der Roadmap, dies sei „der einzige Hebel mit
plausibler Wirkung auf die Erkennungsqualität", ist damit **widerlegt**.

Denkbar bleibt, dass die Begriffe nur von anderen Modulen ausgewertet werden
(etwa `DictationTranscriber`, der eigene `ContentHint`-Optionen besitzt) oder
nur in anderen Sprachen/Presets greifen. Für Sprechlys tatsächlichen Pfad ist
das Ergebnis jedoch eindeutig.

## Recommendation

**Persönliches Wörterbuch: NEIN** — nicht auf diesem Weg.

Das Entscheidungskriterium aus dem Auftrag lautete: deutlich höhere
Target-Term-Trefferquote oder relevante Verbesserung bei zuvor falsch erkannten
Begriffen. Gemessen wurde eine Differenz von exakt null bei 31 Zielbegriffen über
fünf Kategorien. Eine Wörterbuch-UI würde eine Funktion versprechen, die das
System nicht liefert.

**Empfohlene maximale Begriffszahl:** entfällt — mangels Wirkung gibt es nichts
zu dimensionieren. (Falls der Punkt je wieder relevant wird: 100 Begriffe waren
technisch unproblematisch.)

**Datenmodell-Vorschlag:** entfällt.
