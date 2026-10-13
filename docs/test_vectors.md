# Test-Vektoren (am eigenen Gerät verifiziert, 2026-10-13)

Diese Werte stammen aus einem echten Download+Decrypt am eigenen Soundcore Work.
Nutze sie als Unit-Test-Vektoren für die Swift-Portierung – die Swift-Implementierung
muss sie bitgenau reproduzieren.

## 1. HKDF → Session-Key (harter Krypto-Vektor)
```
ecdh_shared_secret = 28f3e8f5314a47640bebe10b1bd3d32d5d0feda73babe80080f92bdf69806b30
salt               = 010203
info               = 010203
erwarteter key     = 4f69a99087eda5ec0704d56dbd51707eab67218d2ed91deea0520ce05faaab3d
```
Test: `HKDF-SHA256(ikm=shared, salt=010203, info=010203, L=32) == erwarteter key`.

## 2. XOR-Checksum
```
payload = 00 01 a6 14 00 …   → checksum = XOR aller payload-Bytes (1 Byte)
```
Gegenbeispiel aus einem echten Command (Time-Sync-Response, nur zur Form):
`timesync_response = 09ff00000101a60a00ba`.

## 3. Fixtures (im Ordner ../fixtures/)
Referenz einer echten Aufnahme (file_id `4b4a7b69`, 2026-01-29, 900 B gemeldet):

| Datei | Inhalt |
|-------|--------|
| `detail_post_ecdh_4b4a7b69.bin` | 97-B File-Header (§5 der Spec) |
| `raw_4b4a7b69.bin` | roher, verschlüsselter Audio-Stream (7380 B) |
| `decrypted_4b4a7b69.ogg` | **erwartetes Ergebnis**: gültige Ogg/Opus-Datei |
| `session_4b4a7b69.json` | shared_secret, session_key (= qc_key) dieser Session |

### End-to-End-Test (Swift)
1. `session_key` aus `shared_secret` ableiten (HKDF) → muss `qc_key` aus der JSON ergeben.
2. File-Header aus `detail_post_ecdh_4b4a7b69.bin` parsen.
3. `fileKey` entpacken → Klartext-Hülle muss mit `soundcored3200` beginnen.
4. `raw_4b4a7b69.bin` entschlüsseln → 45 Opus-Pakete à 160 B.
5. In Ogg verpacken → Bytes müssen `decrypted_4b4a7b69.ogg` entsprechen
   (bzw. ffprobe: codec=opus, 48000 Hz, stereo, ~0,9 s).

### Verifiziertes Ergebnis (Python-Referenz)
```
[+] file-key unwrapped (file_id=4b4a7b69, size=7470)
[+] Decrypted 7,200 bytes (45 packets)
[+] First Opus TOC: 0xbc (config=23 stereo=1)
ffprobe: codec=opus  sample_rate=48000  channels=2  duration=0.9  bit_rate≈76835
```
