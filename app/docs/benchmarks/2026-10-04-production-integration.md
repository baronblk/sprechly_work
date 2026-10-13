# Raw output — 1.2 production integration (final), frozen DE + EN fixtures

Device: iPhone 17 Pro, iOS 27.0.1 · 2026-10-04
Includes the precised legacy migration (marker-driven letter join).
Unaltered test output. Do not overwrite — later runs get their own file.

```
FORMAT-de ENV device=iPhone iOS 27.0.1 locale=de-DE cases=15 source=frozen-fixtures
FORMAT-de RAW names-01 t=0.265s TEXT: René arbeitet bei der Chemnitzer Verkehrs AG.
FORMAT-de RAW names-02 t=0.084s TEXT: Jacqueline hat den Termin mit Hanning und Karl bestätigt.
FORMAT-de RAW technical-01 t=0.081s TEXT: Die Doku liegt in Sharepoint, der Container läuft in Docker.
FORMAT-de RAW technical-02 t=0.086s TEXT: Der Kauf läuft über Store Kit, die Synchronisierung über Cloud Kit.
FORMAT-de RAW technical-03 t=0.071s TEXT: Die Oberfläche ist in SwiftOE geschrieben.
FORMAT-de RAW technical-04 t=0.088s TEXT: Speech Analizer bekommt die Begriffe über Analysis Kontext.
FORMAT-de RAW abbrev-01 t=0.085s TEXT: Der Zugriff läuft über VPN, die Geräte kommen aus dem MDM.
FORMAT-de RAW abbrev-02 t=0.081s TEXT: Die AP ist dokumentiert, die K\letter I\letter läuft auf dem Gerät.
FORMAT-de RAW numbers-01 t=0.071s TEXT: Der Kauf kostet 9,99 Euro Cent.
FORMAT-de RAW numbers-02 t=0.091s TEXT: Das Treffen ist am 4. Oktober 2026 um 13.45 Uhr.
FORMAT-de RAW numbers-03 t=0.078s TEXT: Der Server hat die Adresse 19216824.
FORMAT-de RAW numbers-04 t=0.074s TEXT: Wir veröffentlichen Version als Bild 10.
FORMAT-de RAW mixed-01 t=0.095s TEXT: René legt die CVAG-Unterlagen bis 13.45 Uhr in Sharepoint ab.
FORMAT-de RAW mixed-02 t=0.101s TEXT: Für Version 1. 2.0 prüfen wir die AP und den VPN-Zugang am 4. Oktober.
FORMAT-de RAW mixed-03 t=0.098s TEXT: Die KI-Zusammenfassung läuft on device, der Export geht nach Mark Down.
FORMAT-de MARKUP abbrev-02 found=\letter \letter
FORMAT-de MARKUP AUDIT \letter=2
FORMAT-de BEFORE names-01 wer=0.333 cer=0.022 hits=1/2 fmt-miss=Chemnitzer Verkehrs-AG rec-miss= fmt-acc=0.500
FORMAT-de BEFORE names-02 wer=0.111 cer=0.018 hits=2/2 fmt-miss= rec-miss= fmt-acc=1.000
FORMAT-de BEFORE technical-01 wer=0.000 cer=0.000 hits=2/2 fmt-miss= rec-miss= fmt-acc=1.000
FORMAT-de BEFORE technical-02 wer=0.444 cer=0.031 hits=0/2 fmt-miss=StoreKit|CloudKit rec-miss= fmt-acc=0.000
FORMAT-de BEFORE technical-03 wer=0.167 cer=0.048 hits=0/1 fmt-miss= rec-miss=SwiftUI fmt-acc=1.000
FORMAT-de BEFORE technical-04 wer=0.667 cer=0.070 hits=0/2 fmt-miss= rec-miss=SpeechAnalyzer|AnalysisContext fmt-acc=1.000
FORMAT-de BEFORE abbrev-01 wer=0.000 cer=0.000 hits=2/2 fmt-miss= rec-miss= fmt-acc=1.000
FORMAT-de BEFORE abbrev-02 wer=0.500 cer=0.302 hits=0/2 fmt-miss= rec-miss=API|KI fmt-acc=1.000
FORMAT-de BEFORE numbers-01 wer=0.200 cer=0.192 hits=1/1 fmt-miss= rec-miss= fmt-acc=1.000
FORMAT-de BEFORE numbers-02 wer=0.100 cer=0.021 hits=1/2 fmt-miss=13:45 rec-miss= fmt-acc=0.500
FORMAT-de BEFORE numbers-03 wer=0.167 cer=0.077 hits=0/1 fmt-miss=192.168.2.4 rec-miss= fmt-acc=0.000
FORMAT-de BEFORE numbers-04 wer=0.286 cer=0.149 hits=1/2 fmt-miss= rec-miss=1.2.0 fmt-acc=1.000
FORMAT-de BEFORE mixed-01 wer=0.100 cer=0.016 hits=2/4 fmt-miss=13:45 rec-miss=CVAG fmt-acc=0.667
FORMAT-de BEFORE mixed-02 wer=0.231 cer=0.029 hits=1/4 fmt-miss=1.2.0 rec-miss=API|VPN fmt-acc=0.500
FORMAT-de BEFORE mixed-03 wer=0.444 cer=0.029 hits=0/2 fmt-miss=Markdown rec-miss=KI fmt-acc=0.000
FORMAT-de SUMMARY BEFORE wer=0.250 cer=0.067 terms=13/31 recall=0.419 fmt-acc=0.619 fmt-miss=8 rec-miss=10 fp=0
FORMAT-de AFTER-ALL names-01 wer=0.333 cer=0.022 hits=1/2 fmt-miss=Chemnitzer Verkehrs-AG rec-miss= fmt-acc=0.500
FORMAT-de AFTER-ALL names-02 wer=0.111 cer=0.018 hits=2/2 fmt-miss= rec-miss= fmt-acc=1.000
FORMAT-de AFTER-ALL technical-01 wer=0.000 cer=0.000 hits=2/2 fmt-miss= rec-miss= fmt-acc=1.000
FORMAT-de CHANGED technical-01 FROM: Die Doku liegt in Sharepoint, der Container läuft in Docker.
FORMAT-de CHANGED technical-01   TO: Die Doku liegt in SharePoint, der Container läuft in Docker.
FORMAT-de AFTER-ALL technical-02 wer=0.000 cer=0.000 hits=2/2 fmt-miss= rec-miss= fmt-acc=1.000
FORMAT-de CHANGED technical-02 FROM: Der Kauf läuft über Store Kit, die Synchronisierung über Cloud Kit.
FORMAT-de CHANGED technical-02   TO: Der Kauf läuft über StoreKit, die Synchronisierung über CloudKit.
FORMAT-de AFTER-ALL technical-03 wer=0.167 cer=0.048 hits=0/1 fmt-miss= rec-miss=SwiftUI fmt-acc=1.000
FORMAT-de AFTER-ALL technical-04 wer=0.667 cer=0.070 hits=0/2 fmt-miss= rec-miss=SpeechAnalyzer|AnalysisContext fmt-acc=1.000
FORMAT-de AFTER-ALL abbrev-01 wer=0.000 cer=0.000 hits=2/2 fmt-miss= rec-miss= fmt-acc=1.000
FORMAT-de AFTER-ALL abbrev-02 wer=0.100 cer=0.019 hits=1/2 fmt-miss= rec-miss=API fmt-acc=1.000
FORMAT-de CHANGED abbrev-02 FROM: Die AP ist dokumentiert, die K\letter I\letter läuft auf dem Gerät.
FORMAT-de CHANGED abbrev-02   TO: Die AP ist dokumentiert, die KI läuft auf dem Gerät.
FORMAT-de AFTER-ALL numbers-01 wer=0.200 cer=0.192 hits=1/1 fmt-miss= rec-miss= fmt-acc=1.000
FORMAT-de AFTER-ALL numbers-02 wer=0.000 cer=0.000 hits=2/2 fmt-miss= rec-miss= fmt-acc=1.000
FORMAT-de CHANGED numbers-02 FROM: Das Treffen ist am 4. Oktober 2026 um 13.45 Uhr.
FORMAT-de CHANGED numbers-02   TO: Das Treffen ist am 4. Oktober 2026 um 13:45 Uhr.
FORMAT-de AFTER-ALL numbers-03 wer=0.167 cer=0.077 hits=0/1 fmt-miss=192.168.2.4 rec-miss= fmt-acc=0.000
FORMAT-de AFTER-ALL numbers-04 wer=0.286 cer=0.149 hits=1/2 fmt-miss= rec-miss=1.2.0 fmt-acc=1.000
FORMAT-de AFTER-ALL mixed-01 wer=0.000 cer=0.000 hits=3/4 fmt-miss= rec-miss=CVAG fmt-acc=1.000
FORMAT-de CHANGED mixed-01 FROM: René legt die CVAG-Unterlagen bis 13.45 Uhr in Sharepoint ab.
FORMAT-de CHANGED mixed-01   TO: René legt die CVAG-Unterlagen bis 13:45 Uhr in SharePoint ab.
FORMAT-de AFTER-ALL mixed-02 wer=0.077 cer=0.014 hits=2/4 fmt-miss= rec-miss=API|VPN fmt-acc=1.000
FORMAT-de CHANGED mixed-02 FROM: Für Version 1. 2.0 prüfen wir die AP und den VPN-Zugang am 4. Oktober.
FORMAT-de CHANGED mixed-02   TO: Für Version 1.2.0 prüfen wir die AP und den VPN-Zugang am 4. Oktober.
FORMAT-de AFTER-ALL mixed-03 wer=0.222 cer=0.014 hits=1/2 fmt-miss= rec-miss=KI fmt-acc=1.000
FORMAT-de CHANGED mixed-03 FROM: Die KI-Zusammenfassung läuft on device, der Export geht nach Mark Down.
FORMAT-de CHANGED mixed-03   TO: Die KI-Zusammenfassung läuft on device, der Export geht nach Markdown.
FORMAT-de SUMMARY AFTER-ALL wer=0.155 cer=0.042 terms=20/31 recall=0.645 fmt-acc=0.909 fmt-miss=2 rec-miss=9 fp=0
FORMAT-de SUMMARY RULE-TIMES wer=0.237 cer=0.064 terms=15/31 recall=0.484 fmt-acc=0.714 fmt-miss=6 rec-miss=10 fp=0
FORMAT-de SUMMARY RULE-VERSIONS wer=0.240 cer=0.066 terms=14/31 recall=0.452 fmt-acc=0.667 fmt-miss=7 rec-miss=10 fp=0
FORMAT-de SUMMARY RULE-ACRONYMS wer=0.250 cer=0.067 terms=13/31 recall=0.419 fmt-acc=0.619 fmt-miss=8 rec-miss=10 fp=0
FORMAT-de SUMMARY RULE-COMPOUNDS wer=0.206 cer=0.064 terms=16/31 recall=0.516 fmt-acc=0.762 fmt-miss=5 rec-miss=10 fp=0
FORMAT-de SUMMARY RULE-MARKUP wer=0.237 cer=0.049 terms=13/31 recall=0.419 fmt-acc=0.591 fmt-miss=9 rec-miss=9 fp=0
FORMAT-de SUMMARY RULE-MARKUP-ACRONYMS wer=0.223 cer=0.048 terms=14/31 recall=0.452 fmt-acc=0.636 fmt-miss=8 rec-miss=9 fp=0
FORMAT-de SUMMARY RULE-CASING wer=0.250 cer=0.067 terms=13/31 recall=0.419 fmt-acc=0.619 fmt-miss=8 rec-miss=10 fp=0
FORMAT-de CATEGORY names terms=3/4 fmt-miss=1 rec-miss=0
FORMAT-de CATEGORY technical terms=2/7 fmt-miss=2 rec-miss=3
FORMAT-de CATEGORY abbreviations terms=2/4 fmt-miss=0 rec-miss=2
FORMAT-de CATEGORY numbers terms=3/6 fmt-miss=2 rec-miss=1
FORMAT-de CATEGORY mixed terms=3/10 fmt-miss=3 rec-miss=4
FORMAT-de DELTA AFTER-ALL wer=-0.095 cer=-0.025 terms=20-vs-13 fmt-acc=0.290 false-corrections=0
FORMAT-de RECOVERED AFTER-ALL technical-02 StoreKit
FORMAT-de RECOVERED AFTER-ALL technical-02 CloudKit
FORMAT-de RECOVERED AFTER-ALL abbrev-02 KI
FORMAT-de RECOVERED AFTER-ALL numbers-02 13:45
FORMAT-de RECOVERED AFTER-ALL mixed-01 13:45
FORMAT-de RECOVERED AFTER-ALL mixed-02 1.2.0
FORMAT-de RECOVERED AFTER-ALL mixed-03 Markdown
FORMAT-de DELTA RULE-TIMES wer=-0.013 cer=-0.002 terms=15-vs-13 fmt-acc=0.095 false-corrections=0
FORMAT-de RECOVERED RULE-TIMES numbers-02 13:45
FORMAT-de RECOVERED RULE-TIMES mixed-01 13:45
FORMAT-de DELTA RULE-VERSIONS wer=-0.010 cer=-0.001 terms=14-vs-13 fmt-acc=0.048 false-corrections=0
FORMAT-de RECOVERED RULE-VERSIONS mixed-02 1.2.0
FORMAT-de DELTA RULE-ACRONYMS wer=0.000 cer=0.000 terms=13-vs-13 fmt-acc=0.000 false-corrections=0
FORMAT-de DELTA RULE-COMPOUNDS wer=-0.044 cer=-0.003 terms=16-vs-13 fmt-acc=0.143 false-corrections=0
FORMAT-de RECOVERED RULE-COMPOUNDS technical-02 StoreKit
FORMAT-de RECOVERED RULE-COMPOUNDS technical-02 CloudKit
FORMAT-de RECOVERED RULE-COMPOUNDS mixed-03 Markdown
FORMAT-de DELTA RULE-MARKUP wer=-0.013 cer=-0.018 terms=13-vs-13 fmt-acc=-0.028 false-corrections=0
FORMAT-de DELTA RULE-MARKUP-ACRONYMS wer=-0.027 cer=-0.019 terms=14-vs-13 fmt-acc=0.017 false-corrections=0
FORMAT-de RECOVERED RULE-MARKUP-ACRONYMS abbrev-02 KI
FORMAT-de DELTA RULE-CASING wer=0.000 cer=0.000 terms=13-vs-13 fmt-acc=0.000 false-corrections=0
FORMAT-en ENV device=iPhone iOS 27.0.1 locale=en-US cases=15 source=frozen-fixtures
FORMAT-en RAW en-names-01 t=0.349s TEXT: Renee works at the Kamnitz Transport Company.
FORMAT-en RAW en-names-02 t=0.069s TEXT: Jacqueline confirmed the meeting with Honning and Kel.
FORMAT-en RAW en-technical-01 t=0.078s TEXT: The docks are in SharePoint and the container runs in docker.
FORMAT-en RAW en-technical-02 t=0.070s TEXT: The purchase goes through StoreKit and sinking through CloudKit.
FORMAT-en RAW en-technical-03 t=0.058s TEXT: The interface is written in SwiftUI.
FORMAT-en RAW en-technical-04 t=0.081s TEXT: Speech Analyzer receives the terms through analysis context.
FORMAT-en RAW en-abbrev-01 t=0.078s TEXT: Access runs over VPN and the devices come from MDM.
FORMAT-en RAW en-abbrev-02 t=0.068s TEXT: The API is documented and the AI runs on the device.
FORMAT-en RAW en-numbers-01 t=0.060s TEXT: The purchase costs $9.99
FORMAT-en RAW en-numbers-02 t=0.079s TEXT: The meeting is on October 4, 2026 at 1345 o'clock.
FORMAT-en RAW en-numbers-03 t=0.072s TEXT: The server address is 192-16824.
FORMAT-en RAW en-numbers-04 t=0.067s TEXT: We are shipping version one.  0.0 is billed 10.
FORMAT-en RAW en-mixed-01 t=0.094s TEXT: Renee files the CVAG documents in SharePoint by 1345 o'clock.
FORMAT-en RAW en-mixed-02 t=0.093s TEXT: For version one.  we check the API and the VPN access on October 4th.
FORMAT-en RAW en-mixed-03 t=0.091s TEXT: The AI summary runs on device and the export goes to Markdown.
FORMAT-en MARKUP AUDIT none
FORMAT-en BEFORE en-names-01 wer=0.286 cer=0.089 hits=0/2 fmt-miss= rec-miss=Rene|Chemnitz fmt-acc=1.000
FORMAT-en BEFORE en-names-02 wer=0.250 cer=0.055 hits=1/2 fmt-miss= rec-miss=Hanning fmt-acc=1.000
FORMAT-en BEFORE en-technical-01 wer=0.091 cer=0.017 hits=2/2 fmt-miss= rec-miss= fmt-acc=1.000
FORMAT-en BEFORE en-technical-02 wer=0.111 cer=0.031 hits=2/2 fmt-miss= rec-miss= fmt-acc=1.000
FORMAT-en BEFORE en-technical-03 wer=0.000 cer=0.000 hits=1/1 fmt-miss= rec-miss= fmt-acc=1.000
FORMAT-en BEFORE en-technical-04 wer=0.667 cer=0.034 hits=0/2 fmt-miss=SpeechAnalyzer|AnalysisContext rec-miss= fmt-acc=0.000
FORMAT-en BEFORE en-abbrev-01 wer=0.000 cer=0.000 hits=2/2 fmt-miss= rec-miss= fmt-acc=1.000
FORMAT-en BEFORE en-abbrev-02 wer=0.000 cer=0.000 hits=2/2 fmt-miss= rec-miss= fmt-acc=1.000
FORMAT-en BEFORE en-numbers-01 wer=0.200 cer=0.281 hits=1/1 fmt-miss= rec-miss= fmt-acc=1.000
FORMAT-en BEFORE en-numbers-02 wer=0.182 cer=0.058 hits=1/2 fmt-miss=13:45 rec-miss= fmt-acc=0.500
FORMAT-en BEFORE en-numbers-03 wer=0.200 cer=0.088 hits=0/1 fmt-miss=192.168.2.4 rec-miss= fmt-acc=0.000
FORMAT-en BEFORE en-numbers-04 wer=0.500 cer=0.214 hits=1/2 fmt-miss= rec-miss=1.2.0 fmt-acc=1.000
FORMAT-en BEFORE en-mixed-01 wer=0.182 cer=0.033 hits=2/4 fmt-miss=13:45 rec-miss=Rene fmt-acc=0.667
FORMAT-en BEFORE en-mixed-02 wer=0.071 cer=0.058 hits=3/4 fmt-miss= rec-miss=1.2.0 fmt-acc=1.000
FORMAT-en BEFORE en-mixed-03 wer=0.182 cer=0.016 hits=2/2 fmt-miss= rec-miss= fmt-acc=1.000
FORMAT-en SUMMARY BEFORE wer=0.195 cer=0.065 terms=20/31 recall=0.645 fmt-acc=0.800 fmt-miss=5 rec-miss=6 fp=0
FORMAT-en AFTER-ALL en-names-01 wer=0.286 cer=0.089 hits=0/2 fmt-miss= rec-miss=Rene|Chemnitz fmt-acc=1.000
FORMAT-en AFTER-ALL en-names-02 wer=0.250 cer=0.055 hits=1/2 fmt-miss= rec-miss=Hanning fmt-acc=1.000
FORMAT-en AFTER-ALL en-technical-01 wer=0.091 cer=0.017 hits=2/2 fmt-miss= rec-miss= fmt-acc=1.000
FORMAT-en AFTER-ALL en-technical-02 wer=0.111 cer=0.031 hits=2/2 fmt-miss= rec-miss= fmt-acc=1.000
FORMAT-en AFTER-ALL en-technical-03 wer=0.000 cer=0.000 hits=1/1 fmt-miss= rec-miss= fmt-acc=1.000
FORMAT-en AFTER-ALL en-technical-04 wer=0.333 cer=0.017 hits=1/2 fmt-miss=AnalysisContext rec-miss= fmt-acc=0.500
FORMAT-en CHANGED en-technical-04 FROM: Speech Analyzer receives the terms through analysis context.
FORMAT-en CHANGED en-technical-04   TO: SpeechAnalyzer receives the terms through analysis context.
FORMAT-en AFTER-ALL en-abbrev-01 wer=0.000 cer=0.000 hits=2/2 fmt-miss= rec-miss= fmt-acc=1.000
FORMAT-en AFTER-ALL en-abbrev-02 wer=0.000 cer=0.000 hits=2/2 fmt-miss= rec-miss= fmt-acc=1.000
FORMAT-en AFTER-ALL en-numbers-01 wer=0.200 cer=0.281 hits=1/1 fmt-miss= rec-miss= fmt-acc=1.000
FORMAT-en AFTER-ALL en-numbers-02 wer=0.182 cer=0.058 hits=1/2 fmt-miss=13:45 rec-miss= fmt-acc=0.500
FORMAT-en AFTER-ALL en-numbers-03 wer=0.200 cer=0.088 hits=0/1 fmt-miss=192.168.2.4 rec-miss= fmt-acc=0.000
FORMAT-en AFTER-ALL en-numbers-04 wer=0.500 cer=0.214 hits=1/2 fmt-miss= rec-miss=1.2.0 fmt-acc=1.000
FORMAT-en AFTER-ALL en-mixed-01 wer=0.182 cer=0.033 hits=2/4 fmt-miss=13:45 rec-miss=Rene fmt-acc=0.667
FORMAT-en AFTER-ALL en-mixed-02 wer=0.071 cer=0.058 hits=3/4 fmt-miss= rec-miss=1.2.0 fmt-acc=1.000
FORMAT-en AFTER-ALL en-mixed-03 wer=0.182 cer=0.016 hits=2/2 fmt-miss= rec-miss= fmt-acc=1.000
FORMAT-en SUMMARY AFTER-ALL wer=0.173 cer=0.064 terms=21/31 recall=0.677 fmt-acc=0.840 fmt-miss=4 rec-miss=6 fp=0
FORMAT-en SUMMARY RULE-TIMES wer=0.195 cer=0.065 terms=20/31 recall=0.645 fmt-acc=0.800 fmt-miss=5 rec-miss=6 fp=0
FORMAT-en SUMMARY RULE-VERSIONS wer=0.195 cer=0.065 terms=20/31 recall=0.645 fmt-acc=0.800 fmt-miss=5 rec-miss=6 fp=0
FORMAT-en SUMMARY RULE-ACRONYMS wer=0.195 cer=0.065 terms=20/31 recall=0.645 fmt-acc=0.800 fmt-miss=5 rec-miss=6 fp=0
FORMAT-en SUMMARY RULE-COMPOUNDS wer=0.173 cer=0.064 terms=21/31 recall=0.677 fmt-acc=0.840 fmt-miss=4 rec-miss=6 fp=0
FORMAT-en SUMMARY RULE-MARKUP wer=0.195 cer=0.065 terms=20/31 recall=0.645 fmt-acc=0.800 fmt-miss=5 rec-miss=6 fp=0
FORMAT-en SUMMARY RULE-MARKUP-ACRONYMS wer=0.195 cer=0.065 terms=20/31 recall=0.645 fmt-acc=0.800 fmt-miss=5 rec-miss=6 fp=0
FORMAT-en SUMMARY RULE-CASING wer=0.195 cer=0.065 terms=20/31 recall=0.645 fmt-acc=0.800 fmt-miss=5 rec-miss=6 fp=0
FORMAT-en CATEGORY names terms=1/4 fmt-miss=0 rec-miss=3
FORMAT-en CATEGORY technical terms=5/7 fmt-miss=2 rec-miss=0
FORMAT-en CATEGORY abbreviations terms=4/4 fmt-miss=0 rec-miss=0
FORMAT-en CATEGORY numbers terms=3/6 fmt-miss=2 rec-miss=1
FORMAT-en CATEGORY mixed terms=7/10 fmt-miss=1 rec-miss=2
FORMAT-en DELTA AFTER-ALL wer=-0.022 cer=-0.001 terms=21-vs-20 fmt-acc=0.040 false-corrections=0
FORMAT-en RECOVERED AFTER-ALL en-technical-04 SpeechAnalyzer
FORMAT-en DELTA RULE-TIMES wer=0.000 cer=0.000 terms=20-vs-20 fmt-acc=0.000 false-corrections=0
FORMAT-en DELTA RULE-VERSIONS wer=0.000 cer=0.000 terms=20-vs-20 fmt-acc=0.000 false-corrections=0
FORMAT-en DELTA RULE-ACRONYMS wer=0.000 cer=0.000 terms=20-vs-20 fmt-acc=0.000 false-corrections=0
FORMAT-en DELTA RULE-COMPOUNDS wer=-0.022 cer=-0.001 terms=21-vs-20 fmt-acc=0.040 false-corrections=0
FORMAT-en RECOVERED RULE-COMPOUNDS en-technical-04 SpeechAnalyzer
FORMAT-en DELTA RULE-MARKUP wer=0.000 cer=0.000 terms=20-vs-20 fmt-acc=0.000 false-corrections=0
FORMAT-en DELTA RULE-MARKUP-ACRONYMS wer=0.000 cer=0.000 terms=20-vs-20 fmt-acc=0.000 false-corrections=0
FORMAT-en DELTA RULE-CASING wer=0.000 cer=0.000 terms=20-vs-20 fmt-acc=0.000 false-corrections=0
PERF formatter 1200 segments in 0.153s (0.128ms per segment)
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
