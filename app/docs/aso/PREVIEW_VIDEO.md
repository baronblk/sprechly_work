# App-Preview-Video — Sprechly 1.2

Stand 2026-10-10. **Produziert und freigegeben** für iPhone, de-DE und en-US.
Ersetzt die Planungsfassung; alle Angaben hier beschreiben den tatsächlich
ausgelieferten Stand, nicht eine Absicht.

---

## 1. Finale Assets

| | DE | EN |
|---|---|---|
| Pfad | `Screenshots/video/preview-de.mp4` | `Screenshots/video/preview-en.mp4` |
| Größe | 5.916.165 Bytes (5,6 MB) | 4.864.661 Bytes (4,6 MB) |
| Auflösung | 886 × 1920 | 886 × 1920 |
| Dauer | 28,000 s (840 Frames) | 28,000 s (840 Frames) |
| Video | H.264 High, Level 4.0, yuv420p, 30 fps konstant | dito |
| Video-Bitrate | 1,68 Mbit/s | 1,38 Mbit/s |
| Audio | AAC LC, Stereo, 48 kHz — **absichtlich still** (−91,0 dB) | dito |
| Git-Commit | `d4c0592` | `538923d` |

**Status: `final — uploaded to App Store Connect, pending submission`.**

| | |
|---|---|
| Gerätesichtung auf echtem iPhone | **PASS** (DE und EN), 2026-10-10 |
| Upload nach App Store Connect | **DONE**, 2026-10-11 |
| ASC-Verarbeitung | `assetDeliveryState = COMPLETE`, keine Warnungen, keine Fehler |
| Trägerversion | App-Store-Version **1.2.1** mit Build **12**, `PREPARE_FOR_SUBMISSION`, `releaseType = MANUAL` |
| Zuordnung | `preview-de.mp4` → de-DE · `preview-en.mp4` → en-US, Typ `IPHONE_67` |
| Prüfsummen nach dem Upload | von ASC zurückgemeldet und mit den Finaldateien identisch |

**Noch nicht eingereicht und nicht veröffentlicht.**

### Warum 1.2.1 überhaupt existiert

App Previews hängen an einer App-Store-Version, und die ist nur beschreibbar,
solange sie bearbeitbar ist. Zum Zeitpunkt des Uploads standen **alle fünf**
Versionen der App auf `READY_FOR_SALE`; ein Schreibversuch auf die Lokalisierung
der laufenden 1.2.0 wurde von Apple mit
`409 ENTITY_ERROR.ATTRIBUTE.INVALID.INVALID_STATE` abgewiesen, ohne etwas
anzulegen. Für iOS gibt es kein reines Metadaten-Update — eine neue Version
braucht einen Build. 1.2.1 (12) ist deshalb ein reines Store-Release:
funktional identisch zu 1.2.0, im Diff ausschließlich `MARKETING_VERSION` und
`CURRENT_PROJECT_VERSION`.

### Zur Bitrate

Apple nennt 10–12 Mbit/s als Zielbitrate, und der Encoder ist auch darauf
eingestellt (`-b:v 11M -maxrate 12M -bufsize 24M`). Das Material verbraucht sie
nicht: dunkle, überwiegend statische Oberfläche, dazu Frames, die der
`fps`-Filter über die Lücken der Simulator-Aufnahme dupliziert. Es werden
**keine Füllbits erzwungen**, solange vier Bedingungen bei voller Auflösung
gegengesehen sind — Text scharf, kein Banding, keine Blockartefakte, übrige
technische Anforderungen erfüllt. Für beide Dateien ist das geprüft.

Dass die bewegte Wellenform die DE-Bitrate von 1,18 auf 1,68 Mbit/s hebt,
belegt, dass der Encoder dort zugreift, wo tatsächlich Bewegung ist.

---

## 2. Szenenfolge

| Zeit | Bild |
|---|---|
| 0,0–8,0 s | Aufnahme läuft: Timer, roter Punkt, **aktive Wellenform**, Pegelbalken |
| 8,0–13,5 s | Transkript mit Zeitstempeln |
| 13,5–19,0 s | KI-Zusammenfassung |
| 19,0–24,0 s | Gespeicherte Übersetzung |
| 24,0–28,0 s | Bibliothek |
| 25,0–28,0 s | Marketing-Overlay über der Bibliothek |

### Warum Szene 1 vorn steht

Das Preview läuft in den Suchergebnissen automatisch und stumm an. Die erste
Sekunde entscheidet. Eine laufende Aufnahme mit Timer und ausschlagender
Wellenform ist sofort als Handlung lesbar; eine Liste ist es nicht.

### Overlay-Text

| | |
|---|---|
| DE | **Kein Abo. Kein Konto.** / Transkription auf dem Gerät. |
| EN | **No subscription. No account.** / Transcription on your device. |

Das Overlay liegt über laufendem App-Bild, **keine eigenständige
Schlusstafel** — Apple erwartet, dass ein Preview überwiegend aus
aufgenommenem App-Material besteht; eine reine Marketingtafel wäre ein
Ablehnungsrisiko.

**Bewusst nicht gesagt:** „kein Upload", „bleibt immer ausschließlich lokal"
oder Vergleichbares. Der iCloud-Sync ist optional vorhanden und standardmäßig
aktiv; eine Absolutaussage wäre dieselbe Falschaussage, die mit 1.1.1 aus der
Store-Beschreibung entfernt wurde.

---

## 3. Die Wellenform braucht ein echtes Mikrofonsignal

**Die Wellenform schlägt im Simulator nicht von selbst aus.** Eine frühere
Fassung dieses Dokuments behauptete das; die erste fertige Fassung des Previews
hat es widerlegt — Szene 1–2 zeigte eine flache Punktlinie, weil am Mikrofon
des Aufnahmerechners Stille anliegt.

Gelöst über den gewöhnlichen akustischen Weg:

```
Mac-Lautsprecher  →  Luft  →  eingebautes Mikrofon  →  Simulator-Eingang
                                                    →  Sprechlys echte Aufnahme-Pipeline
```

`scripts/preview_video.sh` lässt `say` den neutralen Sprint-Planungs-Satz aus
`docs/aso/ASSET_SPEC_HERO.md` sprechen, ausgelöst von der `recording`-Marke des
Tests, und beendet ihn danach. Die Wellenform, die im Video zu sehen ist, ist
damit die reale Darstellung eines realen Signals — **nichts ist nachgebaut oder
simuliert.**

Zwei Voraussetzungen, beide geprüft statt angenommen:

- `AudioSessionController` setzt `mode: .default`, also **keine
  Echounterdrückung**. Mit Voice Processing würde der Lautsprecher exakt wieder
  herausgerechnet und die Wellenform bliebe flach.
- Die Ausgabe des Macs war bereits auf voller Lautstärke und nicht stumm. **Es
  wurde kein Loopback-Gerät installiert und die macOS-Audiokonfiguration nicht
  verändert.**

### Das Mikrofonsignal landet nicht im Preview

Die Tonspur des fertigen Videos ist **nicht** die Mikrofonaufnahme. Sie wird
getrennt aus `anullsrc` erzeugt und ist durchgehend still (mean und max
−91,0 dB). Aus der Simulator-Aufnahme übernimmt der Schnitt ausschließlich den
Videostream. Das Mikrofonsignal existiert nur, damit die Wellenform ausschlägt,
und endet dort.

---

## 4. Die Aufnahmekette

```
scripts/preview_video.sh
  ├── Simulator frisch booten, Statusleiste fixieren (09:41, WLAN, voller Akku)
  ├── xcrun simctl io … recordVideo          Rohaufnahme, variable Bildrate
  ├── xcodebuild test  →  PreviewFlowTest    spielt den Ablauf, markiert Szenen
  │     └── say …                            Sprachsignal für Szene 1–2
  ├── scripts/find_app_session.py            findet die App-Sitzung per Helligkeit
  ├── scripts/find_preview_scenes.py         rechnet die Marken in Positionen um
  ├── scripts/make_preview_overlay.py        rendert das Overlay als PNG
  └── ffmpeg                                 schneidet, setzt das Overlay, kodiert
```

### Warum die Szenen geschnitten und nicht am Stück gezeigt werden

Ein einzelner Durchlauf des Ablaufs dauert 46–66 s. Davon sind rund **20 s
reine XCUITest-Übergänge**: Warten auf den Ruhezustand vor jeder Interaktion,
und je etwa drei Sekunden Verharren auf der Detailansicht, nachdem ein Sheet
geschlossen wurde. Das sind keine Pausen, die der Test setzt — sie lassen sich
dort nicht straffen.

Deshalb meldet `PreviewFlowTest` jeden Szenenanfang (`PREVIEWMARK`), und der
Schnitt nimmt pro Szene genau ein Stück heraus. **Jedes Bild des Ergebnisses
ist aufgenommenes App-Material**; weg ist nur der Leerlauf dazwischen.

### Warum der Schnitt am App-Start verankert ist

Die Rohaufnahme beginnt mit 15–45 s Home-Bildschirm, während der Test-Runner
installiert — und diese Spanne schwankt von Lauf zu Lauf um mehr als die Länge
des fertigen Videos. Ein Schnitt vom Ende her trifft deshalb nicht zuverlässig.

`find_app_session.py` misst stattdessen die Helligkeit: Sprechly ist durchgehend
dunkel (YAVG 37–46), der Home-Bildschirm nicht (157–169), der Startbildschirm
ist weiß (232). Die längste dunkle Strecke ist die App-Sitzung. Die Trennung
ist absolut, es gibt keinen Grenzfall.

### Fallstricke, die beim Bau Zeit gekostet haben

Festgehalten, damit sie nicht zweimal auftreten:

- **`-r 30` als Ausgabeoption füllt die Lücken der Aufnahme nicht auf.** Der
  Simulator schreibt bei stehendem Bildschirm gar keine Frames (Lücken bis
  5,5 s); `-r 30` verwarf sie und machte aus einem 22-s-Schnitt 17,7 s.
  `fps=30` **im Filtergraph** dupliziert über die Lücke hinweg. Nicht
  zurückwechseln.
- **Die Containerdauer der Rohaufnahme ist nicht die Länge des Videostreams**,
  und `-ss` landet darin nicht, wo es behauptet. Sequenziell dekodieren.
- **`-loop 1` ohne `-t` flutet den Filtergraph.** Das Overlay-Standbild
  erzeugt sonst endlos Frames, während das Video noch dekodiert wird — der
  Encode lief damit nach 21 Minuten und 1,8 GB noch immer. Alle Eingänge
  begrenzen.
- **Ein Backslash-Zeilenumbruch im Filtergraph verschluckt Zeichen.** Den
  Filter als eine ungebrochene Zeichenkette bauen.
- **Swifts `print` geht verloren, sobald stdout eine Pipe ist.** Die
  Szenenmarken gehen deshalb auf stderr, das ungepuffert ist.

Eine harte Längenprüfung bricht ab, wenn die fertige Datei nicht innerhalb von
±0,2 s auf 28,0 s liegt — lieber kein Preview als ein falsches.

---

## 5. Simulator-Grenzen

| Grenze | Folge |
|---|---|
| Kein `SpeechAnalyzer` | Live-Transkript ist nicht zeigbar — wird nicht gezeigt |
| Keine Foundation Models | Zusammenfassung und Übersetzung sind nicht *erzeugbar* — sie werden als vorhandener Inhalt gezeigt, nicht als Generierung |
| Mikrofon über den Host | Wellenform bleibt flach, bis ein echtes Signal anliegt (Abschnitt 3) |

Die Übersetzung in Szene 5 stammt aus `App/DemoSeed.swift` (DEBUG, In-Memory,
nur unter `SEED_DEMO`). `TranscriptView` stellt eine gespeicherte Übersetzung
beim Öffnen wieder her, also erscheint sie in derselben echten Karte wie bei
einem Nutzer, der einmal übersetzt hat. **Gezeigt wird vorhandener Inhalt, nicht
seine Entstehung** — ein Tippen auf „Übersetzen" mit anschließend erscheinendem
Text würde eine Generierung vortäuschen, die im Simulator gar nicht läuft.

---

## 6. App-Store-Konformität

- [x] 15–30 s — 28,000 s
- [x] 886 × 1920, H.264 High, Level 4.0, yuv420p, 30 fps konstant
- [x] AAC LC Stereo 48 kHz, Spur vorhanden und aktiviert
- [x] überwiegend aufgenommenes App-Material, keine reine Marketingtafel
- [x] keine fremden App-Namen, keine Debug-Elemente, keine echte Uhrzeit
- [x] keine Aussage, die mehr verspricht als die App leistet
- [x] deutlich unter 500 MB
- [x] auf einem echten iPhone gegengesehen — DE und EN PASS, 2026-10-10
- [x] in App Store Connect hochgeladen — 2026-10-11, Verarbeitung `COMPLETE`
- [ ] **zur Review eingereicht — steht aus**

886 × 1920 ist Apples akzeptierte Preview-Auflösung für iPhone mit Dynamic
Island. Die Geräteauflösung 1320 × 2868 ist in Apples Tabelle nur als Referenz
geführt und **keine zulässige Preview-Größe** — die Videos vom 21.06.2026
benutzten sie und wären voraussichtlich abgelehnt worden.

---

## 7. iPad: bewusst nicht produziert

**Noch kein iPad-Preview.** Erst den Nutzen der iPhone-Previews beobachten,
bevor zusätzlicher Produktionsaufwand entsteht.

Technisch käme ohnehin Arbeit dazu: der Ablauf navigiert mit dem Zurück-Knopf
der Navigationsleiste, den es neben einer Split-View nicht gibt. Ein
iPad-Preview braucht einen eigenen Ablauf, kein Umschalten.

---

## 8. Offen

1. Einreichung von 1.2.1 zur Review — bewusst noch nicht ausgelöst.
2. Nach der Veröffentlichung vier Wochen wirken lassen, bevor ein
   Produktseitentest startet, sonst fällt der Video-Effekt in das Testfenster
   (siehe `docs/aso/PPO_TREATMENTS.md`).

**Für künftige Releases:** Werbetext ist das eine Store-Feld, das ASC beim
Anlegen einer Version **nicht** mitkopiert — bei 1.2.1 stand er wieder auf 0
Zeichen, wie schon bei 1.2.0, und wurde aus 1.2.0 übernommen. Beschreibung,
Keywords, URLs und Screenshots kamen automatisch mit.
