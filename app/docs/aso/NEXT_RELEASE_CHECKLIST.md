# ASO-Checkliste für den nächsten Build

Punkte, die beim **nächsten regulären Metadaten-Review** zu prüfen sind. Nicht
vorsorglich abarbeiten — jeder Punkt nennt die Bedingung, unter der er fällig
wird.

Stand 2026-10-11.

---

## 1. Privacy-Keyword-Lücke schließen

**Fällig:** beim nächsten regulären App-Store-Metadaten-Review.
**Nicht fällig:** vorher, und nicht blind.

### Das Problem

`cpp-privacy` ist die einzige der drei Custom Product Pages **ohne
zugewiesene Suchbegriffe**. Grund ist nicht die Seite, sondern der Vorrat: Eine
CPP kann nur Keywords bekommen, die bereits im Keyword-Feld der zuletzt
genehmigten App-Version stehen — und dort gibt es in **keiner** der beiden
Sprachen einen echten Privacy-Intent-Begriff.

Dadurch ist `cpp-privacy` allein auf direkte URL- und Kampagnenzugriffe
angewiesen, während `cpp-meetings` und `cpp-dictation` zusätzlich bei ihren
Suchbegriffen anstelle der Standardseite ausgespielt werden können.

### Kandidaten

| | DE | EN |
|---|---|---|
| | offline | offline |
| | privat | private |
| | datenschutz | privacy |
| | ohne konto | no account |

### Was den Tausch verkompliziert

Das Keyword-Feld ist in beiden Sprachen praktisch voll (de-DE 100/100, en-US
98/100). Ein neuer Begriff bedeutet also, einen bestehenden zu streichen — und
**neun von zehn deutschen Keywords tragen seit dem 11.10. eine CPP**:

| Sprache | an eine CPP gebunden | frei |
|---|---|---|
| de-DE | sprachmemo, transkribieren, meeting, protokoll, interview, zusammenfassung, aufnahme, recorder, sprache | **text** |
| en-US | memo, transcribe, meeting, minutes, notes, interview, dictation, speech, audio, summary, record | **lecture**, **text** |

Wer einen gebundenen Begriff streicht, nimmt ihn damit auch der zugehörigen
CPP weg. **In de-DE ist `text` der einzige Begriff, der ohne Nebenwirkung
ersetzbar ist**; in en-US sind es `lecture` und `text`.

`docs/aso/APP_STORE_OPTIMIZATION.md`, Abschnitt 2.4, hält zusätzlich
`recorder` (englisches Wort im deutschen Feld, während der Name bereits
„Diktiergerät" führt) sowie `sprache` und `aufnahme` (sehr breit, geringe
Kaufabsicht) für schwach — aber alle drei hängen inzwischen an
`cpp-dictation`. Ein Tausch dort ist eine Abwägung, kein Selbstläufer.

### Vorgehen, in dieser Reihenfolge

1. **Erst messen.** Performance-Daten von Hauptseite, `cpp-meetings` und
   `cpp-dictation` auswerten — Impressionen, Conversion, Relevanz je Begriff.
   Ohne diese Daten nicht tauschen.
2. **Bestehende Keywords bewerten.** Welcher Begriff bringt real am wenigsten?
   Die Vermutungen oben sind Hypothesen, keine Messwerte.
3. **Genau einen Begriff ersetzen.** Den schlechtesten oder strategisch
   schwächsten — nicht mehrere auf einmal, sonst ist die Wirkung nicht
   zuzuordnen.
4. **Nebenwirkung prüfen:** Hängt der gestrichene Begriff an einer CPP? Wenn
   ja, verliert diese Seite ihn.
5. **Nach der Genehmigung** den neuen Privacy-Begriff `cpp-privacy` zuweisen —
   in der **ASC-Weboberfläche**, die API bildet die Zuweisung nicht ab
   (`docs/aso/CUSTOM_PRODUCT_PAGES.md`).

### Ziel

`cpp-privacy` soll nicht nur über beworbene URLs erreichbar sein, sondern auch
bei Privacy- und Offline-Suchintentionen als Custom Product Page erscheinen.

---

## 2. Wellenform-Motiv `04-record` erneuern

**Fällig:** beim nächsten Screenshot-Durchlauf.

`04-record` zeigt eine laufende Aufnahme mit **flacher Wellenform**, weil das
Mikrofon des Aufnahmerechners bei der Simulator-Aufnahme Stille lieferte. Für
das Preview-Video ist das gelöst: `scripts/preview_video.sh` lässt den Mac
während der Aufnahmeszene einen neutralen Satz über die Lautsprecher sprechen,
den das eingebaute Mikrofon aufnimmt (`docs/aso/PREVIEW_VIDEO.md`, Abschnitt 3).

`scripts/screenshots.sh` hat diesen Mechanismus **noch nicht**. Das Motiv
steht auf der Hauptseite und auf `cpp-dictation` an zweiter Stelle, wo die
Aufnahme die Kernaussage trägt — dort fällt die flache Linie am meisten auf.

---

## 3. Preview-Video: Wirkung abwarten, dann testen

**Fällig:** vier Wochen nach der Veröffentlichung von 1.2.1.

Vorher keinen Produktseitentest starten, sonst fällt der Video-Effekt in das
Testfenster. Die Impressionsschwelle für einen auswertbaren Test steht in
`docs/aso/PPO_TREATMENTS.md`.

---

## 4. Werbetext bei jeder neuen Version prüfen

**Fällig:** bei jedem Release, ausnahmslos.

**App Store Connect kopiert den Werbetext nicht** in eine neue Version —
Beschreibung, Keywords, URLs, Screenshots und Review-Details dagegen schon.
Der Text stand bei 1.2.0 **und** bei 1.2.1 in beiden Sprachen auf null Zeichen
und wäre bei der Veröffentlichung stillschweigend aus dem Store verschwunden.

Beide Male im Preflight gefunden und aus der Vorgängerversion übernommen.
Gehört in jede Release-Preflight-Liste.
