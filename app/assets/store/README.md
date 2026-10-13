# assets/store — freigegebener Store-Satz

**Status: freigegeben am 2026-10-10** (Lauf E). Dies ist der Satz, der für die
Hauptproduktseite vorgesehen ist. Nur Assets, die tatsächlich live gehen sollen,
liegen hier.

24 Dateien: 6 Motive × 2 Sprachen × 2 Geräte, alle mit exakten
App-Store-Abmessungen.

| Gerät | Abmessung | Motive |
|---|---|---|
| iPhone 17 Pro Max (6,9") | 1320 × 2868 | 01–06 |
| iPad Pro 13-inch (12,9") | 2064 × 2752 | 01–06 |

## Reihenfolge und Botschaft

| # | Datei | Headline DE | Headline EN |
|---|---|---|---|
| 1 | `01-transcript` | Sprich. Sprechly schreibt mit. | Speak. Sprechly writes it down. |
| 2 | `02-summary` | Aus 30 Minuten werden 5 Zeilen | 30 minutes become 5 lines |
| 3 | `03-usp` | Kein Abo. Kein Konto. | No subscription. No account. |
| 4 | `04-record` | Versprecher? Einfach überschreiben | Misspoke? Just record over it |
| 5 | `05-edit` | Schneiden, mischen, exportieren | Cut, mix, export |
| 6 | `06-library` | Alle Aufnahmen, sofort gefunden | Every recording, found instantly |

## Das Hero kommt je Gerät aus einem anderen Screen

Gleiche Botschaft, gerätegerechte Komposition — ausdrücklich so entschieden:

| Gerät | Screen | Grund |
|---|---|---|
| iPhone | Transkript-Blatt | Der Detailbildschirm hat dort keinen Platz für das Transkript |
| iPad | Detailbildschirm | Das Blatt schwebt über abgedunkeltem Hintergrund, derselbe Text steht angeschnitten daneben |

Beides ist **unveränderte Produktions-UI**. Die Zeilen „KI" und „Übersetzung"
über dem Transkript gehören zur echten Oberfläche und bleiben sichtbar; sie per
Produktcode auszublenden wurde ausgeschlossen.

Die Hero-Aufnahme stammt aus `DemoSeed` und trägt bewusst **keine**
KI-Zusammenfassung, damit die Ansicht direkt mit Zeitstempeln beginnt.

## Geprüft

Statusleiste normalisiert (09:41, Mobilfunk, WLAN, voller Akku, kein fremder
App-Name) · keine Debug-Artefakte · nichts abgeschnitten · natürliche
Scrollposition · Leerfläche iPhone 4,3 % (de) und 6,2 % (en), zuvor 24,1 %.

## Reproduzieren

```
bash scripts/screenshots.sh                     # Rohcaptures, DE + EN, beide Geräte
python3 scripts/compose_store_screenshots.py    # betextete Store-Bilder
```

Danach `Screenshots/store/` prüfen und erst nach visueller Freigabe hierher
übernehmen.
