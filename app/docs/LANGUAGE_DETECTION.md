# Spracherkennung: welche Sprache wird gesprochen?

Rohdaten unverändert in
[`benchmarks/2026-10-14-language-detection.md`](benchmarks/2026-10-14-language-detection.md).

**Kurzfassung: Die Regel „Selbstkonsistenz" trifft 30 von 30 Fällen, die
Modellkonfidenz allein nur 28 von 30. Empfehlung A — integrieren, mit einer
Probe auf dem Anfang der Aufnahme und höchstens drei Kandidatensprachen.**

---

## Das Problem

Die Sprache der Transkription kam bisher aus den Gerätesprachen. Nimmt man auf
einem deutschen iPhone englisch auf, läuft das deutsche Modell und produziert
Unsinn, bis man von Hand umstellt.

## Der Denkfehler im naheliegenden Ansatz

Transkribieren und den Text von `NLLanguageRecognizer` einschätzen lassen wirkt
naheliegend, taugt aber nicht: Ein deutsches Modell erzeugt aus englischer
Sprache deutsch *aussehende* Wörter. Der Erkenner sieht dann kaum die
gesprochene, sondern die Modellsprache — und bestätigt die falsche Wahl.

Gemessen wurden deshalb zwei Regeln, die ohne diese Annahme arbeiten. Beide
transkribieren **dieselbe Datei mit jeder Kandidatensprache**:

- **A Selbstkonsistenz** — gilt nur der Lauf, dessen Text sich selbst als die
  Sprache ausweist, in der er transkribiert wurde. Bei mehreren entscheidet die
  Erkennungskonfidenz.
- **B Modellkonfidenz** — der Lauf mit der höheren mittleren
  `transcriptionConfidence` (Attribut des Speech-Frameworks).

## Messaufbau

| | |
|---|---|
| Gerät | „Mein iPhone", iPhone 17 Pro, iOS 27.0.1 |
| Engine | `SpeechTranscriber`, Zuführung identisch zu `SpeechTranscriptionService`, zusätzlich `attributeOptions: [.transcriptionConfidence]` |
| Audio | `Tests/Fixtures/Transcription`, 30 eingefrorene Dateien (15 deutsch, 15 englisch), SHA-256 festgenagelt |
| Kandidaten | `de-DE` und `en-US`, beide Modelle installiert |
| Läufe | 60 (30 Dateien × 2 Sprachen) |
| Laufzeit | 5,3 s für alles |
| Datum | 2026-10-14 |

## Ergebnis

| Regel | Treffer | Unentschieden |
|---|---:|---:|
| **A Selbstkonsistenz** | **30/30** | 0 |
| B Modellkonfidenz | 28/30 | — |

Von 60 Proben waren 32 selbstkonsistent: die 30 richtigen plus zwei Fälle, in
denen auch das falsche Modell Text lieferte, der sich selbst bestätigte. Dort
entschied die Erkennungskonfidenz — beide Male richtig:

| Fall | gesprochen | de-DE | en-US | Wahl |
|---|---|---:|---:|---|
| `names-01` | de | 1,000 | 0,941 | de-DE ✓ |
| `technical-04` | de | 1,000 | 0,990 | de-DE ✓ |

**Das ist die dünnste Stelle der Regel:** bei `technical-04` lagen 0,010
zwischen richtig und falsch. Bei nah verwandten Sprachen dürfte dieser Abstand
häufiger und kleiner werden.

### Warum B versagt

`en-names-01` (englisch gesprochen):

```
de-DE  konfidenz=0.853  →  "Renée works at the Chemnitz Transport Company."
en-US  konfidenz=0.824  →  "Renee works at the Kamnitz Transport Company."
```

Das deutsche Modell war **selbstsicherer** als das englische, obwohl englisch
gesprochen wurde. Die Konfidenz sagt, wie sicher ein Modell seine eigene
Ausgabe findet — nicht, ob es die richtige Sprache ist. Derselbe Effekt bei
`en-numbers-04`.

### Wie deutlich der Unterschied sonst ist

`names-01`, deutsch gesprochen:

```
de-DE  →  "René arbeitet bei der Chemnitzer Verkehrs AG."
en-US  →  "Renee are bited by der kemnitza fakirs agi."
```

## Einschränkungen

Was diese Zahlen **nicht** belegen:

- **Synthetische Sprache.** Sauber artikuliert, ohne Raumhall, Nebengeräusche,
  Dialekt oder Versprecher. Reale Aufnahmen können die Regel schwächer treffen.
- **Nur zwei, weit entfernte Sprachen.** Deutsch gegen Englisch ist der
  einfache Fall. Deutsch/Niederländisch, Spanisch/Portugiesisch oder
  Dänisch/Norwegisch sind **ungemessen** — und genau dort liegt die Schwäche
  der Regel.
- **Keine Regionen.** `NLLanguageRecognizer` liefert eine Sprache, keine
  Region. `en-US` und `en-GB` sind so nicht unterscheidbar; welche Region es
  wird, entscheiden die Gerätesprachen.

## Integration

In `LanguageDetection` umgesetzt, von `TranscriptionViewModel` aufgerufen:

- **Nur beim ersten Lauf.** Hat die Aufnahme schon eine Sprache
  (`Recording.transcriptionLanguage`), ist das die Wahl des Nutzers und wird
  nicht hinterfragt.
- **Nur wenn es etwas zu entscheiden gibt.** Bei einer installierten Sprache
  wird nichts probiert.
- **Höchstens drei Kandidaten**, eine je Sprache, Gerätesprachen zuerst. Jeder
  Kandidat ist ein eigener Lauf, deshalb eine harte Obergrenze.
- **Probe auf den ersten 25 s**, nicht auf der ganzen Datei.
- **Unentschieden heißt: bleiben.** Findet sich keine selbstkonsistente Probe,
  bleibt die bisherige Sprache stehen, statt zu raten.
- **Sichtbar.** Die Ansicht zeigt „Sprache erkannt: …", und der Picker bleibt
  das letzte Wort — eine Korrektur von Hand wird gespeichert und danach
  respektiert.

## Offen

- Nah verwandte Sprachen messen. Dafür braucht es Fixtures in einer zweiten
  Sprachfamilie (etwa Niederländisch gegen Deutsch).
- Sprachwechsel **innerhalb** einer Aufnahme bleibt unbehandelt: erkannt wird
  eine Sprache je Aufnahme, nicht je Abschnitt.
