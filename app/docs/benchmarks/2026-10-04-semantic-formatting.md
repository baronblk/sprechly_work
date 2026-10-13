# Raw output — Phase 4 semantic formatting, frozen fixtures

Device: iPhone 17 Pro, iOS 27.0.1 · locale de-DE · 2026-10-04
Audio: Tests/Fixtures/Transcription (SHA-256 pinned, see SHA256SUMS)
Unaltered test output. Do not overwrite — later runs get their own file.

```
FORMAT ENV device=iPhone iOS 27.0.1 locale=de-DE cases=15 source=frozen-fixtures
FORMAT RAW names-01 t=0.253s TEXT: René arbeitet bei der Chemnitzer Verkehrs AG.
FORMAT RAW names-02 t=0.091s TEXT: Jacqueline hat den Termin mit Hanning und Karl bestätigt.
FORMAT RAW technical-01 t=0.096s TEXT: Die Doku liegt in Sharepoint, der Container läuft in Docker.
FORMAT RAW technical-02 t=0.087s TEXT: Der Kauf läuft über Store Kit, die Synchronisierung über Cloud Kit.
FORMAT RAW technical-03 t=0.076s TEXT: Die Oberfläche ist in SwiftOE geschrieben.
FORMAT RAW technical-04 t=0.088s TEXT: Speech Analizer bekommt die Begriffe über Analysis Kontext.
FORMAT RAW abbrev-01 t=0.082s TEXT: Der Zugriff läuft über VPN, die Geräte kommen aus dem MDM.
FORMAT RAW abbrev-02 t=0.080s TEXT: Die AP ist dokumentiert, die K\letter I\letter läuft auf dem Gerät.
FORMAT RAW numbers-01 t=0.079s TEXT: Der Kauf kostet 9,99 Euro Cent.
FORMAT RAW numbers-02 t=0.096s TEXT: Das Treffen ist am 4. Oktober 2026 um 13.45 Uhr.
FORMAT RAW numbers-03 t=0.082s TEXT: Der Server hat die Adresse 19216824.
FORMAT RAW numbers-04 t=0.075s TEXT: Wir veröffentlichen Version als Bild 10.
FORMAT RAW mixed-01 t=0.094s TEXT: René legt die CVAG-Unterlagen bis 13.45 Uhr in Sharepoint ab.
FORMAT RAW mixed-02 t=0.094s TEXT: Für Version 1. 2.0 prüfen wir die AP und den VPN-Zugang am 4. Oktober.
FORMAT RAW mixed-03 t=0.088s TEXT: Die KI-Zusammenfassung läuft on device, der Export geht nach Mark Down.
FORMAT MARKUP abbrev-02 found=\letter \letter
FORMAT MARKUP AUDIT \letter=2
FORMAT BEFORE names-01 wer=0.333 cer=0.022 hits=1/2 fmt-miss=Chemnitzer Verkehrs-AG rec-miss= fmt-acc=0.500
FORMAT BEFORE names-02 wer=0.111 cer=0.018 hits=2/2 fmt-miss= rec-miss= fmt-acc=1.000
FORMAT BEFORE technical-01 wer=0.000 cer=0.000 hits=2/2 fmt-miss= rec-miss= fmt-acc=1.000
FORMAT BEFORE technical-02 wer=0.444 cer=0.031 hits=0/2 fmt-miss=StoreKit|CloudKit rec-miss= fmt-acc=0.000
FORMAT BEFORE technical-03 wer=0.167 cer=0.048 hits=0/1 fmt-miss= rec-miss=SwiftUI fmt-acc=1.000
FORMAT BEFORE technical-04 wer=0.667 cer=0.070 hits=0/2 fmt-miss= rec-miss=SpeechAnalyzer|AnalysisContext fmt-acc=1.000
FORMAT BEFORE abbrev-01 wer=0.000 cer=0.000 hits=2/2 fmt-miss= rec-miss= fmt-acc=1.000
FORMAT BEFORE abbrev-02 wer=0.500 cer=0.302 hits=0/2 fmt-miss= rec-miss=API|KI fmt-acc=1.000
FORMAT BEFORE numbers-01 wer=0.200 cer=0.192 hits=1/1 fmt-miss= rec-miss= fmt-acc=1.000
FORMAT BEFORE numbers-02 wer=0.100 cer=0.021 hits=1/2 fmt-miss=13:45 rec-miss= fmt-acc=0.500
FORMAT BEFORE numbers-03 wer=0.167 cer=0.077 hits=0/1 fmt-miss=192.168.2.4 rec-miss= fmt-acc=0.000
FORMAT BEFORE numbers-04 wer=0.286 cer=0.149 hits=1/2 fmt-miss= rec-miss=1.2.0 fmt-acc=1.000
FORMAT BEFORE mixed-01 wer=0.100 cer=0.016 hits=2/4 fmt-miss=13:45 rec-miss=CVAG fmt-acc=0.667
FORMAT BEFORE mixed-02 wer=0.231 cer=0.029 hits=1/4 fmt-miss=1.2.0 rec-miss=API|VPN fmt-acc=0.500
FORMAT BEFORE mixed-03 wer=0.444 cer=0.029 hits=0/2 fmt-miss=Markdown rec-miss=KI fmt-acc=0.000
FORMAT SUMMARY BEFORE wer=0.250 cer=0.067 terms=13/31 recall=0.419 fmt-acc=0.619 fmt-miss=8 rec-miss=10 fp=0
FORMAT AFTER-ALL names-01 wer=0.333 cer=0.022 hits=1/2 fmt-miss=Chemnitzer Verkehrs-AG rec-miss= fmt-acc=0.500
FORMAT AFTER-ALL names-02 wer=0.111 cer=0.018 hits=2/2 fmt-miss= rec-miss= fmt-acc=1.000
FORMAT AFTER-ALL technical-01 wer=0.000 cer=0.000 hits=2/2 fmt-miss= rec-miss= fmt-acc=1.000
FORMAT CHANGED technical-01 FROM: Die Doku liegt in Sharepoint, der Container läuft in Docker.
FORMAT CHANGED technical-01   TO: Die Doku liegt in SharePoint, der Container läuft in Docker.
FORMAT AFTER-ALL technical-02 wer=0.000 cer=0.000 hits=2/2 fmt-miss= rec-miss= fmt-acc=1.000
FORMAT CHANGED technical-02 FROM: Der Kauf läuft über Store Kit, die Synchronisierung über Cloud Kit.
FORMAT CHANGED technical-02   TO: Der Kauf läuft über StoreKit, die Synchronisierung über CloudKit.
FORMAT AFTER-ALL technical-03 wer=0.167 cer=0.048 hits=0/1 fmt-miss= rec-miss=SwiftUI fmt-acc=1.000
FORMAT AFTER-ALL technical-04 wer=0.667 cer=0.070 hits=0/2 fmt-miss= rec-miss=SpeechAnalyzer|AnalysisContext fmt-acc=1.000
FORMAT AFTER-ALL abbrev-01 wer=0.000 cer=0.000 hits=2/2 fmt-miss= rec-miss= fmt-acc=1.000
FORMAT AFTER-ALL abbrev-02 wer=0.100 cer=0.019 hits=1/2 fmt-miss= rec-miss=API fmt-acc=1.000
FORMAT CHANGED abbrev-02 FROM: Die AP ist dokumentiert, die K\letter I\letter läuft auf dem Gerät.
FORMAT CHANGED abbrev-02   TO: Die AP ist dokumentiert, die KI läuft auf dem Gerät.
FORMAT AFTER-ALL numbers-01 wer=0.200 cer=0.192 hits=1/1 fmt-miss= rec-miss= fmt-acc=1.000
FORMAT AFTER-ALL numbers-02 wer=0.000 cer=0.000 hits=2/2 fmt-miss= rec-miss= fmt-acc=1.000
FORMAT CHANGED numbers-02 FROM: Das Treffen ist am 4. Oktober 2026 um 13.45 Uhr.
FORMAT CHANGED numbers-02   TO: Das Treffen ist am 4. Oktober 2026 um 13:45 Uhr.
FORMAT AFTER-ALL numbers-03 wer=0.167 cer=0.077 hits=0/1 fmt-miss=192.168.2.4 rec-miss= fmt-acc=0.000
FORMAT AFTER-ALL numbers-04 wer=0.286 cer=0.149 hits=1/2 fmt-miss= rec-miss=1.2.0 fmt-acc=1.000
FORMAT AFTER-ALL mixed-01 wer=0.000 cer=0.000 hits=3/4 fmt-miss= rec-miss=CVAG fmt-acc=1.000
FORMAT CHANGED mixed-01 FROM: René legt die CVAG-Unterlagen bis 13.45 Uhr in Sharepoint ab.
FORMAT CHANGED mixed-01   TO: René legt die CVAG-Unterlagen bis 13:45 Uhr in SharePoint ab.
FORMAT AFTER-ALL mixed-02 wer=0.077 cer=0.014 hits=2/4 fmt-miss= rec-miss=API|VPN fmt-acc=1.000
FORMAT CHANGED mixed-02 FROM: Für Version 1. 2.0 prüfen wir die AP und den VPN-Zugang am 4. Oktober.
FORMAT CHANGED mixed-02   TO: Für Version 1.2.0 prüfen wir die AP und den VPN-Zugang am 4. Oktober.
FORMAT AFTER-ALL mixed-03 wer=0.222 cer=0.014 hits=1/2 fmt-miss= rec-miss=KI fmt-acc=1.000
FORMAT CHANGED mixed-03 FROM: Die KI-Zusammenfassung läuft on device, der Export geht nach Mark Down.
FORMAT CHANGED mixed-03   TO: Die KI-Zusammenfassung läuft on device, der Export geht nach Markdown.
FORMAT SUMMARY AFTER-ALL wer=0.155 cer=0.042 terms=20/31 recall=0.645 fmt-acc=0.909 fmt-miss=2 rec-miss=9 fp=0
FORMAT SUMMARY RULE-TIMES wer=0.237 cer=0.064 terms=15/31 recall=0.484 fmt-acc=0.714 fmt-miss=6 rec-miss=10 fp=0
FORMAT SUMMARY RULE-VERSIONS wer=0.240 cer=0.066 terms=14/31 recall=0.452 fmt-acc=0.667 fmt-miss=7 rec-miss=10 fp=0
FORMAT SUMMARY RULE-ACRONYMS wer=0.250 cer=0.067 terms=13/31 recall=0.419 fmt-acc=0.619 fmt-miss=8 rec-miss=10 fp=0
FORMAT SUMMARY RULE-COMPOUNDS wer=0.206 cer=0.064 terms=16/31 recall=0.516 fmt-acc=0.762 fmt-miss=5 rec-miss=10 fp=0
FORMAT SUMMARY RULE-MARKUP wer=0.237 cer=0.049 terms=13/31 recall=0.419 fmt-acc=0.591 fmt-miss=9 rec-miss=9 fp=0
FORMAT SUMMARY RULE-MARKUP-ACRONYMS wer=0.223 cer=0.048 terms=14/31 recall=0.452 fmt-acc=0.636 fmt-miss=8 rec-miss=9 fp=0
FORMAT SUMMARY RULE-CASING wer=0.250 cer=0.067 terms=13/31 recall=0.419 fmt-acc=0.619 fmt-miss=8 rec-miss=10 fp=0
FORMAT CATEGORY names terms=3/4 fmt-miss=1 rec-miss=0
FORMAT CATEGORY technical terms=2/7 fmt-miss=2 rec-miss=3
FORMAT CATEGORY abbreviations terms=2/4 fmt-miss=0 rec-miss=2
FORMAT CATEGORY numbers terms=3/6 fmt-miss=2 rec-miss=1
FORMAT CATEGORY mixed terms=3/10 fmt-miss=3 rec-miss=4
FORMAT DELTA AFTER-ALL wer=-0.095 cer=-0.025 terms=20-vs-13 fmt-acc=0.290 false-corrections=0
FORMAT RECOVERED AFTER-ALL technical-02 StoreKit
FORMAT RECOVERED AFTER-ALL technical-02 CloudKit
FORMAT RECOVERED AFTER-ALL abbrev-02 KI
FORMAT RECOVERED AFTER-ALL numbers-02 13:45
FORMAT RECOVERED AFTER-ALL mixed-01 13:45
FORMAT RECOVERED AFTER-ALL mixed-02 1.2.0
FORMAT RECOVERED AFTER-ALL mixed-03 Markdown
FORMAT DELTA RULE-TIMES wer=-0.013 cer=-0.002 terms=15-vs-13 fmt-acc=0.095 false-corrections=0
FORMAT RECOVERED RULE-TIMES numbers-02 13:45
FORMAT RECOVERED RULE-TIMES mixed-01 13:45
FORMAT DELTA RULE-VERSIONS wer=-0.010 cer=-0.001 terms=14-vs-13 fmt-acc=0.048 false-corrections=0
FORMAT RECOVERED RULE-VERSIONS mixed-02 1.2.0
FORMAT DELTA RULE-ACRONYMS wer=0.000 cer=0.000 terms=13-vs-13 fmt-acc=0.000 false-corrections=0
FORMAT DELTA RULE-COMPOUNDS wer=-0.044 cer=-0.003 terms=16-vs-13 fmt-acc=0.143 false-corrections=0
FORMAT RECOVERED RULE-COMPOUNDS technical-02 StoreKit
FORMAT RECOVERED RULE-COMPOUNDS technical-02 CloudKit
FORMAT RECOVERED RULE-COMPOUNDS mixed-03 Markdown
FORMAT DELTA RULE-MARKUP wer=-0.013 cer=-0.018 terms=13-vs-13 fmt-acc=-0.028 false-corrections=0
FORMAT DELTA RULE-MARKUP-ACRONYMS wer=-0.027 cer=-0.019 terms=14-vs-13 fmt-acc=0.017 false-corrections=0
FORMAT RECOVERED RULE-MARKUP-ACRONYMS abbrev-02 KI
FORMAT DELTA RULE-CASING wer=0.000 cer=0.000 terms=13-vs-13 fmt-acc=0.000 false-corrections=0
```
