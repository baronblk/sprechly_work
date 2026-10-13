# Soundcore Work (D3200) – Protokoll-Spezifikation

Eigenständige, implementierungsfertige Spezifikation. Erstellt aus eigenem
BLE-Mitschnitt am eigenen Gerät + Abgleich mit öffentlichen Community-Projekten.
Enthält **nur Protokollfakten** (UUIDs, Byte-Layouts, Algorithmen) – kein
übernommener Fremdcode. Diese Fakten sind nicht urheberrechtlich geschützt und
dienen der Interoperabilität (§ 69e UrhG) am eigenen Gerät.

Alle Werte an eigenem Gerät (Pixel-Mitschnitt + macOS-Download) verifiziert.

**Stand 2026-10-13:** Die eigenständige Swift-Implementierung (`SoundcoreWorkKit`)
hat die Sequenz am Gerät komplett durchlaufen und dieselbe Aufnahme
bitgenau (SHA-256-gleich) wie die Python-Referenz erzeugt. Die dabei
gefundenen Abweichungen von der ursprünglichen Fassung sind unten direkt
eingearbeitet und als „am Gerät verifiziert/korrigiert" markiert:
Listen-Opcode `0e1c` statt `0e0c`, Listen-Einträge ab Offset 11 statt 10,
Auth-Token 19 B statt 20 B, `08b0`-Nutzlast = 164-B-Rohframe statt 160-B-Paket,
und Responses tragen keinen Checksum-Trailer.

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
09 FF 00 00 | <flag> | <group> <cmd> <sub> | <daten…>
  0  1  2  3 |   4    |   5      6     7   | 8 …
```
- Präfix: `09 FF 00 00`.
- Der **Opcode** steht in `response[6:8]`.
- **Kein Checksum-Trailer.** Die XOR-Regel gilt nur für Commands; bei Responses
  reichen die Daten bis zum letzten Byte (am Gerät verifiziert: ein `08b0`-Frame
  ist 176 B = 12 B Kopf + 164 B Nutzlast, da bleibt kein Platz für eine Checksum).
  Das Feld „checksum" in §5 ist ein Header-*Feld*, kein Frame-Trailer.
- `response[5:7]` spiegelt `command[1:3]`; `response[7]` ist der Antwort-Subcode.
  Darum unterscheidet sich der Response-Opcode vom Command (`0e0c` → `0e1c`).

### Bekannte Response-Opcodes (`response[6:8]`)
| Opcode | Länge | Bedeutung |
|--------|-------|-----------|
| `07 61` | 97 B | File-Detail-Antwort (enthält File-Header, siehe §5) |
| `08 b0` | 176 B | Audio-Daten-Chunk: `frame[12:]` = **ein vollständiger 164-B-Frame des Rohformats**; `frame[9]` = Frame-Zähler ab 0 |
| `0a 13` | 19 B | Transfer abgeschlossen: `size = LE32(data[10:14])`, danach `file_id = LE32(data[14:18])` |
| `01 6b` | 107 B | Antwort auf den ECDH-Handshake (`014b`), enthält den Geräte-Public-Key |
| `0e 1c` | var. | Dateilisten-Antwort (siehe §4) |
| `0e 14` | 20 B | leere Folgeseite = Listenende |
| `03 0a` | 10 B | Auth bestätigt |
| `a6 0a` | 10 B | Time-Sync bestätigt |
| Typ `06` | 18 B | **Aufnahme gestartet** (Gruppe `1a`) – unaufgefordert, siehe §9 |
| Typ `82` | 20 B | **Aufnahme beendet** (Gruppe `18`) – unaufgefordert, siehe §9 |

> Die Spec führte diese beiden als „`06 12` Metadaten-Push (überspringen)" und
> „`18 82` Transfer-Init". Beides war eine Fehldeutung: `0x12`/`0x14` sind die
> Framelängen (18/20), und bei `18 82` ist `0x18` die **Gruppe**, `0x82` der Typ.
> Beim Download taucht Typ `0x82` nie auf.

> Die Längen sind am eigenen Gerät gemessen (2026-10-13, Swift-Implementierung).

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
   abgeschlossen durch `0a13`. Am Gerät verifiziert: **ein** `0712` genügt – es
   liefert erst den `0761`-Header und direkt danach die Chunks.
8. Entschlüsseln (siehe §6) → Opus-Pakete → Ogg/Opus.

> Reihenfolge-Hinweis vom eigenen Gerät: ECDH **vor** der File-Detail-Anforderung
> ausführen. Eine Detail-Anforderung vor ECDH stößt sofort den Download an und
> „verschluckt" die ECDH-Antwort.

---

## 4. Command-Payloads

Notation: Payload-Bytes (hinter Präfix `08 EE 00 00`, vor dem XOR-Checksum).

| Befehl | Payload (hex) | Felder |
|--------|---------------|--------|
| Auth | `00 0b 03 27 00 1c` + `<token 19B>` + `15` | Token = base64-dekodiert von `AZDxUbC0xETNAC9H16acXvtLeQ==` = `0190f151b0b4c444cd002f47d7a69c5efb4b79` (19 B, nicht 20); Command ist 31 B lang |
| Time-Sync | `00 01 a6 14 00` + `<ts LE32>` + `0a 90 ff e6 6a 08` | ts = Unix-Sekunden |
| Dateiliste | `00 1a 0e 0c 00 <page> 00 2a` | page = 0,1,2,… bis leere Seite |
| File-Detail / Download | `00 1a 07 12 00 00 00 00 00` + `<file_id 4B>` | file_id = 4 Byte, little-endian |
| ECDH | `00 2e 01 4b 00 04` + `<pubkey 64B>` | pubkey = X‖Y big-endian (unkomprimierter P-256-Punkt ohne 0x04-Präfix) |

### Dateiliste-Parsing (`0e1c`-Antwort)
Der Command trägt `0e 0c`, die **Antwort** trägt `0e 1c`. Layout (am Gerät verifiziert):

```
09 ff 00 00 01 1a 0e 1c 00 | 01 00 | 4b 4a 7b 69 | 84 03 00 00 | 00×8 | 4e
                     opcode | count | file_id LE32 | size LE32   | Rest |
  0 .. 8                    | 9 10  | 11 .. 15     | 15 .. 19    | 19.. |
```

- `count = LE16(data[9:11])` – Anzahl Einträge (nur Diagnose).
- Einträge ab **Offset 11** als 8-Byte-Paare `file_id ‖ size`, je LE32.
- Plausibel, wenn `1735000000 < file_id < 1800000000` (file_id ist der
  Aufnahme-Unix-Timestamp) und `0 < size < 10_000_000`.
- Eine leere Folgeseite antwortet mit Opcode `0e 14` → Listenende.

> Die Schrittweite der Einträge ist nicht abschließend belegt: am Testgerät lag
> nur **eine** Aufnahme vor, hinter dem Eintrag standen 8 Nullbytes (entweder
> Reserve des Eintrags → Schrittweite 16, oder Padding der Antwort →
> Schrittweite 8). Das 8-Byte-Raster plus Plausibilitätsfilter liefert in beiden
> Fällen dasselbe Ergebnis, weil Nullbytes nie plausibel sind.
> Mit einer zweiten Aufnahme auf dem Gerät klären.

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

> Hinweis (am Gerät korrigiert): Beim BLE-Download liefert `frame[12:]` eines
> `08b0`-Chunks **genau einen 164-B-Frame des Rohformats**, nicht eine nackte
> 160-B-Nutzlast. Der Zuschnitt `frame[2:162]` oben gilt also für beide Wege;
> BLE-Download und gespeicherte Rohdatei sind Byte für Byte dasselbe.
> Gegenprobe: 45 Chunks à 176 B ⇒ 45 × 164 B = 7380 B = Größe von
> `fixtures/raw_4b4a7b69.bin`. Das erste Frame trägt die Flags `00 02`, das
> letzte `00 04`; `frame[9]` zählt die Frames ab 0.

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


---

## 9. Unaufgeforderte Ereignisse (Live-Status)

Sobald am Gerät selbst etwas passiert, schickt es ohne Anforderung Frames über
die Notify-Characteristic. Darauf beruht die Live-Anzeige in der App.

Am eigenen Gerät über vier Monitor-Läufe (~6 min) mit je drei Start/Stop-Zyklen
verifiziert (2026-10-13).

### Aufnahme gestartet — Gruppe `1a`, Typ `06`, 18 B
```
09 ff 00 00 01 1a 06 12 00 | c7 9b ce 6a | 02 00 00 00 | d7
  0 .. 8                   | file_id @9  | code @13    | Rest
```
- `file_id = LE32(data[9:13])` – die ID der **neu entstehenden** Aufnahme.
- `code = LE32(data[13:17])` – in allen Beobachtungen **2**. Ein anderer Wert
  ist nie aufgetreten, daher ist die Bedeutung als Zustandsraum nicht belegt;
  die Implementierung reicht unbekannte Codes unverändert durch.

### Aufnahme beendet — Gruppe `18`, Typ `82`, 20 B
```
09 ff 00 00 01 18 82 14 00 00 01 | 14 00 00 00 | c7 9b ce 6a | 66
  0 .. 10                        | dauer_s @11 | file_id @15 | Rest
```
- `dauer_s = LE32(data[11:15])` – Dauer in **ganzen Sekunden** (abgerundet).
  Gegenprobe: Push meldete 11 s, die Dateiliste für dieselbe Aufnahme 11,1 s.
- `file_id = LE32(data[15:19])` – dieselbe ID wie im Start-Push.

### Verhalten des Geräts
- **Es gibt kein Pause.** Jeder Tastendruck schaltet um; „pausieren und
  weiter" erzeugt **zwei getrennte Aufnahmen** mit eigenen `file_id`s.
  Beobachtet: Start → Ende (20 s) → Start (neue ID) → Ende (13 s).
- Der Start-Push kommt **~2 s nach** dem Tastendruck: die gemeldete Dauer liegt
  konstant 2–2,5 s über dem Abstand der beiden Pushes. Für die Anzeige ist
  daher die Dauer aus dem Ende-Push bzw. der Dateiliste maßgeblich, nicht die
  selbst gestoppte Zeit.
- Nur diese zwei Ereignisse treten auf. In ~6 min Mitschnitt kam **kein**
  Akkustand und **kein** Ereignis für andere Tasten (Lautstärke, Marker).

### Nicht bekannt
**Akkustand und sonstiger Gerätestatus.** Das Gerät pusht sie nicht, und ein
Abfrage-Command ist nicht bekannt. Dafür müsste man unbekannte Command-Bytes
durchprobieren – nicht aus diesem Mitschnitt ableitbar.
