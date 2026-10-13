# Asset-Mediathek — Sprechly

Geordnete Ablage für alles, was im App Store oder in Kampagnen erscheint.
Konzept und Begründung: `docs/aso/APP_STORE_OPTIMIZATION.md`.

## Verhältnis zu `Screenshots/`

`Screenshots/` ist die **Produktionskette**: Rohcaptures aus dem UI-Test und
die daraus betexteten Bilder. Sie wird von `scripts/screenshots.sh` und
`scripts/compose_store_screenshots.py` erzeugt und überschrieben.

`assets/` ist die **Mediathek**: der kuratierte Stand, der tatsächlich
ausgeliefert wird oder für eine Kampagne vorgesehen ist. Hier wird nichts
automatisch überschrieben.

> Ein Asset gelangt erst dann nach `assets/store/`, wenn es wirklich live ist.

## Struktur

| Ordner | Inhalt | Regel |
|---|---|---|
| `assets/store/` | Hauptproduktseite | **nur was live ist** |
| `assets/variants/` | A/B-Treatments | nie live ohne ausgewerteten Test |
| `assets/cpp/` | Benutzerdefinierte Produktseiten | je Seite ein Unterordner |
| `assets/video/` | App-Previews und Social-Videos | Preview ≠ Promo, siehe unten |

## Namenskonvention

```
<kanal>-<motiv>-<sprache>-<gerät>[-<variante>].<ext>

store-01-transcript-de-iphone69.png
store-01-transcript-de-iphone69-b.png      ← Treatment B
cpp-privacy-01-hero-de-iphone69.png
preview-main-de-iphone69.mp4
social-promo-de-vertical.mp4
```

- **Sprache:** `de`, `en`
- **Gerät:** `iphone69` (1320×2868), `ipad129` (2064×2752)
- **Variante:** `-b`, `-c` — nur unter `variants/`

## Wiederverwendbare Gruppen

| Gruppe | Motive | verwendet in |
|---|---|---|
| `core` | 01-transcript, 03-usp | Hauptseite, alle CPPs |
| `ai` | 02-summary, Export | cpp-meetings |
| `recorder` | 04-record, 06-library | cpp-dictation |
| `trust` | 03-usp, Einstellungen mit iCloud-Schalter | cpp-privacy |

## Versionierung

Assets bleiben im Git und werden über Release-Tags datiert; der gesamte Satz
liegt im zweistelligen MB-Bereich. Eine separate Asset-Datenbank lohnt bei
dieser Menge nicht.

**Preview ≠ Promo:** `preview-*` sind App-Store-App-Previews und unterliegen
Apples Regeln (15–30 s, überwiegend echtes App-Material). `social-promo-*` sind
freie Social-Videos und gehören **nie** nach App Store Connect.

## Stand 2026-10-10 — gerätespezifisches Hero

`assets/store/` enthält den freigegebenen Satz aus Lauf E: 6 Motive × 2 Sprachen
× 2 Geräte = 24 Dateien, alle mit exakten App-Store-Maßen.

**Das Hero kommt je Gerät aus einem anderen Screen** — gleiche Botschaft,
gerätegerechte Komposition:

| Gerät | Hero-Screen | Grund |
|---|---|---|
| iPhone | Transkript-Blatt | Der Detailbildschirm hat dort keinen Platz für das Transkript |
| iPad | Detailbildschirm | Das Blatt schwebt über einem abgedunkelten Hintergrund, mit demselben Text angeschnitten daneben |

Beides ist unveränderte Produktions-UI. Die leeren Zeilen „KI" und
„Übersetzung" über dem Transkript gehören zur echten Oberfläche und werden
**nicht** per Produktcode ausgeblendet.

Die Hero-Aufnahme stammt aus `DemoSeed` und trägt bewusst **keine**
KI-Zusammenfassung, damit die Ansicht direkt mit Zeitstempeln beginnt.

### Treatments für Test 1

- `variants/test1-hero-a/` — bisheriges Live-Hero (Stand `main`), Kontrolle
- `variants/test1-hero-b/` — neues Hero aus Lauf E
- `variants/runC-reference/` — Zwischenkandidat Lauf C, **kein** Store-Asset
