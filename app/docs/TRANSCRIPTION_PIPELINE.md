# Transkriptions-Pipeline — Ist-Analyse und Hebel für 1.2

Stand: 2026-10-04, verifiziert gegen **iPhoneOS 27.0 SDK**. Grundlage für
Roadmap-Punkt **A3 (Transkriptions-Qualität)**. Dieses Dokument beschreibt den
Ist-Zustand und bewertet die Umbau-Optionen — **in 1.1.1 wurde an der Pipeline
bewusst nichts geändert**.

> **SDK-Abweichung zur Roadmap:** Die Roadmap-Notiz von August entstand gegen
> iOS 26.5. Inzwischen liegt **iOS 27** vor, das eine zusätzliche, direkt
> einschlägige API mitbringt (`AnalyzerInputConverter`, siehe Hebel 3). Das
> Deployment-Target des Projekts ist weiterhin **iOS 26.0**.

---

## 0. Ist-Modell der Pipeline (Stand 1.1.1, Build 10)

Die zehn Leitfragen, gegen den Code beantwortet. Zeilennummern beziehen sich auf
den Stand von `v1.1.1`.

### 1. Wie kommt Audio in die Pipeline?

Über **zwei getrennte Wege**, die sich keinen Code teilen:

| | Live (während der Aufnahme) | Datei (nachträglich) |
|---|---|---|
| Einstieg | `AudioRecorderEngine.installTap(bufferSize: 4096, format: nil)` | `AVAudioFile(forReading:)` |
| Treiber | Audio-Tap-Thread (Echtzeit) | `Task` auf Utility-Priorität |
| Transcriber | `SpeechLiveTranscriber` | `SpeechTranscriptionService` |
| Preset | `.timeIndexedProgressiveTranscription` | `.transcription` |

Ein dritter Pfad existiert indirekt: **importierte Dateien** werden von
`AudioImportService` auf das Aufnahmeformat transkodiert und laufen danach durch
den Datei-Pfad.

### 2. Wie wird das Format normalisiert?

An **drei** Stellen unabhängig voneinander:

1. `RecordingWriter.append` konvertiert den Tap-Buffer auf 48 kHz mono für die
   Datei (`RecorderConverterFactory`, Konverter wird bei Formatwechsel neu gebaut).
2. `SpeechLiveHandle.feed` konvertiert **denselben rohen Tap-Buffer** noch einmal,
   auf `SpeechAnalyzer.bestAvailableAudioFormat`.
3. `SpeechTranscriptionService.feed` konvertiert die gelesenen Datei-Chunks auf
   dasselbe Analyzer-Format.

**Befund:** Im Live-Betrieb wird jeder Buffer **zweimal konvertiert** — einmal
für die Datei, einmal für den Analyzer. `RecordingWriter.append` reicht
ausdrücklich den *rohen* Buffer an den Sink weiter ("Forward the raw buffer to
live transcription"), bevor es selbst konvertiert.

### 3. Wie werden Audio-Chunks erzeugt?

- **Live:** Die Chunk-Größe bestimmt der Tap (`bufferSize: 4096`, vom System
  nicht garantiert). Es gibt kein eigenes Chunking.
- **Datei:** Feste Blöcke von **16 384 Frames** in einer `while`-Schleife über
  `file.framePosition < file.length`.

### 4. Wie gelangen die Chunks zum Analyzer?

Beide Pfade bauen einen `AsyncStream<AnalyzerInput>` und übergeben ihn an
`analyzer.start(inputSequence:)`. Die Buffer werden **ohne explizite Startzeit**
eingereicht; die Zeitbasis leitet der Analyzer aus der Reihenfolge des Stroms ab
(so auch im Code kommentiert).

### 5. Wie wird der Fortschritt verwaltet?

Es gibt **keinen Fortschritt im eigentlichen Sinn** — kein `Progress`, keine
Prozentanzeige. Die UI zeigt die Zahl der bisher eingetroffenen Draft-Segmente
(`ProgressView("Wird transkribiert… (\(liveDrafts.count))")`). Bei einer
Stunden-Datei bleibt damit unklar, wie weit der Lauf ist.

### 6. Wie wird Cancellation behandelt?

- **Datei:** `continuation.onTermination = { task.cancel() }`. Verlässt der
  Konsument die `for await`-Schleife (so die 30-Sekunden-Vorschau), terminiert
  der Stream und der produzierende Task wird abgebrochen — durch
  `TranscriptionPreviewTests.previewCancelsTheTranscriptionRun` abgedeckt.
- **Live:** `finish()` schließt die Eingabe, ruft
  `finalizeAndFinishThroughEndOfInput()` und canceln den Results-Task. Kein
  Abbruch mitten im Lauf vorgesehen.

### 7. Wie werden lange Dateien verarbeitet?

Streamend: immer nur ein 16k-Frame-Puffer plus Konvertierungsziel im Speicher.
Die Datei wird nie vollständig geladen. **Aber:** Die erzeugten `TranscriptDraft`
sammeln sich vollständig im RAM (`liveDrafts`) und werden erst am Ende
persistiert — bei sehr langen Aufnahmen wächst das linear.

### 8. Wie wird zwischen Live und Datei unterschieden?

Gar nicht — es sind zwei separate Typen hinter zwei Protokollen
(`TranscriptionProviding`, `LiveTranscribing`) ohne gemeinsame Basis. Die
Formatkonvertierung ist in beiden dupliziert, inklusive der
`PendingBuffer`/`PendingLiveBuffer`-Hilfsklassen.

### 9. Wo entstehen eigene `@unchecked Sendable`-Konstruktionen?

| Typ | Datei | Grund | Entfällt bei Umbau? |
|---|---|---|---|
| `PendingBuffer` | `SpeechTranscriptionService` | `AVAudioPCMBuffer` ist nicht `Sendable`, der Converter-Block ist `@Sendable` | **Ja** (Datei-Initializer) |
| `PendingLiveBuffer` | `SpeechLiveTranscriber` | dito | **Ja** (`AnalyzerInputConverter`, iOS 27) |
| `SpeechLiveHandle` | `SpeechLiveTranscriber` | `feed` läuft auf dem Audio-Thread, Zustand per `NSLock` | Nein — inhärent |
| `RecordingWriter` | `AudioRecorderEngine` | Audio-Tap-Thread | Nein — inhärent |

Zwei der vier existieren **ausschließlich** wegen der selbstgebauten Konvertierung.

### 10. Was existiert nur wegen älterer API-Grenzen?

- Die **manuelle Datei-Chunk-Schleife** — Apple bietet seit iOS 26 einen
  Initializer, der die `AVAudioFile` direkt nimmt.
- Die **beiden Konvertierungsschleifen** samt `Pending*`-Klassen — iOS 27 bietet
  `AnalyzerInputConverter`.
- Die **Zeitbasis aus der Strom-Reihenfolge** statt aus der Datei.

---

## 1. Wie heute segmentiert wird

Es gibt **zwei** getrennte Pfade:

| Pfad | Datei | Transcriber-Preset |
|---|---|---|
| Datei-Transkription (nachträglich) | `Transcription/SpeechTranscriptionService.swift:57` | `.transcription` |
| Live-Transkript (während der Aufnahme) | `Transcription/SpeechLiveTranscriber.swift:9` | `.timeIndexedProgressiveTranscription` |

Die **Segmentierung macht Apple**, nicht die App: `SpeechTranscriber` liefert
`Result`-Werte mit eigener `range: CMTimeRange`. Die App übernimmt diese Grenzen
unverändert als `TranscriptDraft` (`startTime`/`endTime`) und persistiert sie als
`TranscriptSegment`. Eigene Satz-, Pausen- oder Sprechererkennung findet nicht
statt — die Absatzbildung in der Leseansicht ist reine Darstellung
(`TranscriptView.readingParagraphs`, Umbruch bei > 2 s Pause).

**Konsequenz:** Die wahrgenommene Qualität (Zeichensetzung, Wortgrenzen,
Groß-/Kleinschreibung) kommt vollständig aus Apples Modell. Dort gibt es keinen
Schalter, der sie direkt verbessert — der Preset `.transcription` ist korrekt
gewählt, seine Optionen steuern nur Reporting und Attribute
(verifiziert, siehe Roadmap A3).

## 2. Wo die eigene Chunk-Fütterung sitzt

`SpeechTranscriptionService.feed(file:to:analysisFormat:)` (Zeile 93 ff.):

1. `AVAudioFile` wird in Blöcken von **16 384 Frames** gelesen.
2. Weicht das Dateiformat vom Analyzer-Format ab
   (`SpeechAnalyzer.bestAvailableAudioFormat`), konvertiert eine **eigene
   `AVAudioConverter`-Schleife** jeden Block einzeln (`convert(_:using:to:)`).
3. Jeder Block wird als `AnalyzerInput(buffer:)` in einen `AsyncStream` gelegt —
   **ohne explizite Startzeit**; die Zeitbasis leitet der Analyzer aus dem
   kontinuierlichen Strom ab (so auch im Code kommentiert).
4. `analyzer.start(inputSequence:)` konsumiert den Strom,
   `finalizeAndFinishThroughEndOfInput()` schließt ab.

Der Live-Pfad macht dasselbe nochmal separat
(`SpeechLiveTranscriber.feed(_:)`, Zeile 58 ff.), dort pro Tap-Buffer.

**Das ist der eigentliche Eigenbau-Anteil** — rund 60 Zeilen Konvertierungslogik
samt `PendingBuffer`-Hilfsklasse (`@unchecked Sendable`), die es nur gibt, weil
AVFAudio-Buffer nicht `Sendable` sind.

## 3. Hebel 1 — `analyzeSequence(from:)` bzw. der Datei-Initializer

Im SDK **vorhanden und passend** (verifiziert):

```swift
// SpeechAnalyzer
final public func analyzeSequence(from audioFile: AVAudioFile) async throws -> CMTime?
final public func start(inputAudioFile: AVAudioFile, finishAfterFile: Bool = false) async throws

// Convenience-Init, der Datei *und* Kontext zugleich nimmt:
public convenience init(
    inputAudioFile: AVAudioFile,
    modules: [any SpeechModule],
    options: SpeechAnalyzer.Options? = nil,
    analysisContext: AnalysisContext = .init(),
    finishAfterFile: Bool = false,
    volatileRangeChangedHandler: ...
) async throws
```

Damit entfallen Punkt 1–3 aus Abschnitt 2 ersatzlos: kein eigener Reader, kein
eigener Konverter, keine `PendingBuffer`-Krücke. Apple liest und konvertiert die
Datei selbst.

**Bewertung:** klarer Gewinn an Wartbarkeit und vermutlich an Zeitgenauigkeit
(die Zeitbasis kommt dann aus der Datei statt aus der Strom-Reihenfolge).
**Kein** belegter Gewinn an Worterkennungsgüte — das Modell bleibt dasselbe.
Der Umbau betrifft nur den **Datei-Pfad**; der Live-Pfad muss zwingend beim
Puffer-Streaming bleiben, da dort kein `AVAudioFile` existiert.

## 4. Hebel 2 — `AnalysisContext` / kontextuelle Begriffe

Ab iOS 26 verfügbar, also **ohne Verfügbarkeitsprüfung nutzbar**:

```swift
let context = AnalysisContext()
context.contextualStrings[.general] = ["Sprechly", "GmbH", "Vorname Nachname", …]
// entweder über den Init oben, oder nachträglich:
try await analyzer.setContext(context)
```

Das ist der **einzige Hebel mit plausibler Wirkung auf die Erkennungsqualität**
und trifft genau die gemeldeten Schwachstellen: Eigennamen und Fachbegriffe.

Sinnvolle Quellen für die Begriffsliste, aufsteigend nach Aufwand:

1. **Titel vorhandener Aufnahmen** und bereits erzeugte KI-Titel — kostenlos aus
   SwiftData, kein UI nötig.
2. **Kontaktnamen** — stark für Meeting-Mitschriften, aber zusätzliche
   Berechtigung und Datenschutz-Aussage; fürs Erste abzulehnen.
3. **Eigenes Wörterbuch** in den Einstellungen — laut Auftrag ausdrücklich erst
   nach 1.2.

Offene Frage für 1.2: ob der Kontext pro Lauf aus der Bibliothek abgeleitet oder
persistent gepflegt wird.

## 5. Hebel 3 — `AnalyzerInputConverter` (neu in iOS 27)

```swift
@available(anyAppleOS 27, *)
final public class AnalyzerInputConverter {
    public static func converter(compatibleWith modules: [any SpeechModule]) async throws -> AnalyzerInputConverter
    public init(analyzerFormat: AVAudioFormat, configurationHandler: ((AVAudioConverter) -> Void)? = nil)
}
```

Genau der Ersatz für die handgeschriebene Konvertierung im **Live-Pfad**, wo
Hebel 1 nicht greift. **Aber:** `@available(… 27, *)` bei Deployment-Target
26.0 — nutzbar nur hinter `if #available(iOS 27, *)` mit Beibehaltung des
bestehenden Pfads als Fallback. Damit stünde vorerst doppelter Code statt
weniger. Empfehlung: zurückstellen, bis das Deployment-Target auf 27 zieht.

## 6. Risiken

| Bereich | Einschätzung |
|---|---|
| **Speicher** | Hebel 1 **verbessert** die Lage: heute hält die App 16k-Frame-Puffer plus Konvertierungsziel selbst; danach verwaltet Apple das. Kein Vollladen der Datei in beiden Varianten. |
| **Latenz** | Für den Datei-Pfad unkritisch (läuft ohnehin asynchron mit Fortschritts-UI). Der Live-Pfad bleibt unangetastet. |
| **Lange Aufnahmen** | Hauptrisiko des Umbaus. Der heutige Pfad ist auf Stunden-Dateien verifiziert; `analyzeSequence(from:)` ist es **nicht**. Vor einem Wechsel zwingend mit einer mehrstündigen Datei auf dem Gerät gegentesten. |
| **Swift Concurrency** | Hebel 1 **entfernt** die beiden `@unchecked Sendable`-Krücken (`PendingBuffer`) — strikt besser. |
| **OS-Versionen** | Hebel 1 + 2 ab iOS 26 = sofort nutzbar. Hebel 3 erst ab 27. |
| **Sprachmodelle** | Unberührt: `AssetInventory`/Download-Flow hängt am `SpeechTranscriber`, nicht am Eingabeweg. |
| **Testbarkeit** | `TranscriptionProviding` bleibt die Naht; die Mocks in den Tests sind von allen drei Hebeln nicht betroffen. |

## 7. Empfehlung für 1.2

1. **`AnalysisContext` zuerst** — der einzige Hebel, der die gemeldeten
   Qualitätsprobleme (Namen, Fachbegriffe) tatsächlich adressiert. Klein,
   additiv, ab iOS 26, mit Aufnahmetiteln als erster Quelle.
2. **Danach der Datei-Initializer** — ersetzt ~60 Zeilen Eigenbau durch eine
   API-Zeile und nimmt zwei `@unchecked Sendable` mit. Erst nach einem
   Gerätetest mit einer mehrstündigen Aufnahme.
3. **`AnalyzerInputConverter` zurückstellen**, bis das Deployment-Target auf
   iOS 27 steht — sonst entsteht mehr Code statt weniger.

Vorher steht weiterhin Renes manuelle Beurteilung auf dem Gerät (Namen,
Fachbegriffe, Zahlen): ohne sie ist nicht belegt, dass Hebel 2 das richtige
Problem trifft.
