# Live Audio Pipeline — Sprechly 1.2, Phase 6

Untersuchung der in Phase 1 notierten „doppelten Live-Audiokonvertierung".

**Kurzfassung: die Audioarchitektur bleibt unverändert. Von den zwei
Konvertierungen ist eine zwingend und die andere kostet 6,2 µs gegen 147,9 µs
AAC-Write — ein Umbau des Echtzeitpfads ist dadurch nicht zu rechtfertigen.
Entfernt wurden drei nach SDK-Befund unnötige `@unchecked Sendable`-Boxen.**

Rohdaten in
[`benchmarks/2026-10-04-live-audio-pipeline.md`](benchmarks/2026-10-04-live-audio-pipeline.md).

---

## Ist-Pfad

```
AVAudioEngine.inputNode
  └── installTap(onBus: 0, bufferSize: 4096, format: nil)      Audio-Thread
        └── RecordingWriter.append(buffer)
              ├── bufferSink?(buffer)        ← ROH, unkonvertiert
              │     └── SpeechLiveHandle.feed(buffer)
              │           └── AVAudioConverter #2  48k F32 → 16k Int16
              │                 └── AnalyzerInput → SpeechAnalyzer
              └── AVAudioConverter #1  48k F32 → 48k F32
                    ├── AVAudioFile.write(from:)   AAC-Encode
                    └── accumulate() → Meter (gedrosselt ~30/s)
```

Beide Konvertierungen laufen auf **demselben** Audio-Thread, aus **demselben**
Quellbuffer, zu **unterschiedlichen** Zielen.

### Formate (auf Gerät gemessen, iPhone 17 Pro / iOS 27.0.1)

| Stufe | Format |
|---|---|
| Capture (Tap, `format: nil`) | 48 000 Hz · mono · Float32 · non-interleaved |
| Writer-Ziel (`file.processingFormat`) | 48 000 Hz · mono · Float32 · non-interleaved |
| SpeechAnalyzer (`bestAvailableAudioFormat`) | **16 000 Hz · mono · Int16 · interleaved** |

Verfügbare Analyzer-Formate: **nur** 16 kHz und 8 kHz Int16 interleaved. Keines
entspricht dem Writer-Ziel.

```
PIPELINE SHAREABLE writer-target-equals-analyzer-format=false
PIPELINE capture-equals-writer-target=true
PIPELINE capture-equals-analyzer-format=false
```

**Damit ist der Befund präziser als „doppelte Konvertierung":**

1. Die **Speech-Konvertierung ist zwingend** — 48 kHz Float32 auf 16 kHz Int16.
   Sie kann nicht geteilt und nicht weggelassen werden, weil der Analyzer kein
   anderes Format annimmt.
2. Die **Writer-Konvertierung ist auf diesem Gerät ein formatidentischer
   Kopiervorgang** — Capture und Dateiformat sind gleich. Sie existiert für den
   Fall, dass sie es nicht sind (Bluetooth 16 kHz, Route-Wechsel), und ist
   genau dafür richtig: der Konverter wird aus dem **lebenden** Bufferformat
   gebaut, das Ziel bleibt konstant, damit die offene `AVAudioFile` gültig
   bleibt.

### Konverter-Instanzen und Kopien pro Buffer

| | Anzahl |
|---|---|
| `AVAudioConverter`-Instanzen | 2, je **wiederverwendet** bis sich das Eingangsformat ändert |
| Konvertierungen pro Input-Buffer | 2 |
| neue `AVAudioPCMBuffer` pro Input-Buffer | 2 (eine je Konvertierung) |
| Kopien des Rohbuffers | 0 — er wird per Referenz an den Sink gegeben |

`RecorderConverterFactory` baut nur neu, wenn `existing.inputFormat` abweicht.
`SpeechLiveHandle` prüft `converter?.inputFormat != buffer.format` gleichwertig.

### Queues, Actors, Hilfstypen

| Element | Isolation |
|---|---|
| `AudioRecorderEngine` | `actor` — Steuerung, nicht im Callback |
| Tap-Callback | serieller Audio-Thread von AVAudioEngine |
| `RecordingWriter` | `@unchecked Sendable`, `NSLock` nur für das Pause-Flag |
| `SpeechLiveHandle` | `@unchecked Sendable`, `NSLock` für Converter + Segmente |
| `AsyncStream`-Continuations | `yield` aus dem Callback, lock-frei |

## Was geändert wurde

Nur die Concurrency-Sonderkonstrukte. Das SDK entscheidet die Frage:

```c
typedef AVAudioBuffer * (^ NS_SWIFT_NONSENDABLE AVAudioConverterInputBlock)(…);
- (…)convertToBuffer:… withInputFromBlock:(NS_NOESCAPE AVAudioConverterInputBlock)inputBlock;
```

Der Pull-Block ist **nicht-Sendable und nicht-escaping**. Die drei
nahezu identischen `@unchecked Sendable`-Boxen, die nur existierten, um ihm
einen Buffer zu übergeben, sind damit nachweislich unnötig — ein lokales `var`
genügt:

| Entfernt | Datei |
|---|---|
| `PendingBuffer` | `Transcription/SpeechTranscriptionService.swift` |
| `PendingLiveBuffer` | `Transcription/SpeechLiveTranscriber.swift` |
| `Pending` | `Tests/.../BenchmarkEngines.swift` |

Zusätzlich wurde `RecordingWriter.pendingInput` von einer Instanzvariablen zu
einer lokalen — das entfernt geteilten mutablen Zustand aus einer
`@unchecked Sendable`-Klasse und die `[self]`-Capture aus dem Echtzeitpfad.

**Keine Performance-Behauptung daraus.** Der Live-Pfad spart eine kleine
Allokation pro Buffer; das liegt weit unter dem, was die Messungen dieser Phase
auflösen können.

Verbleibende `@unchecked Sendable` sind weiterhin nötig: `RecordingWriter` und
`SpeechLiveHandle` (jeweils Lock plus nicht-Sendable Audioobjekte),
`AudioSessionController.ObserverBox`, sowie Test-Mocks.

## Was nicht geändert wurde, und warum

Die formatidentische Writer-Konvertierung bleibt. Gemessen auf Gerät, mit den
echten Tap-Parametern (4096 Frames @ 48 kHz, also 11,7 Callbacks/s):

| Operation | pro Callback | Anteil Realtime-CPU |
|---|---:|---:|
| Writer-Konvertierung (48k F32 → 48k F32) | **6,2 µs** | 0,0073 % |
| Speech-Konvertierung (48k F32 → 16k Int16) | 7,5 µs | 0,0088 % |
| **AAC-Write derselben Buffer** | **147,9 µs** | 0,1733 % |

Der Schreibvorgang, den die Konvertierung speist, ist **24× teurer** als die
Konvertierung selbst. Ein Fast-Path würde rund 0,26 s CPU pro Aufnahmestunde
sparen und dafür eine Verzweigung in den Echtzeitpfad einbauen. Das
Entscheidungskriterium „messbar weniger Arbeit, keine neue
Concurrency-Gefahr" ist damit nicht erfüllt — der Gewinn ist marginal, das
Risiko nicht null. **Bestehender Pfad beibehalten.**

## Bekannter, pre-existing Befund: Datei-Finalisierung ist nicht synchron

Beim Verifizieren fiel auf, dass `AudioRecorderEngine.stop()` **nicht**
garantiert, dass die Datei anschließend lesbar ist:

```
SEQ same-engine-take1 UNREADABLE bytes=93974 error=… Code=1685348671
SEQ same-engine-take2 OK
SEQ fresh-engine-take2 UNREADABLE bytes=93139
```

`1685348671` = `'dta?'` = `kAudioFileInvalidFileError`. Das Audio ist auf der
Platte (~94 KB für 2 s); nur der AAC-Container ist noch nicht abgeschlossen.
Der Abschluss passiert, wenn die `AVAudioFile` des Writers tatsächlich
freigegeben wird, und das ist nicht synchron zu `stop()`.

**Pre-existing und nicht-deterministisch, gemessen nicht vermutet:** in einem
Worktree auf `a5cc2e2` — dem Stand am Ende von Phase 5, vor jeder Änderung
dieser Phase — tritt dasselbe Muster auf (2 von 5 Takes, jeweils andere). Es
hängt nicht an der Sendable-Vereinfachung.

Die Verzögerung liegt unter 100 ms: mit einem begrenzten Warteschritt wird die
Datei in jedem gemessenen Fall nach **0,0–0,1 s** lesbar. Die Tests bilden das
jetzt so ab, statt es zu verstecken.

**Relevanz:** Der Doc-Comment von `finalizeCurrentFile()` behauptet, die Datei
sei danach „complete and readable". Das ist nicht zuverlässig wahr. In der App
liegt zwischen `stop()` und dem ersten Lesen genug anderer Arbeit
(SwiftData-Insert, Save, UI), weshalb es praktisch nicht auffällt — belastbar
ist es nicht. **Im Rahmen dieser Phase bewusst nicht geändert** („Audioarchitektur
bleibt unverändert", keine weiteren Audiooptimierungen). Eigener Wartungspunkt.

## Verifikation nach der Vereinfachung

### Lange Aufnahmen (echtes Mikrofon, iPhone 17 Pro / iOS 27.0.1)

| | 5 Minuten | 30 Minuten |
|---|---|---|
| Angefordert / Wall-Clock | 300,000 s / 300,202 s | 1800,000 s / 1800,210 s |
| Engine-Dauer / Dateidauer | 299,989 s / 299,989 s | 1799,993 s / 1799,993 s |
| **Drift** | **0,000 s** | **0,000 s** |
| Dateigröße | 4 891 018 B | 29 447 126 B |
| Buffer an den Live-Sink | 3 000 | 18 000 |
| **Frames an den Live-Sink** | **14 400 000 = exakt 300,000 s** | **86 400 000 = exakt 1800,000 s** |
| Capture-Formate im Lauf | 1 | 1 |
| Meter | 8 999 (30,0/s) | 53 999 (30,0/s) |
| Größte Meter-Lücke | 0,127 s | 0,148 s |
| Datei lesbar nach | 0,000 s | 0,000 s |
| Cancellation (Stop nach 2 s) | 1,986 s, Datei 1,986 s | 1,986 s, Datei 1,986 s |

`48 000 × 1800 = 86 400 000` — **kein verlorener Frame über eine halbe Stunde**,
und die Dateidauer stimmt exakt mit der Engine-Dauer überein. Die größte
Meter-Lücke von 0,148 s betrifft die Beobachtungsschleife, nicht die Aufnahme:
die Framezahl ist lückenlos.

### Transkriptionsqualität — unverändert gegenüber Phase 5

Dieselben eingefrorenen Fixtures, dieselben Zahlen, Stelle für Stelle:

| | de-DE vorher → nachher | en-US vorher → nachher |
|---|---|---|
| WER | 0,250 → 0,155 | 0,195 → 0,173 |
| CER | 0,067 → 0,042 | 0,065 → 0,064 |
| Zielbegriffe | 13/31 → 20/31 | 20/31 → 21/31 |
| Formatting Accuracy | 0,619 → 0,909 | 0,800 → 0,840 |
| False Corrections | **0** | **0** |
| Marker-Audit | `\letter=2` | `none` |

Keine Abweichung in irgendeiner Stelle. Das war die Bedingung für diese Phase.

### Regression

| | |
|---|---|
| Simulator | 253 Tests / 54 Suites grün, 0 Warnungen |
| Gerät (relevante Suites) | 85 Tests / 10 Suites grün, 0 Warnungen |
| Neue Concurrency-Warnungen | keine (Swift 6 strict, unverändert) |
