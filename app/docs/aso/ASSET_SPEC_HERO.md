# Asset-Spezifikation — neues Hero-Motiv „Live-Transkript"

Für Screenshot 1 der Hauptproduktseite und als Treatment B in Test 1
(`docs/aso/APP_STORE_OPTIMIZATION.md`, Abschnitt 6).

Diese Spezifikation ist so gefasst, dass das Asset **ohne Rückfragen** erstellt
werden kann.

---

## Warum nicht einfach erzeugt

Das Motiv zeigt ein **laufendes Live-Transkript während der Aufnahme**. Das
braucht `SpeechAnalyzer`, und der existiert **im Simulator nicht** — die
bestehende Pipeline (`scripts/screenshots.sh` → UI-Test im Simulator) kann
dieses Bild prinzipiell nicht aufnehmen.

Deshalb eine Spezifikation statt eines improvisierten Assets. Eine
Zwischenlösung ohne Geräteaufnahme steht in Abschnitt „Fallback".

---

## 1. Ziel und Aussage

| | |
|---|---|
| Zweck | Belegen, was die Headline behauptet: man spricht, der Text entsteht dabei |
| Zielgruppe | Alle — das ist das Hero der Hauptseite, nicht einer Nische |
| Zentrale Botschaft | Sprechly schreibt **während** du sprichst, auf dem Gerät |
| Hervorgehobene Funktion | Live-Transkription (das Merkmal, das Sprechly von einfachen Diktiergeräten trennt) |
| Ersetzt | `Screenshots/store/<lang>/<Gerät>/01-transcript.png` |

## 2. Copy

Unverändert aus `Screenshots/captions.json` — die Headline ist gut, nur das
Bild passte nicht zu ihr:

| | de-DE | en-US |
|---|---|---|
| Headline | `Sprich. Sprechly schreibt mit.` | `Speak. Sprechly writes it down.` |
| Subline (iPhone) | `Transkript direkt auf dem iPhone` | `Transcripts right on your iPhone` |
| Subline (iPad) | `Transkript direkt auf dem iPad` | `Transcripts right on your iPad` |

Keine neue Copy, keine neuen Claims. Der Composer setzt sie automatisch.

## 3. Bildaufbau

Von oben nach unten:

1. **Headline** weiß, SF Rounded Bold — vom Composer gesetzt
2. **Subline** in Akzentgold `#E3B354` — vom Composer gesetzt
3. **App-Screen**, abgerundet, randabfallend bis zur Unterkante

Im App-Screen sichtbar, in dieser Reihenfolge:

- **laufender Aufnahme-Timer** mit rotem Punkt, Stand **zwischen 00:20 und 00:45**
  (nicht 00:05 — es soll nach einer echten Aufnahme aussehen, nicht nach einem
  gerade gestarteten Test)
- **Live-Wellenform** mit sichtbarem Ausschlag, nicht flach
- **Live-Transkriptzeile** mit mindestens **drei vollständigen Zeilen** Text,
  die letzte darf mitten im Satz enden — das zeigt, dass gerade geschrieben wird
- **Transport-Steuerung** unten (Pause, Stopp)

**Entscheidend: die Live-Transkriptzeile muss in der oberen Bildhälfte
liegen.** Im Suchergebnis ist das Bild ein Daumennagel; was unten steht, sieht
niemand.

## 4. Inhalt des Transkripttexts

Deutsch, neutral, geschäftlich, **keine privaten Echtdaten**. Vorschlag — das
Gesprochene muss beim Aufnehmen genau so eingesprochen werden:

> „Lass uns mit der Sprint-Planung starten. Oberste Priorität ist das neue
> Onboarding. Design liefert die Screens bis Mittwoch, dann übernimmt die
> Entwicklung."

Englisch:

> „Let's start with sprint planning. Top priority is the new onboarding. Design
> delivers the screens by Wednesday, then engineering takes over."

Damit bleibt das Motiv konsistent zum Rest des Satzes, der dasselbe
Sprint-Szenario zeigt.

## 5. Technische Vorgaben

| | |
|---|---|
| Dateiname | `01-transcript.png` (ersetzt das bisherige) |
| Rohcapture | `Screenshots/<lang>/<Gerät>/01-transcript.png` |
| Ausgabe | `Screenshots/store/<lang>/<Gerät>/01-transcript.png` |
| Format iPhone | **1320 × 2868** (6,9") — exakt, sonst weist ASC ab |
| Format iPad | **2064 × 2752** (12,9") |
| Farbraum / Typ | sRGB, PNG, ohne Alpha |
| Statusleiste | 16:05, volles WLAN, voller Akku — wie im bestehenden Satz |
| Erscheinungsbild | Dark Mode (die App ist dark-first) |

## 6. Sprachen und Geräte

| Priorität | Umfang |
|---|---|
| 1 | **de-DE, iPhone 6,9"** — Hauptmarkt und Hauptgerät |
| 2 | en-US, iPhone 6,9" |
| 3 | de-DE und en-US, iPad 12,9" |

iPhone zuerst. Ein iPad-Satz ohne iPhone-Satz hilft nicht; umgekehrt schon.

**Die iPad-Subline muss „auf dem iPad" lauten** — der Composer erledigt das
über den `iPad`-Override in `captions.json`, sofern der Override erhalten
bleibt.

## 7. Aufnahme auf dem Gerät

Weil der Simulator ausscheidet:

1. Release- oder Debug-Build 1.2.0 auf dem iPhone installieren
   (Rezept in `docs/DEVICE_TESTS.md` bzw. der bekannten `devicectl`-Kette)
2. Gerät auf die Zielsprache stellen, Dark Mode aktiv
3. Aufnahmebildschirm öffnen, **Live-Transkript einschalten**
4. Den Text aus Abschnitt 4 sprechen
5. Bei 00:20–00:45 mit **Seitentaste + Lauter** einen Screenshot auslösen
6. Datei auf den Mac übertragen, auf exakt 1320 × 2868 prüfen
7. Als `Screenshots/<lang>/iPhone 17 Pro Max/01-transcript.png` ablegen
8. `python3 scripts/compose_store_screenshots.py`

Schritt 8 setzt Headline und Subline automatisch — der betextete Satz bleibt
dadurch gestalterisch identisch zu den übrigen fünf Bildern.

**Vor dem Hochladen prüfen:** keine privaten Inhalte in der Statusleiste, kein
fremder Name im Transkript, Zeitstempel plausibel.

## 8. Fallback ohne Geräteaufnahme

Wenn die Geräteaufnahme aufgeschoben wird, bringt diese Variante den Großteil
des Gewinns und läuft vollständig im Simulator:

1. `App/DemoSeed.swift`: erste Aufnahme von **4 auf 9–10 Transkriptsegmente**
   erweitern (reine `SEED_DEMO`-Demodaten, kein Produktverhalten)
2. `Tests/VoxStudioUITests/ScreenshotTests.swift`: vor
   `capture(app, lang, "01-transcript")` an der KI-Karte vorbeiscrollen, sodass
   das Hero mit Zeitstempeln und Transkripttext beginnt
3. `scripts/screenshots.sh` und `scripts/compose_store_screenshots.py` laufen lassen

Damit verschwinden die gemessenen **19,9 % Leerfläche** und die KI-Karte
verlässt das Hero. Was bleibt: es zeigt weiterhin ein *fertiges* Transkript,
nicht die Entstehung — der eigentliche Reiz des Motivs fehlt also.

**Beide Wege sind nicht ausgeführt**: der erste braucht eine Geräteaufnahme,
der zweite ändert Demodaten und den Aufnahme-Flow.
