# iCloud-Sync — Architektur, Konflikte, Offline

Sprechly synchronisiert Aufnahmen (Metadaten + Transkripte + Audio) über die
Geräte eines Nutzers mit derselben Apple-ID. Kein eigener Server — die Daten
liegen ausschließlich in der **privaten iCloud** des Nutzers (CloudKit).

## Mechanik

- **Store:** SwiftData mit `ModelConfiguration(cloudKitDatabase: .private("iCloud.de.gcng.sprechly"))`
  (siehe `PersistenceController`). Auf dem Simulator/CI ist CloudKit aus
  (kein Entitlement → würde trappen); bei Problemen Fallback auf lokal, nie Crash.
- **Schema:** CloudKit-konform — alle Attribute mit Default, alle Relationships
  optional (`Recording.segments` ist optional, gekapselt über `segmentList`).
- **Audio:** als `@Attribute(.externalStorage)` an `Recording.audioData`. SwiftData
  synchronisiert das als CloudKit-Asset. Da die Engines dateibasiert arbeiten,
  überbrückt `CloudAudioReconciler` beide Welten:
  - lokale Datei vorhanden, kein `audioData` → Datei laden (Upload-Vorbereitung),
  - `audioData` vorhanden, keine lokale Datei → Datei schreiben (abspielbar machen).
  Läuft beim Start, bei `NSPersistentStoreRemoteChange` (eingehender Sync) und
  beim Wechsel in den Vordergrund, plus manuell („Jetzt aktualisieren").
- **Reihenfolge:** Metadaten kommen vor dem Audio-Asset an. Bis das Asset da ist,
  zeigt die Wiedergabe „wird noch aus iCloud geladen" statt eines Fehlers.

## Konfliktstrategie

- **Last-writer-wins pro Eigenschaft.** CloudKit/Core Data mergen auf
  Property-Ebene (NSMergeByPropertyObjectTrumpMergePolicy als Default des
  CloudKit-Containers). Bearbeitet Gerät A den Titel und Gerät B die KI-
  Zusammenfassung derselben Aufnahme, bleiben **beide** Änderungen erhalten
  (verschiedene Properties). Bei derselben Property gewinnt die spätere Schreibung.
- **Audio** wird nach der Aufnahme nicht mehr verändert (nicht-destruktiv: Schnitt/
  Mix erzeugen neue Aufnahmen) → praktisch keine Audio-Konflikte.
- **Löschen** propagiert: Eine auf Gerät A endgültig gelöschte Aufnahme wird auf
  Gerät B entfernt. Papierkorb (30-Tage-Aufbewahrung) wird **pro Gerät** geleert;
  der Trash-Status (`isTrashed`/`deletedAt`) synchronisiert mit.

## Offline-Verhalten

- Ohne Netz/iCloud-Anmeldung arbeitet die App vollständig lokal weiter.
- Änderungen werden bei nächster Verbindung automatisch hoch-/heruntergeladen
  (CloudKit synchronisiert nur, während die App läuft).
- Der Sync-Status (Hochladen/Herunterladen/Aktuell/Fehler, letzte Zeiten,
  ausstehende Downloads, Verlauf) ist in **Einstellungen → iCloud** sichtbar.
- Der Schalter „iCloud-Sync" wirkt beim nächsten App-Start (der Store wird beim
  Start festgelegt).

## Grenzen / offene Punkte

- Große Audio-Assets brauchen Zeit und werden vom System gedrosselt; Sync nur im
  Vordergrund.
- `BGSystemTaskScheduler Code=3` (CloudKit-Hintergrund-Export) ist in der
  Entwicklung harmlos.
- Verifikation über zwei Geräte / zwei iCloud-Accounts steht als Geräte-Test aus
  (siehe DEVICE_TESTS.md).
