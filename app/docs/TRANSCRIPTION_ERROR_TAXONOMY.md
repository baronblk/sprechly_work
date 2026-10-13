# Transcription Error Taxonomy — Sprechly 1.2, Phase 4

Klassifikation **jedes** verfehlten Zielbegriffs der eingefrorenen Baseline.
Grundlage: `SpeechTranscriber(preset: .transcription)` auf den festen Fixtures,
iPhone 17 Pro / iOS 27.0.1, `de-DE`. Rohdaten unverändert in
[`benchmarks/2026-10-04-semantic-formatting.md`](benchmarks/2026-10-04-semantic-formatting.md).

**Baseline: 13 von 31 Zielbegriffen getroffen, 18 verfehlt.** Die 18 Verfehler
sind unten vollständig und einzeln zugeordnet — keine Sammelposten.

---

## Warum die Baseline neu eingefroren wurde

Die Phase-2- und Phase-3-Zahlen für **denselben** Transcriber wichen um 0,019
WER voneinander ab, weil `AVSpeechSynthesizer` zwischen Läufen kein bitgleiches
Audio erzeugt. Ab Phase 4 liest jeder Lauf dieselben 15 Dateien aus
`Tests/Fixtures/Transcription`, per SHA-256-Manifest festgenagelt und von
`BenchmarkFixtureTests` geprüft. Ein neu generiertes Fixture lässt den Test
fehlschlagen, statt eine aufgezeichnete Baseline still zu entwerten.

Die neue Baseline (WER 0,250 · 13/31) ist damit **nicht** direkt mit den
Phase-2/3-Zahlen vergleichbar. Jene bleiben als eigene Datenpunkte bestehen.

## Klassen

| Klasse | Bedeutung | Durch Nachbearbeitung behebbar |
|---|---|---|
| **A — Recognition** | Das Modell hat etwas anderes gehört | ❌ nein |
| **B — Formatting** | Richtige Wörter, falsche Form | ✅ ja |
| **C — Tokenization** | Trennzeichen vollständig verloren | ⚠️ nur durch Raten |
| **D — Acronym / Markup** | Richtig gehört, Ausgabe durch Engine-Markup verunreinigt | ✅ ja |
| **E — Ambiguous** | Engine korrekt, **Messmethode** sieht den Treffer nicht | ❌ Metrik-Grenze |

Die Zuordnung erfolgt von Hand anhand der Rohtexte und ist dort, wo die Metrik
es sehen kann, durch deren Formatierungs/Erkennungs-Trennung gestützt. Wo beide
auseinandergehen, ist das unten vermerkt — die Metrik ist nicht die Instanz, die
über die Klasse entscheidet.

---

## A — Recognition (6)

Das akustische Modell hat die Wörter nicht getroffen. Kein Formatter erreicht
diese Fälle; sie wären nur über ein anderes Modell oder ein benutzerdefiniertes
Sprachmodell angreifbar.

| Fall | Ziel | Ausgabe | Anmerkung |
|---|---|---|---|
| `technical-03` | `SwiftUI` | `SwiftOE` | Lautfolge daneben |
| `technical-04` | `SpeechAnalyzer` | `Speech Analizer` | zusätzlich falsch geschrieben, nicht nur getrennt |
| `technical-04` | `AnalysisContext` | `Analysis Kontext` | eingedeutschtes zweites Wort |
| `abbrev-02` | `API` | `AP` | Buchstabe fehlt |
| `mixed-02` | `API` | `AP` | derselbe Fehler, zweiter Kontext |
| `numbers-04` | `1.2.0` | `Version als Bild 10` | vollständiger Zusammenbruch des Satzteils |

`Analysis Kontext` ist der Grenzfall: die Trennung allein wäre Klasse B, aber
`Kontext` ≠ `Context` ist eine Schreibungsabweichung, die eine Komposita-Regel
nur durch Raten überbrücken könnte. Darum A.

## B — Formatting (7)

Die Wörter sind da, die Form nicht. Das ist die Klasse, für die Phase 4 gebaut
wurde.

| Fall | Ziel | Ausgabe | Behandelt |
|---|---|---|---|
| `technical-02` | `StoreKit` | `Store Kit` | ✅ `knownCompounds` |
| `technical-02` | `CloudKit` | `Cloud Kit` | ✅ `knownCompounds` |
| `numbers-02` | `13:45` | `13.45` | ✅ `clockTimes` |
| `mixed-01` | `13:45` | `13.45` | ✅ `clockTimes` |
| `mixed-02` | `1.2.0` | `1. 2.0` | ✅ `versionNumbers` |
| `mixed-03` | `Markdown` | `Mark Down` | ✅ `knownCompounds` |
| `names-01` | `Chemnitzer Verkehrs-AG` | `Chemnitzer Verkehrs AG` | ❌ **bewusst nicht** |

**`Verkehrs-AG` bleibt unkorrigiert.** Eine Regel „Wort + AG → Bindestrich"
wäre eine Eigennamen-Korrektur ohne generisch belastbare Grundlage: ob eine
Firma mit Bindestrich, Leerzeichen oder zusammen geschrieben wird, lässt sich
dem Audio nicht entnehmen. Lieber ein stehender Formatierungsfehler als eine
erfundene Firmenschreibweise.

## C — Tokenization (1)

| Fall | Ziel | Ausgabe |
|---|---|---|
| `numbers-03` | `192.168.2.4` | `19216824` |

Alle Trennzeichen sind weg. Aus `19216824` eine IP zu rekonstruieren heißt
raten — `192.168.2.4`, `19.216.8.24` und `192.1.68.24` sind aus der Ziffernfolge
gleich gut begründbar. Nicht behandelt.

Die Metrik zählt diesen Fall als Formatierungsfehler, weil das Ziffern-Skelett
übereinstimmt. Fachlich ist er es nicht — die Information über die Gruppierung
ist verloren, nicht nur falsch dargestellt. Darum eigene Klasse.

## D — Acronym / Markup (1) — der schwerste Befund

| Fall | Ziel | Ausgabe | Behandelt |
|---|---|---|---|
| `abbrev-02` | `KI` | `K\letter I\letter` | ✅ `spelledLetterMarkup` + `spelledAcronyms` |

`SpeechTranscriber` liefert buchstabiert gehörte Zeichen mit einem **literalen**
Backslash-Token. Byteweise verifiziert: `4b 5c 6c 65 74 74 65 72` = `K\letter`.

Das ist kein Mess-, sondern ein Produktfehler.
[`SpeechTranscriptionService.swift:86`](../Transcription/SpeechTranscriptionService.swift#L86)
extrahiert den Text in Produktion mit genau demselben
`String(result.text.characters)` und ohne jede Bereinigung — das Markup landet
also im gespeicherten `TranscriptSegment` und in jedem TXT-/Markdown-Export.
Wer Buchstaben einzeln spricht, findet `\letter` wörtlich in seinem Transkript.

**Die Metrik hat diesen Fall als Erkennungsfehler eingeordnet**, weil das
eingefügte `letter` das Skelett zerstört. Die Klassifikation hier korrigiert
das: gehört wurde `K` und `I`, und zwar richtig.

### Marker-Audit

Es wird ausschließlich behandelt, was belegt ist. Das Benchmark meldet jede
Backslash-Sequenz im Rohoutput:

```
FORMAT MARKUP abbrev-02 found=\letter \letter
FORMAT MARKUP AUDIT \letter=2
```

**Gefunden: nur `\letter`, zwei Vorkommen, in einem von 15 Fällen.** Kein
`\number`, kein `\spell`, keine andere Escape-Sequenz. Marker wie `\number`
werden daher **nicht** behandelt — sie sind nicht belegt. Taucht einer auf,
erscheint er in dieser Audit-Zeile, bevor eine Regel dafür entsteht.

## E — Ambiguous (3) — Grenze der Messmethode, nicht Fehler der App

| Fall | Ziel | Ausgabe | Bewertung |
|---|---|---|---|
| `mixed-01` | `CVAG` | `CVAG-Unterlagen` | Engine korrekt |
| `mixed-02` | `VPN` | `VPN-Zugang` | Engine korrekt |
| `mixed-03` | `KI` | `KI-Zusammenfassung` | Engine korrekt |

`BenchmarkMetrics.containsTerm` verlangt übereinstimmende **Token**, und ein
Bindestrich-Kompositum ist ein Token. `KI-Zusammenfassung` enthält `KI` für
jeden Leser, für die Metrik nicht.

Das ist bewusst nicht „repariert". Die strenge Token-Gleichheit ist der Grund,
warum `9,99` nicht auf `999` und `KI` nicht auf `Kino` passt — die Strenge
aufzugeben, um drei Fälle schöner aussehen zu lassen, würde die Aussagekraft
aller anderen Zahlen senken. Stattdessen gilt: **die Baseline von 13/31
unterschätzt die tatsächliche Erkennungsleistung um drei Begriffe.**

---

## Verteilung

| Klasse | Anzahl | Anteil der 18 Verfehler | behandelt |
|---|---:|---:|---:|
| A — Recognition | 6 | 33 % | 0 |
| B — Formatting | 7 | 39 % | 6 |
| C — Tokenization | 1 | 6 % | 0 |
| D — Acronym / Markup | 1 | 6 % | 1 |
| E — Ambiguous | 3 | 17 % | 0 |
| **Summe** | **18** | **100 %** | **7** |

**Behebbar waren 8 von 18 (B + D), behandelt werden 7.** Übrig bleiben
`Verkehrs-AG` (bewusst) und, außerhalb der Reichweite, A, C und E.

## Nicht in der Taxonomie: unsichtbare Schreibungsfehler

Zwei Fälle sind für die Metrik **kein** Verfehler, weil `containsTerm`
normalisiert und dabei kleinschreibt — für den Leser sind sie aber falsch:

| Fall | Ausgabe | Korrekt |
|---|---|---|
| `technical-01` | `Sharepoint` | `SharePoint` |
| `mixed-01` | `Sharepoint` | `SharePoint` |

Beide zählen in der Baseline als Treffer. Die `canonicalSpellings`-Regel
behandelt sie trotzdem, und das ist der Grund, warum diese Regel in der
Messung **0,000** bewegt: Formatting Accuracy kann sie strukturell nicht sehen.
Ihr Nutzen liegt im Text, den der Nutzer liest, nicht in der Kennzahl. Die
Regel wird deshalb nicht über die Messung begründet, sondern über diese zwei
belegten Vorkommen.

---

## Real-World-Befund 2026-10-05: Zahlen über Segmentgrenzen hinweg

Aus einer echten Aufnahme (02:52, Deutsch, auf Gerät, Build 1.2.0 (11)) —
**kein Benchmark-Audio**, deshalb hier getrennt geführt.

Der Recognizer setzt Segmentgrenzen mitten in eine Zahl:

| Segment endet mit | Nächstes Segment beginnt mit | Gemeint war |
|---|---|---|
| `… stammt aus dem Jahr 18` | `64 und zählt zu den ältesten …` | **1864** |
| `… Bezahlt man wohl 3` | `,50 und dann kann man da hoch.` | **3,50** |

Beide Fälle sind weder A noch B: die Wörter stimmen, die Form innerhalb jedes
Segments stimmt auch — **die Information liegt zwischen zwei Segmenten**. Der
heutige Formatter arbeitet pro finalisiertem Segment und kann das prinzipiell
nicht sehen.

Bemerkenswert: die KI-Zusammenfassung derselben Aufnahme setzt beide Zahlen
korrekt zusammen („Der 1864 erbaute …", „gegen 3,50 €"), weil sie den
zusammengefügten Volltext liest. Der Schaden beschränkt sich also auf die
Segmentansicht und den Transkript-Export.

**Nicht in 1.2 behandelt. Scope Freeze bleibt.** Als eigener Punkt notiert:

> **Cross-Segment Formatting / Segment Boundary Repair** — zusammengehörige
> Zahlen (und womöglich Komposita) über eine Segmentgrenze hinweg
> zusammenführen, ohne Zeitstempel oder Tap-to-Seek zu beschädigen.

Offene Fragen für eine spätere Untersuchung, bevor eine Zeile Code entsteht:
an welches Segment gehört die zusammengeführte Zahl, was passiert mit dem
Zeitstempel des zweiten Segments, wie oft tritt der Fall überhaupt auf, und wie
unterscheidet man ihn sicher von zwei wirklich getrennten Zahlen („… Kapitel 18"
/ „64 Prozent davon …"). Ohne belastbare Antwort darauf wäre jede Regel genau
die Art von Raterei, die dieser Formatter vermeidet.

## Real-World-Erkennungsfehler, bewusst nicht behandelt

Dieselbe Aufnahme zeigt echte Erkennungs- und Tokenisierungsfehler der Klasse A
bzw. C, für die es **keine sichere Formatterregel** gibt und die deshalb stehen
bleiben: `El-Sandstein-Gebirge` / `Elb-Sandstein-gebirges`, `Sandsteinhoffläche`,
`Tadelbergplateau`, `hoheinerne`, `desandsteingebirges`. Eigennamen und
zusammengesetzte Ortsbezeichnungen zu „korrigieren" hieße, sie zu erfinden.
