# Sprechly Work — kopierte VoxStudio-Basis

> **Vorrang:** Für App-Identität, Ziel und Bauplan gilt `../CLAUDE.md` im
> Projekt-Root, nicht diese Datei. Hier steht die Architektur- und
> Entscheidungs-Historie der **Store-App Sprechly (VoxStudio)**, aus der diese
> Basis kopiert wurde — fachlich weiter gültig, bei Identitätsfragen aber
> überholt.
>
> Diese Kopie läuft als eigene App: Target/Produkt `SprechlyWork`,
> Bundle-ID `de.gcng.sprechly.work`, Anzeigename „Sprechly Work",
> CloudKit-Container `iCloud.de.gcng.sprechly.work`. Das Store-Projekt unter
> `~/Development/Tools/src/de.gcng.voxstudio/` bleibt unberührt.

---

# VoxStudio — CLAUDE.md

Persistenter Kontext für jede Claude-Code-Session. Diese Datei ist verbindlich.

## 0. Festgelegte Entscheidungen (Phase 1)

- **App-Name:** **Sprechly** (Anzeigename). **Bundle-ID:** `de.gcng.sprechly`. Store-Name + Untertitel werden **erst in App Store Connect** final gesetzt, nicht im Repo verdrahtet (Vorschlag Untertitel: „Aufnahme & Transkript"). **Kein „Diktat"** (überfüllter Sub-Markt, Verwechslungsnähe zu Speechly/Spokenly) und **kein „Pro" im App-Namen** (gehört zum IAP-Tier). Intern bleibt Modul/Target/`.xcodeproj` „VoxStudio" (für Nutzer unsichtbar). **In dieser Work-Kopie:** Anzeigename „Sprechly Work", Bundle-ID `de.gcng.sprechly.work`, Target/Projekt `SprechlyWork`.
- **Aufnahme-Format:** Standard **Mono 48 kHz AAC (M4A) ~128 kbps**. Variable Einstellbarkeit (Rate/Bitrate) kommt in einem späteren Slice; jetzt fester Default.
- **Soft-Delete:** Papierkorb mit **automatischer Endlöschung nach 30 Tagen**; `Recording.deletedAt: Date?` trägt den Löschzeitpunkt. Löschen/Purge entfernt **Audiodatei (Documents) + Wellenform-Sidecar (Caches)**.
- **Hintergrundaufnahme:** `UIBackgroundModes: audio` aktiv — Aufnahme läuft bei Hintergrund/Lock weiter.
- **Wellenform-Peaks:** Sidecar-Cache in Caches (key = recording-id), bei Miss neu erzeugt (Audio liegt sicher in Documents).
- **Aufnahme-API:** `AVAudioEngine` (+ einzelne `AVAudioFile`) — pause/resume via `engine.pause()/start()` bei durchgehender Datei; `AVAudioConverter` normalisiert Tap-Buffer aufs Aufnahmeformat. Engines sind persistenz-agnostisch (URLs + Streams; ViewModel orchestriert Persistenz).
- **Git-Remote:** Diese Kopie liegt in `baronblk/sprechly_work`; das Store-Repo ist ein anderes.

---

## 1. Rolle & Mission

Senior iOS-Engineer, native produktionsreife Voice-Recorder- und Audio-Editor-App für iPhone. Vorbild ist eine reife Recorder-App (Aufnahme, Wellenform-Editor, Mix/Merge, Multi-Format-Export, Teilen) — erweitert um **On-Device-Transkription**.

**Qualitätsanspruch:** App-Store-fähig, kein Prototyp. Sauberer State, kein toter Code, kein `print`, keine `fatalError` in Produktionspfaden, keine Force-Unwraps in Hot-Paths.

**IP:** Vorbild ist nur funktionale Referenz. **Kein** Übernehmen von Markennamen, Marketing-Texten oder Icons. Eigenes Branding, eigene Texte, eigene Assets.

---

## 2. Tech-Stack (verbindlich)

| Bereich | Festlegung |
|---|---|
| Sprache | Swift 6.x, **strict concurrency** komplett aktiviert |
| Min. Target | **iOS 26.0** (Liquid Glass, Foundation Models, SpeechAnalyzer) |
| UI | SwiftUI ausschließlich, **kein** UIKit außer zwingend (dann via `UIViewRepresentable` gekapselt) |
| State | `@Observable` — **niemals** `ObservableObject`/`@Published` |
| Persistenz | **SwiftData** (`@Model`, `@Query`) |
| Audio | `AVAudioEngine` + `AVAudioRecorder`/`AVAudioFile`, `AVAudioPlayer`/`AVAudioPlayerNode`, `AVAudioSession` |
| ASR | nativ **`SpeechAnalyzer` + `SpeechTranscriber`** (Speech-Framework, on-device, iOS 26) |
| KI-Nachbearbeitung | **Foundation Models** (`LanguageModelSession`) für Zusammenfassung/Bereinigung/Titel |
| Sync | **CloudKit** (privat) + optional iCloud Drive Export |
| Logging | `os.Logger` — **niemals** `print` |
| Tests | **Swift Testing** (`@Test`, `#expect`) — kein XCTest |
| Dependencies | **SPM only**, minimal. Bevorzugt **null** Drittpakete in Phase 1–3 |
| Nebenläufigkeit | `async/await`, `actor` für geteilten Zustand, `@MainActor` nur für UI |

**ASR-Begründung:** `SpeechAnalyzer`/`SpeechTranscriber` ist Apples natives On-Device-Framework ab iOS 26 mit System-Modell-Download (`AssetInventory`) und Mehrsprachigkeit. **WhisperKit (SPM, ≥0.9.0)** ist dokumentierter Fallback — nur auf explizite Anweisung, nicht Default. Exakte Speech-API-Signaturen gegen installiertes SDK verifizieren.

---

## 3. Architektur-Regeln (verbindlich)

```
View (SwiftUI, zustandslos)
  └── ViewModel (@Observable class, @MainActor)
        └── Service / Engine (actor oder struct, thread-sicher)
              └── DataSource (SwiftData, AVFoundation, FileManager, CloudKit)
```

- **Views:** nur Darstellung + Interaktion, keine Business-Logik.
- **ViewModels:** UI-State, koordinieren Services, `@MainActor`-isoliert.
- **Services/Engines:** zustandslos oder `actor`-basiert. Audio-Engine ist `actor`.
- **Strukturierte Fehlertypen** (`enum AppError: Error, LocalizedError`). Kein `try?`-Verschlucken in nutzersichtbaren Pfaden.
- **Kein Singleton-Wildwuchs.** App-weiter State via `@Observable AppState` + `.environment(...)`.
- **Navigation:** `NavigationStack` mit typsicherem `enum AppRoute: Hashable`.

---

## 4. Projektstruktur

```
VoxStudio/
├── App/                  VoxStudioApp.swift, AppState.swift, AppRoute.swift
├── Features/             Recording/, Library/, Editor/, Transcription/, Settings/
├── Engine/               AudioRecorderEngine, AudioPlaybackEngine, AudioEditingService,
│                         AudioExportService, WaveformGenerator
├── Transcription/        SpeechTranscriptionService (actor), AISummaryService (actor)
├── Persistence/          Recording (@Model), TranscriptSegment (@Model), CloudSyncCoordinator
├── DesignSystem/         Theme, WaveformView (Canvas), Components/
├── Resources/            Localizable (de, en)
└── Tests/VoxStudioTests/ Swift Testing
```

---

## 5. Feature-Scope mit Phasen

> **Strikt phasenweise. Phase vollständig abschließen (inkl. Tests + DoD), bevor die nächste beginnt. Freigabe vor jedem Phasenwechsel einholen.**

### Phase 1 — Aufnahme-Kern (MVP)
- Aufnahme start/pause/resume/stop via `AVAudioEngine`.
- Live-Pegel + Live-Wellenform während Aufnahme.
- Wiedergabe mit Scrubbing + Cursor auf statischer Wellenform.
- SwiftData-Persistenz (Datei-URL + Metadaten).
- Bibliothek: Liste, Umbenennen, Löschen (Soft-Delete/Papierkorb), Suche.
- `AVAudioSession` korrekt (record/playback, Interruptions, Route-Changes).
- Dark-Mode-UI mit Design-System-Grundlage.
- **Standard-Format M4A/AAC.**

### Phase 2 — Editor & Export
- **Trim** mit Drag-Handles, nicht-destruktiv.
- **Merge** mehrerer Aufnahmen.
- **Mix:** zweite Spur überlagern, Lautstärke 0–100 %, Positions-/Trim-Handles.
- **Geschwindigkeit** 0,5×–3× (optional pitch-korrigiert).
- **Gain** beim Export.
- **Teilen** via `ShareLink`.
- **Multi-Format-Export:** M4A, AAC, MP3, WAV, AIFF, CAF (MP3-Weg verifizieren).
- **iCloud-Drive-Export** einzelner Dateien.

### Phase 3 — Transkription (Kern-USP)
- On-Device-Transkription via `SpeechAnalyzer`/`SpeechTranscriber`.
- **Live-Transkription** via `AsyncStream` von Segmenten.
- Modell-/Asset-Download (`AssetInventory`) mit Fortschritts-UI + Offline-Hinweis.
- Transkript-Persistenz als `TranscriptSegment` mit Zeitstempeln; Tap springt zur Audio-Position.
- **KI-Nachbearbeitung via Foundation Models:** Zusammenfassung, Titel, Bereinigung, Bullets. `@Generable`. Availability prüfen, sauberer Fallback.
- Export Transkript als TXT/Markdown.

### Phase 4 — Erweiterte Aufnahme & Plattform (separat freigeben)
- Geplante Aufnahme, VAD (sprachaktiviert), Bluetooth-Route-Selection, Live Activity / Dynamic Island, App Intents / Siri, Klingelton (.m4r).
- **Voice Changer** — ⚠️ eigenes Spike-Projekt. **Video-Mix** — ⚠️ separat scopen.

---

## 6. Audio-Engine — Detailvorgaben

- `AudioRecorderEngine` und `AudioPlaybackEngine` getrennte `actor`s. UI über `@MainActor`-ViewModels.
- `AVAudioSession`: Kategorie/Modus passend, Interruptions + Route-Changes behandeln, beim Verlassen deaktivieren.
- Pegel + Wellenform über `installTap(onBus:)` mit gedrosselter Sample-Reduktion (~30 fps, kein Update pro Buffer).
- `WaveformGenerator`: PCM → Buckets (min/max/RMS pro Pixel-Spalte), off-main; Rendering via `Canvas`.
- Editier-Operationen **nicht-destruktiv:** Original bleibt; Trim/Mix/Speed erzeugen neue Datei.
- Temp-Dateien in Caches, finale in `Documents` (iCloud-Backup).

---

## 7. Transkription — Detailvorgaben

- `SpeechTranscriptionService` (`actor`): kapselt `SpeechAnalyzer`/`SpeechTranscriber`, Segmente als `AsyncStream`.
- Sprach-Auswahl + Asset-Verfügbarkeit prüfen; Download nur mit Nutzer-Bestätigung.
- `AISummaryService` (`actor`): `LanguageModelSession`, `@Generable`-Output (Titel, Summary, KeyPoints).
- Beide Services kapseln Availability-Checks und liefern definierte Fehlerfälle statt Crash.

---

## 8. Datenmodell (SwiftData)

- `Recording`: id, title, fileName (relativ!), duration, createdAt, isDeleted, segments (cascade).
- `TranscriptSegment`: id, text, startTime, endTime.
- **Keine** absoluten Datei-URLs persistieren — nur relative `fileName`, zur Laufzeit zum `Documents`-Pfad auflösen.

---

## 9. iCloud / Sync

- CloudKit privater Container für Metadaten.
- Audiodateien zunächst lokal + optionaler iCloud-Drive-Export pro Datei; Full-Asset-CloudKit-Sync ist Phase-4-Entscheidung.
- Konflikt-Strategie + Offline-Verhalten dokumentieren, bevor Sync gebaut wird.

---

## 9a. Monetarisierung & In-App-Käufe

**Modell:** **Gratis-App** + **ein** einmaliger **Non-Consumable**-IAP `de.gcng.sprechly.ai` (6,99 €) für den KI-Layer (entschieden 2026-06-21 für Release 1.0.0 — ersetzt die frühere „Vollpreis-App"-Idee: mehr Downloads/Conversion, Aufnahme/Transkription gratis testbar). **Kein Abo. Kein externes Payment. Kein eigenes Receipt-Parsing/Server-Validierung — ausschließlich StoreKit 2** (async/await, keine StoreKit-1-APIs, kein `SKProduct`/`SKPaymentQueue`).

**Architektur (`Features/Monetization/`):**
- `Entitlement.swift` — `enum Entitlement: String, CaseIterable, Sendable`, Case `.ai = "de.gcng.sprechly.ai"`. Bewusst enum (erweiterbar), **kein** Bool.
- `EntitlementProviding.swift` — Protokoll: `isUnlocked(_:) -> Bool` + async `load`, `purchase`, `restore`. ViewModels hängen am Protokoll (Testbarkeit), nicht an der Klasse.
- `StoreManager.swift` — `@MainActor @Observable final class StoreManager: EntitlementProviding`. Hält `products`, `owned: Set<Entitlement>`. Methoden: `load()`, `purchase(_:)`, `restore()` (via `AppStore.sync()`), `refreshEntitlements()` (via `Transaction.currentEntitlements`), `observeTransactionUpdates()` (langlebiger Task auf `Transaction.updates`). DEBUG-Override via Env-Var `UNLOCK_ALL=1`.
- `MockEntitlementStore` (Tests) — konfigurierbarer Mock.

**Verdrahtung:** `StoreManager` in `AppState`, via `.environment(...)`. `observeTransactionUpdates()` als langlebiger Task beim App-Start; `refreshEntitlements()` bei `.task`/Foreground. Wiederverwendbarer Gate-Mechanismus (ViewModifier `.requiresEntitlement(.ai) { showPaywall }` oder ViewModel-Helper), den Phase 3 an die KI-Einstiegspunkte hängt.

**Kauf-Flow (Phase 3):** `product.purchase()` → `.success(.verified(let t))` → Entitlement gewähren → `t.finish()`. `.unverified` → **kein** Zugang. `.userCancelled`/`.pending` sauber behandeln. Nur `.verified` gewährt Zugang; jede gewährte Transaktion wird `finish()`-ed. Entitlements auch offline aus `currentEntitlements`.

**Gating (Phase 3):** an ALLEN KI-Einstiegspunkten (Transkription starten, Live-Transkription, KI-Zusammenfassung, Transkript-Export) im **ViewModel/Service-Layer** über `isUnlocked(.ai)` — nicht nur UI verstecken. Bei gesperrt → Paywall.

**Trial:** SwiftData-Flag `hasUsedFreeTranscription`. Erste Transkription gratis, danach Paywall. Kein Re-Install-Schutz.

**Paywall (Phase 3):** `PaywallView` mit Produktname, lokalisiertem Preis (aus `Product`), KI-Nutzen, Kauf-Button, **„Käufe wiederherstellen"** (Pflicht für Non-Consumables). Dark-Mode, Design-System, VoiceOver.

**SDK-verifiziert (Xcode 26.5):** `Product.products(for:)`, `@MainActor product.purchase(options:)→PurchaseResult`, `PurchaseResult{.success(VerificationResult<Transaction>)|.userCancelled|.pending}`, `VerificationResult{.verified|.unverified}`, `Transaction.currentEntitlements`/`.updates` (AsyncSequence von `VerificationResult<Transaction>`), `Transaction.finish() async`, `AppStore.sync() async throws`.

**Phasen:** Teil A (jetzt, Phase 1) = Gerüst + Verdrahtung, in DEBUG via `UNLOCK_ALL=1` alles entsperrt. Teil B (Phase 3, nach Freigabe) = StoreKit Config File, Paywall, scharfes Gating, Trial, Kauf/Restore.

**Nicht Claudes Aufgabe (manuell in App Store Connect):** Preis, IAP-Produkt anlegen, Paid Apps Agreement, Banking/Steuer, SBP, Review. Keine Platzhalter — stattdessen `MONETIZATION.md` mit zu spiegelnden Product-IDs/Preisen.

---

## 10. UI/UX

- **Dark-first.** `Theme.swift` mit semantischen Farben, Spacing-Skala, Corner-Radii. Heller Modus später, Tokens von Anfang an semantisch.
- **Liquid Glass (iOS 26):** Standard-Komponenten übernehmen Glass automatisch — **nicht** überschreiben. Eigenes `.glassEffect()` nur bewusst für Overlay-Controls, nach Layout-Modifiern, in `GlassEffectContainer`. `#available(iOS 26, *)` mit `.regularMaterial`-Fallback.
- Wellenform als performantes `Canvas` (Cursor, Trim-Handles, Mix-Overlay).
- Transport: Play/Pause, Geschwindigkeit, Loop, Zeit `mm:ss.SS`.
- Haptik bei Start/Stopp + Handle-Snapping.
- VoiceOver: alle interaktiven Elemente mit `accessibilityLabel`; Wellenform mit Summary-Label.

---

## 11. Berechtigungen & Privacy

- `NSMicrophoneUsageDescription` (klare DE-Begründung).
- `NSSpeechRecognitionUsageDescription` falls erforderlich.
- `PrivacyInfo.xcprivacy` vollständig.
- `ITSAppUsesNonExemptEncryption = false`.
- Transkription **on-device** — als Datenschutz-Vorteil kommunizieren, keine Server-Übertragung.
- Offline-Impressum + Datenschutzerklärung in Settings (eigene Texte).

---

## 12. Sicherheit, Wartbarkeit, Skalierbarkeit

- Keine Secrets im Code/Repo.
- Datei-I/O + Audio-Processing strikt off-main; UI 60 fps auch bei langen Aufnahmen.
- Lange Aufnahmen streamend, keine kompletten PCM-Buffer im RAM.
- Jede Engine/Service isoliert testbar (Protokoll-Abstraktion für ASR/KI).
- Feature-Module entkoppelt für additive Phase-4-Features.

---

## 13. Git-Workflow (verbindlich)

- **Conventional Commits, Englisch, Imperativ, klein, kein Punkt, ≤72 Zeichen Subject.**
- **Atomare Commits** — ein Commit = eine logische Änderung.
- **Sofort nach jedem Commit `git push`.**
- **NIEMALS** `Co-authored-by: Claude`, kein `--author="Claude"`, keine AI-Attribution in Commits, Kommentaren, PRs, Tags. Commits erscheinen als Renes eigenständige Arbeit.
- SemVer-Tags (`vMAJOR.MINOR.PATCH`).
- Beispiele:
  ```
  feat(recording): add live waveform tap on audio engine
  fix(editor): keep original file intact on trim export
  refactor(transcription): extract SpeechTranscriptionService into actor
  chore(deps): pin whisperkit to 0.9.0
  ```
- `GIT_WORKFLOW.md` im Root beim Setup anlegen.

---

## 14. Testing (Swift Testing)

- `WaveformGenerator`: Sample-Reduktion (Bucket-Anzahl, min/max).
- `AudioEditingService`: Trim-Grenzen, Merge-Dauer = Summe, Mix-Dauer.
- `AudioExportService`: jedes Zielformat erzeugt valide, abspielbare Datei.
- Transkription/KI: über Protokoll gemockt, keine echte Modell-Abhängigkeit.
- ViewModels: State-Übergänge (idle → recording → paused → stopped).
- Async-Tests mit `await`, keine XCTest-Patterns.

---

## 15. Definition of Done (pro Phase)

- [ ] Kompiliert ohne Warnungen, strict concurrency clean.
- [ ] Kein `print`, kein `fatalError` in Produktionspfaden, keine Force-Unwraps in Hot-Paths.
- [ ] Tests für neue Logik grün.
- [ ] Auf echtem Gerät getestet (Foundation Models & SpeechAnalyzer laufen **nicht** im Simulator).
- [ ] VoiceOver auf neuen Screens geprüft.
- [ ] Atomar committed + gepusht.
- [ ] Kurzer Statusbericht: was gebaut, welche Annahmen, was offen.

---

## 16. Explizite Nicht-Ziele / Verbote

- ❌ Kein UIKit-View-Controller-Stack, kein Storyboard.
- ❌ Kein `ObservableObject`, kein Combine für neuen State.
- ❌ Kein CocoaPods/Carthage.
- ❌ Keine Cloud-/Server-Transkription, kein Hochladen von Audio.
- ❌ Keine Übernahme von Marken, Texten, Icons des Vorbilds.
- ❌ Kein „alles auf einmal" — Phasen einhalten, vor Phasenwechsel fragen.
- ❌ Voice Changer und Video-Mix **nicht** ungefragt in Phase 2.
