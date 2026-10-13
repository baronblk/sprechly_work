# Sprechly — Organic Marketing Package

Stand: 2026-10-04 · Zero-Budget-Kampagne, organisch, transparent, ohne Spam.

Dieses Dokument ist der Einstieg. Die Texte stehen in [ORGANIC_POST_LIBRARY.md](ORGANIC_POST_LIBRARY.md), der Zeitplan in [ORGANIC_MARKETING_30_DAYS.md](ORGANIC_MARKETING_30_DAYS.md), die Community-Regeln in [COMMUNITY_CHECKLIST.md](COMMUNITY_CHECKLIST.md).

Nichts wurde veröffentlicht, kein Konto angelegt, keine Plattform verändert, keine Nachricht verschickt. Am App-Code wurde nichts geändert.

## Befunde, die vor dem Start zu klären sind

Die Produktanalyse hat sieben Stellen gefunden, an denen das, was öffentlich steht oder versprochen wird, vom Code oder vom geplanten Stand abweicht. Die ersten vier blockieren den Start.

| # | Befund | Beleg | Folge |
|---|---|---|---|
| 1 | **Im Store ist 1.1.0 live**, mit dem Namen „Sprechly: Recorder & KI“. Die korrigierte Beschreibung und die neuen Screenshots gehören zu 1.1.1 und sind nicht eingespielt. Laut Roadmap enthält die Live-Beschreibung noch zwei falsche Aussagen | App-Store-Seite DE, abgerufen 2026-10-04. `docs/ROADMAP.md` A2 | Kampagne erst nach Livegang von 1.1.1 |
| 2 | **Der Preis steht vor einer Änderung.** Live 6,99 €, geplant 9,99 € mit 1.1.1 | App-Store-Seite. `MONETIZATION.md` | Preis vor Tag 1 festlegen. Die Texte nennen ihn über `[PREIS]`. Ausnahme: RD-L4, RD-L5, RD-S5, IH-2 und IH-4 machen die Erhöhung von 6,99 € auf 9,99 € selbst zum Thema und gelten nur, wenn sie umgesetzt ist |
| 3 | **Die Landingpage ist überholt und nicht erreichbar.** `docs/html/index.html` nennt 6,99 €, „Aufnahme & Transkription gratis“, „deine Stimme verlässt das Gerät nicht“ und „AIFF“. `https://www.gcng.de/sprechly/` lief in eine Weiterleitungsschleife | Datei im Repo. Abruf 2026-10-04 | Alle Texte verlinken den App Store. Die Seite ist auch als Marketing-URL im Store hinterlegt |
| 4 | **Zu prüfen: Erreichen Nichtkäufer die 30-Sekunden-Vorschau?** Der Eintrag „Sprachmodelle“ in den Einstellungen ist nur nach dem Kauf sichtbar. Ohne geladenes Modell zeigt der Transkript-Bildschirm keinen Knopf „30 Sekunden gratis testen“, sondern den Hinweis, das Modell „unter Transkription in der Bibliothek“ zu laden. Einen solchen Eintrag gibt es in der Bibliothek nicht. Ob iOS das Modell der Gerätesprache ohnehin bereithält, ließ sich ohne Gerät nicht klären | `SettingsView.swift` Z. 40–48, `TranscriptView.swift` Z. 309–345 | Auf einem Gerät ohne Kauf testen. Wenn die Vorschau nicht erreichbar ist, trägt das zentrale Versprechen der Kampagne nicht |
| 5 | Die Datenschutzerklärung schreibt „Wenn du iCloud-Sync aktivierst“. Der Sync ist ab Werk an | `docs/html/privacy.html`. `SettingsView.swift` (`icloudSyncEnabled = true`) | Formulierung anpassen |
| 6 | Die neue Store-Beschreibung für 1.1.1 sagt im KI-Abschnitt „nichts wird hochgeladen“, im Kopf „deine Aufnahmen werden weder an uns noch an Dritte übertragen“ und nennt den iCloud-Sync „optional“, ohne zu sagen, dass er ab Werk an ist. Für die Verarbeitung stimmt das. Mit eingeschaltetem Sync gehen die Aufnahmen aber an Apple | `STORE_LISTING.md` | Vor der Einreichung von 1.1.1 anpassen. Die Beiträge LI-DE-3, LI-EN-4 und MA-DE-12 erzählen, dass die Beschreibung korrigiert wurde. Das hält nur, wenn sie danach wirklich genau ist |
| 7 | `MONETIZATION.md` beginnt mit „transcription is free“. Seit Juni ist die vollständige Transkription Teil des Kaufs | `MONETIZATION.md`, `docs/DECISIONS.md` 2026-06-21 | Doku nachziehen |

Dazu zwei Hinweise ohne Handlungsdruck: Die Store-Seite listet Macs mit Apple-Chip als kompatibel, im Repo ist das weder getestet noch dokumentiert, die Texte erwähnen den Mac deshalb nicht. Und die Roadmap plant für 1.1.1 einen Vergleich von 28 Tagen davor und danach. Eine gleichzeitige Kampagne macht diesen Vergleich unschärfer.

## Product positioning

### Was Sprechly ist

Ein Diktiergerät für iPhone und iPad (ab iOS 26), das Aufnahmen auf dem Gerät transkribiert, per KI verdichtet und als Text exportiert. Kostenloser Download, ein einmaliger In-App-Kauf, kein Abo, kein Konto. Entwickelt von einer Person.

Die vollständige Faktenbasis mit Belegen steht in der Library, Abschnitt 0.4. Die Grenzen stehen in 0.5.

### Fünf Positionierungen im Vergleich

Bewertung von 1 (schwach) bis 5 (stark). Die Punkte sind eine Einschätzung auf Basis der Produktanalyse und keine Messung.

| | Positionierung | Verständlich | Differenzierend | Glaubwürdig | Relevant | Summe | Zielgruppe |
|---|---|---|---|---|---|---|---|
| **A** | „Transkription auf iPhone und iPad. Ohne Abo.“ | 5 | 4 | 5 | 5 | **19** | Abo-Müde, Studierende, Selbstständige, alle Gelegenheitsnutzer |
| **B** | „Diktiergerät, Transkript und KI in einer App.“ | 4 | 2 | 4 | 3 | 13 | Allgemein |
| **C** | „Transkription, die auf deinem Gerät rechnet. Ohne Konto.“ | 4 | 4 | 4 | 4 | **16** | Datenschutzbewusste Apple-Nutzer, Journalisten, kleine Unternehmen |
| **D** | „Meeting, Interview oder Vorlesung aufnehmen und direkt transkribieren.“ | 5 | 2 | 4 | 4 | 15 | Meeting-Nutzer, Interviewer, Studierende |
| **E** | „Einmal kaufen, weil kein Server mitläuft. Gebaut von einem einzelnen Entwickler.“ | 3 | 4 | 5 | 3 | 15 | Entwickler, Indie-Szene, Hacker News |

Begründung in Kürze:

- **A** ist in einem Satz verstanden und sofort überprüfbar. Der Preis steht im Store. „Kein Abo“ ist bei Transkriptions-Apps ein echtes Unterscheidungsmerkmal, und Sprechly kann es begründen: Es gibt keine Serverkosten.
- **B** beschreibt die App richtig, unterscheidet sie aber von keiner anderen. „KI“ gilt zudem nur auf Geräten mit Apple Intelligence.
- **C** ist stark, verlangt aber Genauigkeit. Die Aussage trägt nur in der Form „rechnet auf dem Gerät, kein eigener Server, kein Konto“. Sobald sie zu „bleibt auf dem Gerät“ verkürzt wird, ist sie wegen des iCloud-Syncs falsch. Der Quellcode ist nicht öffentlich, die Aussage lässt sich also nur über das Datenschutzlabel und den Flugmodus-Test stützen.
- **D** trifft die Anwendungsfälle, verspricht bei Meetings und Interviews aber implizit eine Sprecher-Zuordnung, die es nicht gibt.
- **E** ist keine Positionierung für Endkunden. In Entwickler-Communities ist sie die ehrlichste und wirksamste Erzählung.

### Die zwei Hauptpositionierungen

1. **A: „Transkription auf iPhone und iPad. Ohne Abo.“** Sie trägt alle Beiträge für Endnutzer.
2. **C: „Transkription, die auf deinem Gerät rechnet. Ohne Konto.“** Sie trägt die Beiträge für datenschutzbewusste Leser, immer zusammen mit dem Satz zum iCloud-Sync.

E ist der Ton für Entwickler-Kanäle (Reddit-Entwicklerforen, Hacker News, Indie Hackers). D liefert die Anwendungsfälle innerhalb von A.

Der stärkste einzelne Inhalt der Kampagne ist ein Nebenprodukt von C: **Rene hat seine eigene Store-Beschreibung korrigiert, weil eine Datenschutzaussage nicht stimmte.** Diese Geschichte gehört nur zu dieser App, und sie belegt die Glaubwürdigkeit besser als jede Behauptung.

## Target audiences

| Zielgruppe | Problem | Nutzen von Sprechly | Relevante Funktionen | Plattformen | Sprache und Ton | CTA |
|---|---|---|---|---|---|---|
| **Studierende** | Aufgenommene Vorlesungen sind nicht durchsuchbar. Wenig Geld | Transkript führt zurück zur Stelle im Audio. Aufnahme und Audio-Export gratis, Transkript einmalig | Tippen auf Zeile springt ins Audio, Stichpunkte, Markdown-Export, iPad | Mastodon, Bluesky. r/studytips nach Regelprüfung | Deutsch, duzen, knapp. Hinweis auf Erlaubnis zum Aufnehmen | 30 Sekunden gratis testen |
| **Journalisten** | Abtippen kostet Zeit. Material soll nicht bei einem Dienst liegen | Transkript mit Zeitmarken, Zitat am Original prüfbar | Zeitmarken, Import, TXT/Markdown-Export | LinkedIn, Mastodon | Deutsch und Englisch, sachlich. Grenze nennen: keine Sprecher-Zuordnung | Mit eigener Aufnahme testen |
| **Interviewer** (Forschung, Personal, Podcasts) | Wie Journalisten, dazu Einverständnis und Vertraulichkeit | Verarbeitung auf dem Gerät, kein Konto | wie oben, dazu Schnitt | LinkedIn, Mastodon | sachlich, Grenzen zuerst | Mit eigener Aufnahme testen |
| **Selbstständige** | Kundengespräche und Ideen gehen verloren. Keine Lust auf ein weiteres Abo | Gespräch zu Protokoll, einmal zahlen | Protokoll, Kernaussagen, Markdown-Export | LinkedIn, r/StartupDACH nach Regelprüfung | Deutsch, Du oder neutral, Kostenargument | App Store ansehen |
| **Kleine Unternehmen** | Besprechungsprotokolle, Vorbehalte gegen Cloud-Dienste | Protokoll entsteht auf dem Gerät, kein Konto, kein Vertrag | Protokoll-Stil, Datenschutzlabel, iCloud abschaltbar | LinkedIn | Deutsch, nüchtern. Genau sagen, was an Apple geht | App Store ansehen |
| **Meeting-Nutzer** | 30 Minuten Gespräch, niemand schreibt mit | Zusammenfassung in Zeilen statt Minuten | Aufnahme bei gesperrtem Bildschirm, Protokoll, Stichpunkte | LinkedIn, Bluesky, Mastodon | kurz, Nutzen zuerst, Einverständnis erwähnen | Beim nächsten Meeting ausprobieren |
| **Menschen, die Sprachmemos transkribieren** | Aufnahmen stapeln sich ungehört | Aus Gesprochenem wird lesbarer Text | Import, Bereinigung, Überschreiben ab Cursor | Mastodon, Bluesky, deutsche Foren | Deutsch, alltagsnah | Eine alte Aufnahme importieren |
| **Nutzer, die Abos vermeiden** | Zu viele laufende Abos | Einmal kaufen, vieles dauerhaft gratis | Einmalkauf, Wiederherstellen über Apple-ID | Mastodon, Bluesky, r/apple nach Regelprüfung, Foren | direkt, mit Begründung (kein Server) | App Store ansehen |
| **Datenschutzbewusste Apple-Nutzer** | Misstrauen gegenüber Diensten, die Audio verarbeiten | Verarbeitung auf dem Gerät, kein Konto, keine SDKs | Datenschutzlabel, Flugmodus-Test, iCloud-Schalter | Mastodon, LinkedIn. **Nicht r/privacy** | präzise, nichts verkürzen | Datenschutzlabel ansehen, nachfragen |
| **Podcaster und Content Creator** | Rohmaterial sichten, Zitate und Shownotes ziehen | Transkript als Arbeitsgrundlage, Versprecher überschreiben | Überschreiben ab Cursor, Stille entfernen, Mix, WAV-Export | Mastodon, Bluesky. r/podcasting nur im Wochen-Thread | Englisch und Deutsch. Grenze nennen: kein Mehrspur-Editor | App Store ansehen |
| **Personen, die auf iPhone und iPad arbeiten** | Wollen ohne Mac und ohne Web-Dienst auskommen | Alles auf dem Gerät, iPad mit geteilter Ansicht, Sync über die eigene iCloud | iPad-Layout, iCloud-Sync, Teilen-Menü | Mastodon, Bluesky, MacRumors, deutsche Foren | sachlich | App Store ansehen |
| *Zusätzlich:* **iOS-Entwickler** | Suchen Erfahrungen mit SpeechAnalyzer und Foundation Models | Konkrete Befunde aus einem ausgelieferten Projekt | – | r/iOSProgramming nach Regelprüfung, Mastodon (iosdev), Hacker News, Indie Hackers | Englisch, technisch, ohne Verkauf | Erfahrungen austauschen |

## Platform strategy

| Plattform | Rolle | Ton | Häufigkeit in 30 Tagen | Wichtigste Regel |
|---|---|---|---|---|
| **Mastodon** | Hauptkanal Deutsch. Datenschutz, Indie-Szene, Entwickler | persönlich, knapp, 3–5 Hashtags in CamelCase | 6 | Nicht nur Links. KI-Einsatz je nach Instanz offenlegen |
| **LinkedIn** | Selbstständige, kleine Unternehmen, berufliches Netzwerk | Geschichte mit Nutzen, erste Zeile trägt | 5 | Link notfalls in den ersten Kommentar |
| **Reddit** | Reichweite, aber nur wo Entwicklerbeiträge erlaubt sind | Erfahrungsbericht, Grenzen offen nennen, Fragen stellen | 5, in fünf Subreddits | Regeln live prüfen. Vorher normal mitdiskutieren |
| **Bluesky** | Kurzform, Englisch und Deutsch, Threads für Entwickler | Einstieg, Nutzen, Entwicklerrolle | 4 | Kommerzielle Inhalte kenntlich machen |
| **Foren** (Sir Apfelot, macuser.de, MacRumors) | Sachliche Vorstellung, langlebige Threads, Suchmaschinen finden sie | nüchtern: Problem, Lösung, Abgrenzung, Preis, Link | 3, je ein Thread | Ein Thread je App. Updates als Antwort im eigenen Thread |
| **Indie Hackers** | Preis- und ASO-Erkenntnisse | Zahlen, Fehler, offene Fragen | 2 | Regeln nicht verifiziert. Erst kommentieren |
| **Hacker News** | Einmaliger Versuch über den technischen Zugang | selbst geschrieben, nüchtern | 1 | Kein generierter Text. Keine Bitte um Upvotes |

Was die Kampagne zusammenhält: Jeder Beitrag liefert etwas, das auch ohne Download nützt. Ein technischer Befund, eine Zahl, ein eingestandener Fehler, eine genaue Auskunft. Der Link kommt am Ende oder gar nicht.

Was sie nicht tut: denselben Text in mehreren Communities, Links in fremden Threads, Direktnachrichten, Bitten um Upvotes oder Bewertungen an Bekannte, erfundene Nutzerstimmen, Vergleiche mit Wettbewerbern ohne Beleg.

## 30-day plan

Vollständig in [ORGANIC_MARKETING_30_DAYS.md](ORGANIC_MARKETING_30_DAYS.md). Kurzfassung:

- 26 Beiträge in 30 Tagen, vier freie Tage für Antworten und Zwischenstand.
- Tag 1 ist ein Dienstag, damit r/apple auf einen Sonntag und r/iOSProgramming auf einen Samstag fällt.
- Woche 1: Vorstellung auf Mastodon, LinkedIn, Bluesky, im Sir-Apfelot-Forum und in r/apple.
- Woche 2: technische und Datenschutz-Inhalte, Hacker News, r/iOSProgramming, macuser.de.
- Woche 3: Preismodell und Zahlen, r/SideProject, Indie Hackers, MacRumors.
- Woche 4: Vertiefung, r/indiehackers, r/StartupDACH, Auswertung.
- Messung nur über App Store Connect, mit einer Apple-Kampagne je Plattform, wo ein langer Link passt.

## Post library

Vollständig in [ORGANIC_POST_LIBRARY.md](ORGANIC_POST_LIBRARY.md). Umfang:

| Bereich | Inhalt |
|---|---|
| Reddit | 5 längere Posts mit Titel, 2 Modmail-Vorlagen, 10 kurze Varianten, 10 Titel, 10 Antworten auf Rückfragen (englisch und deutsch) |
| LinkedIn | 5 deutsche und 5 englische Beiträge |
| Mastodon | 15 deutsche und 10 englische Beiträge |
| Bluesky | 15 Kurzbeiträge (8 deutsch, 7 englisch), 5 Thread-Konzepte |
| Hacker News | Faktengliederung und Titelvorschlag für einen selbst geschriebenen Show-HN-Beitrag |
| Indie Hackers | 5 Beiträge: Launch, Building in Public, Preis, ASO, Technik |
| Foren | 2 deutsche Vorstellungen, 1 englische |
| Content-Säulen | 15 Säulen mit je Hook, Kernbotschaft, CTA, 3 Kurzposts, 1 längerem Post |

Über jedem Text stehen Zielgruppe, CTA, Hashtags und die gemessene Zeichenzahl. Die Limits (Mastodon 500, Bluesky 300, LinkedIn 3.000) sind bei allen Texten eingehalten.

## Recommended communities

Nur Communities, deren Regeln am 2026-10-04 direkt gelesen wurden, gelten als geeignet.

**Geeignet unter Bedingungen**

| Community | Bedingung |
|---|---|
| Sir-Apfelot-Forum, „Stelle deine App der Community vor“ | Fragenkatalog einhalten, ein Beitrag je App |
| macuser.de, „App Review, Promotion“ | App-Store-Link ohne Parameter, keine eigene Website |
| MacRumors, „iOS Apps and Apple Arcade“ | Profil ausfüllen, als Entwickler kenntlich, ein Thread |
| Mastodon | Instanzregeln beachten, Hashtags sparsam |
| Bluesky | Entwicklerrolle nennen |
| Hacker News, „Show HN“ | selbst schreiben, einmal, anwesend bleiben |
| Apfeltalk, „App-Promotion“ | nur mit bestehendem Konto, das 3 Monate, 50 Beiträge und 5 Zustimmungen erfüllt |

LinkedIn ist das eigene Profil und unterliegt keinen Community-Regeln. Die Nutzungsbedingungen von LinkedIn wurden nicht geprüft.

**Kandidaten, vor dem Posten selbst zu prüfen** (Regeln nur aus Sekundärquellen): r/apple (sonntags), r/SideProject, r/iOSProgramming (samstags, einmal im Jahr), r/indiehackers (einmal, mit Flair), r/StartupDACH, r/studytips, r/podcasting (Wochen-Thread), r/iosapps, r/productivityapps, r/de_Apple, Indie Hackers.

**Nur nach Zusage der Moderation:** r/ios, r/iphone, r/de_EDV, r/Studium, r/GradSchool.

## Do-not-post list

| Community | Grund |
|---|---|
| r/productivity | Eigenwerbung in jeder Form verboten |
| r/privacy | Werbung verboten, Closed-Source-Software unerwünscht |
| r/college | Werbung und Startup-Beiträge verboten |
| r/de | Eigenwerbung verboten |
| r/Finanzen | Werbung verboten, thematisch fremd |
| r/apfel | „kein Gratis-Werbe-Forum“ |
| r/apps | Konten zum Bewerben eigener Apps unerwünscht |
| r/AppHookup | nur Preisaktionen |
| r/macapps | nur macOS |
| r/InternetIsBeautiful | keine Downloads, kein Freemium |
| MacTechNews-Forum | gewerbliche Nutzung untersagt |
| iszene.com | kommerzielle Werbung untersagt |
| Apple Support Communities | Werbung untersagt |
| Apple Developer Forums | Eigenwerbung unerwünscht |
| r/indieapps, r/transcription, r/AppleIntelligence | Existenz nicht belegbar |

Außerdem gilt überall:

- keine Fake-Accounts, keine erfundenen Bewertungen oder Nutzerstimmen
- keine als unabhängig getarnten Empfehlungen
- kein identischer Text in mehreren Communities
- keine Bitte um Upvotes, kein organisiertes Abstimmen
- keine App-Links in fremden Threads, keine automatisierten Direktnachrichten
- keine Aussagen über Wettbewerber ohne Beleg

## Wiederverwendung der vorhandenen Screenshots

Gesichtet wurden die sechs deutschen iPhone-Screenshots für 1.1.1 (`Screenshots/store/de/iPhone 17 Pro Max/`), der iPad-Screenshot `01-transcript` und das Banner `Screenshots/marketing-de.png`. Die englischen Fassungen und die iPad-Reihe folgen demselben Aufbau. Die vier Videos unter `Screenshots/video/` wurden nur technisch geprüft (Format, Dauer), nicht inhaltlich.

Neue Grafiken sind nicht nötig. Die vorhandenen reichen.

| Motiv | Zeigt | Reddit | LinkedIn | Mastodon | Bluesky | Foren |
|---|---|---|---|---|---|---|
| `01-transcript` „Sprich. Sprechly schreibt mit.“ | Transkript mit Zeitmarken, KI-Kernpunkte | ja, für r/SideProject | ja, erstes Bild | ja | ja | ja, erstes Bild |
| `02-summary` „Aus 30 Minuten werden 5 Zeilen“ | Wiedergabe, Wellenform, KI-Zusammenfassung | – | ja, zu Meeting-Beiträgen | ja, zu MA-DE-08 | ja, zu BS-DE-06 | ja |
| `03-usp` „Kein Abo. Kein Konto.“ | Einstellungen mit dem Umfang des Kaufs | ja, zu Preis-Beiträgen | ja, zu LI-DE-4 | ja, zu MA-DE-02 | ja | ja, beim Preis |
| `04-record` „Versprecher? Einfach überschreiben“ | laufende Aufnahme | – | – | ja, zu MA-DE-04 | ja, zu BS-DE-04 | ja |
| `05-edit` „Schneiden, mischen, exportieren“ | Schnitt mit Auswahl, Stille entfernen, Tempo, Format | – | – | ja, zu MA-DE-11 | – | ja |
| `06-library` „Alle Aufnahmen, sofort gefunden“ | Bibliothek mit Suche und Kennzeichen | – | – | – | – | ja |
| `marketing-de.png` / `marketing-en.png` (2400 × 1260) | Icon, Name, „On-Device. Kein Abo.“ | – | ja, als Titelbild | ja | ja | – |
| iPad `01-transcript` | geteilte Ansicht auf dem iPad | – | – | ja, zu iPad-Beiträgen | – | ja, MacRumors |
| `Screenshots/video/promo-*.mp4` (1080 × 1920, 19 s) | nicht gesichtet | – | möglich | möglich | möglich | – |

Hinweise:

- **Reddit:** In Entwickler- und Erfahrungsbeiträgen wirken die Store-Screenshots mit Werbeüberschrift wie Anzeigen. Dort besser gar kein Bild oder die Rohaufnahme ohne Überschrift (`Screenshots/de/iPhone 17 Pro Max/…`). r/apple verlangt einen reinen Textbeitrag.
- **Hochformat:** Die Store-Screenshots sind 1320 × 2868. Mastodon, Bluesky und LinkedIn beschneiden solche Bilder in der Vorschau. Zwei oder drei nebeneinander wirken besser als eines.
- **Videos:** Die Promo-Videos stammen vom Juni, also aus der Zeit vor der Korrektur der Store-Texte. Vor der Verwendung ansehen und auf überholte Aussagen und den alten Preis prüfen.
- **Banner:** Das Banner trägt keine Aussage, die geprüft werden müsste, außer „On-Device. Kein Abo.“. Beides stimmt.

**Bildbeschreibungen für Mastodon und Bluesky** (als Alt-Text):

- `01-transcript`: „Bildschirmfoto der App Sprechly: Transkript einer Besprechung mit Zeitmarken, darüber eine KI-Zusammenfassung mit Kernpunkten.“
- `02-summary`: „Bildschirmfoto der App Sprechly: Wiedergabe einer Aufnahme mit Wellenform, darunter eine KI-Zusammenfassung.“
- `03-usp`: „Bildschirmfoto der Einstellungen von Sprechly: Der einmalige Kauf umfasst Transkription, Live-Transkript, Transkript-Export, KI-Titel und Zusammenfassung sowie Übersetzung.“
- `04-record`: „Bildschirmfoto der App Sprechly während einer laufenden Aufnahme mit Zeitanzeige, Wellenform, Pause- und Stopp-Taste.“
- `05-edit`: „Bildschirmfoto des Schnitt-Editors von Sprechly mit markierter Auswahl, den Tasten Auswahl behalten, Auswahl entfernen und Stille automatisch entfernen sowie Tempo und Exportformat.“
- `06-library`: „Bildschirmfoto der Bibliothek von Sprechly mit Suchfeld und vier Aufnahmen.“

**Formate, die es noch nicht gibt** (nur dokumentiert, nicht erstellt):

- Querformat 16:9 mit zwei Bildschirmen nebeneinander, für Beiträge ohne Linkvorschau.
- Quadrat 1080 × 1080 für LinkedIn.
- Eine kurze Bildschirmaufnahme „Zeile antippen, Audio springt“. Das ist die Funktion, die sich im Standbild am schlechtesten zeigen lässt.
- Ein Vorschaubild (Open Graph) für die Landingpage, sobald sie wieder erreichbar ist.

## Best 10 posts

Auswahl nach drei Kriterien: Der Beitrag hat auch ohne Download einen Wert, er ist unverwechselbar, und er passt zu den Regeln seines Kanals.

| # | Text | Kanal | Warum |
|---|---|---|---|
| 1 | **LI-DE-3** „In meiner App-Beschreibung stand ein Satz, der nicht stimmte“ | LinkedIn | Der eigene Fehler als Beleg für Genauigkeit. Die Geschichte gehört nur zu dieser App |
| 2 | **RD-L3** „Eight things that broke“ | r/iOSProgramming | Acht nachprüfbare Befunde zu einer neuen API, dazu eine eigene Messung mit Nullergebnis |
| 3 | **RD-L1** Entwickler-Post | r/apple | Größte Reichweite, klare Struktur, Grenzen offen genannt |
| 4 | **RD-L2** „128 downloads and 4 sales“ | r/SideProject | Echte Zahlen, benannte Fehler, eine konkrete Bitte |
| 5 | **MA-DE-03** „Datenschutz, genau gesagt“ | Mastodon | Sagt den unbequemen Teil selbst, vor einem Publikum, das darauf achtet |
| 6 | **LI-DE-4** „Warum kein Abo“ | LinkedIn | Begründet den Preis mit der Architektur und nennt die Kehrseite |
| 7 | **FO-DE-2** Vorstellung nach Fragenkatalog | Sir-Apfelot-Forum | Einzige Community, die Entwickler ausdrücklich einlädt |
| 8 | **LI-DE-5** „128 Downloads, 4 Käufe, 0 Bewertungen“ | LinkedIn | Echte Zahlen und ein Fehler mit einprägsamer Größe (97 %), für Entwickler lehrreich |
| 9 | **IH-3** Vorschau statt Bezahlschranke | Indie Hackers | Übertragbare Erkenntnis mit drei klaren Regeln |
| 10 | **MA-DE-15** „Welche Wörter gehen bei euch schief?“ | Mastodon | Nennt das eigene Messergebnis und stellt eine Frage, deren Antworten in die Arbeit an 1.2 einfließen |

## Best first 5 actions

1. **Auf einem Gerät ohne Kauf prüfen, ob die 30-Sekunden-Vorschau erreichbar ist** (Befund 4), und die Store-Beschreibung für 1.1.1 noch einmal gegen den iCloud-Standardwert lesen (Befund 6). Danach **1.1.1 einreichen und veröffentlichen, mit festgelegtem Preis.** Vorher beginnt nichts.
2. **Die Landingpage korrigieren und erreichbar machen, oder die Marketing-URL im Store vorerst entfernen.** `docs/html/index.html` widerspricht in vier Punkten der App. Dazu die Datenschutzerklärung an den Standardwert des iCloud-Syncs anpassen.
3. **In App Store Connect die Kampagnenlinks erzeugen** und die Ausgangswerte der letzten 28 Tage ins Wochenprotokoll eintragen. Ohne Ausgangswert gibt es später nichts zu vergleichen.
4. **Die Regeln der fünf Reddit-Kandidaten im Browser lesen** und die Checkliste ausfüllen. Parallel RD-M1 an die Moderation von r/ios schicken. Wo der eigene Account bisher nicht aktiv war: erst mitdiskutieren, dann posten.
5. **Mit Tag 1 bis 4 des Plans beginnen:** MA-DE-01 auf Mastodon, LI-DE-1 auf LinkedIn, BS-EN-01 auf Bluesky, FO-DE-2 im Sir-Apfelot-Forum. Diese Kanäle haben direkt gelesene Regeln oder sind das eigene Profil, und sie bringen erste Rückmeldungen, bevor Reddit und Hacker News an die Reihe kommen.
