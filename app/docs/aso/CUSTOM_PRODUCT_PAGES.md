# Benutzerdefinierte Produktseiten — Spezifikation

Drei Seiten, vorbereitet, **nicht angelegt**. Begründung und Traffic-Vorbehalt
in `docs/aso/APP_STORE_OPTIMIZATION.md`, Abschnitt 4.

Gemeinsame Regeln für alle drei:

- **Die Hauptseite bleibt unverändert.** Eine CPP ersetzt nichts, sie ergänzt.
- Pro Seite dürfen Screenshots, App-Preview und Werbetext abweichen —
  **Name, Untertitel, Beschreibung, Keywords und Preis nicht.**
- Jede Seite braucht **eigene Screenshots je Sprache und Gerätegröße**, sonst
  erbt sie die der Hauptseite.
- Alle Assets gehen durch die App-Review, bevor die Seite erreichbar ist.
- Maximal 35 Seiten je App — die Zahl ist hier keine Grenze.

---

## URL- und Deep-Link-Konzept

Eine CPP hat **zwei** Wege zu Besuchern, und sie unterscheiden sich stark:

1. **Über ihre eigene URL** — beworben in Beiträgen, Newslettern, Anzeigen.
2. **Über zugewiesene Suchbegriffe** — Apple kann die CPP bei genau diesen
   Begriffen **anstelle der Standard-Produktseite** in den Suchergebnissen
   ausspielen. Zuweisbar sind nur Keywords der zuletzt genehmigten App-Version.

Für `cpp-meetings` und `cpp-dictation` ist der zweite Weg aktiv; sie bekommen
Sichtbarkeit auch ohne eine einzige beworbene URL. **`cpp-privacy` nicht** — zur
Datenschutz-Positionierung existiert derzeit kein passendes Keyword im
genehmigten Bestand, deshalb ist diese Seite zunächst vollständig auf direkte
URL- und Kampagnenzugriffe angewiesen. Das Schließen dieser Lücke steht als
Punkt 1 in `docs/aso/NEXT_RELEASE_CHECKLIST.md`.

App Store Connect vergibt die URL beim Anlegen:

```
https://apps.apple.com/app/id6782676748?ppid=<PRODUCT_PAGE_ID>
```

`ppid` ist eine von Apple vergebene UUID; sie lässt sich nicht frei wählen und
steht erst nach dem Anlegen fest.

**Kampagnenzuordnung** über zusätzliche Parameter, die Apple in den
Analytics-Berichten ausweist:

```
?ppid=<ID>&pt=<provider>&ct=<campaign>&mt=8

cpp-privacy    → ct=privacy-reddit     / privacy-mastodon
cpp-meetings   → ct=meetings-linkedin  / meetings-newsletter
cpp-dictation  → ct=dictation-forum
```

`ct` ist frei wählbar und sollte **pro Beitrag** variieren, nicht nur pro
Seite — sonst lässt sich später nicht trennen, welcher Beitrag getragen hat.
Die Beitragsentwürfe auf dem Branch `docs/marketing` sind die vorgesehene
Quelle dieser Links.

**Ablage der fertigen URLs:** nach dem Anlegen hier ergänzen, damit die
Beiträge nicht aus ASC abgeschrieben werden müssen.

| Seite | ppid | Status |
|---|---|---|
| cpp-privacy | `52ab5655-e92e-433f-9d92-127e09becd50` | eingereicht 2026-10-11, `WAITING_FOR_REVIEW` |
| cpp-meetings | `781e098a-cbe5-4a48-bed5-89b2b33835e4` | eingereicht 2026-10-11, `WAITING_FOR_REVIEW` |
| cpp-dictation | `259b8075-4ef3-4545-bbe7-79af008ae442` | eingereicht 2026-10-11, `WAITING_FOR_REVIEW` |

### Keywords: der Mechanismus und seine Grenze

Apple stellt den zuweisbaren Keyword-Vorrat über
`GET /v1/apps/{id}/searchKeywords?filter[locale]=…&filter[platform]=IOS`
bereit — Typ `appKeywords`, die ID ist das Schlagwort selbst. Das sind genau die
Keywords der zuletzt genehmigten App-Version: 10 für de-DE, 13 für en-US.

**Die Zuweisung selbst ist in der v1-API nicht abgebildet, wohl aber in der
Weboberfläche** — dort steht sie je Seite und Sprache als Checkbox-Liste unter
„Schlüsselwörter (optional)".
`appKeywords` hat keine Attribute und laut API „no allowed operations"; zwischen
`appCustomProductPages`/`appCustomProductPageVersions` und den Keywords
existiert in keiner Richtung eine Beziehung, und der searchKeywords-Endpunkt
nimmt weder `include` noch einen CPP-Filter.

**Gesetzt am 2026-10-11** über die Weboberfläche, je Seite und Sprache
gegengelesen:

| Seite | de-DE | en-US |
|---|---|---|
| cpp-meetings | meeting, protokoll, zusammenfassung, interview | meeting, minutes, summary, interview, notes |
| cpp-dictation | sprachmemo, transkribieren, aufnahme, recorder, sprache | memo, dictation, transcribe, record, speech, audio |
| cpp-privacy | — | — |

Die Keyword-Sets von Meetings und Diktat überschneiden sich nicht. Die Keywords
der **Hauptseite** blieben unverändert (de-DE 100, en-US 98 Zeichen).

**Lücke im Keyword-Bestand:** Für die Privacy-Positionierung existiert
derzeit **kein passendes Keyword** — weder „offline", „lokal", „privat",
„datenschutz" noch „ohne konto". cpp-privacy kann deshalb keine sinnvolle
Zuweisung bekommen. Das gehört in ein künftiges Keyword-Update der
**Hauptseite**; erst danach steht der Begriff auch für eine CPP zur Verfügung.

---

## cpp-privacy — „Bleibt auf deinem Gerät"

| | |
|---|---|
| Zielgruppe | Datenschutzbewusste; Betriebsräte, Journalisten, Ärzte, Anwälte, Therapeuten |
| Kanal | Datenschutz-Communities, Mastodon, einschlägige Subreddits |
| Kernbotschaft | Transkription und KI laufen auf dem Gerät — nichts geht an einen fremden Server |

### Copy

**Werbetext DE** (max. 170):
> Transkription und KI laufen vollständig auf deinem iPhone. Kein Konto, kein
> Abo, keine fremden Server. iCloud-Sync ist optional und nutzt deine eigene
> private iCloud.

**Werbetext EN** (max. 170):
> Transcription and AI run entirely on your iPhone. No account, no
> subscription, no third-party servers. iCloud sync is optional and uses your
> own private iCloud.

**Diese Formulierung ist bewusst so gewählt.** Die frühere Store-Aussage „die
Stimme verlässt nie dein Gerät" war falsch, weil iCloud-Sync standardmäßig
aktiv ist und Audio in die private iCloud des Nutzers lädt. Der Satz wurde mit
1.1.1 korrigiert; diese Seite darf ihn nicht wieder einführen.

### Screenshot-Reihenfolge

| # | Motiv | Caption DE | Caption EN |
|---|---|---|---|
| 1 | `03-usp` | Kein Abo. Kein Konto. | No subscription. No account. |
| 2 | neues Hero `01-transcript` | Sprich. Sprechly schreibt mit. | Speak. Sprechly writes it down. |
| 3 | **neu:** Einstellungen mit iCloud-Schalter | Du entscheidest, was synchronisiert | You decide what syncs |
| 4 | `02-summary` | Zusammenfassung auf dem Gerät | Summaries on your device |
| 5 | `05-edit` | Export als TXT oder Markdown | Export as TXT or Markdown |

**Asset 3 fehlt noch** — Spezifikation unten.

---

## cpp-meetings — „Das Protokoll schreibt sich selbst"

| | |
|---|---|
| Zielgruppe | Projektleitung, Beratung, Teams mit vielen Terminen |
| Kanal | LinkedIn, Produktivitäts-Newsletter, Fach-Communities |
| Kernbotschaft | Aus 30 Minuten Besprechung werden fünf Zeilen Protokoll |

### Copy

**Werbetext DE:**
> Nimm die Besprechung auf und erhalte Transkript, Zusammenfassung und
> Protokoll. Einmal kaufen, kein Abo.

**Werbetext EN:**
> Record the meeting and get a transcript, a summary and minutes. Buy once, no
> subscription.

### Screenshot-Reihenfolge

Bewusst mit der KI-Zusammenfassung zuerst — also genau dem, was die Hauptseite
**nicht** zuerst zeigen soll, weil sie ein breiteres Publikum anspricht.

| # | Motiv | Caption DE | Caption EN |
|---|---|---|---|
| 1 | `02-summary` | Aus 30 Minuten werden 5 Zeilen | 30 minutes become 5 lines |
| 2 | neues Hero `01-transcript` | Jede Aussage mit Zeitstempel | Every line with a timestamp |
| 3 | **neu:** Export-Share-Sheet | Protokoll als Markdown teilen | Share minutes as Markdown |
| 4 | `06-library` | Alle Termine, sofort gefunden | Every meeting, found instantly |
| 5 | `03-usp` | Kein Abo. Kein Konto. | No subscription. No account. |

**Asset 3 fehlt noch** — Spezifikation unten.

---

## cpp-dictation — „Einfach drüber sprechen"

| | |
|---|---|
| Zielgruppe | Vielsprecher: Außendienst, Handwerk, Pflege, Autoren |
| Kanal | Branchenforen, Fachgruppen |
| Kernbotschaft | Aufnehmen, Versprecher überschreiben, fertig — ohne Nachbearbeitung |

### Copy

**Werbetext DE:**
> Versprochen? Zurückspulen und einfach drüber sprechen. Ohne Schnittprogramm,
> ohne Abo.

**Werbetext EN:**
> Misspoke? Rewind and simply record over it. No editing app, no subscription.

### Screenshot-Reihenfolge

| # | Motiv | Caption DE | Caption EN |
|---|---|---|---|
| 1 | `04-record` | Versprecher? Einfach überschreiben | Misspoke? Just record over it |
| 2 | neues Hero `01-transcript` | Sprich. Sprechly schreibt mit. | Speak. Sprechly writes it down. |
| 3 | `06-library` | Alle Aufnahmen, sofort gefunden | Every recording, found instantly |
| 4 | `05-edit` | Schneiden, mischen, exportieren | Cut, mix, export |
| 5 | `03-usp` | Kein Abo. Kein Konto. | No subscription. No account. |

Nutzt ausschließlich vorhandene Motive — diese Seite ist ohne neue Assets
umsetzbar, sobald das neue Hero steht.

---

## Fehlende Assets

### `settings-icloud` — für cpp-privacy

| | |
|---|---|
| Zweck | Zeigt, dass Synchronisierung eine Entscheidung des Nutzers ist |
| Screen | Einstellungen, Abschnitt mit dem iCloud-Sync-Schalter sichtbar |
| Aufnahme | Simulator, `SEED_DEMO`, Flow um einen Schritt „Einstellungen öffnen" erweitern |
| Dateiname | `03-privacy.png` im jeweiligen Sprach-/Geräteordner |
| Achtung | Kein Debug-Abschnitt im Bild — der erscheint nur in Debug-Builds und müsste weggescrollt oder im Release-Build aufgenommen werden |

### `export-share` — für cpp-meetings

| | |
|---|---|
| Zweck | Belegt den Export, der sonst nur behauptet wird |
| Screen | Transkript → „Exportieren" → geöffnetes Menü mit „Text (.txt)" und „Markdown (.md)" |
| Aufnahme | Simulator; das **System-Share-Sheet** selbst ist nicht zuverlässig aufnehmbar, deshalb das Exportmenü der App zeigen, nicht das Sheet |
| Dateiname | `03-export.png` |

Beide sind **nicht erstellt**. Sie werden erst gebraucht, wenn die jeweilige
Seite tatsächlich angelegt wird.
