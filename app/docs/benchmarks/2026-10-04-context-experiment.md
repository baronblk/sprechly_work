# Raw benchmark output — 1.2 context experiment

Device run, 2026-10-04T17:24:35Z. Kept verbatim as the baseline record.

```
BENCH BASELINE abbrev-01 TEXT: Der Zugriff läuft über VPN, die Geräte kommen aus dem MDM.
BENCH BASELINE abbrev-01 wer=0.000 cer=0.000 hits=2/2 missed= fp= t=0.087s
BENCH BASELINE abbrev-02 TEXT: Die AP ist dokumentiert, die K\letter I\letter läuft auf dem Gerät.
BENCH BASELINE abbrev-02 wer=0.500 cer=0.302 hits=0/2 missed=API|KI fp= t=0.081s
BENCH BASELINE mixed-01 TEXT: René legt die CVAG-Unterlagen bis 13.45 Uhr in Sharepoint ab.
BENCH BASELINE mixed-01 wer=0.100 cer=0.016 hits=2/4 missed=CVAG|13:45 fp= t=0.107s
BENCH BASELINE mixed-02 TEXT: Für Version 1. 2.0 prüfen wir die API und den VPN-Zugang am 4. Oktober.
BENCH BASELINE mixed-02 wer=0.154 cer=0.014 hits=2/4 missed=1.2.0|VPN fp= t=0.104s
BENCH BASELINE mixed-03 TEXT: Die KI-Zusammenfassung läuft on device, der Export geht nach Markdown.
BENCH BASELINE mixed-03 wer=0.222 cer=0.014 hits=1/2 missed=KI fp= t=0.092s
BENCH BASELINE names-01 TEXT: Rrene arbeitet bei der Chemnitzer Verkehrs AG.
BENCH BASELINE names-01 wer=0.500 cer=0.067 hits=0/2 missed=René|Chemnitzer Verkehrs-AG fp= t=0.276s
BENCH BASELINE names-02 TEXT: Ja,quelene hat den Termin mit Henning und Karl bestätigt.
BENCH BASELINE names-02 wer=0.333 cer=0.070 hits=0/2 missed=Jacqueline|Hanning fp= t=0.092s
BENCH BASELINE numbers-01 TEXT: Der Kauf kostet 9,99 Euro Cent.
BENCH BASELINE numbers-01 wer=0.200 cer=0.192 hits=1/1 missed= fp= t=0.076s
BENCH BASELINE numbers-02 TEXT: Das Treffen ist am 4. Oktober 2026 um 13:45 Uhr.
BENCH BASELINE numbers-02 wer=0.000 cer=0.000 hits=2/2 missed= fp= t=0.099s
BENCH BASELINE numbers-03 TEXT: Der Surver hat die Adresse 192.1682.4.
BENCH BASELINE numbers-03 wer=0.333 cer=0.051 hits=0/1 missed=192.168.2.4 fp= t=0.109s
BENCH BASELINE numbers-04 TEXT: Wir veröffentlichen Version als Bild 10.
BENCH BASELINE numbers-04 wer=0.286 cer=0.149 hits=1/2 missed=1.2.0 fp= t=0.086s
BENCH BASELINE technical-01 TEXT: Die Doku liegt in SharePoint, der Container läuft in Docker.
BENCH BASELINE technical-01 wer=0.000 cer=0.000 hits=2/2 missed= fp= t=0.090s
BENCH BASELINE technical-02 TEXT: Der Kauf läuft über Stockit, die Synchronisierung über Cloud Kit.
BENCH BASELINE technical-02 wer=0.333 cer=0.046 hits=0/2 missed=StoreKit|CloudKit fp= t=0.093s
BENCH BASELINE technical-03 TEXT: Die Oberfläche ist in SwiftOE geschrieben.
BENCH BASELINE technical-03 wer=0.167 cer=0.048 hits=0/1 missed=SwiftUI fp= t=0.070s
BENCH BASELINE technical-04 TEXT: Speech Analizer bekommt die Begriffe über Analysis Kontext.
BENCH BASELINE technical-04 wer=0.667 cer=0.070 hits=0/2 missed=SpeechAnalyzer|AnalysisContext fp= t=0.085s
BENCH CATEGORY BASELINE abbreviations terms=2/4 wer=0.250
BENCH CATEGORY BASELINE mixed terms=5/10 wer=0.159
BENCH CATEGORY BASELINE names terms=0/4 wer=0.417
BENCH CATEGORY BASELINE numbers terms=4/6 wer=0.205
BENCH CATEGORY BASELINE technical terms=2/7 wer=0.292
BENCH CATEGORY CONTEXT abbreviations terms=2/4 wer=0.250
BENCH CATEGORY CONTEXT mixed terms=5/10 wer=0.159
BENCH CATEGORY CONTEXT names terms=0/4 wer=0.417
BENCH CATEGORY CONTEXT numbers terms=4/6 wer=0.205
BENCH CATEGORY CONTEXT technical terms=2/7 wer=0.292
BENCH CONTEXT abbrev-01 TEXT: Der Zugriff läuft über VPN, die Geräte kommen aus dem MDM.
BENCH CONTEXT abbrev-01 wer=0.000 cer=0.000 hits=2/2 missed= fp= t=0.096s
BENCH CONTEXT abbrev-02 TEXT: Die AP ist dokumentiert, die K\letter I\letter läuft auf dem Gerät.
BENCH CONTEXT abbrev-02 wer=0.500 cer=0.302 hits=0/2 missed=API|KI fp= t=0.087s
BENCH CONTEXT mixed-01 TEXT: René legt die CVAG-Unterlagen bis 13.45 Uhr in Sharepoint ab.
BENCH CONTEXT mixed-01 wer=0.100 cer=0.016 hits=2/4 missed=CVAG|13:45 fp= t=0.104s
BENCH CONTEXT mixed-02 TEXT: Für Version 1. 2.0 prüfen wir die API und den VPN-Zugang am 4. Oktober.
BENCH CONTEXT mixed-02 wer=0.154 cer=0.014 hits=2/4 missed=1.2.0|VPN fp= t=0.107s
BENCH CONTEXT mixed-03 TEXT: Die KI-Zusammenfassung läuft on device, der Export geht nach Markdown.
BENCH CONTEXT mixed-03 wer=0.222 cer=0.014 hits=1/2 missed=KI fp= t=0.090s
BENCH CONTEXT names-01 TEXT: Rrene arbeitet bei der Chemnitzer Verkehrs AG.
BENCH CONTEXT names-01 wer=0.500 cer=0.067 hits=0/2 missed=René|Chemnitzer Verkehrs-AG fp= t=0.084s
BENCH CONTEXT names-02 TEXT: Ja,quelene hat den Termin mit Henning und Karl bestätigt.
BENCH CONTEXT names-02 wer=0.333 cer=0.070 hits=0/2 missed=Jacqueline|Hanning fp= t=0.084s
BENCH CONTEXT numbers-01 TEXT: Der Kauf kostet 9,99 Euro Cent.
BENCH CONTEXT numbers-01 wer=0.200 cer=0.192 hits=1/1 missed= fp= t=0.078s
BENCH CONTEXT numbers-02 TEXT: Das Treffen ist am 4. Oktober 2026 um 13:45 Uhr.
BENCH CONTEXT numbers-02 wer=0.000 cer=0.000 hits=2/2 missed= fp= t=0.098s
BENCH CONTEXT numbers-03 TEXT: Der Surver hat die Adresse 192.1682.4.
BENCH CONTEXT numbers-03 wer=0.333 cer=0.051 hits=0/1 missed=192.168.2.4 fp= t=0.095s
BENCH CONTEXT numbers-04 TEXT: Wir veröffentlichen Version als Bild 10.
BENCH CONTEXT numbers-04 wer=0.286 cer=0.149 hits=1/2 missed=1.2.0 fp= t=0.087s
BENCH CONTEXT technical-01 TEXT: Die Doku liegt in SharePoint, der Container läuft in Docker.
BENCH CONTEXT technical-01 wer=0.000 cer=0.000 hits=2/2 missed= fp= t=0.085s
BENCH CONTEXT technical-02 TEXT: Der Kauf läuft über Stockit, die Synchronisierung über Cloud Kit.
BENCH CONTEXT technical-02 wer=0.333 cer=0.046 hits=0/2 missed=StoreKit|CloudKit fp= t=0.089s
BENCH CONTEXT technical-03 TEXT: Die Oberfläche ist in SwiftOE geschrieben.
BENCH CONTEXT technical-03 wer=0.167 cer=0.048 hits=0/1 missed=SwiftUI fp= t=0.073s
BENCH CONTEXT technical-04 TEXT: Speech Analizer bekommt die Begriffe über Analysis Kontext.
BENCH CONTEXT technical-04 wer=0.667 cer=0.070 hits=0/2 missed=SpeechAnalyzer|AnalysisContext fp= t=0.083s
BENCH DELTA wer=0.000 cer=0.000 recall=0.000 terms=13-vs-13 fp=0-vs-0
BENCH ENV device=iPhone iOS 27.0.1 locale=de-DE cases=15
BENCH SCALE size=0 terms=2/4 wer=0.100 t=0.109s fp=
BENCH SCALE size=104 terms=2/4 wer=0.100 t=0.100s fp=
BENCH SCALE size=14 terms=2/4 wer=0.100 t=0.107s fp=
BENCH SCALE size=54 terms=2/4 wer=0.100 t=0.103s fp=
BENCH SUMMARY BASELINE wer=0.253 cer=0.069 terms=13/31 recall=0.419 fp=0 time=1.545s
BENCH SUMMARY CONTEXT wer=0.253 cer=0.069 terms=13/31 recall=0.419 fp=0 time=1.340s
```

## Wiring verification (separate device run)

```
WIRING initializer: count=3 values=["Proxmox", "CloudKit", "Chemnitzer Verkehrs-AG"]
WIRING setContext: before=0 after=3 values=["Proxmox", "CloudKit", "Chemnitzer Verkehrs-AG"]
```
