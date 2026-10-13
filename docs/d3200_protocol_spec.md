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

### Vollständiger Command-Katalog (cmdType/cmdId, aus Community-Repo)
Ergänzt die verifizierten Rohpayloads oben. Frame beim Senden immer über den
`08ee`-Kanal an `0xA102` mit XOR-Checksum (§2); Längen-/Byte-Wrapping beim
Implementieren einmal gegen das reale Gerät gegenprüfen.

| Funktion | cmdType | cmdId | Payload |
|----------|---------|-------|---------|
| Device-Info | 0x01 | 0x01 | – |
| Factory-Reset | 0x01 | 0xB8 | – |
| Time-Sync | 0x01 | 0xA6 | tz/ts |
| Record Start/Resume | 0x18 | 0x82 | `01` |
| Record Pause | 0x18 | 0x82 | `02` |
| Dateiliste | 0x1A | 0x0E | u16LE(page) |
| Dateiliste (alt) | 0x1B | 0x0E | u16LE(page) |
| Datei löschen | 0x1A | 0x10 | u32LE(fileId) – **am Gerät verifiziert**, siehe §7d |
| BT-Transport starten | 0x1A | 0x0F | `00` (iOS: `01`) |
| BT-Transport stoppen | 0x1A | 0x11 | `00` (iOS: `01`) |
| Datei-Transfer (Download) | 0x1A | 0x07 | fileId + realtimeFlag |
| WLAN-SoftAP konfigurieren | 0x1A | 0x05 | `[ssid_len][ssid][pwd_len][pwd]` |
| WLAN schließen | 0x1A | 0x02 | – |
| ECDH-Handshake | 0x2E | 0x01 | pubkey |
| Binding | 0x0B | 0x87 | `01`/`00` |
| Einstellung (More) | 0x10 | 0xA2 | `01`/`00` |

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

## 7a. Record-Control (bidirektional) – aus Community-Repo verifiziert

Die Aufnahme wird über **cmdType `0x18`, cmdId `0x82`** ferngesteuert (Payload 1 Byte):

| Aktion | cmdType/cmdId | Payload | Hinweis |
|--------|---------------|---------|---------|
| **Start** | 0x18 / 0x82 | `01` | neue Aufnahme |
| **Pause** | 0x18 / 0x82 | `02` | |
| **Resume** | 0x18 / 0x82 | `01` | identisch zu Start; Gerät erkennt Resume daran, dass der vorige Status 2 (pause) war |
| **Stop** | 0x18 / 0x82 | `00` | **Existiert** – am eigenen Gerät verifiziert, obwohl im Community-Katalog nicht enthalten. Der Wert ist derselbe wie der Statuscode 0. |

### Am eigenen Gerät verifiziert (2026-10-13)

Die Befehle wurden gesendet und das Gerät hat reagiert – damit sind sie Fakt,
nicht übernommene Annahme:

```
→ 08 ee 00 00 00 18 82 0b 00 01 90      Start
← 09 ff 00 00 01 18 82 0c 00 01 90 40   status = 1 (läuft)
← 09 ff 00 00 01 1a 06 12 00 58a1ce6a 02000000 6e   neue Aufnahme angelegt

→ 08 ee 00 00 00 18 82 0b 00 02 93      Pause
← 09 ff 00 00 01 18 82 0c 00 02 93 44   status = 2 (Pause)

→ 08 ee 00 00 00 18 82 0b 00 00 91      Stop
← 09 ff 00 00 01 18 82 0c 00 00 91 40   status = 0 (gestoppt)
← 09 ff 00 00 01 18 82 14 00 00 01 18000000 3facce6a f3
                                        fertig: 24 s, file_id 6acead3f
```

Der Stop liefert zwei Nachrichten: erst die kurze Bestätigung (12 B) mit
Status 0, dann die lange Fertig-Meldung (20 B) mit Dauer und `file_id` –
dieselbe, die auch bei einem Stop an der Hardwaretaste kommt.

Der Command trägt die Framelänge auf Offset 7 (`0x0b` = 11) wie jeder andere
Command auch; das Nutzbyte steht auf Offset 9.

**Status-Notification vom Gerät** (`0x18/0x82`): Das Statusbyte steht auf
**Offset 9**. `0 = stop, 1 = recording, 2 = pause`. Nur die Stop-Meldung des
Geräts ist mit 20 B lang genug, um danach `durationSec` (Offset 11) und
`fileId` (Offset 15) zu tragen; die Bestätigung eines eigenen Befehls ist
12 B lang und trägt beides nicht.

> **Korrektur gegenüber der Repo-Angabe:** `0x1A/0x06` ist **nicht** der
> Statuskanal. Diese Nachricht kündigt eine **neu angelegte Aufnahme** an und
> trug in allen Beobachtungen den Code `2` – auch während das Gerät lief.
> Wer `2` dort als „pause" liest, bekommt beim Start einen Pause-Zustand
> angezeigt. Der Status kommt ausschließlich aus `0x18/0x82`.

> Korrektur: Der im eigenen Capture als „Transfer init" notierte Opcode `18 82`
> ist in Wahrheit **Audio/Record-Control**.

## 7b. Geräte-Metadaten (Status-Notifications) – aus Repo verifiziert

Das Gerät meldet/liefert folgende Metadaten über cmdType `0x01` (Device-Info-Familie)
und verwandte Opcodes. Die App pollt zusätzlich alle ~15 s Device-Info, da manche
Firmwares nur auf Abfrage aktualisieren.

### Battery (cmdId `0x03`), payload ≥ 2 Byte
- `payload[0]` = Mic/Gerät-Akku, `payload[1]` = Ladecase-Akku.
- Werte sind **0–9 Buckets**, nicht direkt Prozent. Umrechnung:
  `prozent = raw <= 9 ? (raw + 1) * 10 : raw` (0→10 %, 9→100 %).

### Charging (cmdId `0x04`), payload ≥ 2 Byte
- `payload[0]` = Gerät lädt (1/0), `payload[1]` = Ladecase lädt (1/0).

### Am eigenen Gerät verifiziert (2026-10-13)

Alle drei Abfragen wurden gesendet und beantwortet. Abfrage-Commands sind
10 B: `08 ee 00 00 | 00 <gruppe> <typ> 0a 00 | xor`.

```
→ 08 ee 00 00 00 01 03 0a 00 08        Akku
← 09 ff 00 00 01 01 03 0c 00 09 09 2b  Gerät 9, Case 9 → je 100 %

→ 08 ee 00 00 00 01 04 0a 00 0f        Laden
← 09 ff 00 00 01 01 04 0c 00 01 01 1c  beide 1

→ 08 ee 00 00 00 01 01 0a 00 0a        Geräte-Info
← 78-B-Antwort (siehe unten)
```

**Wichtig zur Offsetlage:** Bei Akku und Laden beginnen die Nutzdaten auf
**Offset 9**. Die Geräte-Info trägt dort ein zusätzliches Byte (`01`), ihre
Nutzdaten beginnen erst auf **Offset 10**. Wer beide gleich behandelt, liest
den Akku um ein Byte versetzt.

### Volles Device-Info (cmdId `0x01`), 78 B – am Gerät verifiziert

```
09 ff 00 00 01 01 01 4e 00 | 01 | 09 | 01 | 30332e3336 | 3332…3262 |
  0 .. 8                   | @9 |akku|lädt| fw 5 ASCII | serial 16 |
  a0387300 | a02e7300 | 01     | 312e312e38 | 09       | 212121212121 | …
  total @33| free  @37| case@41| caseFw @42 | caseAkku | caseMac @48  |
```

Am eigenen Gerät gelesen: Akku 9 (100 %), lädt, Firmware `03.36`,
Seriennummer `32007ce9131d272b`, 7 551 136 KB gesamt / 7 548 576 KB frei
(= 7,20 GiB, 2 560 KB belegt), Ladecase `1.1.8` mit Akku 9, MAC `21 21 …`
= Füllbytes. Hinter `caseMac` folgen weitere Felder, darunter eine zweite
Versionszeichenkette (`03.02`); sie sind nicht zugeordnet.

### Feldreihenfolge (Repo-Angabe, oben bestätigt)
Reihenfolge der Felder im Payload:
`batteryRaw(1) · chargingStatus(1) · firmware(5 ASCII) · serial(16 ASCII) ·
totalMemoryKB(u32 LE) · freeMemoryKB(u32 LE) · boxChargingFlag(1) ·
boxFirmware(5 ASCII) · boxBatteryRaw(1) · boxMac(6)` –
danach optionale Felder: deviceColor, autoPowerOffSwitch/Index, Indicator-Lights,
**recording-Bit**, WLAN-Firmware.
- Speicher: KB-Einheit (ein 64-GB-Gerät meldet ~60 Mio. KB). `used = total − free`.
- MAC-Filter: `21:21:…` oder `00:00:…` = Padding/ungültig → verwerfen.

### Weitere Status-Pushes
| Opcode | Bedeutung |
|--------|-----------|
| `0x18/0x82` | Record-Status: `payload[0]` 0=stop, 1=recording/resume, 2=pause; bei stop optional `durationSec` u32 @payload[1] |
| `0x1A/0x06` | neue Datei während Aufnahme: status=recording + `fileId` (LE) @payload[0] |
| `0x0B/0x87` | Bind-/Unbind-Ergebnis (Erfolg = low nibble des Status) |
| `0x0B/0x88` | Geräte-Bestätigung nach Bind |
| `0x2E/0x01` | ECDH-RX: devPub = `raw[9:74]` (65 B), zusätzliches Material `raw[74:106]` |

**Für Sprechly Work** damit anzeigbar: Mic-Akku %, Case-Akku %, Laden ja/nein,
Firmware-Version, Seriennummer, belegter/freier Speicher, Aufnahme-Status, Case-MAC.

## 7c. Realtime-Audio-Stream (Live-Pegel + Live-Transkription)

Die App steuert nur fern – das **Gerät** nimmt auf, nicht das iPhone-Mikro. Einen
Live-Pegel oder Live-Audio gibt es daher **nur** über den Realtime-BLE-Stream:

- Gestartet mit **`startTransportAudioFile` (0x1A/0x07)** und `realtimeFlag = 1`,
  `preferSpp = false` → das Gerät schickt **während der Aufnahme** laufend
  Opus-Slices über den Notify-Kanal (kein SoftAP).
- Jeder Slice wird wie beim Download entschlüsselt (AES-256-CTR, §6) → 160-B-Opus-
  Paket → Opus-Decode zu PCM16.
- **Aufnahmepegel** = RMS/Peak der dekodierten PCM-Samples pro Frame (z. B.
  `level = sqrt(mean(sample²))`, geglättet). Es gibt kein separates Pegel-Feld
  im Protokoll – der Pegel wird clientseitig aus dem Live-PCM berechnet.
- Dasselbe PCM speist die **Live-Transkription** (bei tacshi: Stream an Soniox;
  bei Sprechly Work: an das lokale Whisper/SpeechAnalyzer).

> Ohne diesen Stream gibt es systembedingt keinen Pegel – das ist ein zu bauendes
> Feature, kein Bug.

## 7d. Aufnahme löschen – am Gerät verifiziert (2026-10-14)

```
→ 08 ee 00 00 00 1a 10 0e 00 31 b2 ce 6a <xor>   löscht 6aceb231
← 09 ff 00 00 01 1a 10 0a 00 ..                  Bestätigung, 10 B
```

14-Byte-Command: Gruppe `0x1a`, Typ `0x10`, Länge auf Offset 7, danach ein
Nullbyte und die `file_id` als LE32. Die vier Füllbytes der
Download-Anforderung braucht es hier **nicht**.

> **Eigenheit:** Das Gerät bestätigt sofort, aber die Dateiliste zeigt die
> Aufnahme noch eine Weile weiter. Direkt nach der Bestätigung neu aufzulisten
> liefert sie unverändert mit – gelöscht ist sie trotzdem; beim nächsten
> Verbinden fehlt sie. Eine Oberfläche darf sich deshalb nicht auf ein
> sofortiges Neuladen verlassen, sondern muss den Eintrag selbst entfernen.
>
> Genau daran wäre die Prüfung fast gescheitert: Der erste Versuch galt als
> wirkungslos, weil die Liste unmittelbar danach noch 22 Einträge zeigte.

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

> Siehe §7a: der Aufnahme**status** kommt aus `0x18/0x82`. Die hier
> beschriebene Nachricht `1a/06` meldet nur, dass eine neue Aufnahme
> angelegt wurde.

### Neue Aufnahme angelegt — Gruppe `1a`, Typ `06`, 18 B
```
09 ff 00 00 01 1a 06 12 00 | c7 9b ce 6a | 02 00 00 00 | d7
  0 .. 8                   | file_id @9  | code @13    | Rest
```
- `file_id = LE32(data[9:13])` – die ID der **neu entstehenden** Aufnahme.
- `code = LE32(data[13:17])` – in allen Beobachtungen **2**, auch während das
  Gerät aufnahm. Das ist **nicht** der Aufnahmestatus (siehe §7a).

### Aufnahme beendet — Gruppe `18`, Typ `82`, 20 B
Das ist die Stop-Meldung des Record-Control-Kanals (§7a) mit `status = 0`.
```
09 ff 00 00 01 18 82 14 00 | 00 | 01 | 14 00 00 00 | c7 9b ce 6a | 66
  0 .. 8                   |stat| ?  | dauer_s @11 | file_id @15 | Rest
```
- `dauer_s = LE32(data[11:15])` – Dauer in **ganzen Sekunden** (abgerundet).
  Gegenprobe: Push meldete 11 s, die Dateiliste für dieselbe Aufnahme 11,1 s.
- `file_id = LE32(data[15:19])` – dieselbe ID wie im Start-Push.

### Verhalten des Geräts
- **Pause an der Hardwaretaste ist über BLE unsichtbar** – anders als eine
  ferngesteuerte Pause, die der Status quittiert (§7a). Verifiziert mit der Sequenz
  Start → Pause → Weiter → Stop: es kam nur ein Start-Push (48,6 s) und ein
  Ende-Push (81,3 s) mit **derselben** `file_id`, und in der Dateiliste stand
  danach **eine** Aufnahme (`6ace9c87`, 35,4 s). Pause/Weiter bleibt also
  innerhalb einer Aufnahme.
  Eine App kann daher nur „läuft" und „fertig" anzeigen, keinen Pause-Zustand.
- Mehrere getrennte Aufnahmen entstehen durch Stop und erneutes Start – dabei
  bekommt jedes Segment eine eigene `file_id` (beobachtet: Ende 20 s, dann
  Start mit neuer ID, Ende 13 s).
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
