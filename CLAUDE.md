# Sprechly Work – Projekt-Briefing (für Claude Code)

**Ziel:** Eine eigenständige iOS/macOS-App „Sprechly Work", die den **Anker
Soundcore Work (D3200)** AI-Rekorder lokal nutzbar macht: Aufnahmen per BLE
holen, lokal entschlüsseln, mit Whisper transkribieren – ohne Anker-Konto/Cloud.

**Privater Test, kein Store-Release.** Basis ist die bestehende Sprechly-App
(VoxStudio), aber als **eigene App mit eigener Identität**. Das offizielle
Store-Projekt bleibt unberührt.

---

## Stand (was schon bewiesen ist)
Das Geräteprotokoll ist vollständig reverse-engineert und an Renes eigenem Gerät
**verifiziert**: BLE-Scan, ECDH-Handshake, Dateiliste, Download und lokale
Entschlüsselung einer echten Aufnahme zu gültigem Ogg/Opus funktionieren.

- Vollständige Spec: `docs/d3200_protocol_spec.md`
- Verifizierte Krypto-/E2E-Testvektoren: `docs/test_vectors.md`
- Referenz-Fixtures einer echten Aufnahme: `fixtures/`
- Lauffähige Python-Referenz (nur als Vergleich, GPL-3.0, NICHT kopieren):
  `~/Developer/soundcore-work/d3200-downloader/`

## Rechtlich / Lizenz (wichtig)
Die Community-Referenz (d3200-ble-note-downloader, tacshi/Soundcore) ist **GPL-3.0**.
Für Sprechly Work: Protokoll **aus `docs/` verstehen und eigenständig in Swift neu
implementieren** – keinen GPL-Code übernehmen. Byte-Layouts/UUIDs/Algorithmen sind
Fakten (nicht schützbar) und dienen der Interoperabilität am eigenen Gerät (§ 69e UrhG).

---

## Neue App-Identität (Pflicht – sonst Kollision mit der echten Sprechly-App)
| Was | Wert |
|-----|------|
| Bundle-ID (App) | `de.gcng.sprechly.work` |
| Target / Produktname | `SprechlyWork` |
| Anzeigename | `Sprechly Work` |
| Widgets-Bundle-ID | `de.gcng.sprechly.work.widgets` |
| Tests | `de.gcng.sprechly.work.tests` |

Beim Kopieren der VoxStudio-Basis ALLE `de.gcng.sprechly`-Identifier auf
`de.gcng.sprechly.work` umstellen (App-Group/iCloud-Container ggf. ebenfalls neu,
damit keine Daten der Store-App berührt werden).

---

## Bauplan

### Schritt 0 – VoxStudio-Basis hereinkopieren (ohne Build-Müll, ohne .git)
```bash
rsync -a --exclude='.git' --exclude='.derivedData' --exclude='DerivedData' \
      --exclude='build' --exclude='Screenshots' --exclude='.DS_Store' \
      ~/Development/Tools/src/de.gcng.voxstudio/  ~/Development/Tools/src/sprechly_work/app/
```
Danach: Target/Scheme/Bundle-IDs auf die neue Identität umstellen (siehe Tabelle),
Anzeigename auf „Sprechly Work", und einmal sauber bauen, bevor Neues dazukommt.

### Schritt 1 – `SoundcoreWorkKit` (lokales Swift Package) ← HIER STARTEN
Eigenständiges Package, unabhängig testbar. Implementiere exakt nach
`docs/d3200_protocol_spec.md`:

```
SoundcoreWorkKit/
  Package.swift
  Sources/SoundcoreWorkKit/
    Protocol/RCSPFrame.swift        # Frame bauen/parsen, XOR-Checksum, Opcodes
    Protocol/D3200Commands.swift    # auth, timeSync, listFiles, fileDetail, ecdh
    Protocol/D3200FileHeader.swift  # Header-Parsing (§5)
    Crypto/AESCTR.swift             # CommonCrypto kCCModeCTR (CryptoKit kann kein CTR!)
    Crypto/D3200Crypto.swift        # P256 ECDH (CryptoKit), HKDF(salt/info=010203),
                                    # fileKey-unwrap, chunk-decrypt
    Audio/OggOpusWriter.swift       # 160-B-Opus-Pakete → Ogg (OpusHead/Tags/Pages)
    Transport/DeviceTransport.swift # protocol: connect/write/notifications (async)
    Transport/BLETransport.swift    # CoreBluetooth-Implementierung
    D3200Client.swift               # Orchestrierung (Sequenz §3)
  Tests/SoundcoreWorkKitTests/
    CryptoTests.swift               # HKDF→qc_key, fileKey-unwrap (Vektoren §test_vectors)
    DecryptE2ETests.swift           # fixtures/raw → == decrypted_4b4a7b69.ogg
    FrameTests.swift                # XOR-Checksum, Command-Byte-Layouts
    Fixtures/                       # Kopien aus ../../fixtures (als Package-Resource)
```
**Zuerst Crypto + Decrypt gegen die Fixtures grün bekommen** (kein Gerät nötig,
reiner Offline-Test). Erst wenn `swift test` die Vektoren reproduziert, weiter.

### Schritt 2 – BLE-Transport (CoreBluetooth)
`BLETransport` nach Spec §1/§3. Am echten Gerät testen (Work darf nicht mit dem
Handy verbunden sein – nur eine BLE-Verbindung gleichzeitig). Scan nach Service-UUID.

### Schritt 3 – Integration in die App
Neues Feature „Work-Import" in der kopierten Sprechly-Basis:
- Geräte-Scan/Connect, Akku/Status, Aufnahmeliste
- Download + Entschlüsselung via `SoundcoreWorkKit` → Opus in die bestehende Library
- Bestehende Sprechly-Transkription (Whisper) auf die importierten Opus-Dateien anwenden

### Schritt 4 – lokal aufs iPhone
Eigenes Signing/Provisioning für `de.gcng.sprechly.work`, auf Renes Gerät laden.

---

## Dev-Umgebung (verifiziert)
Xcode 27.1, Swift 6.4, iOS-Deployment-Target 26.0 (wie VoxStudio). CryptoKit für
P256/HKDF, CommonCrypto für AES-CTR.

## Gerät für Live-Tests
Soundcore Work BLE-Name „soundcore Work", Service `020cf5da-…`. Für den Mac-Test
(bleak/Python-Referenz) lag RSSI ~ -50. Vor jedem Live-Test: Work vom Handy trennen.
