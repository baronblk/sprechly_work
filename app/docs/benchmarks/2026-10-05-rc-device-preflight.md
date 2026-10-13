# Raw output — 1.2.0 RC device preflight

Device: iPhone 17 Pro, iOS 27.0.1 · 2026-10-05 · version 1.2.0 (11)
Unaltered test output. Do not overwrite — later runs get their own file.

```
PIPELINE capture  48000Hz ch=1 fmt=1 interleaved=false
PIPELINE writer   48000Hz ch=1 fmt=1 interleaved=false
PIPELINE analyzer 16000Hz ch=1 fmt=3 interleaved=true
PIPELINE SHAREABLE writer-target-equals-analyzer-format=false
PIPELINE capture-equals-writer-target=true
PIPELINE capture-equals-analyzer-format=false
PIPELINE analyzer-candidate 16000Hz ch=1 fmt=3 interleaved=true equals-writer-target=false
PIPELINE analyzer-candidate 8000Hz ch=1 fmt=3 interleaved=true equals-writer-target=false
LONGEDIT source 1800.000s written in 9.554s bytes=22848838
LONGEDIT edit out=1344.000s expected=1344.000s took=10.872s progress=19689 last=1.000 monotonic=true peak=0.8912509
LONGEDIT merge out=3144.000s expected=3144.000s took=0.969s
LONGEDIT mix out=1800.000s main=1800.000s took=10.322s
LONGEDIT export m4a 3144.000s took=6.358s bytes=46507050
LONGEDIT export wav 3144.000s took=0.594s bytes=301828096
GATE3E txt name=Sprint Planung.txt bytes=329
GATE3E markdown name=Sprint Planung.md bytes=393
GATE3E locked: no file for either format
GATE3B requesting de.gcng.sprechly.ai
GATE3B returned 1 product(s)
GATE3B id=de.gcng.sprechly.ai type=Non-Consumable displayPrice=6,99 € price=6.99 name=Sprechly KI
GATE3B currentEntitlements=de.gcng.sprechly.ai
SEQ same-engine-take1 readable-after=0.0s reported=1.9857291666666668 file=1.9857291666666668 bytes=94816
SEQ same-engine-take2 readable-after=0.1s reported=1.9857291666666668 file=1.9857291666666668 bytes=93529
SEQ fresh-engine-take1 readable-after=0.0s reported=1.9857291666666668 file=1.9857291666666668 bytes=93366
SEQ fresh-engine-take2 readable-after=0.0s reported=1.9857291666666668 file=1.9857291666666668 bytes=94802
SEQ isolated readable-after=0.1s reported=1.9857291666666668 file=1.9857291666666668 bytes=93581
PERF formatter 1200 segments in 0.131s (0.110ms per segment)
INTEGRATION abbrev-02 SERVICE TEXT: Die AP ist dokumentiert, die KI läuft auf dem Gerät.
INTEGRATION numbers-02 expects '13:45' in: Das Treffen ist am 4. Oktober 2026 um 13:45 Uhr.
INTEGRATION mixed-02 expects '1.2.0' in: Für Version 1.2.0 prüfen wir die AP und den VPN-Zugang am 4. Oktober.
INTEGRATION technical-01 expects 'SharePoint' in: Die Doku liegt in SharePoint, der Container läuft in Docker.
INTEGRATION technical-02 expects 'StoreKit' in: Der Kauf läuft über StoreKit, die Synchronisierung über CloudKit.
INTEGRATION technical-02 expects 'CloudKit' in: Der Kauf läuft über StoreKit, die Synchronisierung über CloudKit.
INTEGRATION technical-03 expects 'SwiftUI' in: Die Oberfläche ist in SwiftOE geschrieben.
INTEGRATION mixed-03 expects 'Markdown' in: Die KI-Zusammenfassung läuft on device, der Export geht nach Markdown.
INTEGRATION EXPORT txt: Abbrev ⏎  ⏎ Transkript ⏎ [00:00] Die AP ist dokumentiert, die KI läuft auf dem Gerät. ⏎ 
INTEGRATION EXPORT markdown: # Abbrev ⏎  ⏎ --- ⏎  ⏎ ## Transkript ⏎  ⏎ **`00:00`** Die AP ist dokumentiert, die KI läuft auf dem Gerät. ⏎  ⏎ --- ⏎  ⏎ *Erstellt mit Sprechly* ⏎ 
INTEGRATION MIGRATED: Die AP ist dokumentiert, die KI läuft auf dem Gerät.
LIVE updates=17 FINAL: Die AP ist dokumentiert, die KI läuft auf dem Gerät
LIVE VOLATILE: Die
LIVE VOLATILE: Die A
LIVE VOLATILE: Die AP
LIVE VOLATILE: Die AP ist
LIVE VOLATILE: Die AP ist d
LIVE VOLATILE: Die AP ist dok
LIVE VOLATILE: Die AP ist dokumentiert
LIVE VOLATILE: Die AP ist dokumentiert,
LIVE VOLATILE: Die AP ist dokumentiert, die
LIVE VOLATILE: Die AP ist dokumentiert, die K
LIVE VOLATILE: Die AP ist dokumentiert, die K I
LIVE VOLATILE: Die AP ist dokumentiert, die K I läuft
LIVE VOLATILE: Die AP ist dokumentiert, die K I läuft auf
LIVE VOLATILE: Die AP ist dokumentiert, die K I läuft auf dem
LIVE VOLATILE: Die AP ist dokumentiert, die K I läuft auf dem Ger
LIVE VOLATILE: Die AP ist dokumentiert, die K I läuft auf dem Gerät
LIVE VOLATILE: Die AP ist dokumentiert, die KI läuft auf dem Gerät
PRESET transcription reporting=[] transcription=[] attributes=[]
PRESET timeIndexedProgressiveTranscription reporting=[Speech.SpeechTranscriber.ReportingOption.volatileResults, Speech.SpeechTranscriber.ReportingOption.fastResults] transcription=[] attributes=[Speech.SpeechTranscriber.ResultAttributeOption.audioTimeRange]
```

## Frozen benchmarks on the 1.2.0 (11) build

```
FORMAT-de MARKUP AUDIT \letter=2
FORMAT-de SUMMARY BEFORE wer=0.250 cer=0.067 terms=13/31 recall=0.419 fmt-acc=0.619 fmt-miss=8 rec-miss=10 fp=0
FORMAT-de SUMMARY AFTER-ALL wer=0.155 cer=0.042 terms=20/31 recall=0.645 fmt-acc=0.909 fmt-miss=2 rec-miss=9 fp=0
FORMAT-de DELTA AFTER-ALL wer=-0.095 cer=-0.025 terms=20-vs-13 fmt-acc=0.290 false-corrections=0
FORMAT-en MARKUP AUDIT none
FORMAT-en SUMMARY BEFORE wer=0.195 cer=0.065 terms=20/31 recall=0.645 fmt-acc=0.800 fmt-miss=5 rec-miss=6 fp=0
FORMAT-en SUMMARY AFTER-ALL wer=0.173 cer=0.064 terms=21/31 recall=0.677 fmt-acc=0.840 fmt-miss=4 rec-miss=6 fp=0
FORMAT-en DELTA AFTER-ALL wer=-0.022 cer=-0.001 terms=21-vs-20 fmt-acc=0.040 false-corrections=0
```
