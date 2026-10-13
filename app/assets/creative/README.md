# Kreativ-Inhalte (Produktseiten-Kopfzeile & Suchergebnisse)

Eine **andere Gattung** als `assets/store/`. Store-Screenshots sind
Hochformat-Bildschirme mit Caption darüber; Kreativ-Inhalte sind breite
Querformat-Bilder, die oben auf der Produktseite und in derselben Größe in den
Suchergebnissen erscheinen.

## Warum eigene Dateien nötig waren

Keiner der 115 bestätigten Inhalte in der ASC-Mediathek passt. App Store Connect
führt sie als „App-Bildschirmfoto (1320 × 2868 Pixel)" mit
**„Funktioniert mit: App-Bildschirmfoto, iMessage-Bildschirmfoto"** — die
Kopfzeile taucht dort nicht auf. Der Auswahldialog für die Kopfzeile zeigte
entsprechend **0 verfügbare Inhalte**.

## Format

Apple akzeptiert **16:9, 5244 × 2950** für *beide* Platzierungen. Deshalb eine
Datei je Sprache statt zwei — 21:9 (3840 × 1646) für die Kopfzeile und 3:2 für
die Suchergebnisse wären zwei getrennte Sätze.

PNG, **kein Alphakanal** (Transparenz wird abgelehnt).

## Erzeugung

```
python3 scripts/compose_creative_asset.py          # de und en
```

Quelle ist der unbetextete Rohcapture
`Screenshots/<lang>/iPhone 17 Pro Max/01-transcript.png`. Der Bildschirmausschnitt
wird **unverändert** platziert; gezeichnet werden nur Hintergrund und Caption —
dieselbe Regel, der auch die Store-Screenshots folgen.

Headline und Subline kommen aus `Screenshots/captions.json`, Eintrag
`01-transcript`. Keine neuen Aussagen, keine neuen Claims.

## Gestalterische Entscheidungen

- **Ausschnitt statt ganzem Telefon.** Ein 1320 × 2868-Bildschirm in einem
  16:9-Rahmen wird etwa ein Fünftel der Breite breit, die Mitte bleibt leer und
  der Transkripttext ist in Suchergebnisgröße ein grauer Fleck. Der Ausschnitt
  der Transkriptliste, auf volle Höhe skaliert, füllt den Rahmen und bleibt
  lesbar.
- **Karte statt Verlauf.** Ein weicher Verlauf an der linken Kante dimmte die
  Zeitstempelspalte und sah nach Rendering-Fehler aus.
- **Headline höchstens zweizeilig.** Dreizeilig brach „Sprich." allein auf eine
  Zeile.

## Reichweite

Kreativ-Inhalte werden laut Apple erst Nutzern ab **iOS/iPadOS 27** angezeigt.
Die Wirkung wächst also über Monate.

Sie lassen sich **unabhängig von einer App-Einreichung** hochladen und vorab
genehmigen — anders als Screenshots und App-Previews braucht es dafür keine neue
Version.

## Stand

| Datei | Status |
|---|---|
| `default/de/header-16x9.png` | erzeugt, **nicht hochgeladen** |
| `default/en/header-16x9.png` | erzeugt, **nicht hochgeladen** |

Die drei benutzerdefinierten Produktseiten haben denselben Slot und sind
ebenfalls leer — erst die Standardseite, weil sie alle Besucher sehen.
