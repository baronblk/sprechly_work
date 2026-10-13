# Sprechly — App Store Optimization

Stand 2026-10-10. Grundlage: tatsächlicher Repository-Stand und ein rein
lesender App-Store-Connect-Audit, nicht allgemeine ASO-Theorie.

**Nichts hiervon ist in App Store Connect ausgeführt.** Begründung in
„ASC-Änderungen".

---

## 1. Ist-Zustand

### Store-Auftritt (ASC, gelesen am 2026-10-10)

| Feld | de-DE | en-US |
|---|---|---|
| Name | `Sprechly: Diktiergerät & KI` | `Sprechly: Voice Recorder & AI` |
| Untertitel | `Transkription offline ohne Abo` | `Private offline transcription` |
| Beschreibung | 2799 Zeichen | 2434 Zeichen |
| Keywords | **100/100 Zeichen** | 98/100 Zeichen |
| Werbetext | 152 Zeichen | 138 Zeichen |
| Screenshots | 6 × iPhone 6.9", 6 × iPad 12.9" | ebenso |
| **App-Preview-Video** | **0** | **0** |

Live: **1.2.0 (Build 11)**. Keywords de-DE:
`sprachmemo,transkribieren,meeting,protokoll,interview,zusammenfassung,aufnahme,recorder,sprache,text`

### Genutzte App-Store-Marketingfunktionen

| Funktion | Status |
|---|---|
| Benutzerdefinierte Produktseiten | **0 angelegt** |
| Produktseitenoptimierung (A/B) | **0 Experimente** |
| App-Previews (Video) | **0 hochgeladen** |
| Inhalts-Mediathek | nicht strukturiert genutzt |

### Was im Repository bereits existiert

- `scripts/screenshots.sh` → Rohcaptures über `VoxStudioUITests/ScreenshotTests/testCaptureScreenshots`
- `scripts/compose_store_screenshots.py` → betextete Store-Bilder aus `Screenshots/captions.json`
- `scripts/preview_video.sh` → App-Preview-Video, 6,9"
- `scripts/promo_video.sh` → vertikales Social-Video
- `scripts/validate_store_metadata.py` → ASC-Längenprüfung
- `STORE_LISTING.md` → alle Store-Texte als Quelle der Wahrheit
- `docs/marketing` (eigener Branch) → organischer Marketingplan, 30 Tage

**Die Werkzeugkette ist vollständig.** Es fehlt nicht an Automatisierung,
sondern an Nutzung.

---

## 2. Schwächen und Hebel

### 2.1 Das Preview-Video ist neu produziert und noch nicht hochgeladen

`Screenshots/video/preview-de.mp4` und `preview-en.mp4` sind am 10.10.2026 neu
aufgenommen worden und ersetzen die Fassung vom 21. Juni:

```
886x1920 · H.264 High 4.0 · yuv420p · 30 fps · 28,000 s · stille AAC-Stereospur
```

Status **`final — hochgeladen, noch nicht eingereicht`**. Beide liegen seit
2026-10-11 in App Store Connect an der Version 1.2.1 (Build 12), Verarbeitung
`COMPLETE`, DE an de-DE und EN an en-US. Das Video spielt in den
Suchergebnissen automatisch ab und ist damit das einzige Asset, das sowohl auf
die Tap-Rate als auch auf die Conversion wirkt.

**Die Juni-Dateien waren nicht hochladbar.** Sie lagen bei 1320 × 2868 — das ist
die Geräteauflösung, die Apple nur als Referenz führt und **nicht** als
Preview-Größe akzeptiert. Sie wären voraussichtlich abgelehnt worden. Dazu
zeigten sie eine drei Releases alte Oberfläche.

Vollständige Spezifikation, Szenenfolge und Aufnahmekette:
`docs/aso/PREVIEW_VIDEO.md`.

### 2.2 Das Hero-Motiv widerspricht seiner eigenen Headline

Headline: *„Sprich. Sprechly schreibt mit."* — das Bild zeigt aber den
**fertigen Transkriptbildschirm**, in dem oben die **KI-Zusammenfassung** und
eine Übersetzen-Zeile dominieren. Das Transkript selbst steht in der unteren
Hälfte.

Das Hero führt damit mit dem **kostenpflichtigen KI-Layer** statt mit dem
Kernversprechen. Wer das Bild im Suchergebnis sieht, erkennt nicht, dass die
App diktiert und mitschreibt.

### 2.3 20 % des Hero-Motivs sind leerer Hintergrund

Gemessen, nicht geschätzt:

```
Leinwand 1320×2868 · Caption endet bei y=316 · verfügbar 2552 px
Transkript-Screen nach Trim und Skalierung: 1982 px
→ 570 px bleiben Hintergrund = 19,9 % der Leinwand
```

**Ursache ist nicht die Pipeline.** `compose_store_screenshots.py` schneidet
den leeren Boden bereits ab (`trim_empty_bottom`) und bemisst die Leinwand aus
der Originalgröße. Die Fläche bleibt leer, weil der Screen **weniger Inhalt
hat, als die Leinwand zeigen kann** — die erste Demo-Aufnahme in
`App/DemoSeed.swift` enthält genau **vier Transkriptsegmente**.

Scrollen allein löst das deshalb nicht: unterhalb der KI-Karte stehen nur noch
vier Zeilen.

### 2.4 Keywords: das Feld ist voll, aber nicht scharf

de-DE nutzt 100 von 100 Zeichen — jeder schwache Begriff verdrängt einen
starken. Auffällig:

- `recorder` — englisches Wort im deutschen Feld, während der Name bereits
  `Diktiergerät` führt
- `sprache`, `text`, `aufnahme` — sehr breit, hoher Wettbewerb, geringe
  Kaufabsicht

Name und Untertitel werden **mitindexiert**. `Transkription` steht im
Untertitel und `transkribieren` zusätzlich im Keyword-Feld.

**Seit dem 11.10. hängt an diesem Feld mehr als die Suche:** Custom Product
Pages können nur Keywords zugewiesen bekommen, die hier stehen. Neun der zehn
deutschen Begriffe tragen inzwischen eine CPP, und für die
Datenschutz-Positionierung fehlt ein passender Begriff vollständig. Der Tausch
ist deshalb keine reine Keyword-Entscheidung mehr —
`docs/aso/NEXT_RELEASE_CHECKLIST.md`, Punkt 1.

**Wichtig und oft falsch gemacht:** Die **Beschreibung wird auf iOS nicht
indexiert**. Sie länger zu machen bringt für die Auffindbarkeit nichts. Nur
Name, Untertitel und Keywords zählen für die Suche; alles andere wirkt auf die
Conversion.

### 2.5 Keine Grundlage für Messung

Ohne eine einzige Produktseitenoptimierung ist **jede bisherige
Screenshot-Entscheidung eine unbelegte Meinung** — auch meine Kritik oben. Das
ist der eigentliche strukturelle Mangel.

### 2.6 Die Datenlücke besteht weiter

Bekannt sind Downloads (30 in 30 Tagen, −30 %) und Käufe (4). **Unbekannt sind
Impressions und Produktseitenaufrufe.** Ohne sie lässt sich nicht sagen, ob
Sprechly seltener *gefunden* oder seltener *geladen* wird — und das sind
verschiedene Probleme mit verschiedenen Lösungen.

### Größter Hebel

**Das Preview-Video**, weil es das einzige fehlende Asset ist, das direkt im
Suchergebnis wirkt, und weil die Produktionskette dafür bereits existiert.
Danach erst das Hero-Motiv.

---

## 3. Neues primäres Marketing-Image

### Gewählte Richtung

Von den vier vorgeschlagenen Botschaften ist **„Sprich. Sprechly schreibt
mit."** die stärkste — **sie ist aber bereits die aktuelle Headline.** Das
Problem ist nicht die Aussage, sondern dass das Bild sie nicht belegt.

**Entscheidung: Headline behalten, Motiv austauschen.**

Begründung gegen die Alternativen:

| Richtung | Warum nicht als Hero |
|---|---|
| „Transkription direkt auf deinem Gerät" | Technikaussage, kein Nutzen; steht zudem schon im Untertitel |
| „Datenschutzfreundliche Transkription ohne unnötige Cloud" | Negativ formuliert, lang, und mit aktivem iCloud-Sync erklärungsbedürftig |
| „Diktieren, transkribieren, zusammenfassen" | Feature-Aufzählung; Hero-Bilder gewinnen mit *einer* Aussage |

### Das Zielmotiv

**Aufnahmebildschirm mit laufendem Live-Transkript.** Es zeigt die Headline
wörtlich: man spricht, und der Text erscheint währenddessen. Es ist
gleichzeitig das einzige Motiv, das die App von einfachen Diktiergeräten
unterscheidet.

**Harte Einschränkung — deshalb kein improvisiertes Asset:** Live-Transkription
braucht `SpeechAnalyzer`, und der **existiert im Simulator nicht**. Die
bestehende Pipeline kann dieses Motiv prinzipiell nicht erzeugen. Es braucht
eine Aufnahme auf echter Hardware.

Vollständige Spezifikation: **`docs/aso/ASSET_SPEC_HERO.md`** — so detailliert,
dass das Asset ohne Rückfragen erstellt werden kann.

### Zwischenlösung ohne Geräteaufnahme

Falls die Geräteaufnahme aufgeschoben wird, lässt sich das Hero rein im
Simulator deutlich verbessern:

1. `App/DemoSeed.swift`: erste Aufnahme von 4 auf **9–10 Transkriptsegmente**
   erweitern (nur `SEED_DEMO`-Demodaten, kein Produktverhalten)
2. `ScreenshotTests.swift`: vor `capture(app, lang, "01-transcript")` an der
   KI-Karte vorbeiscrollen
3. `screenshots.sh` + `compose_store_screenshots.py` erneut laufen lassen

Ergebnis: Transkript füllt die Fläche, die KI-Karte verlässt das Hero, die
19,9 % Leerfläche verschwinden. **Nicht ausgeführt** — es ändert Demodaten und
den Aufnahme-Flow und gehört deshalb bestätigt.

---

## 4. Benutzerdefinierte Produktseiten

### Empfehlung: Konzepte jetzt, Anlage später

Eine Custom Product Page wird **nur über ihre eigene URL** erreicht, die man
aktiv bewirbt. Ohne Werbebudget und ohne laufende Kampagne bekommt sie
schlicht keinen Traffic — bei derzeit 30 Downloads im Monat wäre sie
wirkungslos.

**Sie wird genau dann sinnvoll, wenn der organische Marketingplan auf dem
Branch `docs/marketing` anläuft** — dessen Community- und Reddit-Beiträge sind
exakt die Traffic-Quelle, die eine CPP braucht. Jeder Beitrag kann auf die
passende Seite zeigen statt auf die generische.

Deshalb: die drei Konzepte vorbereiten, in ASC anlegen, **sobald der erste
Kanal steht**.

### CPP-1 — „Offline & Datenschutz"

| | |
|---|---|
| Interne Bezeichnung | `cpp-privacy` |
| Zielgruppe | Datenschutzbewusste, Betriebsräte, Journalisten, Ärzte, Anwälte |
| Kernbotschaft | Das Gespräch verlässt das Gerät nicht |
| Unterschied zur Hauptseite | Führt mit On-Device statt mit Geschwindigkeit |
| Screenshots | 1) neues Hero · 2) `03-usp` („Kein Abo. Kein Konto.") · 3) Einstellungen mit iCloud-Schalter · 4) `01-transcript` · 5) `05-edit` |
| Copy-Richtung | „Transkription, die auf deinem iPhone bleibt." Ehrlich bleiben: iCloud-Sync ist standardmäßig **an** und synchronisiert in die **private** iCloud des Nutzers — das gehört auf die Seite, nicht weggelassen |

### CPP-2 — „Meeting-Notizen & Protokoll"

| | |
|---|---|
| Interne Bezeichnung | `cpp-meetings` |
| Zielgruppe | Projektleitung, Beratung, Teams mit vielen Terminen |
| Kernbotschaft | Aus 30 Minuten Besprechung werden fünf Zeilen Protokoll |
| Unterschied zur Hauptseite | Führt mit der **KI-Zusammenfassung** — also dem, was die Hauptseite bewusst *nicht* zuerst zeigen soll |
| Screenshots | 1) `02-summary` als Hero · 2) `01-transcript` · 3) Export TXT/Markdown · 4) `06-library` mit Suche · 5) `03-usp` |
| Copy-Richtung | „Das Protokoll schreibt sich selbst." |

### CPP-3 — „Diktiergerät"

| | |
|---|---|
| Interne Bezeichnung | `cpp-dictation` |
| Zielgruppe | Vielsprecher: Außendienst, Handwerk, Pflege, Autoren |
| Kernbotschaft | Aufnehmen, überschreiben, fertig — ohne Nachbearbeitung |
| Unterschied zur Hauptseite | Führt mit dem Überschreiben-Feature (`04-record`), das auf der Hauptseite an vierter Stelle steht |
| Screenshots | 1) `04-record` · 2) neues Hero · 3) `06-library` · 4) `05-edit` · 5) `03-usp` |
| Copy-Richtung | „Versprochen? Einfach drüber sprechen." |

**WhisperScribe-Pro-Cross-Sell bewusst nicht als CPP.** Eine Produktseite
bewirbt *diese* App; eine fremde App dort in den Mittelpunkt zu stellen,
verschenkt die Seite. Der Querverweis steht bereits in den Einstellungen und
gehört dorthin.

---

## 5. Inhalts-Mediathek / Asset-Struktur

### Namenskonvention

```
<kanal>-<motiv>-<sprache>-<gerät>[-<variante>].<ext>

store-01-transcript-de-iphone69.png
store-01-transcript-de-iphone69-b.png     ← A/B-Treatment
cpp-privacy-01-hero-de-iphone69.png
preview-main-de-iphone69.mp4
social-promo-de-vertical.mp4
```

Gerätekürzel: `iphone69`, `ipad129`. Sprache: `de`, `en`.

### Ablage im Repository

```
Screenshots/
├── de|en/<Gerät>/            Rohcaptures (unverändert, Quelle)
├── store/de|en/<Gerät>/      Hauptseite — das, was live ist
├── cpp/<cpp-name>/de|en/…    je Produktseite
├── variants/<test-id>/…      A/B-Treatments, nie live ohne Test
├── video/                    preview-*, promo-*
└── captions.json             alle Headlines, eine Quelle
```

**Regel: `store/` enthält ausschließlich, was tatsächlich live ist.** Alles
Experimentelle liegt unter `variants/` oder `cpp/`. Ein Testasset darf nie mit
dem ausgelieferten Satz verwechselbar sein.

### Versionierung

Assets bleiben im Git (sie sind klein: der gesamte Satz liegt bei 49 MB) und
werden über Release-Tags datiert. Eine zusätzliche Asset-Datenbank lohnt bei
dieser Menge nicht.

### Wiederverwendbare Gruppen

| Gruppe | Motive | verwendet in |
|---|---|---|
| `core` | 01-transcript, 03-usp | Hauptseite, alle CPPs |
| `ai` | 02-summary, Export | cpp-meetings |
| `recorder` | 04-record, 06-library | cpp-dictation |
| `trust` | 03-usp, Einstellungen/iCloud | cpp-privacy |

### Was neu zu erstellen ist

1. Neues Hero (Spezifikation liegt vor)
2. Preview-Video neu aufgenommen auf Stand 1.2.0
3. Ein Einstellungen-Screenshot mit sichtbarem iCloud-Schalter für `cpp-privacy`
4. Ein Export-Screenshot (Share Sheet mit TXT/Markdown) für `cpp-meetings`

---

## 6. Produktseitenoptimierung (A/B)

### Vorab, und das ist der wichtigste Punkt dieses Abschnitts

**Bei Sprechlys aktuellem Traffic ist ein A/B-Test statistisch nicht
auswertbar.** Überschlagsrechnung für 80 % Power bei α = 0,05 und einer
angenommenen Impression-zu-Download-Rate von 5 %:

| gesuchter Effekt | nötige Impressions **je Arm** |
|---|---:|
| +10 % relativ | ~30.000 |
| +30 % relativ | ~3.400 |
| +50 % relativ | ~1.200 |

30 Downloads im Monat entsprechen bei 5 % etwa 600 Impressions — pro Arm also
300. Selbst ein **+50 %-Effekt** bräuchte rund **vier Monate**, ein realistischer
+10 %-Effekt wäre nie nachweisbar.

**Konsequenz:** Zuerst das Offensichtliche beheben (Video hochladen, Hero
reparieren), Reichweite aufbauen — **danach** testen. Ein Test, der nichts
entscheiden kann, kostet nur Zeit und blockiert die Seite.

**Startschwelle:** frühestens ab etwa **5.000 Impressions pro Monat**, und
vorher die echten Impressionszahlen aus ASC holen statt sie wie hier zu
schätzen.

Die Tests sind trotzdem fertig ausgearbeitet, damit sie sofort laufen können,
sobald die Schwelle erreicht ist.

### Test 1 — Hero-Motiv (erster Test, allein)

| | |
|---|---|
| Hypothese | Ein Hero, das die Headline belegt (Live-Transkript) statt den fertigen KI-Bildschirm zu zeigen, erhöht die Conversion |
| A (Kontrolle) | heutiges `01-transcript` |
| B (Treatment) | neues Hero nach `ASSET_SPEC_HERO.md` |
| Einzige Änderung | **nur Screenshot 1**, Position 2–6 identisch, Headline identisch |
| Kennzahl | Conversion-Rate Produktseite → Download |
| Erfolg | ≥ +15 % relativ, Konfidenz ≥ 90 % |
| Abbruch | −10 % relativ bei ≥ 90 % Konfidenz, oder 90 Tage ohne Signifikanz |
| Laufzeit | 30–90 Tage, mindestens die Impressionszahl oben |

### Test 2 — Nutzenbotschaft (erst nach Test 1)

| | |
|---|---|
| Hypothese | „Kein Abo. Kein Konto." an erster Stelle schlägt die Funktionsaussage, weil der Einmalkauf der schärfste Unterschied zum Wettbewerb ist |
| A | Reihenfolge wie heute (Transkript → Zusammenfassung → USP) |
| B | USP nach vorn (USP → Transkript → Zusammenfassung) |
| Einzige Änderung | **Reihenfolge**, dieselben Bilder |
| Kennzahl / Erfolg / Abbruch | wie Test 1 |

### Test 3 — Zweites Motiv (optional, zuletzt)

| | |
|---|---|
| Hypothese | Das Überschreiben-Feature (`04-record`) ist konkreter als die KI-Zusammenfassung und wirkt auf Position 2 besser |
| A | Position 2 = `02-summary` |
| B | Position 2 = `04-record` |

### Was während eines Tests nicht verändert werden darf

Sonst ist das Ergebnis nicht interpretierbar:

- **kein Preis** — die Anhebung auf 9,99 € ist ohnehin aufgeschoben
- keine Änderung an Name, Untertitel, Keywords
- kein neues App-Release mit sichtbaren UI-Änderungen
- kein Upload oder Austausch des Preview-Videos
- keine Beschreibung, kein Werbetext
- keine parallele CPP-Kampagne auf dieselbe Zielgruppe

---

## 7. ASC-Änderungen

**Keine.** Nicht angelegt, nicht hochgeladen, nicht verändert — weder Custom
Product Pages noch Experimente noch Assets. Der Audit war rein lesend.

Begründung:

1. **CPP und PPO brauchen zuerst die Assets.** Eine Produktseite mit den
   heutigen Bildern anzulegen, bedeutet die bekannten Schwächen zu
   vervielfältigen.
2. **Jedes CPP- und Treatment-Asset geht durch die App-Review.** Unfertige
   Assets einzureichen, kostet Review-Zyklen.
3. **Ein A/B-Test wäre derzeit nicht auswertbar** (Abschnitt 6).
4. Die Vorgabe lautete: nichts blind live schalten.

---

## 8. Empfohlene Reihenfolge

1. **Impressions und Produktseitenaufrufe aus ASC holen** — ohne diese Zahl
   ist alles Weitere Schätzung. Erfordert das Anlegen eines Analytics-Reports
   in ASC (schreibender Aufruf) und damit eine Freigabe.
2. **Preview-Video neu aufnehmen und hochladen** — größter Hebel, Kette
   existiert, Asset ist nur veraltet.
3. **Hero reparieren** — Geräteaufnahme nach Spezifikation, oder die
   Simulator-Zwischenlösung aus Abschnitt 3.
4. **Keywords schärfen** — `recorder`, `sprache`, `text` gegen spezifischere
   Begriffe tauschen, Dopplungen mit Name und Untertitel auflösen.
5. **CPPs anlegen**, sobald der erste Marketingkanal läuft.
6. **A/B-Tests**, sobald die Impressionsschwelle erreicht ist.
