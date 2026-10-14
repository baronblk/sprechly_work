# Sprechly Work aufs iPhone laden

Verifiziert am 2026-10-13 mit Xcode 27.1 auf „Mein iPhone" (iPhone 17 Pro, iOS 27.0.1).

## Einmalig

Nichts. Automatisches Signing hat die App-IDs **und** den CloudKit-Container
`iCloud.de.gcng.sprechly.work` selbst im Developer-Portal angelegt – es war kein
manueller Schritt im Portal nötig. Team ist `KZFCCDV6A8` (in `app/project.yml`).

## Wie lange die App läuft

Die Signatur ist ein **Development-Profil eines bezahlten Developer-Accounts**,
Laufzeit 365 Tage:

| | |
|---|---|
| Profil | `iOS Team Provisioning Profile: de.gcng.sprechly.work` |
| Erstellt | 2026-10-13 |
| **Gültig bis** | **2027-10-13** |
| Zertifikat | Apple Development, Team `KZFCCDV6A8` |

Danach startet die App nicht mehr; ein erneuter Durchlauf von `scripts/deploy.sh`
genügt, dann läuft die Uhr wieder ein Jahr. Zum Vergleich: eine kostenlose Apple
ID bekäme **7 Tage** und maximal drei Apps.

**Die Daten bleiben dabei erhalten**, solange Bundle-ID *und* Signatur-Identität
gleich bleiben – neu installieren heißt überinstallieren, nicht vorher löschen.
Wechselt das Team oder die Bundle-ID, behandelt iOS es als andere App und die
Bibliothek ist weg.

TestFlight wäre hier **kein** Fortschritt: Builds verfallen dort nach 90 Tagen.

## In einem Befehl

```bash
cd app && ./scripts/deploy.sh
```

Erzeugt das Xcode-Projekt neu (nötig, weil die `.xcodeproj` gitignored ist und
Dateien explizit listet), baut signiert, **prüft die Identität gegen die
Store-App**, installiert und startet. Am Ende steht das Ablaufdatum der
Signatur. Mit `./scripts/deploy.sh <UDID>` für ein bestimmtes Gerät.

Die Einzelschritte darunter bleiben als Referenz, falls etwas klemmt.

## Bei jedem Durchlauf

```bash
# 1. Xcode-Projekt neu erzeugen, falls project.yml geändert wurde
cd app && xcodegen generate

# 2. Geräte-UDID holen
xcrun devicectl list devices | grep -v simulated

# 3. Signiert für das Gerät bauen
xcodebuild -project SprechlyWork.xcodeproj -scheme SprechlyWork \
  -destination 'id=<UDID>' -derivedDataPath .derivedData \
  -allowProvisioningUpdates build

# 4. Installieren und starten
xcrun devicectl device install app --device <UDID> \
  .derivedData/Build/Products/Debug-iphoneos/SprechlyWork.app
xcrun devicectl device process launch --device <UDID> de.gcng.sprechly.work
```

Das iPhone muss entsperrt und dem Mac vertraut sein.

## Gegenprobe der Identität

```bash
codesign -d --entitlements - .derivedData/Build/Products/Debug-iphoneos/SprechlyWork.app
```

Erwartet: `application-identifier KZFCCDV6A8.de.gcng.sprechly.work` und
`iCloud.de.gcng.sprechly.work`. Taucht dort `de.gcng.sprechly` **ohne** `.work`
auf, greift die App auf die Daten der Store-App zu – dann sofort stoppen.

## Erster Start am Gerät

1. Beim ersten Verbinden fragt iOS nach **Bluetooth** – erlauben, sonst bleibt
   der Work-Tab bei „Nicht verbunden".
2. Den Soundcore Work **vom Handy trennen**: Er erlaubt nur eine
   BLE-Verbindung gleichzeitig. Solange die Anker-App verbunden ist, findet
   Sprechly Work ihn nicht.
