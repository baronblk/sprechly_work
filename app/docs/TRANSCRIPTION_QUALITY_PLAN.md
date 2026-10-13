# Sprechly 1.2 — Transcription Quality & Personal Vocabulary

Plan für 1.2, Stand 2026-10-04. Das Ist-Modell der Pipeline steht in
[TRANSCRIPTION_PIPELINE.md](TRANSCRIPTION_PIPELINE.md) → Abschnitt 0.

**Phase 1 (dieses Dokument) ändert keine Speech-Logik.** Es legt fest, was
gemessen wird, bevor irgendetwas optimiert wird.

---

## 1. Was 1.2 beantworten muss

Nach 1.2 soll nicht „fühlt sich besser an" im Changelog stehen, sondern:

> Bei diesen N Testfällen erkennt Sprechly X von Y Schlüsselbegriffen — vorher
> waren es Z.

Dafür braucht es **zuerst** eine Messung, die ohne Code-Änderung reproduzierbar
ist. Erst danach wird entschieden, ob ein Umbau überhaupt lohnt.

---

## 2. Die harte Einschränkung

**`SpeechAnalyzer` und `SpeechTranscriber` laufen nicht im Simulator.** Jede
Messung der Erkennungsqualität muss auf echter Hardware stattfinden.

Konsequenz für die Architektur der Baseline:

- Die Messung läuft als **Swift-Testing-Suite auf dem Gerät**
  (`xcodebuild test -destination 'platform=iOS,id=<device>'`), nicht im
  Simulator.
- Im Simulator **überspringt** sich die Suite selbst, statt rot zu werden —
  sonst bricht die bestehende CI (die auf Simulatoren läuft).
- Ergebnis ist kein Pass/Fail, sondern ein **Messprotokoll**, das die Suite
  ausgibt und das versioniert abgelegt wird.

---

## 3. Testkorpus

### 3.1 Woher das Audio kommt

Drei Optionen, bewertet:

| Variante | Reproduzierbar | Repo-Größe | Realitätsnähe | Urteil |
|---|---|---|---|---|
| Echte Aufnahmen | nein (nicht wiederholbar) | hoch | hoch | ungeeignet als Fixture |
| macOS `say` → Dateien im Repo | **ja** | ~4 MB bei 20 Fällen | niedrig | brauchbar |
| `AVSpeechSynthesizer` **auf dem Gerät** | ja | **0 MB** | niedrig | **bevorzugt** |

**Entscheidung: `AVSpeechSynthesizer` zur Testlaufzeit auf dem Gerät.** Die
Suite synthetisiert jeden Satz selbst, transkribiert ihn und vergleicht. Kein
Audio im Repository, keine Binärdateien in der Historie, und der Input ist bei
jedem Lauf bitgleich derselbe.

Falls sich im Praxistest zeigt, dass `AVSpeechSynthesizer.write` nicht stabil
nutzbar ist, ist der `say`-Weg der Rückfall — dann liegen die Fixtures unter
`Tests/Fixtures/Transcription/` und werden per Skript neu erzeugt.

### 3.2 Was synthetische Sprache *nicht* misst

Ehrlich festgehalten, damit die Zahlen später nicht überinterpretiert werden:

TTS-Audio ist sauber artikuliert, ohne Raumhall, Nebengeräusche, Dialekt,
Versprecher oder Übersprechen. Ein Wert von „18 von 20 Begriffen erkannt" sagt
**nichts** über die Qualität bei einer echten Besprechungsaufnahme.

Wofür die Messung taugt: **Vergleich zweier Varianten bei identischem Input.**
Genau das ist die Frage von 1.2 — hilft `contextualStrings` oder nicht. Für die
absolute Qualität bleibt Renes Urteil auf echten Aufnahmen maßgeblich.

### 3.3 Kategorien und Fälle

Je Fall: Satz, erwartete Schlüsselbegriffe, Kategorie, Sprache, optionale
Kontextwörter. Bewertet wird **nicht** die Wortfehlerrate des ganzen Satzes,
sondern ob die Schlüsselbegriffe getroffen wurden — darum geht es beim
Wörterbuch.

| Kategorie | Beispiele für Schlüsselbegriffe |
|---|---|
| `names` | René, Jacqueline, Hanning & Kahl, Chemnitzer Verkehrs-AG |
| `technical` | SharePoint, Intune, Proxmox, Docker, StoreKit, CloudKit, SpeechAnalyzer |
| `abbreviations` | CVAG, M365, API, VPN, MDM, KI |
| `numbers` | 9,99 Euro; 192.168.2.4; 13:45 Uhr; 4. Oktober 2026; Version 1.2.0; Build 10 |
| `mixed` | Kombinationen aus allen vier in einem Satz |

Alle Begriffe sind öffentlich oder generisch. **Keine** privaten Kontaktdaten,
Telefonnummern, E-Mail-Adressen, Zugangsdaten oder internen Unternehmensdaten —
das Korpus ist für ein öffentliches Repository geeignet.

### 3.4 Bewertung

Pro Fall:

- **Treffer**: Schlüsselbegriff steht normalisiert im Transkript
  (Groß-/Kleinschreibung, Satzzeichen und Bindestriche normalisiert)
- **Fehltreffer**: fehlt oder ist entstellt
- Protokolliert wird zusätzlich der **Rohtext**, damit Entstellungen
  nachvollziehbar sind („CVAG" → „CVAG" vs. „Ce Vau A Ge" vs. „CV AG")

Ergebnis je Lauf: Trefferquote je Kategorie + Gesamtquote + Rohprotokoll.

---

## 4. Hebel, in der Reihenfolge ihrer Bewertung

### A. `AnalysisContext.contextualStrings` — der eigentliche Kandidat

Gegen das iOS-27-SDK verifiziert:

```swift
let context = AnalysisContext()
context.contextualStrings[.general] = ["CVAG", "SharePoint", "Proxmox"]
// beim Erzeugen:
SpeechAnalyzer(inputSequence:modules:options:analysisContext:…)
SpeechAnalyzer(inputAudioFile:modules:options:analysisContext:…)   // ab iOS 26
// oder zur Laufzeit:
try await analyzer.setContext(context)
```

- Verfügbar **ab iOS 26** → Deployment-Target 26.0 reicht, keine
  Verfügbarkeitsprüfung nötig
- `AnalysisContext` ist `Sendable`
- Nur ein Tag vorhanden: `.general`
- **Das SDK dokumentiert kein Limit** für Anzahl oder Länge der Begriffe, und es
  sagt auch nicht zu, dass `SpeechTranscriber` sie auswertet

**Daraus folgt der wichtigste Punkt des Plans:** Ob dieser Hebel überhaupt
wirkt, ist *unbewiesen*. Es wird **kein** Wörterbuch-UI gebaut, bevor die
Baseline zeigt, dass Kontextbegriffe die Trefferquote messbar erhöhen.

### B. Datei-Initializer statt eigener Chunk-Schleife

Entfernt ~60 Zeilen und zwei `@unchecked Sendable`-Krücken, bringt eine
Zeitbasis aus der Datei statt aus der Strom-Reihenfolge. **Kein** belegter
Gewinn an Erkennungsgüte. Lohnt nach den Kriterien aus dem Auftrag (weniger
Code, weniger Concurrency-Risiko, weniger Eigenkonvertierung) — aber erst nach
einem Gerätetest mit einer mehrstündigen Datei.

### C. `AnalyzerInputConverter` (iOS 27)

Würde die doppelte Konvertierung im Live-Pfad ersetzen. **Blockiert:**
`@available(… 27, *)` bei Deployment-Target 26.0 bedeutet zwei Codepfade statt
einem. Zurückstellen, bis das Target auf 27 zieht.

### D. Doppelte Live-Konvertierung (unabhängig von C)

`RecordingWriter` konvertiert den Tap-Buffer für die Datei, `SpeechLiveHandle`
konvertiert denselben Buffer noch einmal für den Analyzer. Ob sich das durch
Weiterreichen des bereits konvertierten Buffers vermeiden lässt, hängt davon ab,
ob `bestAvailableAudioFormat` dem Aufnahmeformat entspricht — **zu prüfen**,
nicht anzunehmen.

---

## 5. Reihenfolge in Phase 2

1. **Baseline-Suite** bauen (Gerät, skippt im Simulator), Korpus anlegen
2. **Baseline messen** — ohne jede Änderung an der Pipeline, Protokoll ablegen
3. **Hebel A messen**: identischer Lauf mit `contextualStrings` aus den
   erwarteten Begriffen. Differenz entscheidet alles Weitere.
4. Nur bei belegter Wirkung: Wörterbuch-Datenmodell, Einstellungen-UI,
   Verdrahtung in beide Pfade
5. Unabhängig davon und separat freigeben: Hebel B
6. Erneut messen, Protokolle vergleichen, Ergebnis ins Changelog

**Abbruchkriterium:** Zeigt Schritt 3 keine messbare Verbesserung, wird das
Wörterbuch **nicht** gebaut. Dann ist die ehrliche Konsequenz, dass Sprechly die
Erkennungsqualität mit den verfügbaren Apple-APIs nicht gezielt beeinflussen
kann — und 1.2 bekommt einen anderen Schwerpunkt.

---

## 6. Risiken

| Risiko | Einschätzung |
|---|---|
| `contextualStrings` wirkt nicht | **Hauptrisiko.** Deshalb Messung vor Implementierung. |
| TTS-Ergebnisse übertragen sich nicht auf echte Sprache | Real. Messung taugt nur für A/B, nicht für absolute Aussagen. |
| Gerätetests nicht automatisierbar in CI | Gegeben. Die Suite läuft manuell auf dem Gerät; CI überspringt sie. |
| Umbau bricht lange Aufnahmen | Vor Hebel B zwingend mit Stunden-Datei gegentesten. |
| Sprachmodell nicht installiert | Suite muss das prüfen und sauber skippen statt falsch zu messen. |
| Scope-Drift Richtung „großes Release" | 1.2 ist auf Transkriptionsqualität begrenzt; alles andere gehört ins Backlog. |

---

## 7. Was in Phase 1 bewusst **nicht** passiert ist

- keine Änderung an Speech-Code
- keine Version auf 1.2 gesetzt
- kein Wörterbuch-Datenmodell, kein UI
- keine Fixtures committed (erst wenn der Synthesizer-Weg verifiziert ist)
