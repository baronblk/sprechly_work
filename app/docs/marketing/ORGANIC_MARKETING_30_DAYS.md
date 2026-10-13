# Sprechly — Organic Marketing, 30-Tage-Plan

Stand: 2026-10-04 · Texte: [ORGANIC_POST_LIBRARY.md](ORGANIC_POST_LIBRARY.md) · Regeln: [COMMUNITY_CHECKLIST.md](COMMUNITY_CHECKLIST.md) · Strategie: [ORGANIC_MARKETING_PACKAGE.md](ORGANIC_MARKETING_PACKAGE.md)

Dieser Plan ist eine Vorlage zum Abarbeiten. Nichts wird automatisch veröffentlicht. Rene postet jeden Beitrag selbst, in eigenen Worten, und trägt Status und Ergebnis ein.

## Startbedingungen (Tag 0)

Der Plan beginnt erst, wenn diese Punkte erledigt sind. Tag 1 ist der erste **Dienstag** danach. Die Wochentage im Plan hängen daran, weil r/apple Entwicklerbeiträge nur sonntags und r/iOSProgramming nur samstags zulässt.

- [ ] **1.1.1 ist im Store.** Am 2026-10-04 war 1.1.0 live. Laut `docs/ROADMAP.md` enthält die Live-Beschreibung noch zwei falsche Aussagen (Exportformate, „Stimme verlässt das Gerät nicht“). Eine Kampagne, die auf Genauigkeit setzt, darf nicht auf diese Seite führen.
- [ ] **Der Preis steht fest und ist im Store sichtbar.** Live: 6,99 €. Geplant mit 1.1.1: 9,99 €. `[PREIS]` in den Texten erst danach ersetzen. Eine Preisänderung mitten im Plan macht Beiträge falsch, die schon draußen sind.
- [ ] **Die Landingpage ist korrigiert oder wird nicht verlinkt.** `docs/html/index.html` nennt noch 6,99 €, „Aufnahme & Transkription gratis“, „deine Stimme verlässt das Gerät nicht“ und „AIFF“. `https://www.gcng.de/sprechly/` lief am 2026-10-04 in eine Weiterleitungsschleife. Alle Texte verlinken deshalb den App Store.
- [ ] **Kampagnenlinks sind erzeugt** (App Store Connect → Analyse → Akquise → Kampagnen). Siehe „Messung“.
- [ ] **Community-Regeln sind im Browser gelesen** und in der Checkliste abgehakt. Für Reddit ist das Pflicht, dort wurde nichts im Original gelesen.
- [ ] **Flugmodus-Test gemacht:** Sprachmodell laden, Flugmodus an, transkribieren. Mehrere Texte verweisen darauf.
- [ ] **Die Vorschau ist für Nichtkäufer erreichbar.** Auf einem Gerät ohne Kauf prüfen, ob „30 Sekunden gratis testen“ erscheint, auch wenn noch kein Sprachmodell geladen ist. Im Code ist der Eintrag „Sprachmodelle“ in den Einstellungen nur nach dem Kauf sichtbar (`SettingsView.swift`), und ohne geladenes Modell zeigt der Transkript-Bildschirm keinen Vorschau-Knopf (`TranscriptView.swift`). Die 30-Sekunden-Vorschau ist das zentrale Versprechen der Kampagne.
- [ ] **Die vier Lücken `‹…›` in der Library sind gefüllt oder gestrichen.**

## Regeln für die 30 Tage

- Höchstens ein Hauptbeitrag am Tag. Vier Tage sind bewusst frei.
- Nie an zwei Tagen hintereinander dieselbe Plattform.
- Kein Text erscheint in zwei Communities. Jeder Eintrag hat seine eigene Variante.
- Reddit nur, wenn die Regel am Tag des Postens im Original gelesen ist und passt. Sonst entfällt der Tag ersatzlos.
- Nach jedem Beitrag am selben Tag für Antworten da sein. Ein Beitrag ohne Antworten des Autors wirkt wie abgeladene Werbung.
- Keine Bitte um Upvotes, Boosts oder Bewertungen an Freunde. Keine Direktnachrichten.
- In jedem Beitrag mit Link steht, dass Rene der Entwickler ist.

## Plan

Spalte „Link“: **Kampagne** = App-Store-Link mit `pt`/`ct`, **einfach** = Link ohne Parameter, **–** = Beitrag ohne Link. Spalte „Status“: offen / gepostet / entfallen.

| Tag | Plattform | Zielgruppe | Thema | Hook | Textvariante | CTA | Link | Status | Ergebnis später |
|---|---|---|---|---|---|---|---|---|---|
| 1 (Di) | Mastodon, deutsch | Apple-Nutzer, Abo-Müde | Vorstellung | „Ich bin Rene und entwickle allein Sprechly“ | MA-DE-01 | App Store | einfach | offen | |
| 2 (Mi) | LinkedIn, deutsch | Selbstständige, kleine Unternehmen | Produktvorstellung | „Auf zwei Dinge … habe ich verzichtet: das Abo und das Benutzerkonto“ | LI-DE-1 | App Store, Feedback zur Transkription | Kampagne `linkedin` | offen | |
| 3 (Do) | Bluesky, englisch | Apple users, subscription-fatigued | Introduction | "I built a voice recorder for iPhone that transcribes on the device" | BS-EN-01 | App Store | einfach | offen | |
| 4 (Fr) | Sir-Apfelot-Forum | Deutschsprachige Apple-Nutzer | App-Vorstellung nach Fragenkatalog | „Sprechly. Ich bin der Entwickler und arbeite allein daran.“ | FO-DE-2 | App Store, Rückmeldung | einfach | offen | |
| 5 (Sa) | – | – | Antworten auf Tag 1–4 | – | – | – | – | – | |
| 6 (So) | Reddit r/apple *(Regel live prüfen)* | Apple-Nutzer | Entwickler-Post am Sonntag | "I built a voice recorder that transcribes on-device" | RD-L1 | App Store, Feedback | Kampagne `reddit` | offen | |
| 7 (Mo) | – | – | Antworten, Zwischenstand notieren | – | – | – | – | – | |
| 8 (Di) | Mastodon, englisch | iOS developers | SpeechAnalyzer: Zeitstempel | "Don't set bufferStartTime yourself" | MA-EN-06 | Austausch | – | offen | |
| 9 (Mi) | LinkedIn, deutsch | Datenschutzbewusste, IT-Verantwortliche | Korrektur der eigenen Datenschutzaussage | „In meiner App-Beschreibung stand ein Satz, der nicht stimmte“ | LI-DE-3 | Diskussion | Kampagne `linkedin` | offen | |
| 10 (Do) | Hacker News | Entwickler | Show HN | Titel aus HN-1 | HN-1, **selbst formuliert** | Feedbackfrage zu `contextualStrings` | einfach | offen | |
| 11 (Fr) | Bluesky, deutsch | Diktierende | Versprecher überschreiben | „Versprecher? Zurückspulen, reinhören, ab dem Cursor neu aufnehmen“ | BS-DE-04 | App Store | einfach | offen | |
| 12 (Sa) | Reddit r/iOSProgramming *(Regel live prüfen)* | iOS-Entwickler | Acht technische Befunde | "Eight things that broke" | RD-L3 | Austausch | Kampagne `reddit` | offen | |
| 13 (So) | macuser.de, „App Review, Promotion“ | Deutschsprachige Apple-Nutzer | Sachliche Vorstellung | „Vorstellung durch den Entwickler“ | FO-DE-1 | App Store, Rückmeldung | einfach | offen | |
| 14 (Mo) | – | – | Antworten, Zwischenstand notieren | – | – | – | – | – | |
| 15 (Di) | LinkedIn, deutsch | Abo-Müde, Selbstständige | Warum kein Abo | „Weil ich keine Rechnung bekomme, wenn jemand sie benutzt“ | LI-DE-4 | Meinung zum Preismodell | Kampagne `linkedin` | offen | |
| 16 (Mi) | Reddit r/SideProject *(Regel live prüfen)* | Side-Project-Community | Zahlen und Fehler | "128 downloads and 4 sales in its first two months" | RD-L2 | Feedback zur Store-Seite | Kampagne `reddit` | offen | |
| 17 (Do) | Mastodon, deutsch | Studierende | Vorlesung wiederfinden | „Vorlesung aufgenommen und die eine Erklärung nicht wiedergefunden?“ | MA-DE-06 | App Store | einfach | offen | |
| 18 (Fr) | Indie Hackers *(Regel prüfen)* | Indie Hacker | Vorschau statt Bezahlschranke | "A hard paywall got me 4 sales from 128 downloads" | IH-3 | Erfahrungen | Kampagne `indiehackers` | offen | |
| 19 (Sa) | MacRumors, „iOS Apps and Apple Arcade“ | Englischsprachige Apple-Nutzer | Sachliche Vorstellung | "Posted by the developer" | FO-EN-1 | App Store, Rückmeldung | Kampagne `macrumors` | offen | |
| 20 (So) | Bluesky, englisch (Thread) | iOS developers | Acht Befunde als Thread | "Eight things broke on the way" | BS-T2 | Austausch | einfach | offen | |
| 21 (Mo) | – | – | Antworten, Zwischenstand notieren | – | – | – | – | – | |
| 22 (Di) | Reddit r/indiehackers *(Regel live prüfen)* | Indie Hacker | Preisfrage | "One-time purchase instead of a subscription" | RD-L4 | Kritik am Preismodell | Kampagne `reddit` | offen | |
| 23 (Mi) | LinkedIn, englisch | Journalists, interviewers | Transkriptionsqualität | "As good as Apple's model, and I can't change that" | LI-EN-2 | Eigene Erfahrungen | Kampagne `linkedin` | offen | |
| 24 (Do) | Mastodon, deutsch | Datenschutzbewusste | Datenschutz, genau gesagt | „Und der Teil, den ich nicht verschweige“ | MA-DE-03 | Nachfragen | – | offen | |
| 25 (Fr) | Reddit r/StartupDACH *(Regel live prüfen)* | Selbstständige, Gründer | Einmalkauf, Zahlen | „Meine Zahlen nach den ersten zwei Monaten“ | RD-L5 | Fachlicher Austausch | Kampagne `reddit` | offen | |
| 26 (Sa) | Bluesky, deutsch | Meeting-Nutzer | Besprechung zu Protokoll | „Aus 30 Minuten Besprechung werden 5 Zeilen“ | BS-DE-06 | App Store | einfach | offen | |
| 27 (So) | Mastodon, englisch | iOS developers | AVAudioEngine und Route-Wechsel | "installTap(format: nil) resolves the format once" | MA-EN-07 | Austausch | – | offen | |
| 28 (Mo) | LinkedIn, deutsch | Entwickler, Netzwerk | Indie-Bilanz | „128 Downloads, 4 Käufe, 0 Bewertungen“ | LI-DE-5 | Erfahrungsaustausch | Kampagne `linkedin` | offen | |
| 29 (Di) | Indie Hackers *(Regel prüfen)* | App-Entwickler | ASO-Erkenntnisse | "Only 2.2% of my App Store impressions became page views" | IH-4 | ASO-Erfahrungen | Kampagne `indiehackers` | offen | |
| 30 (Mi) | Mastodon, deutsch | Alle Nutzer von Spracherkennung | Frage in die Runde, danach Auswertung | „Welche Wörter gehen bei euch regelmäßig schief?“ | MA-DE-15 | Antworten | – | offen | |

**Verteilung:** 26 Beiträge in 30 Tagen. Mastodon 6, LinkedIn 5, Reddit 5 (fünf verschiedene Subreddits), Bluesky 4, Foren 3, Indie Hackers 2, Hacker News 1.

**Reserve**, falls ein Reddit-Tag entfällt: MA-DE-08 (Meeting), MA-DE-12 (Korrektur der Store-Beschreibung), LI-EN-4 (dieselbe Geschichte auf Englisch), BS-DE-07 (Bewertungs-Fehler), ein Kurzpost aus den Säulen P05 (Interviews) oder P11 (Produktivität). Weitere Reddit-Kandidaten nach Regelprüfung: RD-S7 für r/studytips, RD-S8 für den Wochen-Thread in r/podcasting, RD-S3 für r/iosapps.

**Hinweis zu r/apple:** „Sonntag“ meint dort die kalifornische Zeit. Sonntagnachmittag oder -abend deutscher Zeit liegt sicher im Fenster.

**Hinweis zu RD-L4, RD-L5, RD-S5, IH-2 und IH-4:** Diese Texte nennen die Preisänderung von 6,99 € auf 9,99 € in der Vergangenheitsform. Nur verwenden, wenn sie so umgesetzt ist. Sonst den Absatz streichen.

**Wiederholungen:** Die Geschichte „128 Downloads, 4 Käufe“ erscheint an den Tagen 16, 18, 22, 25 und 28, jedes Mal auf einer anderen Plattform und mit anderem Schwerpunkt (Fehler, Vorschau, Preis, Zahlen, Bilanz). Die Korrektur der Store-Beschreibung erscheint nur an Tag 9. Wer in Woche 4 den Eindruck hat, sich zu wiederholen, ersetzt Tag 25 oder Tag 28 durch einen Text aus der Reserve.

## Messung ohne Nutzertracking

Die App bleibt, wie sie ist: kein Analyse-SDK, keine Code-Änderung. Gemessen wird ausschließlich in App Store Connect.

### Was gemessen wird

| Messgröße | Quelle |
|---|---|
| Impressionen | App Store Connect → Analyse |
| Produktseitenaufrufe | App Store Connect → Analyse |
| Erst-Downloads | App Store Connect → Analyse |
| Käufe „Sprechly KI“ | App Store Connect → Umsatz |
| Conversion Seitenaufruf → Download | abgeleitet |
| Conversion Download → Kauf | abgeleitet |
| Erlös je Download | abgeleitet |
| Anzahl und Durchschnitt der Bewertungen | App Store Connect → Bewertungen |
| Herkunft: Web-Referrer, App-Referrer | App Store Connect → Analyse → Akquise → Quellen |
| Kampagnen | App Store Connect → Analyse → Akquise → Kampagnen |

### Kampagnenlinks von Apple

Apple bietet eine Zuordnung an, die ohne Daten einzelner Nutzer auskommt. Das Format lautet:

```
https://apps.apple.com/app/apple-store/id6782676748?pt=[PT]&ct=[KAMPAGNE]&mt=8
```

- `pt` ist das Provider-Token des Entwicklerkontos. Es lässt sich nicht von Hand bilden. Es entsteht, wenn in App Store Connect der erste Kampagnenlink erzeugt wird. Bis dahin steht hier `[PT]`.
- `ct` benennt die Kampagne, höchstens 30 Zeichen.
- Eine Kampagne erscheint erst, wenn mindestens **fünf** Personen darüber erstmals geladen haben, und frühestens 24 Stunden nach dem Start. Gezählt wird ein Download innerhalb von 24 Stunden nach dem Tipp auf den Link.

Bei 128 Downloads in den ersten zwei Monaten heißt das: Ein Link pro Beitrag bliebe fast immer unter der Schwelle und zeigte nichts. Deshalb gibt es **eine Kampagne je Plattform**:

| `ct` | Verwendet in |
|---|---|
| `reddit` | allen Reddit-Beiträgen |
| `linkedin` | allen LinkedIn-Beiträgen |
| `indiehackers` | Indie Hackers |
| `macrumors` | MacRumors |

**Einfacher Link ohne Parameter** auf Mastodon, Bluesky, Hacker News, macuser.de, Sir Apfelot und Apfeltalk. Die Gründe: macuser.de und Apfeltalk untersagen Ref-Links ausdrücklich. Auf Bluesky sprengt der lange Kampagnenlink das Limit von 300 Zeichen, auf das die Texte ausgelegt sind. Und vor einem Publikum, dem man „kein Tracking“ verspricht, wirkt ein Link mit Kampagnenparametern widersprüchlich, auch wenn Apple nur Summen ausweist. Dort bleibt die Auswertung über die Web-Referrer und den zeitlichen Zusammenhang.

Wer in einer Community nach den Parametern gefragt wird, erklärt sie: Apple zählt damit Downloads je Kampagne, ohne dass der Entwickler einzelne Personen sieht.

### Wochenprotokoll

Jeden Montag (Tag 7, 14, 21, 28) und am Tag 30 eintragen. Die erste Zeile ist die Ausgangslage aus den 28 Tagen vor Tag 1.

| Zeitraum | Impressionen | Seitenaufrufe | Erst-Downloads | Käufe | Erlös | Bewertungen (Anzahl / Schnitt) | Auffälligkeiten |
|---|---|---|---|---|---|---|---|
| 28 Tage vor Tag 1 | | | | | | | |
| Tag 1–7 | | | | | | | |
| Tag 8–14 | | | | | | | |
| Tag 15–21 | | | | | | | |
| Tag 22–28 | | | | | | | |
| Tag 1–30 gesamt | | | | | | | |

### Wie die Zahlen zu lesen sind

- Die Kampagne fällt mit 1.1.1 zusammen, also mit neuem Store-Auftritt und möglicherweise neuem Preis. `docs/ROADMAP.md` (A5) plant dafür einen Vergleich von 28 Tagen davor und danach. Die Kampagne macht diesen Vergleich unschärfer: Ein Anstieg lässt sich nicht sauber dem Store-Auftritt oder den Beiträgen zuordnen. Wer den Vergleich sauber halten will, startet den Plan erst nach den 28 Messtagen.
- Ein einzelner Beitrag bewegt bei dieser Größenordnung wenige Downloads. Aussagekräftig ist die Woche, nicht der Tag.
- Zielgröße bleibt der Erlös je Download, wie in der Roadmap festgelegt.
- Was sich ohne Tracking nicht messen lässt: wer nach einem Beitrag später über die Suche kommt. Das taucht als Suche auf, nicht als Kampagne.
