# Rohdaten: Spracherkennung — 2026-10-14

Unveränderte Ausgabe von `SprechlyWorkTests/LanguageDetectionBenchmark`
(`detectSpokenLanguage`), ausgeführt auf „Mein iPhone" (iPhone 17 Pro,
iOS 27.0.1) gegen die eingefrorenen Fixtures aus `Tests/Fixtures/Transcription`.

Je Fall wird dieselbe Datei mit `de-DE` **und** `en-US` transkribiert.
`A` = Wahl nach Selbstkonsistenz, `B` = Wahl nach mittlerer Modellkonfidenz.

```
LANGDETECT names-01 gesprochen=de A=de-DE B=de-DE
  de-DE konfidenz=0.802 erkannt=de (1.000) selbstkonsistent=ja text=René arbeitet bei der Chemnitzer Verkehrs AG.
  en-US konfidenz=0.390 erkannt=en (0.941) selbstkonsistent=ja text=Renee are bited by der kemnitza fakirs agi.
LANGDETECT names-02 gesprochen=de A=de-DE B=de-DE
  de-DE konfidenz=0.950 erkannt=de (1.000) selbstkonsistent=ja text=Jacqueline hat den Termin mit Hanning und Karl bestätigt.
  en-US konfidenz=0.351 erkannt=de (0.998) selbstkonsistent=nein text=Jacqueline hat denter min methanning und kal berstetzicht.
LANGDETECT technical-01 gesprochen=de A=de-DE B=de-DE
  de-DE konfidenz=0.950 erkannt=de (1.000) selbstkonsistent=ja text=Die Doku liegt in Sharepoint, der Container läuft in Docker.
  en-US konfidenz=0.486 erkannt=de (0.859) selbstkonsistent=nein text=Didoko leaked in sharepoint, der container loft in Docker.
LANGDETECT technical-02 gesprochen=de A=de-DE B=de-DE
  de-DE konfidenz=0.951 erkannt=de (1.000) selbstkonsistent=ja text=Der Kauf läuft über Store Kit, die Synchronisierung über Cloud Kit.
  en-US konfidenz=0.465 erkannt=de (0.996) selbstkonsistent=nein text=Der Kaufleuf, to Uber Storkit, diesen kronesiron Uber Klaudkit.
LANGDETECT technical-03 gesprochen=de A=de-DE B=de-DE
  de-DE konfidenz=0.950 erkannt=de (1.000) selbstkonsistent=ja text=Die Oberfläche ist in SwiftOE geschrieben.
  en-US konfidenz=0.504 erkannt=de (1.000) selbstkonsistent=nein text=Die Oberflescher ist in swift or eger schrieben.
LANGDETECT technical-04 gesprochen=de A=de-DE B=de-DE
  de-DE konfidenz=0.970 erkannt=de (1.000) selbstkonsistent=ja text=Speech Analizer bekommt die Begriffe über Analysis Kontext.
  en-US konfidenz=0.604 erkannt=en (0.990) selbstkonsistent=ja text=Speech analyzer becomes die be griffer uber analysis context.
LANGDETECT abbrev-01 gesprochen=de A=de-DE B=de-DE
  de-DE konfidenz=0.970 erkannt=de (1.000) selbstkonsistent=ja text=Der Zugriff läuft über VPN, die Geräte kommen aus dem MDM.
  en-US konfidenz=0.286 erkannt=de (0.976) selbstkonsistent=nein text=Der zu griffleuf, uber saupe en, diegeritte common austem MDM.
LANGDETECT abbrev-02 gesprochen=de A=de-DE B=de-DE
  de-DE konfidenz=0.971 erkannt=de (1.000) selbstkonsistent=ja text=Die AP ist dokumentiert, die K\letter I\letter läuft auf dem Gerät.
  en-US konfidenz=0.300 erkannt=de (0.981) selbstkonsistent=nein text=DRP is documented, dika iloft auf dem gerrit.
LANGDETECT numbers-01 gesprochen=de A=de-DE B=de-DE
  de-DE konfidenz=0.808 erkannt=de (1.000) selbstkonsistent=ja text=Der Kauf kostet 9,99 Euro Cent.
  en-US konfidenz=0.344 erkannt=de (1.000) selbstkonsistent=nein text=Der Kauf Kostet, Nein, Erl und Nein, und Nein, Sich, sen.
LANGDETECT numbers-02 gesprochen=de A=de-DE B=de-DE
  de-DE konfidenz=0.946 erkannt=de (1.000) selbstkonsistent=ja text=Das Treffen ist am 4. Oktober 2026 um 13.45 Uhr.
  en-US konfidenz=0.422 erkannt=de (1.000) selbstkonsistent=nein text=Das Streffen ist amfieten oktober zweitusen, sechsund vans sich undreitzen, urfen wund für
LANGDETECT numbers-03 gesprochen=de A=de-DE B=de-DE
  de-DE konfidenz=0.887 erkannt=de (0.999) selbstkonsistent=ja text=Der Server hat die Adresse 19216824.
  en-US konfidenz=0.337 erkannt=de (1.000) selbstkonsistent=nein text=Der züvehardie adrese eins noins wei, eins sechs acht, zwei, fier.
LANGDETECT numbers-04 gesprochen=de A=de-DE B=de-DE
  de-DE konfidenz=0.832 erkannt=de (1.000) selbstkonsistent=ja text=Wir veröffentlichen Version als Bild 10.
  en-US konfidenz=0.469 erkannt=de (0.909) selbstkonsistent=nein text=Wier fer effenlichhen wesion eins, zweig, null alsbelt zein.
LANGDETECT mixed-01 gesprochen=de A=de-DE B=de-DE
  de-DE konfidenz=0.923 erkannt=de (1.000) selbstkonsistent=ja text=René legt die CVAG-Unterlagen bis 13.45 Uhr in Sharepoint ab.
  en-US konfidenz=0.359 erkannt=de (1.000) selbstkonsistent=nein text=Renelich, diet zie fau arge unterlagen bestreit zin urfun wund fürt sich en scherpoint ab.
LANGDETECT mixed-02 gesprochen=de A=de-DE B=de-DE
  de-DE konfidenz=0.929 erkannt=de (1.000) selbstkonsistent=ja text=Für Version 1. 2.0 prüfen wir die AP und den VPN-Zugang am 4. Oktober.
  en-US konfidenz=0.450 erkannt=de (1.000) selbstkonsistent=nein text=Für vasion eins, zwei, null prüfen werdi api und den faupi en zu gang amfieten oktober.
LANGDETECT mixed-03 gesprochen=de A=de-DE B=de-DE
  de-DE konfidenz=0.868 erkannt=de (1.000) selbstkonsistent=ja text=Die KI-Zusammenfassung läuft on device, der Export geht nach Mark Down.
  en-US konfidenz=0.495 erkannt=de (0.663) selbstkonsistent=nein text=Dika, it so zamen fasung loft on device, der export gait nach markdown.
LANGDETECT en-names-01 gesprochen=en A=en-US B=de-DE
  de-DE konfidenz=0.853 erkannt=en (0.981) selbstkonsistent=nein text=Renée works at the Chemnitz Transport Company.
  en-US konfidenz=0.824 erkannt=en (0.987) selbstkonsistent=ja text=Renee works at the Kamnitz Transport Company.
LANGDETECT en-names-02 gesprochen=en A=en-US B=en-US
  de-DE konfidenz=0.764 erkannt=en (0.995) selbstkonsistent=nein text=Jacqueline confirmed the meeting with horning and cell
  en-US konfidenz=0.853 erkannt=en (0.979) selbstkonsistent=ja text=Jacqueline confirmed the meeting with Honning and Kel.
LANGDETECT en-technical-01 gesprochen=en A=en-US B=en-US
  de-DE konfidenz=0.673 erkannt=en (0.980) selbstkonsistent=nein text=The Dogs are in sareointan the container runs in Docker
  en-US konfidenz=0.863 erkannt=en (0.993) selbstkonsistent=ja text=The docks are in SharePoint and the container runs in docker.
LANGDETECT en-technical-02 gesprochen=en A=en-US B=en-US
  de-DE konfidenz=0.799 erkannt=en (0.988) selbstkonsistent=nein text=The purchase goes throug a store kid and sinking tough Cloud kid.
  en-US konfidenz=0.824 erkannt=en (0.997) selbstkonsistent=ja text=The purchase goes through StoreKit and sinking through CloudKit.
LANGDETECT en-technical-03 gesprochen=en A=en-US B=en-US
  de-DE konfidenz=0.646 erkannt=en (0.991) selbstkonsistent=nein text=The interfaces written with Swift UI
  en-US konfidenz=0.879 erkannt=en (0.970) selbstkonsistent=ja text=The interface is written in SwiftUI.
LANGDETECT en-technical-04 gesprochen=en A=en-US B=en-US
  de-DE konfidenz=0.837 erkannt=en (0.999) selbstkonsistent=nein text=Speed anelizer receives the terms through analysis contacts.
  en-US konfidenz=0.943 erkannt=en (0.999) selbstkonsistent=ja text=Speech Analyzer receives the terms through analysis context.
LANGDETECT en-abbrev-01 gesprochen=en A=en-US B=en-US
  de-DE konfidenz=0.852 erkannt=en (0.986) selbstkonsistent=nein text=Access runs over VPN in the devices come from PM.
  en-US konfidenz=0.955 erkannt=en (0.986) selbstkonsistent=ja text=Access runs over VPN and the devices come from MDM.
LANGDETECT en-abbrev-02 gesprochen=en A=en-US B=en-US
  de-DE konfidenz=0.849 erkannt=en (0.997) selbstkonsistent=nein text=The API is documented in the SI runs on the device.
  en-US konfidenz=0.931 erkannt=en (0.998) selbstkonsistent=ja text=The API is documented and the AI runs on the device.
LANGDETECT en-numbers-01 gesprochen=en A=en-US B=en-US
  de-DE konfidenz=0.772 erkannt=en (0.983) selbstkonsistent=nein text=The purchase cost 9.99 Dollars.
  en-US konfidenz=0.911 erkannt=en (0.994) selbstkonsistent=ja text=The purchase costs $9.99
LANGDETECT en-numbers-02 gesprochen=en A=en-US B=en-US
  de-DE konfidenz=0.775 erkannt=en (0.916) selbstkonsistent=nein text=The meeting is on Oktober 2026 at 1345 a clock.
  en-US konfidenz=0.910 erkannt=en (0.992) selbstkonsistent=ja text=The meeting is on October 4, 2026 at 1345 o'clock.
LANGDETECT en-numbers-03 gesprochen=en A=en-US B=en-US
  de-DE konfidenz=0.687 erkannt=en (0.984) selbstkonsistent=nein text=The s Server adresses 192, 168,woour
  en-US konfidenz=0.872 erkannt=en (0.833) selbstkonsistent=ja text=The server address is 192-16824.
LANGDETECT en-numbers-04 gesprochen=en A=en-US B=de-DE
  de-DE konfidenz=0.780 erkannt=en (0.923) selbstkonsistent=nein text=We are shipping version 1.2.0 is buildten.
  en-US konfidenz=0.767 erkannt=en (1.000) selbstkonsistent=ja text=We are shipping version one.  0.0 is billed 10.
LANGDETECT en-mixed-01 gesprochen=en A=en-US B=en-US
  de-DE konfidenz=0.810 erkannt=en (0.939) selbstkonsistent=nein text=Renée files the CVAG documents in shareoint by 1345 a clock.
  en-US konfidenz=0.918 erkannt=en (0.974) selbstkonsistent=ja text=Renee files the CVAG documents in SharePoint by 1345 o'clock.
LANGDETECT en-mixed-02 gesprochen=en A=en-US B=en-US
  de-DE konfidenz=0.801 erkannt=en (0.994) selbstkonsistent=nein text=Proversion 1.2.0 we check the API in the VPN Access on Oktoberour.
  en-US konfidenz=0.943 erkannt=en (0.996) selbstkonsistent=ja text=For version one.  we check the API and the VPN access on October 4th.
LANGDETECT en-mixed-03 gesprochen=en A=en-US B=en-US
  de-DE konfidenz=0.810 erkannt=en (0.992) selbstkonsistent=nein text=The AI smmary runs on device and the export goesomar down.
  en-US konfidenz=0.944 erkannt=en (0.980) selbstkonsistent=ja text=The AI summary runs on device and the export goes to Markdown.
LANGDETECT SUMME Fälle=30 A-Treffer=30 (unentschieden=0) B-Treffer=28
```
