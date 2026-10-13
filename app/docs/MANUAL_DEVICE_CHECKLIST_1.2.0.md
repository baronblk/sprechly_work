# Manuelle Gerätetests — Sprechly 1.2.0 (11)

## ✅ Alle Punkte bestanden (2026-10-05)

| Punkt | Gate | Status | Gerät |
|---|---|---|---|
| A | Share Sheet (`3e`) | ✅ PASS | iPhone 17 Pro, echte Aufnahme |
| B | Echter Erstkauf (`3b`) | ✅ PASS | iPhone 12 Pro, Release-Build |
| C | VoiceOver (`VO`) | ✅ PASS | Release-Build |
| D | Diktiergerät-Überschreiben (`DCT`) | ✅ PASS | Release-Build |
| E | Keine Debug-Sektion im Release-Build | ✅ PASS | am Artefakt verifiziert |

**Geräteseitig ist für 1.2.0 nichts mehr offen.** Die Schritte unten bleiben als
Vorlage für künftige Releases stehen.

Automatisierte Ergebnisse: `docs/benchmarks/2026-10-05-rc-device-preflight.md`.

**Vorbereitung** (einmal, macht der Agent per CLI):

```
xcodegen generate
DEV=00008150-000E43C40A63401C
xcodebuild -project VoxStudio.xcodeproj -scheme VoxStudio -destination "id=$DEV" \
  -derivedDataPath .derivedData -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=KZFCCDV6A8 CODE_SIGN_STYLE=Automatic build
xcrun devicectl device install app --device $DEV \
  .derivedData/Build/Products/Debug-iphoneos/VoxStudio.app
```

Dann die App **vom Homescreen** starten (nicht aus Xcode) — sonst greift die
StoreKit-Testkonfiguration und B misst nicht den echten Store.

Trage je Punkt PASS/FAIL plus Datum in `docs/DEVICE_TESTS.md` ein.

---

## A — Share Sheet (Gate 3e) — ✅ **PASS, 2026-10-05**

Von Rene auf dem Gerät durchgeführt, echte Aufnahme „Route zum Schneeberg"
(02:52). Beide Formate exportiert und in Dateien gespeichert: Umlaute korrekt,
UTF-8 korrekt, Zeitstempel und Zusammenfassung vorhanden, Markdown korrekt
strukturiert, **kein sichtbares `\letter`**. Die Schritte bleiben als Vorlage
für künftige Releases stehen.

Der Dateiinhalt ist bereits verifiziert; offen ist nur, ob sich das Share Sheet
öffnet und die Datei korrekt übergibt.

| # | Wohin tippen | Was du sehen musst |
|---|---|---|
| 1 | Tab **Bibliothek** → eine Aufnahme **mit Transkript** antippen | Transkript mit Zeitstempeln |
| 2 | **„Exportieren"** (Pfeil-nach-oben-Symbol) | Menü mit **„Text (.txt)"** und **„Markdown (.md)"** |
| 3 | **„Text (.txt)"** | iOS-Share-Sheet öffnet sich, Dateiname = Aufnahmetitel + `.txt` |
| 4 | **„In Dateien speichern"** → Ort wählen → **Speichern** | Datei liegt in Dateien |
| 5 | Datei in **Dateien** öffnen | Titel, Zeitstempel `[00:00]`, Umlaute korrekt (**kein** `Ã¼`), nirgends `\letter` |
| 6 | Schritte 2–5 mit **„Markdown (.md)"** | `#`-Titel, `**00:00**`-Zeitstempel, Umlaute korrekt |

**PASS:** Sheet öffnet sich bei beiden Formaten, beide Dateien landen lesbar mit
korrekten Umlauten und ohne `\letter`.
**FAIL:** Sheet öffnet nicht, falscher/leerer Dateiname, Mojibake (`Ã¤`, `Ã¼`),
oder `\letter` irgendwo im Text.

---

## E — Debug-Sektion darf im Release-Build fehlen

Der Debug-Build zeigt unter **Einstellungen → Debug** den Schalter
**„Premium im Test entsperren"**. Er ist in `SettingsView` mit `#if DEBUG`
geklammert, erscheint im Release-Build also nicht. Vor dem Archiv einmal am
echten Release-Build gegenprüfen.

| # | Wohin tippen | Was du sehen musst |
|---|---|---|
| 1 | Release-Build starten → **Einstellungen** | Abschnitte „Rechtliches", „Über", „Weitere Apps" |
| 2 | Ganz nach unten scrollen | **Kein** Abschnitt „Debug", **kein** Schalter „Premium im Test entsperren" |
| 3 | **Über → Version** | **1.2.0 (11)** |

**PASS:** Keine Debug-Sektion, Version stimmt.
**FAIL:** Debug-Sektion sichtbar — dann wurde ein Debug-Build installiert.

---

## B — Echter Kauf (Gate 3b) — ✅ **PASS, 2026-10-05**

Von Rene auf einem **iPhone 12 Pro** (`00008101-001A0C623E43003A`) mit dem
**Release-Build 1.2.0 (11)**, vom Homescreen gestartet. Das dort angemeldete
Konto besaß das Produkt noch nicht — es war damit ein **echter Erstkauf**, kein
Restore-Pfad:

- Produkt `de.gcng.sprechly.ai` geladen
- Preis **6,99 €** korrekt angezeigt
- Kauf erfolgreich abgeschlossen
- Premium unmittelbar freigeschaltet

Das iPhone 17 Pro war dafür ungeeignet: dessen Konto hielt das Entitlement
bereits (`currentEntitlements` enthielt es), dort wäre nur Restore prüfbar
gewesen. Die Schritte bleiben als Vorlage für künftige Releases stehen.

Verifiziert ist: das Produkt lädt aus dem echten Store, `de.gcng.sprechly.ai`,
Non-Consumable, Preis **6,99 €** dynamisch aus StoreKit, kein Preis im Code.

⚠️ **Nur mit dem Release-/RC-Build testen.** Der Debug-Build simuliert den Kauf
über „Premium im Test entsperren" und ist deshalb für dieses Gate ungeeignet.

⚠️ **Dieses Gerät besitzt das Produkt bereits** (`currentEntitlements` enthält
es). Ein *neuer* Kauf braucht deshalb einen **Sandbox-Tester**:
Einstellungen → App Store → **Sandbox-Account** → Sandbox-Tester anmelden.
Diesen Schritt muss ich dir überlassen — Zugangsdaten eingeben ist mir nicht
erlaubt.

| # | Wohin tippen | Was du sehen musst |
|---|---|---|
| 1 | Mit Sandbox-Tester angemeldet, App starten, Aufnahme → **Transkript** | Button **„30 Sekunden gratis testen"** (= gesperrt) |
| 2 | Antippen, Vorschau abwarten | Echtes Transkript der ersten 30 s, dann „Vorschau endet hier" |
| 3 | **„Vollständig freischalten"** | Paywall, Button **„Freischalten"** mit Preis **fett daneben** |
| 4 | Preis prüfen | Zahl kommt vom Store: **6,99 €**. Die Anhebung auf 9,99 € ist aufgeschoben (2026-10-05), siehe `MONETIZATION.md` |
| 5 | **„Freischalten"** → Sandbox-Kaufdialog bestätigen | „[Environment: Sandbox]"-Hinweis im Dialog |
| 6 | Nach dem Kauf | Paywall schließt sich, Transkript läuft in **voller Länge** |
| 7 | KI-Bereich → **„Erstellen"** | Titel + Zusammenfassung erscheinen |
| 8 | App löschen, neu installieren, Transkript öffnen → Paywall → **„Käufe wiederherstellen"** | Zugang ist **ohne** erneute Zahlung wieder da |

**PASS:** Preis kommt dynamisch, Kauf schließt ab, Entitlement greift sofort,
Restore stellt ihn nach Neuinstallation wieder her.
**FAIL:** Paywall ohne Produkt/Preis, Endlos-Spinner, Kauf ohne Freischaltung,
oder Restore ohne Wirkung.

---

## C — VoiceOver (`VO`) — ✅ **PASS, 2026-10-05**

Von Rene auf dem Release-Build geprüft. Der Punkt war seit dem Phase-2-Go als
**Release-Blocker** im Repository geführt und wurde hier zum ersten Mal auf
echter Hardware durchlaufen — damit ist er geschlossen.

Im Repo seit dem Phase-2-Go offen und dort ausdrücklich als Release-Blocker
geführt. Von 1.2 nicht verändert, aber nie auf Gerät geprüft.

VoiceOver einschalten: Einstellungen → Bedienungshilfen → VoiceOver → Ein
(oder 3× Seitentaste, wenn als Kurzbefehl gesetzt). Navigation: nach rechts
streichen = nächstes Element, Doppeltipp = aktivieren.

| # | Bildschirm | Was VoiceOver ansagen muss |
|---|---|---|
| 1 | **Aufnahme** (leer) | Aufnahme-Button, **„Live-Transkript"**-Schalter mit Zustand, **„Einstellungen"** |
| 2 | Aufnahme läuft | **„Aufnahmedauer"** mit Wert, **„Pegel"**, **„Pausieren"** |
| 3 | Pausiert | **„10 Sekunden zurück"**, **„Anhören"**, **„10 Sekunden vor"** — jedes einzeln erreichbar |
| 4 | Wellenform | Eine sinnvolle Zusammenfassung, **kein** „Bild"/„unbeschriftet" |
| 5 | **Bibliothek** | Jede Aufnahme mit Titel, Dauer und Datum; Suchfeld erreichbar |
| 6 | **Wiedergabe** | Play/Pause mit Zustand, Position, Geschwindigkeit |
| 7 | **Transkript** | Segmente mit Zeitstempel; **„Exportieren"** erreichbar |
| 8 | **Paywall** | Produktname, Preis, **„Freischalten"**, **„Käufe wiederherstellen"** |

**PASS:** Jedes interaktive Element ist per Streichen erreichbar und wird
sinnvoll benannt; Zustände (ein/aus, läuft/pausiert) werden angesagt.
**FAIL:** „unbeschriftet", „Bild", übersprungene Buttons, oder ein Schalter
ohne Zustandsansage.

**VoiceOver danach wieder ausschalten**, sonst sind die anderen Punkte mühsam.

---

## D — Diktiergerät-Überschreiben (`DCT`) — ✅ **PASS, 2026-10-05**

Von Rene auf dem Release-Build geprüft. Der Audiopfad war bis dahin nur über
ViewModel-Unit-Tests abgedeckt; von 1.2 nicht verändert, auf deine Vorgabe hin
einmal manuell bestätigt.

ViewModel-Logik ist unit-getestet, der Audiopfad auf Gerät nicht. Von 1.2 nicht
verändert; du wolltest es vor Release einmal manuell sehen.

**Wichtig zur UI:** Es gibt keinen Button „Überarbeiten" — **Pause schaltet
direkt in den Überarbeitungsmodus** (`pause()` → Review-State). Die
Transport-Reihe erscheint dann unter der Wellenform.

| # | Wohin tippen | Was du sehen/hören musst |
|---|---|---|
| 1 | **Aufnahme** → Record, ca. 20 s sprechen (zähle „eins, zwei, … zwanzig") | Laufende Dauer, Pegel bewegt sich |
| 2 | **Pausieren** | Transport erscheint: ⏪10, ▶︎, ⏩10 und darunter Record + Stop |
| 3 | **⏪ 10 Sekunden zurück** 1× | Cursor springt auf ≈ 10 s |
| 4 | **▶︎ Anhören** | Wiedergabe **ab Cursor**, nicht von vorn |
| 5 | Auf der **Wellenform** auf ca. 10 s ziehen | Cursor folgt dem Finger |
| 6 | **Record** (links der Stop-Taste) | Aufnahme läuft **ab Cursor** weiter und überschreibt den Rest |
| 7 | Deutlich etwas anderes sagen, ca. 10 s | — |
| 8 | **Stop** | „Aufnahme gespeichert" |
| 9 | Bibliothek → Take abspielen | Erste ~10 s original, danach **ohne Knacken** der neue Teil; Gesamtdauer ≈ 20 s, **nicht** 30 s |
| 10 | Schritte 2–8 im **selben** Take ein zweites Mal | Mehrfaches Überschreiben funktioniert, Dauer bleibt plausibel |

**PASS:** Überschreiben setzt am Cursor an, die Naht ist hörbar lückenlos, die
Dauer entspricht der tatsächlich aufgenommenen Zeit, mehrfaches Überschreiben
hält.
**FAIL:** Knacken/Lücke an der Naht, Dauer zählt verworfenes Audio mit, Cursor
wird ignoriert, oder der zweite Durchgang bricht.
