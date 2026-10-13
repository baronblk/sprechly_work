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
| Live-Ereignisse Start/Ende (§9) | ✅ am Gerät, 3 Zyklen reproduziert |
| Akkustand / Gerätestatus | ❌ Gerät pusht ihn nicht, Abfrage-Command unbekannt |
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

### Live-Status

`D3200Client.events()` liefert die unaufgeforderten Ereignisse des Geräts:

```swift
Task {
    for await event in await client.events() {
        switch event {
        case .recordingState(let fileID, let state) where state.isRecording:
            …   // am Work wurde gerade eine Aufnahme gestartet
        case .recordingFinished(let fileID, let seconds):
            …   // fertig – jetzt ist sie in der Dateiliste
        case .unknown(let group, let type, _):
            …   // noch nicht zugeordnet, bewusst durchgereicht
        }
    }
}
```

**Pause ist über BLE unsichtbar.** Das Gerät kann pausieren, meldet es aber
nicht: bei Start → Pause → Weiter → Stop kamen nur ein Start- und ein
Ende-Push mit derselben `file_id`, und die Liste zeigte danach **eine**
Aufnahme (35,4 s). Die App kann deshalb „läuft" und „fertig" anzeigen, aber
keinen Pause-Zustand – eine Pause-Anzeige wäre geraten.

### Noch offen

**Akkustand und Gerätestatus.** In ~6 min Mitschnitt kam dazu kein einziges
Frame, und ein Abfrage-Command steht nicht in der Spec. Das lässt sich nur
durch Durchprobieren unbekannter Command-Bytes klären.

**Statuscodes des Start-Pushes.** Der Code war in allen Beobachtungen `2`.
Ob es weitere Werte gibt, ist offen – unbekannte Codes gehen daher
unverändert durch.

## Sicherheits-Hinweis

Session-Key und File-Key sind allein aus dem BLE-Handshake plus
geräteübergreifend gleichen Konstanten ableitbar; das Gerät authentifiziert
seinen Gegenüber nicht (Spec §8). Nur am eigenen Gerät verwenden.
