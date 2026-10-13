# Raw output — 1.2 Phase 3 transcriber comparison

Device run, 2026-10-04T17:43:58Z. SpeechTranscriber vs DictationTranscriber,
identical audio within this run.

```
CAPS dictation installed=de_DE,en_US
CAPS dictation supported-de=true
CAPS dictation supportedLocales=54 installedLocales=2
CAPS preset longDictation: hints=0 transcription=[Speech.DictationTranscriber.TranscriptionOption.punctuation] reporting=[] attributes=[]
CAPS preset phrase: hints=1 transcription=[] reporting=[] attributes=[]
CAPS preset progressiveLongDictation: hints=0 transcription=[Speech.DictationTranscriber.TranscriptionOption.punctuation] reporting=[Speech.DictationTranscriber.ReportingOption.volatileResults] attributes=[]
CAPS preset progressiveShortDictation: hints=1 transcription=[Speech.DictationTranscriber.TranscriptionOption.punctuation] reporting=[Speech.DictationTranscriber.ReportingOption.volatileResults, Speech.DictationTranscriber.ReportingOption.frequentFinalization] attributes=[]
CAPS preset shortDictation: hints=1 transcription=[Speech.DictationTranscriber.TranscriptionOption.punctuation] reporting=[] attributes=[]
CAPS preset timeIndexedLongDictation: hints=0 transcription=[Speech.DictationTranscriber.TranscriptionOption.punctuation] reporting=[] attributes=[Speech.DictationTranscriber.ResultAttributeOption.audioTimeRange]
CAPS speech installed=de_AT,de_CH,de_DE,en_AU,en_CA,en_GB,en_IE,en_IN,en_NZ,en_SG,en_US,en_ZA
CAPS speech isAvailable=true supportedLocales=45 installedLocales=12
COMPARE CATEGORY DICT-FARFIELD abbreviations terms=3/4 wer=0.100
COMPARE CATEGORY DICT-FARFIELD mixed terms=6/10 wer=0.391
COMPARE CATEGORY DICT-FARFIELD names terms=3/4 wer=0.222
COMPARE CATEGORY DICT-FARFIELD numbers terms=3/6 wer=0.199
COMPARE CATEGORY DICT-FARFIELD technical terms=1/7 wer=0.358
COMPARE CATEGORY DICTATION abbreviations terms=3/4 wer=0.100
COMPARE CATEGORY DICTATION mixed terms=6/10 wer=0.391
COMPARE CATEGORY DICTATION names terms=3/4 wer=0.222
COMPARE CATEGORY DICTATION numbers terms=3/6 wer=0.282
COMPARE CATEGORY DICTATION technical terms=1/7 wer=0.358
COMPARE CATEGORY SPEECH abbreviations terms=2/4 wer=0.250
COMPARE CATEGORY SPEECH mixed terms=5/10 wer=0.159
COMPARE CATEGORY SPEECH names terms=3/4 wer=0.222
COMPARE CATEGORY SPEECH numbers terms=4/6 wer=0.205
COMPARE CATEGORY SPEECH technical terms=2/7 wer=0.319
COMPARE DELTA DICT-FARFIELD wer=0.035 cer=0.028 recall=0.000 terms=16-vs-16
COMPARE DELTA DICTATION wer=0.058 cer=0.032 recall=0.000 terms=16-vs-16
COMPARE DICT-FARFIELD abbrev-01 TEXT: Der Zugriff läuft über VPN die Geräte kommen aus dem MDM
COMPARE DICT-FARFIELD abbrev-01 wer=0.000 cer=0.034 hits=2/2 missed= fp= t=0.147s
COMPARE DICT-FARFIELD abbrev-02 TEXT: Die APS dokumentiert die KI läuft auf dem Gerät
COMPARE DICT-FARFIELD abbrev-02 wer=0.200 cer=0.113 hits=1/2 missed=API fp= t=0.281s
COMPARE DICT-FARFIELD mixed-01 TEXT: René legt die CVAG Unterlagen bis 13:45 Uhr in SharePoint ab
COMPARE DICT-FARFIELD mixed-01 wer=0.200 cer=0.033 hits=4/4 missed= fp= t=0.172s
COMPARE DICT-FARFIELD mixed-02 TEXT: Für Version 120 prüfen wir die AP und den VPN Zugang am 4. Oktober
COMPARE DICT-FARFIELD mixed-02 wer=0.308 cer=0.071 hits=2/4 missed=1.2.0|API fp= t=0.186s
COMPARE DICT-FARFIELD mixed-03 TEXT: Die K.I. Zusammenfassung läuft on Devise der Export geht nach Mark Down
COMPARE DICT-FARFIELD mixed-03 wer=0.667 cer=0.114 hits=0/2 missed=KI|Markdown fp= t=0.187s
COMPARE DICT-FARFIELD names-01 TEXT: René arbeitet bei der Chemnitzer Verkehrs AG
COMPARE DICT-FARFIELD names-01 wer=0.333 cer=0.044 hits=1/2 missed=Chemnitzer Verkehrs-AG fp= t=0.121s
COMPARE DICT-FARFIELD names-02 TEXT: Jacqueline hat den Termin mit Hanning und Karl bestätigt
COMPARE DICT-FARFIELD names-02 wer=0.111 cer=0.035 hits=2/2 missed= fp= t=0.146s
COMPARE DICT-FARFIELD numbers-01 TEXT: Der Kauf kostet 9,99 €
COMPARE DICT-FARFIELD numbers-01 wer=0.200 cer=0.231 hits=1/1 missed= fp= t=0.128s
COMPARE DICT-FARFIELD numbers-02 TEXT: Das Treffen ist am 4. Oktober 2026 um 13:45 Uhr
COMPARE DICT-FARFIELD numbers-02 wer=0.000 cer=0.021 hits=2/2 missed= fp= t=0.172s
COMPARE DICT-FARFIELD numbers-03 TEXT: Der Server hat die Adresse 192.168.284
COMPARE DICT-FARFIELD numbers-03 wer=0.167 cer=0.051 hits=0/1 missed=192.168.2.4 fp= t=0.191s
COMPARE DICT-FARFIELD numbers-04 TEXT: Wir veröffentlichen Version 120 als Bild zehn
COMPARE DICT-FARFIELD numbers-04 wer=0.429 cer=0.149 hits=0/2 missed=1.2.0|10 fp= t=0.153s
COMPARE DICT-FARFIELD technical-01 TEXT: Die Doku liegt in SharePoint der Container läuft in Doca
COMPARE DICT-FARFIELD technical-01 wer=0.100 cer=0.083 hits=1/2 missed=Docker fp= t=0.144s
COMPARE DICT-FARFIELD technical-02 TEXT: Der Kauf läuft über die Synchronisierung über Cloud Kit
COMPARE DICT-FARFIELD technical-02 wer=0.333 cer=0.185 hits=0/2 missed=StoreKit|CloudKit fp= t=0.168s
COMPARE DICT-FARFIELD technical-03 TEXT: Die Oberfläche ist in Swift UE geschrieben
COMPARE DICT-FARFIELD technical-03 wer=0.333 cer=0.071 hits=0/1 missed=SwiftUI fp= t=0.150s
COMPARE DICT-FARFIELD technical-04 TEXT: Speech Analyse bekommt die Begriffe über Analysis Kontext
COMPARE DICT-FARFIELD technical-04 wer=0.667 cer=0.105 hits=0/2 missed=SpeechAnalyzer|AnalysisContext fp= t=0.142s
COMPARE DICTATION abbrev-01 TEXT: Der Zugriff läuft über VPN die Geräte kommen aus dem MDM
COMPARE DICTATION abbrev-01 wer=0.000 cer=0.034 hits=2/2 missed= fp= t=0.147s
COMPARE DICTATION abbrev-02 TEXT: Die APS dokumentiert. Die KI läuft auf dem Gerät.
COMPARE DICTATION abbrev-02 wer=0.200 cer=0.094 hits=1/2 missed=API fp= t=0.384s
COMPARE DICTATION mixed-01 TEXT: René legt die CVAG Unterlagen bis 13:45 Uhr in SharePoint ab
COMPARE DICTATION mixed-01 wer=0.200 cer=0.033 hits=4/4 missed= fp= t=0.209s
COMPARE DICTATION mixed-02 TEXT: Für Version 120 prüfen wir die AP und den VPN Zugang am 4. Oktober
COMPARE DICTATION mixed-02 wer=0.308 cer=0.071 hits=2/4 missed=1.2.0|API fp= t=0.199s
COMPARE DICTATION mixed-03 TEXT: Die K.I. Zusammenfassung läuft on Devise der Export geht nach Mark Down
COMPARE DICTATION mixed-03 wer=0.667 cer=0.114 hits=0/2 missed=KI|Markdown fp= t=0.295s
COMPARE DICTATION names-01 TEXT: René arbeitet bei der Chemnitzer Verkehrs AG
COMPARE DICTATION names-01 wer=0.333 cer=0.044 hits=1/2 missed=Chemnitzer Verkehrs-AG fp= t=0.269s
COMPARE DICTATION names-02 TEXT: Jacqueline hat den Termin mit Hanning und Karl bestätigt
COMPARE DICTATION names-02 wer=0.111 cer=0.035 hits=2/2 missed= fp= t=0.221s
COMPARE DICTATION numbers-01 TEXT: Der Kauf kostet 9,99 €
COMPARE DICTATION numbers-01 wer=0.200 cer=0.231 hits=1/1 missed= fp= t=0.134s
COMPARE DICTATION numbers-02 TEXT: Das Treffen ist am 4. Oktober 2026 um 13:45 Uhr
COMPARE DICTATION numbers-02 wer=0.000 cer=0.021 hits=2/2 missed= fp= t=0.192s
COMPARE DICTATION numbers-03 TEXT: Der Server hat die Adresse 192.1 6,8.2 8,4
COMPARE DICTATION numbers-03 wer=0.500 cer=0.154 hits=0/1 missed=192.168.2.4 fp= t=0.223s
COMPARE DICTATION numbers-04 TEXT: Wir veröffentlichen Version 120 als Bild zehn
COMPARE DICTATION numbers-04 wer=0.429 cer=0.149 hits=0/2 missed=1.2.0|10 fp= t=0.158s
COMPARE DICTATION technical-01 TEXT: Die Doku liegt in SharePoint. Der Container läuft in Doca.
COMPARE DICTATION technical-01 wer=0.100 cer=0.067 hits=1/2 missed=Docker fp= t=0.190s
COMPARE DICTATION technical-02 TEXT: Der Kauf läuft über die Synchronisierung über Cloud Kit
COMPARE DICTATION technical-02 wer=0.333 cer=0.185 hits=0/2 missed=StoreKit|CloudKit fp= t=0.193s
COMPARE DICTATION technical-03 TEXT: Die Oberfläche ist in Swift UE geschrieben
COMPARE DICTATION technical-03 wer=0.333 cer=0.071 hits=0/1 missed=SwiftUI fp= t=0.231s
COMPARE DICTATION technical-04 TEXT: Speech Analyse bekommt die Begriffe über Analysis Kontext
COMPARE DICTATION technical-04 wer=0.667 cer=0.105 hits=0/2 missed=SpeechAnalyzer|AnalysisContext fp= t=0.184s
COMPARE ENV device=iPhone iOS 27.0.1 locale=de-DE cases=15
COMPARE SPEECH abbrev-01 TEXT: Der Zugriff läuft über VPN, die Geräte kommen aus dem MDM.
COMPARE SPEECH abbrev-01 wer=0.000 cer=0.000 hits=2/2 missed= fp= t=0.078s
COMPARE SPEECH abbrev-02 TEXT: Die AP ist dokumentiert, die K\letter I\letter läuft auf dem Gerät.
COMPARE SPEECH abbrev-02 wer=0.500 cer=0.302 hits=0/2 missed=API|KI fp= t=0.075s
COMPARE SPEECH mixed-01 TEXT: René legt die CVAG-Unterlagen bis 13.45 Uhr in Sharepoint ab.
COMPARE SPEECH mixed-01 wer=0.100 cer=0.016 hits=2/4 missed=CVAG|13:45 fp= t=0.090s
COMPARE SPEECH mixed-02 TEXT: Für Version 1. 2.0 prüfen wir die API und den VPN-Zugang am 4. Oktober.
COMPARE SPEECH mixed-02 wer=0.154 cer=0.014 hits=2/4 missed=1.2.0|VPN fp= t=0.091s
COMPARE SPEECH mixed-03 TEXT: Die KI-Zusammenfassung läuft on device, der Export geht nach Markdown.
COMPARE SPEECH mixed-03 wer=0.222 cer=0.014 hits=1/2 missed=KI fp= t=0.085s
COMPARE SPEECH names-01 TEXT: René arbeitet bei der Chemnitzer Verkehrs AG.
COMPARE SPEECH names-01 wer=0.333 cer=0.022 hits=1/2 missed=Chemnitzer Verkehrs-AG fp= t=0.236s
COMPARE SPEECH names-02 TEXT: Jacqueline hat den Termin mit Hanning und Karl bestätigt.
COMPARE SPEECH names-02 wer=0.111 cer=0.018 hits=2/2 missed= fp= t=0.075s
COMPARE SPEECH numbers-01 TEXT: Der Kauf kostet 9,99 Euro Cent.
COMPARE SPEECH numbers-01 wer=0.200 cer=0.192 hits=1/1 missed= fp= t=0.071s
COMPARE SPEECH numbers-02 TEXT: Das Treffen ist am 4. Oktober 2026 um 13:45 Uhr.
COMPARE SPEECH numbers-02 wer=0.000 cer=0.000 hits=2/2 missed= fp= t=0.093s
COMPARE SPEECH numbers-03 TEXT: Der Surver hat die Adresse 192.1682.4.
COMPARE SPEECH numbers-03 wer=0.333 cer=0.051 hits=0/1 missed=192.168.2.4 fp= t=0.090s
COMPARE SPEECH numbers-04 TEXT: Wir veröffentlichen Version als Bild 10.
COMPARE SPEECH numbers-04 wer=0.286 cer=0.149 hits=1/2 missed=1.2.0 fp= t=0.074s
COMPARE SPEECH technical-01 TEXT: Die Doku liegt in Sharepoint, der Container läuft in Docker.
COMPARE SPEECH technical-01 wer=0.000 cer=0.000 hits=2/2 missed= fp= t=0.090s
COMPARE SPEECH technical-02 TEXT: Der Kauf läuft über Store Kit, die Synchronisierung über Cloud Kit.
COMPARE SPEECH technical-02 wer=0.444 cer=0.031 hits=0/2 missed=StoreKit|CloudKit fp= t=0.083s
COMPARE SPEECH technical-03 TEXT: Die Oberfläche ist in SwiftOE geschrieben.
COMPARE SPEECH technical-03 wer=0.167 cer=0.048 hits=0/1 missed=SwiftUI fp= t=0.070s
COMPARE SPEECH technical-04 TEXT: Speech Analizer bekommt die Begriffe über Analysis Kontext.
COMPARE SPEECH technical-04 wer=0.667 cer=0.070 hits=0/2 missed=SpeechAnalyzer|AnalysisContext fp= t=0.080s
COMPARE SUMMARY DICT-FARFIELD wer=0.270 cer=0.089 terms=16/31 recall=0.516 fp=0 time=2.487s cases=15
COMPARE SUMMARY DICTATION wer=0.292 cer=0.094 terms=16/31 recall=0.516 fp=0 time=3.228s cases=15
COMPARE SUMMARY SPEECH wer=0.234 cer=0.062 terms=16/31 recall=0.516 fp=0 time=1.380s cases=15
COMPARE TERM DICT-FARFIELD abbrev-01 MDM: speech=hit other=hit
COMPARE TERM DICT-FARFIELD abbrev-01 VPN: speech=hit other=hit
COMPARE TERM DICT-FARFIELD abbrev-02 API: speech=miss other=miss
COMPARE TERM DICT-FARFIELD abbrev-02 KI: speech=miss other=hit
COMPARE TERM DICT-FARFIELD mixed-01 13:45: speech=miss other=hit
COMPARE TERM DICT-FARFIELD mixed-01 CVAG: speech=miss other=hit
COMPARE TERM DICT-FARFIELD mixed-01 René: speech=hit other=hit
COMPARE TERM DICT-FARFIELD mixed-01 SharePoint: speech=hit other=hit
COMPARE TERM DICT-FARFIELD mixed-02 1.2.0: speech=miss other=miss
COMPARE TERM DICT-FARFIELD mixed-02 4. Oktober: speech=hit other=hit
COMPARE TERM DICT-FARFIELD mixed-02 API: speech=hit other=miss
COMPARE TERM DICT-FARFIELD mixed-02 VPN: speech=miss other=hit
COMPARE TERM DICT-FARFIELD mixed-03 KI: speech=miss other=miss
COMPARE TERM DICT-FARFIELD mixed-03 Markdown: speech=hit other=miss
COMPARE TERM DICT-FARFIELD names-01 Chemnitzer Verkehrs-AG: speech=miss other=miss
COMPARE TERM DICT-FARFIELD names-01 René: speech=hit other=hit
COMPARE TERM DICT-FARFIELD names-02 Hanning: speech=hit other=hit
COMPARE TERM DICT-FARFIELD names-02 Jacqueline: speech=hit other=hit
COMPARE TERM DICT-FARFIELD numbers-01 9,99: speech=hit other=hit
COMPARE TERM DICT-FARFIELD numbers-02 13:45: speech=hit other=hit
COMPARE TERM DICT-FARFIELD numbers-02 4. Oktober 2026: speech=hit other=hit
COMPARE TERM DICT-FARFIELD numbers-03 192.168.2.4: speech=miss other=miss
COMPARE TERM DICT-FARFIELD numbers-04 1.2.0: speech=miss other=miss
COMPARE TERM DICT-FARFIELD numbers-04 10: speech=hit other=miss
COMPARE TERM DICT-FARFIELD technical-01 Docker: speech=hit other=miss
COMPARE TERM DICT-FARFIELD technical-01 SharePoint: speech=hit other=hit
COMPARE TERM DICT-FARFIELD technical-02 CloudKit: speech=miss other=miss
COMPARE TERM DICT-FARFIELD technical-02 StoreKit: speech=miss other=miss
COMPARE TERM DICT-FARFIELD technical-03 SwiftUI: speech=miss other=miss
COMPARE TERM DICT-FARFIELD technical-04 AnalysisContext: speech=miss other=miss
COMPARE TERM DICT-FARFIELD technical-04 SpeechAnalyzer: speech=miss other=miss
COMPARE TERM DICTATION abbrev-01 MDM: speech=hit other=hit
COMPARE TERM DICTATION abbrev-01 VPN: speech=hit other=hit
COMPARE TERM DICTATION abbrev-02 API: speech=miss other=miss
COMPARE TERM DICTATION abbrev-02 KI: speech=miss other=hit
COMPARE TERM DICTATION mixed-01 13:45: speech=miss other=hit
COMPARE TERM DICTATION mixed-01 CVAG: speech=miss other=hit
COMPARE TERM DICTATION mixed-01 René: speech=hit other=hit
COMPARE TERM DICTATION mixed-01 SharePoint: speech=hit other=hit
COMPARE TERM DICTATION mixed-02 1.2.0: speech=miss other=miss
COMPARE TERM DICTATION mixed-02 4. Oktober: speech=hit other=hit
COMPARE TERM DICTATION mixed-02 API: speech=hit other=miss
COMPARE TERM DICTATION mixed-02 VPN: speech=miss other=hit
COMPARE TERM DICTATION mixed-03 KI: speech=miss other=miss
COMPARE TERM DICTATION mixed-03 Markdown: speech=hit other=miss
COMPARE TERM DICTATION names-01 Chemnitzer Verkehrs-AG: speech=miss other=miss
COMPARE TERM DICTATION names-01 René: speech=hit other=hit
COMPARE TERM DICTATION names-02 Hanning: speech=hit other=hit
COMPARE TERM DICTATION names-02 Jacqueline: speech=hit other=hit
COMPARE TERM DICTATION numbers-01 9,99: speech=hit other=hit
COMPARE TERM DICTATION numbers-02 13:45: speech=hit other=hit
COMPARE TERM DICTATION numbers-02 4. Oktober 2026: speech=hit other=hit
COMPARE TERM DICTATION numbers-03 192.168.2.4: speech=miss other=miss
COMPARE TERM DICTATION numbers-04 1.2.0: speech=miss other=miss
COMPARE TERM DICTATION numbers-04 10: speech=hit other=miss
COMPARE TERM DICTATION technical-01 Docker: speech=hit other=miss
COMPARE TERM DICTATION technical-01 SharePoint: speech=hit other=hit
COMPARE TERM DICTATION technical-02 CloudKit: speech=miss other=miss
COMPARE TERM DICTATION technical-02 StoreKit: speech=miss other=miss
COMPARE TERM DICTATION technical-03 SwiftUI: speech=miss other=miss
COMPARE TERM DICTATION technical-04 AnalysisContext: speech=miss other=miss
COMPARE TERM DICTATION technical-04 SpeechAnalyzer: speech=miss other=miss
```
