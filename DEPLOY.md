# Sprechly Work aufs iPhone laden

Verifiziert am 2026-10-13 mit Xcode 27.1 auf „Mein iPhone" (iPhone 17 Pro, iOS 27.0.1).

## Einmalig

Nichts. Automatisches Signing hat die App-IDs **und** den CloudKit-Container
`iCloud.de.gcng.sprechly.work` selbst im Developer-Portal angelegt – es war kein
manueller Schritt im Portal nötig. Team ist `KZFCCDV6A8` (in `app/project.yml`).

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
