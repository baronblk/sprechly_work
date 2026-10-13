# SoundcoreWorkKit

Eigenständige Swift-Implementierung des Soundcore Work (D3200) BLE-Protokolls –
Handshake, Dateiliste, Download, Entschlüsselung und Ogg/Opus-Verpackung.

Implementiert nach `../docs/d3200_protocol_spec.md`. Kein übernommener
Fremdcode; die GPL-Referenzimplementierung wurde nicht herangezogen.

## Status

| Bereich | Stand |
|---|---|
| XOR-Checksum, Command-Layouts (§2/§4) | ✅ gegen Spec + Fixture getestet |
| HKDF → Session-Key (§6.2) | ✅ harter Testvektor reproduziert |
| P-256-ECDH, Geräte-Public-Key-Parsing (§6.1) | ✅ offline getestet, am Gerät noch offen |
| File-Header-Parsing (§5) | ✅ gegen Fixture getestet |
| File-Key entpacken (§6.3) | ✅ Hülle `soundcored3200` verifiziert |
| Audio-Entschlüsselung (§6.4) | ✅ 45 Opus-Pakete à 160 B |
| Ogg/Opus-Writer (§7) | ✅ **bitgenau identisch** mit `decrypted_4b4a7b69.ogg` |
| `BLETransport` (§1/§3) | ⚠️ geschrieben, noch **nicht am Gerät** getestet |
| `D3200Client`-Sequenz (§3) | ⚠️ geschrieben, noch **nicht am Gerät** getestet |

```bash
swift test   # 37 Tests, kein Gerät nötig
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

## Offene Punkte für den Live-Test (Schritt 2)

Vorher: Work vom Handy trennen – BLE erlaubt nur eine Verbindung.

1. **Chunk-Nutzlast.** Spec §2 sagt `frame[12:]` ergibt 160 B. Jeder
   Response-Frame endet laut §2 aber auf ein Checksum-Byte. `audioPayload(from:)`
   verwirft deshalb ein überzähliges Byte, wenn die Länge `% 160 == 1` ist.
   Am Gerät prüfen, wie lang ein `08b0`-Frame wirklich ist – bei MTU 512 könnte
   er auch mehrere Pakete tragen. Ein falscher Zuschnitt fällt sofort auf:
   `download(...)` wirft `incompleteAudio`, wenn die Summe kein Vielfaches von
   160 ist.
2. **Auth-Token-Länge.** Der Base64-String aus §4
   (`AZDxUbC0xETNAC9H16acXvtLeQ==`) dekodiert zu **19** Byte, die Spec-Prosa
   nennt 20. Implementiert ist die Byte-Folge aus dem Mitschnitt. Da das Gerät
   den Token nicht validiert, sollte das genügen – falls Auth fehlschlägt, ist
   das der erste Verdacht.
3. **Dateilisten-Opcode.** `0x0e0c` auf Offset 6 ist aus §4 übernommen, aber
   nicht durch eine Fixture belegt (anders als `0761`). Bei leerer Liste zuerst
   den echten Opcode der Antwort mitschneiden.
4. **Eine oder zwei `0712`-Anforderungen.** §3 liest sich so, dass dieselbe
   Anforderung erst den Header und dann den Chunk-Stream auslöst. `download(...)`
   sendet sie genau einmal. Bleibt es nach dem `0761` still, ein zweites Mal senden.
5. **Response-Checksum.** Die Response-Frames aus `session_4b4a7b69.json`
   (`09ff00000101a60a00ba`) erfüllen die XOR-Regel aus §2 **nicht** – das letzte
   Byte wird daher nicht als Integritätsprüfung verwendet. Falls der Algorithmus
   noch gebraucht wird, hier mitschneiden.

## Sicherheits-Hinweis

Session-Key und File-Key sind allein aus dem BLE-Handshake plus
geräteübergreifend gleichen Konstanten ableitbar; das Gerät authentifiziert
seinen Gegenüber nicht (Spec §8). Nur am eigenen Gerät verwenden.
