# Soundcore Work (D3200) – Protokoll-Spezifikation

Eigenständige, implementierungsfertige Spezifikation. Erstellt aus eigenem
BLE-Mitschnitt am eigenen Gerät + Abgleich mit öffentlichen Community-Projekten.
Enthält **nur Protokollfakten** (UUIDs, Byte-Layouts, Algorithmen) – kein
übernommener Fremdcode. Diese Fakten sind nicht urheberrechtlich geschützt und
dienen der Interoperabilität (§ 69e UrhG) am eigenen Gerät.

Alle Werte an eigenem Gerät (Pixel-Mitschnitt + macOS-Download) verifiziert.

---

## 1. Transport

- **BLE GATT.** Steuerung **und** Audio-Download laufen über BLE (JieLi RCSP-Framing).
- Daneben existiert ein schnellerer WLAN-SoftAP+WebSocket-Pfad (hier nicht spezifiziert;
  für iOS ist der BLE-Weg der richtige, weil CoreBluetooth-nativ und ohne MFi).

### GATT
| Rolle | UUID |
|-------|------|
| Service | `020cf5da-0000-1000-8000-00805f9b34fb` |
| Write (App→Gerät), *write without response* | `00007777-0000-1000-8000-00805f9b34fb` |
| Notify (Gerät→App) | `00008888-0000-1000-8000-00805f9b34fb` |

Beim Verbinden: Notifications auf dem Notify-Characteristic aktivieren (CCCD),
dann MTU aushandeln (beobachtet: 512).

Scan: nach dem Service-UUID filtern (das Gerät nutzt eine zufällige BLE-Adresse).
Hinweis: BLE erlaubt nur **eine** aktive Verbindung – das Gerät darf während des
Scans/Verbindens nicht mit dem Handy verbunden sein.

---

## 2. Frame-Format (RCSP)

### Command (App → Gerät)
```
08 EE 00 00 | <payload…> | <checksum>
```
- Präfix: `08 EE 00 00` (2 Byte Magic „Command", 2 Byte reserviert = 00 00)
- `checksum` = **XOR aller payload-Bytes** (nur der payload, ohne Präfix), 1 Byte.

### Response / Event (Gerät → App, per Notify)
```
09 FF 00 00 | <payload…> | <checksum>
```
- Präfix: `09 FF 00 00`.
- Der **Opcode** steht in `response[6:8]` (die ersten zwei payload-Bytes hinter dem Präfix).

### Bekannte Response-Opcodes (`response[6:8]`)
| Opcode | Bedeutung |
|--------|-----------|
| `07 61` | File-Detail-Antwort (enthält File-Header, siehe §5) |
| `08 b0` | Audio-Daten-Chunk (Nutzlast = `frame[12:]`) |
| `0a 13` | Transfer abgeschlossen (`total = LE32(data[10:14])`) |
| `06 12` | Metadaten-Push (überspringen) |
| `18 82` | Transfer-Init |

---

## 3. Verbindungs-/Download-Sequenz

Am eigenen Gerät verifizierte, funktionierende Reihenfolge:

1. **Scan** nach Service-UUID → verbinden → Notify aktivieren.
2. **Auth** senden (statischer Token, Gerät validiert ihn nicht).
3. **Time-Sync** senden.
4. **Dateiliste** abrufen (paginiert).
5. **ECDH-Handshake** (ein einziges `014b`, QC-Keypair) → Session-Key ableiten.
6. **File-Detail** anfordern (`0712` + file_id) → liefert `0761`-Response mit File-Header.
7. **Audio-Download**: dieselbe `0712`-Anforderung stößt den Chunk-Stream (`08b0`) an,
   abgeschlossen durch `0a13`.
8. Entschlüsseln (siehe §6) → Opus-Pakete → Ogg/Opus.

> Reihenfolge-Hinweis vom eigenen Gerät: ECDH **vor** der File-Detail-Anforderung
> ausführen. Eine Detail-Anforderung vor ECDH stößt sofort den Download an und
> „verschluckt" die ECDH-Antwort.

---

## 4. Command-Payloads

Notation: Payload-Bytes (hinter Präfix `08 EE 00 00`, vor dem XOR-Checksum).

| Befehl | Payload (hex) | Felder |
|--------|---------------|--------|
| Auth | `00 0b 03 27 00 1c` + `<token 20B>` + `15` | Token = base64-dekodiert von `AZDxUbC0xETNAC9H16acXvtLeQ==` (statisch) |
| Time-Sync | `00 01 a6 14 00` + `<ts LE32>` + `0a 90 ff e6 6a 08` | ts = Unix-Sekunden |
| Dateiliste | `00 1a 0e 0c 00 <page> 00 2a` | page = 0,1,2,… bis leere Seite |
| File-Detail / Download | `00 1a 07 12 00 00 00 00 00` + `<file_id 4B>` | file_id = 4 Byte, little-endian |
| ECDH | `00 2e 01 4b 00 04` + `<pubkey 64B>` | pubkey = X‖Y big-endian (unkomprimierter P-256-Punkt ohne 0x04-Präfix) |

### Dateiliste-Parsing (`0e0c`-Antwort)
Ab Offset 10 in 8-Byte-Einträgen: `file_id = LE32(data[i:i+4])`, `size = LE32(data[i+4:i+8])`.
Plausibel, wenn `1735000000 < file_id < 1800000000` (file_id ist der Aufnahme-Unix-Timestamp)
und `0 < size < 10_000_000`.

---

## 5. File-Header (aus `0761`-Response, ≥ 97 Byte)

| Feld | Offset | Länge |
|------|--------|-------|
| file_id | 9 | 4 (LE) |
| file_size | 13 | 4 (LE) |
| nonce | 17 | 16 |
| encryptedFileKey | 33 | 46 |
| sessionNonce | 79 | 16 |
| status | 95 | 1 |
| checksum | 96 | 1 |

---

## 6. Kryptografie

### 6.1 ECDH
- Kurve: **NIST P-256 (secp256r1)**.
- Eigener Public Key wird als 64 Byte `X‖Y` big-endian gesendet (im `014b`-Command).
- Geräte-Public-Key aus der Handshake-Response: SEC1-unkomprimiert, `0x04`-Marker
  bei Offset 9, danach `X` (32B) und `Y` (32B). Robust: nach `0x04` an Offsets
  9,8,10,6,7 suchen und Punkt gegen die Kurve validieren.
- Shared Secret = ECDH(eigener privater Key, Geräte-Public-Key) → 32 Byte (X-Koordinate).

### 6.2 Session-Key (HKDF)
```
session_key = HKDF-SHA256(
    ikm  = ecdh_shared_secret,   # 32 B
    salt = 0x01 0x02 0x03,       # fix, in allen Geräten gleich
    info = 0x01 0x02 0x03,       # fix
    L    = 32
)
```
RFC-5869-HKDF: `PRK = HMAC-SHA256(salt, ikm)`; `T(1) = HMAC-SHA256(PRK, info || 0x01)`;
`session_key = T(1)[:32]`.

### 6.3 Per-File-Key entpacken
```
plaintext = AES-256-CTR(key = session_key, iv = sessionNonce[16B], data = encryptedFileKey[46B])
# plaintext = b"soundcored3200" (14 B) || fileKey (32 B)
fileKey   = plaintext[14:46]
```

### 6.4 Audio entschlüsseln
Der rohe Audio-Stream besteht aus 164-Byte-Frames. Pro Frame:
- `payload = frame[2:162]` (160 Byte; die ersten 2 Byte sind RCSP-Frame-Präfix).
- `seq` = Frame-Index (0,1,2,…).
- `counter = nonce[0:12] ‖ BE32(seq * 10)` (16 Byte AES-CTR-IV; `nonce` aus dem File-Header).
- `opusPacket = AES-256-CTR(key = fileKey, iv = counter, data = payload)` → 160 Byte Opus.

> Hinweis: Beim BLE-Download kommen die 160-B-Nutzlasten bereits als `08b0`-Chunks
> (`frame[12:]`). Der 164-B/`frame[2:162]`-Zuschnitt oben gilt für das gespeicherte
> Rohformat; beide Wege liefern dieselben 160-B-Pakete in Reihenfolge.

### 6.5 AES-CTR auf Apple-Plattformen
CryptoKit bietet **kein** AES-CTR. Verwende `CommonCrypto`:
`CCCryptorCreateWithMode(kCCEncrypt, kCCModeCTR, kCCAlgorithmAES, ccNoPadding,
iv(16B), key(32B), keyLen, …)` mit `kCCModeOptionCTR_BE`. CTR ist symmetrisch
(Ent-/Verschlüsseln identisch). P-256-ECDH und HKDF-SHA256 kommen aus CryptoKit
(`P256.KeyAgreement`, `HKDF<SHA256>`), wobei HKDF hier mit den fixen salt/info-Bytes
zu parametrisieren ist.

---

## 7. Opus → Ogg-Container
Die entschlüsselten 160-B-Pakete sind rohe Opus-Pakete. Zum Abspielen in einen
Ogg/Opus-Container verpacken:
- OpusHead: 2 Kanäle, pre-skip 312, input sample rate 16000.
- OpusTags: beliebig (Vendor/Comments).
- Danach je ein Opus-Paket pro Ogg-Page, granule = (index+1) * 960.

ffprobe am eigenen Ergebnis bestätigte: `codec=opus, 48000 Hz, stereo` (Opus dekodiert
intern immer auf 48 kHz).

---

## 8. Sicherheits-Hinweis (ISB-relevant)
Der Session-Key ist allein aus dem BLE-Handshake plus **geräteübergreifend gleichen**
Konstanten (salt/info = 010203) ableitbar; das Gerät prüft den Auth-Token nicht und
authentifiziert den Verbindungspartner nicht. Jeder BLE-Client in Reichweite eines
nicht gekoppelten Geräts kann damit Aufnahmen lesen. Für dieses Projekt: nur am
eigenen, bewusst gekoppelten Gerät nutzen. Für Anker ein Fall für Responsible Disclosure.
