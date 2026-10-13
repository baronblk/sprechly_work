import Foundation
import Testing

@testable import SoundcoreWorkKit

@Suite("RCSP-Framing und Command-Layouts")
struct FrameTests {
    @Test("XOR-Checksum über die Payload")
    func xorChecksum() {
        // Payload-Präfix des Time-Sync-Commands: 00^01^A6^14^00
        #expect(RCSPFrame.checksum(Data([0x00, 0x01, 0xA6, 0x14, 0x00])) == 0xB3)
        #expect(RCSPFrame.checksum(Data()) == 0x00)
        #expect(RCSPFrame.checksum(Data([0xFF])) == 0xFF)
        #expect(RCSPFrame.checksum(Data([0xAA, 0xAA])) == 0x00)
    }

    @Test("Command trägt Präfix und Checksum")
    func commandEnvelope() {
        let payload = Data([0x00, 0x1A, 0x0E, 0x0C, 0x00, 0x00, 0x00, 0x2A])
        let frame = RCSPFrame.command(payload: payload)
        #expect(frame.prefix(4) == Data([0x08, 0xEE, 0x00, 0x00]))
        #expect(Data(frame.dropFirst(4).dropLast()) == payload)
        #expect(frame.last == RCSPFrame.checksum(payload))
    }

    /// Am Gerät beobachtete Ack-Frames – identisch mit session_4b4a7b69.json.
    @Test("Ack-Frames von Auth und Time-Sync tragen keinen gelisteten Opcode")
    func acknowledgementFrames() throws {
        let auth = try #require(Data(hex: "09ff0000010b030a0021"))
        let timeSync = try #require(Data(hex: "09ff00000101a60a00ba"))

        #expect(RCSPFrame.isResponse(auth))
        #expect(RCSPFrame.isResponse(timeSync))
        // 030a bzw. a60a sind keine der in D3200Opcode gelisteten Werte:
        // die Frames gelten nur als Bestätigung.
        #expect(D3200Opcode(rawValue: RCSPFrame.opcode(of: auth)!) == nil)
        #expect(D3200Opcode(rawValue: RCSPFrame.opcode(of: timeSync)!) == nil)
    }

    @Test("Opcode liegt auf Offset 6 der Response")
    func opcodeOffset() throws {
        let header = try Fixture.fileHeaderResponse()
        #expect(RCSPFrame.isResponse(header))
        #expect(RCSPFrame.opcode(of: header) == D3200Opcode.fileDetail.rawValue)
        #expect(RCSPFrame.opcode(of: Data([0x09, 0xFF, 0x00])) == nil)
    }

    /// Achtung: Der in `docs/d3200_protocol_spec.md` §4 angegebene Base64-Token
    /// dekodiert zu **19** Byte, nicht zu den dort genannten 20. Maßgeblich ist
    /// die Byte-Folge aus dem Mitschnitt, daher wird hier 19 festgeschrieben.
    @Test("Auth-Command: 6 B Präfix-Payload, 19 B Token, Abschluss 0x15")
    func authCommand() {
        let frame = D3200Commands.auth()
        #expect(D3200Commands.authToken.count == 19)
        #expect(D3200Commands.authToken.hexString == "0190f151b0b4c444cd002f47d7a69c5efb4b79")
        #expect(frame.count == 4 + 26 + 1)
        let payload = Data(frame.dropFirst(4).dropLast())
        #expect(payload.prefix(6) == Data([0x00, 0x0B, 0x03, 0x27, 0x00, 0x1C]))
        #expect(Data(payload.dropFirst(6).dropLast()) == D3200Commands.authToken)
        #expect(payload.last == 0x15)
    }

    @Test("Time-Sync-Command trägt den Timestamp als LE32")
    func timeSyncCommand() {
        let date = Date(timeIntervalSince1970: 1_769_687_627)
        let payload = Data(D3200Commands.timeSync(date: date).dropFirst(4).dropLast())
        #expect(payload.count == 15)
        #expect(payload.prefix(5) == Data([0x00, 0x01, 0xA6, 0x14, 0x00]))
        #expect(payload.littleEndianUInt32(at: 5) == 1_769_687_627)
        #expect(Data(payload.suffix(6)) == Data([0x0A, 0x90, 0xFF, 0xE6, 0x6A, 0x08]))
    }

    @Test("Dateilisten-Command trägt die Seitennummer", arguments: [0, 1, 7] as [UInt8])
    func listFilesCommand(page: UInt8) {
        let payload = Data(D3200Commands.listFiles(page: page).dropFirst(4).dropLast())
        #expect(payload == Data([0x00, 0x1A, 0x0E, 0x0C, 0x00, page, 0x00, 0x2A]))
    }

    @Test("File-Detail-Command trägt die file_id als LE32")
    func fileDetailCommand() {
        let payload = Data(D3200Commands.fileDetail(fileID: 0x697B_4A4B).dropFirst(4).dropLast())
        #expect(payload.count == 13)
        #expect(payload.prefix(9) == Data([0x00, 0x1A, 0x07, 0x12, 0x00, 0x00, 0x00, 0x00, 0x00]))
        #expect(Data(payload.suffix(4)) == Data([0x4B, 0x4A, 0x7B, 0x69]))
    }

    @Test("ECDH-Command trägt den 64-B-Public-Key")
    func keyExchangeCommand() throws {
        let publicKey = try #require(Data(hex: Fixture.session().ourPublicKey))
        #expect(publicKey.count == 64)
        let payload = Data(D3200Commands.keyExchange(publicKey: publicKey).dropFirst(4).dropLast())
        #expect(payload.count == 70)
        #expect(payload.prefix(6) == Data([0x00, 0x2E, 0x01, 0x4B, 0x00, 0x04]))
        #expect(Data(payload.suffix(64)) == publicKey)
    }

    /// Echter Frame vom eigenen Gerät (2026-10-13). Die Spec nennt Opcode
    /// `0e0c` und Offset 10 – beides sind die Command-Bytes; das Gerät
    /// antwortet mit `0e1c` und Einträgen ab Offset 11.
    static let liveFileListResponse = Data(hex:
        "09ff0000011a0e1c00" +   // Präfix, Flag, Gruppe 1a, Opcode 0e1c, 00
        "0100" +                 // Eintragszähler LE16 = 1
        "4b4a7b69" +             // file_id LE32 = 0x697b4a4b
        "84030000" +             // size LE32 = 900
        "0000000000000000" +     // Reserve bzw. Padding
        "4e"                     // Checksum
    )!

    @Test("Live-Listen-Antwort: Opcode 0e1c, ein Eintrag mit 900 B")
    func liveFileListParsing() {
        let response = Self.liveFileListResponse
        #expect(response.count == 28)
        #expect(RCSPFrame.opcode(of: response) == D3200Opcode.fileList.rawValue)
        #expect(D3200Recording.declaredCount(response: response) == 1)

        let recordings = D3200Recording.parseList(response: response)
        #expect(recordings.count == 1)
        #expect(recordings.first?.fileID == 0x697B_4A4B)
        #expect(recordings.first?.size == 900)
        // file_id ist der Aufnahme-Timestamp
        #expect(recordings.first?.recordedAt == Date(timeIntervalSince1970: 1_769_687_627))
    }

    @Test("Dateiliste: Müll und Reservebytes werden verworfen")
    func fileListRejectsImplausibleEntries() {
        var response = Data([0x09, 0xFF, 0x00, 0x00, 0x01, 0x1A, 0x0E, 0x1C, 0x00, 0x02, 0x00])
        response.append(littleEndian: UInt32(0x697B_4A4B))  // plausible file_id
        response.append(littleEndian: UInt32(7470))
        response.append(littleEndian: UInt32(42))            // unplausibel: zu kleine id
        response.append(littleEndian: UInt32(100))
        response.append(0x00)                                // Checksum

        let recordings = D3200Recording.parseList(response: response)
        #expect(recordings.count == 1)
        #expect(recordings.first?.fileID == 0x697B_4A4B)
    }

    @Test("Leere Listenseite liefert keine Einträge")
    func emptyFileListPage() {
        let response = Data([0x09, 0xFF, 0x00, 0x00, 0x01, 0x1A, 0x0E, 0x1C, 0x00, 0x00, 0x00, 0x00])
        #expect(D3200Recording.parseList(response: response).isEmpty)
        #expect(D3200Recording.declaredCount(response: response) == 0)
    }

    /// Die Checksum darf nie als Eintragsanfang gelesen werden.
    @Test("Antwort ohne Einträge, aber mit Checksum, bleibt leer")
    func checksumIsNotAnEntry() {
        let response = Data([0x09, 0xFF, 0x00, 0x00, 0x01, 0x1A, 0x0E, 0x1C, 0x00, 0x00, 0x00]) + Data([0x4E])
        #expect(D3200Recording.parseList(response: response).isEmpty)
    }

    /// Am Gerät verifiziert: 45 Chunks à 176 B. Ab Offset 12 steht ein
    /// kompletter 164-Byte-Frame des Rohformats, Offset 9 der Frame-Zähler.
    @Test("Audio-Chunk: 176 B Frame liefert 164 B Rohframe")
    func audioChunkPayload() {
        let head = Data(hex: "09ff0000011a08b000")!   // Präfix, Flag, Gruppe, Opcode, 00
        let sequence = Data([0x2C])                    // Frame-Zähler 44
        let filler = Data([0x00, 0x00])                // Offset 10/11
        let rawFrame = Data([0x00, 0x04]) + Data(repeating: 0x5A, count: 160) + Data([0xC8, 0x12])
        let frame = head + sequence + filler + rawFrame

        #expect(frame.count == 176)
        #expect(RCSPFrame.opcode(of: frame) == D3200Opcode.audioChunk.rawValue)
        #expect(D3200Client.chunkSequence(of: frame) == 44)

        let payload = D3200Client.audioPayload(from: frame)
        #expect(payload.count == D3200Crypto.rawFrameSize)
        #expect(payload == rawFrame)
        // Die ersten zwei Bytes sind die Frame-Flags (hier 0x0004 = letzter Frame).
        #expect(payload.prefix(2) == Data([0x00, 0x04]))
    }

    /// Am Gerät beobachtet: `09ff0000011a0a1300` + Größe LE32 + file_id LE32.
    @Test("Transfer-Complete trägt Größe auf Offset 10 und die file_id")
    func transferCompleteLayout() throws {
        let frame = try #require(Data(hex: "09ff0000011a0a13000084030000" + "4b4a7b69" + "40"))

        #expect(frame.count == 19)
        #expect(RCSPFrame.opcode(of: frame) == D3200Opcode.transferComplete.rawValue)
        #expect(frame.littleEndianUInt32(at: D3200Opcode.transferComplete.payloadOffset) == 900)
        #expect(frame.littleEndianUInt32(at: 14) == 0x697B_4A4B)
    }

}
