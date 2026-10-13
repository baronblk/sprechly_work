# Produktseitenoptimierung — vorbereitete Treatments

Drei Tests, **nicht gestartet**. Die Treatments sind so weit vorbereitet, dass
ein Test ohne weitere Konzeptarbeit laufen kann.

## Startbedingung

**Nicht starten, solange der Traffic nicht reicht.** Überschlag für 80 % Power,
α = 0,05, angenommene Impression-zu-Download-Rate 5 %:

| gesuchter Effekt | Impressions **je Arm** | bei ~600 Impr./Monat |
|---|---:|---|
| +10 % relativ | ~30.000 | nicht erreichbar |
| +30 % relativ | ~3.400 | ~11 Monate |
| +50 % relativ | ~1.200 | ~4 Monate |

**Schwelle: ab etwa 5.000 Impressions pro Monat.** Vorher die echten
Impressionszahlen aus App Store Connect holen, statt wie hier zu schätzen —
die Schätzung beruht auf 30 Downloads und einer angenommenen Conversion.

Apple erlaubt bis zu **drei Treatments gegen die Kontrolle** gleichzeitig und
bis zu **90 Tage** Laufzeit. Trotzdem: **immer nur einen Test** laufen lassen,
sonst ist nicht trennbar, was gewirkt hat.

---

## Test 1 — Hero-Motiv

Der erste Test, weil das Hero das einzige Bild ist, das praktisch jeder sieht.

| | |
|---|---|
| **Hypothese** | Ein Hero, das das Transkript zeigt statt der generierten Zusammenfassung, belegt die Headline und erhöht die Conversion |
| **A (Kontrolle)** | bisheriges `01-transcript` — KI-Karte oben, 19,9 % leere Fläche |
| **B (Treatment)** | neues `01-transcript` — am KI-Block vorbeigescrollt, Transkript mit Zeitstempeln füllt die Fläche |
| **Geändert wird** | **ausschließlich Screenshot 1.** Position 2–6 identisch, Headline identisch, Werbetext identisch |
| **Kennzahl** | Conversion-Rate Produktseite → Download |
| **Erfolg** | ≥ +15 % relativ bei ≥ 90 % Konfidenz → B wird die neue Hauptseite |
| **Abbruch** | −10 % relativ bei ≥ 90 % Konfidenz, oder 90 Tage ohne Signifikanz |
| **Laufzeit** | 30–90 Tage, mindestens die Impressionsschwelle oben |
| **Assets** | A: `assets/store/` · B: `assets/variants/test1-hero-b/` |

Beide Varianten liegen fertig vor — der Test kann ohne Vorlauf starten.

---

## Test 2 — Privacy-Claim gegen Productivity-Claim

Erst nach Test 1, weil er auf demselben Hero aufbaut.

| | |
|---|---|
| **Hypothese** | Der Datenschutz-Vorteil überzeugt breiter als das Produktivitätsversprechen — oder umgekehrt. Beides ist plausibel, genau deshalb wird es getestet |
| **A (Kontrolle)** | Reihenfolge wie heute: Transkript → Zusammenfassung → USP |
| **B (Treatment)** | Privacy zuerst: `03-usp` („Kein Abo. Kein Konto.") auf Position 1, Transkript auf 2, Zusammenfassung auf 3 |
| **Geändert wird** | **nur die Reihenfolge der ersten drei Bilder.** Keine neuen Motive, keine neuen Captions |
| **Kennzahl** | Conversion-Rate Produktseite → Download |
| **Erfolg / Abbruch** | wie Test 1 |

Dass hier keine neuen Assets nötig sind, ist Absicht: der Test misst die
Botschaftsreihenfolge, nicht die Bildqualität. Neue Bilder würden zwei
Variablen vermischen.

---

## Test 3 — Zweites Motiv

| | |
|---|---|
| **Hypothese** | Das Überschreiben-Feature ist konkreter als die KI-Zusammenfassung und hält Besucher länger auf der Seite |
| **A (Kontrolle)** | Position 2 = `02-summary` |
| **B (Treatment)** | Position 2 = `04-record` („Versprecher? Einfach überschreiben") |
| **Geändert wird** | **nur Position 2** |
| **Kennzahl** | Conversion-Rate; sekundär die Scroll-Tiefe, soweit ASC sie ausweist |
| **Erfolg / Abbruch** | wie Test 1 |

---

## Was während eines laufenden Tests nicht verändert werden darf

Jede dieser Änderungen macht das Ergebnis uninterpretierbar:

- **Preis** — die Anhebung auf 9,99 € ist ohnehin aufgeschoben, und sie darf
  nicht in ein Testfenster fallen
- Name, Untertitel, Keywords
- Beschreibung, Werbetext
- Upload oder Austausch des App-Preview-Videos
- ein neues Release mit sichtbaren UI-Änderungen
- eine parallele CPP-Kampagne auf dieselbe Zielgruppe
- ein zweiter gleichzeitiger Test

## Reihenfolge

1. Impressionszahlen aus ASC holen → Schwelle prüfen
2. Preview-Video hochladen und **vier Wochen wirken lassen**, bevor ein Test
   startet — sonst fällt der Video-Effekt in das Testfenster
3. Test 1
4. Gewinner übernehmen, dann Test 2
5. Test 3 nur, wenn Test 1 und 2 verwertbare Ergebnisse geliefert haben
