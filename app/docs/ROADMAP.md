# Sprechly — Roadmap

Stand: 2026-10-04. Die App ist **veröffentlicht** — damit hat sich die Priorität
verschoben: nicht mehr „bauen bis zum Release", sondern **ausliefern, gefunden
werden, überzeugen**. Geräte-Verifikationen siehe [DEVICE_TESTS.md](DEVICE_TESTS.md),
Entscheidungen siehe [DECISIONS.md](DECISIONS.md).

Status: ☐ offen · ◑ teilweise · ✅ erledigt · ⏸ bewusst verschoben

---

## Ist-Stand

**Live im Store: 1.1.0.** In Arbeit: **1.1.1 (10) — Growth & Value Release**
(Branch `release/1.1.1-growth-value`, nicht eingereicht).

**Lage seit 1.1.0** (qualitativ, aus Renes ASC-Auswertung — konkrete Zahlen noch
nachzutragen): deutlich **weniger Sichtbarkeit** als zum Launch, bei gleichzeitig
**merklich besserer Conversion**. Der Engpass ist damit weiterhin Auffindbarkeit
und Produktdarstellung, nicht fehlende Funktionen. Die Wette von 1.1.0 (Wert vor
dem Kauf zeigen) scheint aufzugehen — deshalb wird in 1.1.1 der Preis angehoben
statt gesenkt.

**Baseline vor 1.1.0** (App Store Connect, Stand 18.08.2026, 90 Tage):

| Kennzahl | Wert | Lesart |
|---|---|---|
| Impressionen | 9.340 | |
| Produktseitenaufrufe | 209 | **2,2 %** — der eigentliche Engpass |
| Erstmalige Downloads | 128 | |
| In-App-Käufe | 4 | 3,1 % der Downloads |
| Erlöse | 17 $ | |
| **Bewertungen** | **0** | die App hat bis heute nie danach gefragt |

**Diagnose (unverändert gültig):** Das Problem ist nicht das Gating und nicht der
Funktionsumfang, sondern **Reichweite** und **fehlender Vertrauensbeweis**. Was
sich seit 1.1.0 geändert hat: die Conversion stimmt inzwischen, die Sichtbarkeit
nicht. Genau dort setzt 1.1.1 an.

---

## A. Jetzt — Wirkung vor neuen Features

### A1 — Release 1.1.0 ✅ erledigt (live)
- ✅ Version 1.1.0 (9), IPA signiert und über Transporter hochgeladen
- ✅ `CHANGELOG.md` + What's-New (de/en)
- ✅ Store-Screenshots neu (6,9" iPhone + 13" iPad, de/en)
- ✅ IAP-Review-Screenshot neu, inkl. Ausweichgrößen in `Screenshots/iap-review/`
  (das IAP-Feld in ASC lehnte die 6,9"-Größe ab)
- ✅ Store-Beschreibung korrigiert (versprach fälschlich „Transkription gratis")
- ✅ **Eingereicht 2026-08-20**
- ✅ Freigegeben und veröffentlicht

**Während der Review keine Metadaten der eingereichten Version ändern** — das
kann den Review zurückwerfen. Der **Werbetext** ist die Ausnahme: jederzeit
änderbar, ohne neue Prüfung.

### A2 — ASO / Store-Auftritt ◑ in 1.1.1 umgesetzt, Einspielen offen
Größter Hebel auf Downloads, ohne die App zu ändern.
- ✅ App-Name, Untertitel, Werbetext und Keywords überarbeitet (`STORE_LISTING.md`),
  alle Zeichenlimits per `scripts/validate_store_metadata.py` geprüft
- ✅ Beschreibung: Einmalkauf, kein Konto und On-Device-Verarbeitung stehen jetzt
  im ersten Drittel statt im vierten Absatz
- ✅ **Zwei falsche Aussagen korrigiert** (siehe „Abgeschlossen")
- ✅ Sechs Store-Screenshots je Sprache mit Überschriften, Transkript zuerst
  (`scripts/compose_store_screenshots.py`, Texte in `Screenshots/captions.json`)
- ☐ In App Store Connect einspielen (Rene) — erst mit der 1.1.1-Einreichung

**Preis (Entscheidung 2026-10-04, ersetzt die Aussage vom 2026-08-19):**
**Korrigiert 2026-10-05: Die Anhebung ist aufgeschoben.** 1.1.1 geht mit
**6,99 €** live. Grund: Downloads −30 % bei gleichzeitig hoher Kaufquote (13 %)
— der Funnel bricht oben, nicht an der Paywall, und Listing-Rework und
Preiserhöhung würden dieselbe Kennzahl gegenläufig bewegen. Die Anhebung kostet
nichts, wenn man sie später als eigene Änderung vornimmt (kein Build, kein
Review). Bedingungen und Rechnung in `MONETIZATION.md`.

~~Mit 1.1.1 wird der Einmalkauf „Sprechly KI" von 6,99 € auf 9,99 € angehoben.~~
Der neue Preis wird gemeinsam mit dem überarbeiteten Store-Auftritt als **neue
Baseline** gemessen, nicht als isolierter Preistest. Weiterhin kein Abo, weiterhin
kostenloser Download, die 30-Sekunden-Vorschau bleibt. Durchzuführen in ASC —
Schritte in `MONETIZATION.md` → „Release checklist 1.1.1".

### A3 — Transkriptions-Qualität ✅ **gemessen, Scope entschieden**
`SpeechAnalyzer` läuft **nicht** im Simulator; jede Änderung hier ist auf dem
iPhone verifiziert. Ist-Analyse: **`docs/TRANSCRIPTION_PIPELINE.md`** (gegen das
iOS-27-SDK verifiziert).

Vier Phasen sind gemessen und abgeschlossen. **Zwei davon mit negativem
Ergebnis — die bleiben als Entscheidungsgrundlage bestehen und werden nicht
erneut aufgerollt:**

- ✅ **Phase 1** — Ist-Modell der Pipeline. Preset `.transcription` ist korrekt;
  die Optionen steuern Reporting/Attribute, nicht die Erkennungsgüte.
- ❌ **Phase 2 — `AnalysisContext.contextualStrings` widerlegt.**
  `docs/TRANSCRIPTION_CONTEXT_BENCHMARK.md`: **zeichenidentische** Transkripte,
  WER/CER/Recall-Delta exakt 0,000, auch bei 104 Begriffen. Ein eigener
  Wiring-Test belegt, dass der Kontext ankam (`setContext`: 0 → 3 Begriffe) —
  das Nullergebnis liegt an der API, nicht am Messaufbau.
  **Folge: kein Personal Vocabulary, keine Wörterbuch-UI.**
- ❌ **Phase 3 — `DictationTranscriber` kein Ersatz.**
  `docs/TRANSCRIBER_COMPARISON.md`: gleicher Zielbegriff-Recall (16/31) bei
  **schlechterer** WER (+0,058) und CER (+0,032), 2,3× Laufzeit, 2 statt 12
  installierte Locales, kein `isAvailable` — und **Inhaltsverlust** („StoreKit,"
  ersatzlos weggelassen). Der entscheidende Nebenbefund: jeder Punkt, in dem er
  gewinnt, ist ein **Formatierungs**problem, kein Erkennungsproblem.
- ✅ **Phase 4 — konservative semantische Formatierung, freigegeben und
  integriert.** `docs/SEMANTIC_FORMATTING.md`,
  `docs/TRANSCRIPTION_ERROR_TAXONOMY.md`.

Offen geblieben, nicht in 1.2:
- ☐ **Datei-Initializer / `analyzeSequence(from:)`** — ersetzt ~60 Zeilen Eigenbau
  und zwei `@unchecked Sendable`-Krücken. Kein belegter Gewinn an Erkennungsgüte.
  Vorher zwingend mit einer mehrstündigen Datei auf dem Gerät testen.
- ⏸ **`AnalyzerInputConverter`** (iOS 27) — erst sinnvoll, wenn das
  Deployment-Target von 26.0 auf 27 zieht.
- ⏸ **`customizedLanguage(modelConfiguration:)`** — der klassische Weg zu einem
  echten benutzerdefinierten Sprachmodell, etwas völlig anderes als die
  widerlegten `contextualStrings`. **Ungemessen**, eigenes Thema.

---

## Sprechly 1.2 — Transcription Quality & Smart Formatting

Scope eingefroren 2026-10-04. Alles unten ist implementiert, auf dem Gerät
gemessen und auf `feature/1.2-transcription-quality` committet. **Noch nicht
nach `main` gemerged, keine Versionsänderung, keine ASC-Aktion.**

**Enthalten:**
- ✅ Konservativer **Transcript Formatter**, zentral in beiden Speech-Services,
  genau einmal angewendet, nur auf finalisierte Ergebnisse.
- ✅ **`\letter`-Bugfix** — der Recognizer schrieb buchstabierte Zeichen als
  literales Markup in Transkripte und Exporte. Byteweise belegt, Marker-Audit im
  Benchmark, nur der belegte Marker wird behandelt.
- ✅ **Sichere Akronym-Behandlung** — über den belegten Pfad
  (Markup-Cleanup → eindeutiger Buchstabenlauf), keine breite Heuristik.
  Überlange und ambige Läufe werden ganz abgelehnt.
- ✅ **Uhrzeit- und Versionsformatierung**, beide nur mit Kontextbeleg
  (Zeit-Marker bzw. Schlüsselwort).
- ✅ **Belegte technische Schreibweisen** — dokumentierte Liste aus fünf Namen,
  kein Fuzzy-Matching.
- ✅ **Migration bestehender `\letter`-Segmente** — markierte Buchstabenfolgen
  werden aufgelöst (`K\letter I\letter` → `KI`), unmarkierte Folgen (`K I`,
  `A B C`) bleiben unberührt. Keine rückwirkende Neuformatierung von Nutzertext.
- ✅ **Eingefrorene DE- und EN-Benchmarks** — 30 Fixtures, SHA-256-Manifest,
  per Test erzwungen.

**Messergebnis** (iPhone 17 Pro, iOS 27.0.1, identisches Audio):

| | de-DE | en-US |
|---|---|---|
| Zielbegriffe | 13/31 → **20/31** | 20/31 → **21/31** |
| Formatting Accuracy | 0,619 → **0,909** | 0,800 → **0,840** |
| WER | 0,250 → **0,155** | 0,195 → **0,173** |
| **False Correction Count** | **0** | **0** |

**Explizit verworfen bzw. nicht enthalten:**
- ❌ **Personal Vocabulary** — durch Phase 2 widerlegt.
- ❌ **`contextualStrings`** — messbar wirkungslos.
- ❌ **`DictationTranscriber`-Migration** — durch Phase 3 widerlegt.
- ❌ **Generative Autokorrektur** — kein LLM auf Transkripttext; der Formatter
  ist deterministisch und vollständig testbar.
- ❌ **Große Speech-Pipeline-Migration** — Engine, Audio-Pipeline und Preset
  unverändert.
- ❌ Eigennamen-/Firmenkorrektur (`Chemnitzer Verkehrs-AG` bleibt, wie es ist).

Gemessen und **bewusst verworfen** (2026-10-04): eine en-US-Uhrzeitregel für
`1345 o'clock`. Die Engine verliert dort alle Trennzeichen — messbar wären +2
Begriffe, die Regel müsste aber Ziffergrenzen erraten und widerspricht damit dem
konservativen Prinzip. Bleibt als bekannte Grenze dokumentiert.

**Phase 6 — Live Audio Pipeline** (`docs/LIVE_AUDIO_PIPELINE.md`): die in
Phase 1 notierte doppelte Live-Konvertierung ist gemessen und **bleibt**. Von
den zwei Konvertierungen ist eine zwingend (der Analyzer nimmt nur 16 kHz Int16),
die andere kostet 6,2 µs gegen 147,9 µs AAC-Write derselben Buffer — 0,26 s CPU
pro Aufnahmestunde. Entfernt wurden drei nach SDK-Befund
(`NS_SWIFT_NONSENDABLE`, `NS_NOESCAPE`) unnötige `@unchecked Sendable`-Boxen.
**Entscheidung: Audioarchitektur unverändert, unnötige Sendable-Wrapper entfernt.**

### Forschungspunkt nach 1.2
- ☐ **Cross-Segment Formatting / Segment Boundary Repair** — der Recognizer
  trennt zusammengehörige Zahlen an Segmentgrenzen (`… Jahr 18` + `64 …`,
  `… wohl 3` + `,50 …`), real beobachtet am 2026-10-05. Der Formatter arbeitet
  pro Segment und kann das nicht sehen; die KI-Zusammenfassung dagegen schon,
  weil sie den Volltext liest. **Bewusst nicht in 1.2.** Vor einer Regel sind
  Zeitstempel-Zuordnung, Häufigkeit und die Abgrenzung zu echt getrennten
  Zahlen zu klären — Details in `docs/TRANSCRIPTION_ERROR_TAXONOMY.md`.

### Offene Wartungspunkte (nicht 1.2)
- ☐ **Volle Testsuite auf Gerät** — 16 Suites scheitern mit
  `No eligible connection available` beim CloudKit-Container des Test-Hosts.
  Auf `2f41f3b` reproduziert, also **pre-existing** und unabhängig von der
  Transkriptionsarbeit. Details in `docs/SEMANTIC_FORMATTING.md`.
- ☐ **Datei-Finalisierung nach `stop()`** — der AAC-Container wird erst
  abgeschlossen, wenn die `AVAudioFile` des Writers freigegeben wird, nicht
  synchron zu `stop()`. Der Doc-Comment von `finalizeCurrentFile()` behauptet
  mehr, als zutrifft. Verzögerung < 100 ms, nicht-deterministisch, auf
  `a5cc2e2` reproduziert — also **pre-existing**. Details in
  `docs/LIVE_AUDIO_PIPELINE.md`.

### A4 — Bewertungen einsammeln ◑
- ✅ Rating-Prompt erreichbar ohne Kauf (gespeicherte Aufnahme, Schnitt, Merge, Mix)
- ✅ Mit 1.1.0 erstmals live gegangen — davor hat die App nie gefragt.
- ✅ 1.1.1 ergänzt einen permanenten Eintrag **„Sprechly bewerten"** in den
  Einstellungen, für alle, die den automatischen Prompt weggetippt haben.
- ☐ **Beobachten:** Zahl und Durchschnitt der Bewertungen (siehe Messphase unten).

### A5 — Messphase nach 1.1.1 ☐

1.1.1 ändert Preis **und** Store-Auftritt gleichzeitig. Das ist bewusst so: Ziel
ist nicht ein sauber isolierter Preistest, sondern eine neue Baseline. Entsprechend
wird das Paket als Ganzes gemessen.

**Vergleich: 28 Tage vor vs. 28 Tage nach der Veröffentlichung.**

| Messgröße | Quelle |
|---|---|
| Impressionen | ASC → Analyse |
| Produktseitenaufrufe | ASC → Analyse |
| Downloads | ASC → Analyse |
| Käufe „Sprechly KI" | ASC → Umsatz |
| Conversion Download → Kauf | abgeleitet |
| **Erlös je Download** | abgeleitet — die eigentliche Zielgröße |
| Anzahl Bewertungen | ASC → Bewertungen |
| Durchschnittliche Bewertung | ASC → Bewertungen |
| Suchpositionen relevanter Keywords | manuell / ASO-Werkzeug |

**Zielbild:** nicht maximale Downloadzahl, sondern **höherer nachhaltiger Umsatz
bei weiterhin attraktiver Conversion**. Ein Rückgang der Käufe bei gleichzeitig
steigendem Erlös je Download ist ein Erfolg, kein Rückschritt.

**Wichtig für die Auswertung:** Der Vorher-Zeitraum muss vollständig *nach* dem
1.1.0-Release liegen, sonst vermischt er die alte und die neue Conversion.

---

## B. Danach — Features (jeweils separat freigeben)

Nach Wirkung auf Downloads sortiert, nicht nach Aufwand.

- ☐ **App Intents / Siri** — der einzige offene Punkt mit echtem Store-Argument
  („Hey Siri, nimm auf"); zahlt auf Sichtbarkeit und Systemintegration ein.
- ☐ **Geplante Aufnahme**, **VAD** (sprachaktiviert), **Bluetooth-Route-Wahl**
  — Nischenfunktionen für Bestandsnutzer.
- ☐ **Klingelton-Export** (.m4r) — klein, nett, ohne Conversion-Wirkung.
- ☐ **Voice Changer** — eigenes Spike-Projekt.
- ⏸ **Video-Aufnahme/-Mix** — bewusst in die Zukunft verschoben, kein
  Release-Ziel. Entitlement `.video` bleibt bundle-ready vorbereitet.

---

## C. Offen, aber unkritisch

- ☐ Anwaltliche Endprüfung der Rechtstexte (Vorlage ersetzt keine Rechtsberatung)
- ☐ EN-Korrekturlesen durch Muttersprachler
- ☐ Marketing-Website unter `https://www.gcng.de/sprechly/` deployen +
  Sitemap-Eintrag in der Root-`robots.txt` (Rene)
- ☐ Optional: finale Designer-Politur am App-Icon
- ☐ Ungetesteter Fehlerpfad: fehlschlagendes `modelContext.save()` in
  Editor/Merge/Mix ist behoben, aber ohne Protokoll-Injection nicht auslösbar
  und damit nicht durch einen Test abgedeckt

---

## Abgeschlossen

### 2026-10-04 — 1.1.1 Growth & Value (Branch, nicht eingereicht)
- ✅ **Store-Auftritt überarbeitet**: Name, Untertitel, Werbetext, Keywords und
  der Kopf der Beschreibung tragen jetzt den Einmalkauf und die On-Device-
  Verarbeitung; Zeichenlimits per Skript validiert.
- ✅ **Zwei falsche Marketingaussagen korrigiert**: Die Beschreibung bot Export
  „als M4A, AAC, WAV, AIFF, CAF" an, obwohl `ExportFormat` nur `m4a` und `wav`
  kennt; und sie versprach, die Stimme verlasse das Gerät nie, obwohl der
  iCloud-Sync **standardmäßig an** ist und die Audiodaten in die private iCloud
  des Nutzers lädt.
- ✅ **Sechs Store-Screenshots je Sprache** mit Überschrift und Unterzeile,
  Transkript zuerst; Aufnahme-Screenshot zeigt eine laufende Aufnahme statt
  00:00. Komposition über `scripts/compose_store_screenshots.py`.
- ✅ **„Sprechly bewerten"** als permanenter Eintrag in den Einstellungen.
- ◑ **Preis 9,99 €** vorbereitet, aber **aufgeschoben** (2026-10-05): nur Doku und lokale StoreKit-Testkonfiguration,
  der echte Preis bleibt eine manuelle ASC-Änderung.
- ✅ **A3 technisch analysiert** (`docs/TRANSCRIPTION_PIPELINE.md`), ohne Umbau.
- ◑ **WhisperScribe-Pro-Verweis** eingebaut, aber inaktiv: Die Store-ID steht in
  keinem der beiden Repositories, und ein geratener Link führt auf eine fremde
  App. Eintrag erscheint, sobald `SiblingApp.whisperScribeProID` gesetzt ist.

### 2026-08-19 — Monetarisierung, Bewertungen, Qualität
- ✅ **30-Sekunden-Vorschau statt Paywall-Wand** — ein gesperrter Lauf
  transkribiert die ersten 30 s und zeigt sie; nichts wird persistiert,
  exportiert oder KI-verarbeitet, und der Stream wird sauber abgebrochen.
- ✅ **Paywall zeigt das Ergebnis** — der eigene Vorschautext des Nutzers, sonst
  ein als „Beispiel" gekennzeichnetes Transkript samt KI-Zusammenfassung.
- ✅ **Rating-Prompt ohne Kauf erreichbar** — hing zuvor ausschließlich an
  gekauften Funktionen, damit für ~97 % der Nutzer unerreichbar.
- ✅ **Bug: Suchfeld unbenutzbar** — lag komplett hinter der Tab-Leiste
  (iOS 26 platziert `.searchable` unten); jetzt unter dem Titel verankert.
- ✅ **Bug: Transkript-Ende unlesbar** — die Detail-Spalte des
  `NavigationSplitView` erbt den Safe-Area-Inset der Tab-Leiste nicht; die
  Leiste veröffentlicht ihre gemessene Höhe jetzt über die Environment.
- ✅ **Bug: Speicher-Explosion beim iCloud-Abgleich** — der Reconciler lud bei
  jedem Start/Foreground/Remote-Change die gesamte Bibliothek in den RAM und
  hielt alle Blobs bis zu einem einzigen Save; jetzt gemappt und pro Aufnahme
  gespeichert. Erste Tests für beide Sync-Richtungen.
- ✅ **Bug: stiller Datenverlust** — Editor/Merge/Mix meldeten „gespeichert",
  obwohl `try?` den Speicherfehler verschluckte; jetzt mit Rollback von
  Datenbank-Eintrag **und** Datei.
- ✅ **Startbildschirm zeigt die USP** — Live-Transkript-Schalter (vorher in den
  Einstellungen vergraben) und Bestätigung mit Weg zur Bibliothek nach dem
  Stoppen (vorher: keinerlei Rückmeldung).
- ✅ Toter Code + letzte Compiler-Warnungen entfernt → **strict-concurrency clean**.
- ✅ 165 Tests grün.

### Früher
- ✅ **Phase 1** Aufnahme-Kern (Engine, Live-Wellenform, Wiedergabe, SwiftData, Bibliothek, Soft-Delete)
- ✅ **Phase 2** Editor (Trim), Merge, Mix, Speed/Gain, Multi-Format-Export
- ✅ **Schnitt-Editor** „Auswahl behalten/entfernen" + „Stille automatisch entfernen"
- ✅ **Phase 3** On-Device-Transkription (SpeechAnalyzer), Live-Transkript, Sprachmodell-Manager
- ✅ **KI** (Foundation Models): Zusammenfassung / Protokoll / Stichpunkte / Kernaussagen / Bereinigung, Titel, Chunking
- ✅ **Übersetzung** des Transkripts (on-device, persistiert, teilbar)
- ✅ **Diktiergerät-Aufnahme**: zurückspulen, anhören, ab Cursor überschreiben
- ✅ **Monetarisierung**: StoreKit 2, Kauf-only-Gating, Krönchen, pro Gerät verfügbare Features
- ✅ **iCloud-Voll-Sync** (Metadaten + Audio als Asset) + Sync-Status in Settings
- ✅ **iPad-Support** + adaptive Split-View + Top-Level-Sidebar auf Regular-Width
- ✅ **Externer Audio-Import** (Bibliothek + Mixer), **Live Activity / Dynamic Island**
- ✅ **Lokalisierung de/en** (String Catalogs), **App-Icon**, **Onboarding**, **Design-System**
- ✅ **Release 1.0.0**: Store-Texte, Screenshots, Preview-Video, Marketing-Website, Review-Notes, IAP in ASC, Sandbox-Kauf verifiziert
- ✅ **CI** (self-hosted Runner) grün
