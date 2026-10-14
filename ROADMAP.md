# Sprechly Work — Roadmap

Privates Projekt, kein Store-Release. Die Roadmap der echten Sprechly-App liegt
in `app/docs/ROADMAP.md` und bleibt davon unberührt.

Stand: 2026-10-14

---

## Erledigt

Der Bauplan aus `CLAUDE.md` (Schritt 0–4) ist durch: Geräteprotokoll in Swift
nachgebaut und am eigenen Gerät verifiziert, Work-Import in der App, Fernsteuerung
(Start/Pause/Stop), Löschen, automatischer Import mit Statusanzeige, automatische
Transkription, Klopfmarkierungen, Sprache pro Aufnahme samt automatischer
Erkennung. Protokollstand in `docs/d3200_protocol_spec.md`.

---

## A — macOS-Version von Sprechly Work ☐

**Auslöser:** Systemton mitschneiden, etwa ein laufendes Teams-Meeting.

### Warum das ein eigenes Target braucht

Auf iOS ist es **nicht möglich**. Es gibt keine öffentliche API, mit der eine App
den Ton einer anderen abgreift. Der einzige systemweite Weg wäre eine ReplayKit
Broadcast Upload Extension mit `.audioApp`-Puffern — mit Handstart über das
Kontrollzentrum, roter Statusleiste, ~50 MB Speicherlimit und, als vermuteter
Showstopper, ohne den Ton von Telefonie-Apps wie Teams, Zoom oder FaceTime.
Letzteres ist **nicht gemessen**; ein halber Tag mit einer minimalen Extension
und einem echten Meeting würde es beantworten, falls der iOS-Weg je wieder
infrage kommt.

Auf macOS ist es sauber lösbar, am SDK geprüft (MacOSX 27.0):

| Weg | Verfügbar | Eignung |
|---|---|---|
| `AudioHardwareCreateProcessTap` + `CATapDescription` | **macOS 14.2+**, auf iOS ausdrücklich nicht | Gezielt **einzelne Prozesse** abgreifen (`initStereoMixdownOfProcesses:`) oder alles außer bestimmten (`initStereoGlobalTapButExcludeProcesses:`) — genau das, was „nur Teams mitschneiden" braucht |
| ScreenCaptureKit, `SCStreamConfiguration.capturesAudio` | macOS 13+ | Systemton insgesamt; gröber, dafür länger etabliert |

Kein Kernel-Hack, kein virtuelles Audiogerät — nur Berechtigungen.

### Umfang

- Eigenes macOS-Target in `app/project.yml` (heute sind **alle vier** Targets
  iOS). `SoundcoreWorkKit` ist bereits für macOS 14 gebaut, der Geräteteil
  müsste also nicht neu entstehen.
- Audio-Aufnahme über Process-Taps, Aufnahmeziel wie bisher die Bibliothek.
- Oberfläche: eigenes Fenster, nicht die iOS-Ansichten durchgereicht.
- Signierung/Berechtigungen: Bildschirmaufnahme-Freigabe, eigene App-ID.

### Vor dem Start zu entscheiden

- Teilt sich die Mac-App die Bibliothek mit dem iPhone (iCloud) oder bleibt sie
  für sich? Das bestimmt das Datenmodell und den Aufwand erheblich.
- Braucht die Mac-Version den Work überhaupt, oder ist sie reine
  Systemton-Aufnahme plus Transkription?
- Wie groß darf die Oberfläche werden — ein Menüleisten-Helfer, der aufnimmt und
  transkribiert, ist ein Bruchteil einer vollen App.

### Rechtlicher Rahmen (gehört ins Feature, nicht ins Kleingedruckte)

Das Mitschneiden des nicht öffentlich gesprochenen Wortes ohne Einwilligung ist
in Deutschland nach **§ 201 StGB** strafbar. Ein Hinweis in der App und das
Ansagen im Meeting sind Teil der Umsetzung.

---

## B — Transkriptionsqualität

Vorgeschichte und Messungen in `app/docs/`: `contextualStrings` ist widerlegt,
`DictationTranscriber` als Ersatz verworfen, konservative Formatierung
integriert (13/31 → 20/31 Zielbegriffe). Offen bleiben drei Hebel:

- ☐ **Korrekturliste** — du korrigierst `Store Kit` → `StoreKit`, die App merkt
  es sich und wendet es künftig an. Braucht keine Messung, deterministisch,
  testbar mit dem bestehenden Korpus. Apples Modell selbst lernt nicht; das
  Lernen findet in unserem Code statt.
- ☐ **Alternativen auswerten** — `SpeechTranscriber` kann
  `.transcriptionWithAlternatives` und `transcriptionConfidence` liefern, die App
  wirft beides weg. Messung: Steht bei den verbliebenen Erkennungsfehlern der
  richtige Begriff unter den Alternativen? Entscheidet, ob aus der Korrekturliste
  ein echtes Wörterbuch werden kann. Halber Tag.
- ☐ **Eigenes Sprachmodell** — `SFCustomLanguageModelData` mit Phrasen **und
  Lautschrift** (`CustomPronunciation`), eingehängt über
  `DictationTranscriber.ContentHint.customizedLanguage`. Der einzige API-Weg, der
  die Erkennung selbst verändert, aber an die Engine mit Inhaltsverlust gebunden.
  Kriterium: muss den heutigen `SpeechTranscriber` schlagen, nicht bloß den
  nackten Dictation-Pfad.

---

## C — Aufnahmepegel am Work ☐

Über BLE ausgeschlossen und sauber gemessen (Spec §7e). Verbleibender Verdacht
ist der SoftAP/WebSocket-Weg (`1a/05` → IP:Port → `wss://`). Nächster Schritt
ist ein frischer HCI-Mitschnitt auf dem Pixel, während die Anker-App die
reagierende Wellenform zeigt.

---

## D — Kleinkram

- ☐ Zwei Testaufnahmen vom 2026-10-14 liegen noch auf dem Gerät (~18 s, ~15 s)
- ☐ Nah verwandte Sprachen für die Spracherkennung messen (heute nur de/en,
  siehe `app/docs/LANGUAGE_DETECTION.md`)
- ☐ Sprachwechsel **innerhalb** einer Aufnahme bleibt unbehandelt
