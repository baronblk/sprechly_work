# SoundcoreWorkKit

Eigenständige Swift-Implementierung des Soundcore Work (D3200) BLE-Protokolls –
Handshake, Dateiliste, Download, Entschlüsselung und Ogg/Opus-Verpackung.

Implementiert nach `../docs/d3200_protocol_spec.md`. Kein übernommener
Fremdcode; die GPL-Referenzimplementierung wurde nicht herangezogen.

## Status

**Am eigenen Gerät verifiziert (2026-10-13).** Die Sequenz lief komplett durch
und erzeugte dieselbe Aufnahme **bitgenau** wie die Python-Referenz:

```
sha256  6458957895bef95fc047fdf3d20abca7b1a8f82ee485316d0f2cc9a2ac4859e0
        = fixtures/decrypted_4b4a7b69.ogg
ffprobe codec=opus  48000 Hz  stereo  0,9 s
```

| Bereich | Stand |
|---|---|
| XOR-Checksum, Command-Layouts (§2/§4) | ✅ offline + am Gerät |
| HKDF → Session-Key (§6.2) | ✅ harter Testvektor reproduziert |
| P-256-ECDH, Geräte-Public-Key-Parsing (§6.1) | ✅ am Gerät |
| File-Header-Parsing (§5) | ✅ am Gerät (97-B-Frame) |
| File-Key entpacken (§6.3) | ✅ am Gerät (Hülle `soundcored3200`) |
| Audio-Entschlüsselung (§6.4) | ✅ 45 Opus-Pakete à 160 B |
| Ogg/Opus-Writer (§7) | ✅ bitgenau identisch mit der Referenz |
| `BLETransport` (§1/§3) | ✅ am Gerät (Scan, Connect, Notify, MTU) |
| `D3200Client`-Sequenz (§3) | ✅ am Gerät, voller Download |
| Schrittweite der Listen-Einträge | ⚠️ offen – siehe unten |

```bash
swift test                              # 41 Tests, kein Gerät nötig
cd ../tools/d3200ctl && swift run d3200ctl pull   # Lauf am echten Gerät
```

## Aufbau

```
Protocol/   RCSP-Framing, Commands, File-Header, Opcodes
Crypto/     AES-CTR (CommonCrypto), ECDH + HKDF + File-Key (CryptoKit)
Audio/      Ogg/Opus-Container inkl. Ogg-CRC32
Transport/  DeviceTransport-Protokoll + CoreBluetooth-Implementierung
D3200Client Orchestrierung der Gerätesequenz
```

`DeviceTransport` ist die Naht für Tests: `D3200Client` kennt kein CoreBluetooth.

## Benutzung

```swift
let client = D3200Client(transport: BLETransport())
try await client.connect()
try await client.authenticate()
try await client.syncTime()
let recordings = try await client.listRecordings()

try await client.performKeyExchange()   // zwingend VOR dem ersten Download
let download = try await client.download(fileID: recordings[0].fileID) { done, total in
    print("\(done)/\(total)")
}
try download.oggOpus().write(to: url)
```

Für die App braucht das Target den Eintrag `NSBluetoothAlwaysUsageDescription`
in der Info.plist.

## Was der Live-Test ergeben hat

Der Lauf mit `tools/d3200ctl` hat fünf Punkte geklärt; alle Korrekturen sind in
`../docs/d3200_protocol_spec.md` eingearbeitet.

1. **Chunk-Zuschnitt.** `frame[12:]` eines `08b0`-Chunks ist **ein vollständiger
   164-B-Frame des Rohformats**, keine nackte 160-B-Nutzlast. Frame-Länge 176 B,
   45 Chunks ⇒ 7380 B = Größe von `fixtures/raw_4b4a7b69.bin`. BLE-Download und
   gespeicherte Rohdatei sind damit identisch, und beide Wege laufen durch
   `D3200Crypto.decryptRawStream`. `frame[9]` zählt die Frames ab 0; der Client
   prüft die Reihenfolge darüber.
2. **Listen-Opcode.** Die Antwort trägt `0e1c` (nicht `0e0c`, das sind die
   Command-Bytes), die Einträge beginnen auf Offset **11** (nicht 10), davor
   steht auf 9/10 ein Eintragszähler. Eine leere Folgeseite antwortet mit `0e14`.
3. **Auth-Token.** 19 B, wie die Byte-Folge vorgibt – das Gerät bestätigt mit
   `030a`. Die 20 B der Spec-Prosa waren falsch.
4. **Eine `0712`-Anforderung genügt**: sie liefert erst den `0761`-Header und
   direkt danach den Chunk-Stream.
5. **Response-Checksum gibt es nicht.** Die XOR-Regel aus §2 gilt nur für
   Commands; bei `08b0` reicht die Nutzlast bis zum letzten Byte
   (12 + 164 = 176). Das Feld „checksum" in §5 ist ein Header-Feld.

### Noch offen

**Schrittweite der Listen-Einträge.** Am Testgerät lag nur eine Aufnahme vor;
hinter dem Eintrag standen 8 Nullbytes – entweder Reserve des Eintrags
(Schrittweite 16) oder Padding der Antwort (Schrittweite 8). `parseList` nutzt
ein 8-Byte-Raster plus Plausibilitätsfilter und liefert damit in beiden Fällen
dasselbe Ergebnis. Mit einer **zweiten Aufnahme** auf dem Gerät abschließend
klären: `d3200ctl list` zeigt den vollen Frame.

## Sicherheits-Hinweis

Session-Key und File-Key sind allein aus dem BLE-Handshake plus
geräteübergreifend gleichen Konstanten ableitbar; das Gerät authentifiziert
seinen Gegenüber nicht (Spec §8). Nur am eigenen Gerät verwenden.
