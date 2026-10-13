import Foundation
import Testing

@testable import SoundcoreWorkKit

@Suite("RCSP-Framing und Command-Layouts")
struct FrameTests {
    // MARK: - Checksum und Command-Hülle

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

    // MARK: - Response-Kopf (Gruppe / Typ / Länge)

    /// Am Gerät beobachtete Frames (2026-10-13). Byte 7 ist die Framelänge –
    /// darum sind `0e14`, `0e1c` und `0e24` dieselbe Nachricht.
    @Test("Response-Kopf: Gruppe, Typ und Länge", arguments: [
        ("09ff0000010b030a0021", 0x0B, D3200Message.auth, 10),
        ("09ff00000101a60a00ba", 0x01, D3200Message.timeSync, 10),
        ("09ff0000011a0a13000084030000" + "4b4a7b69" + "40", 0x1A, D3200Message.transferComplete, 19),
    ])
    func responseHeader(hex: String, group: Int, message: D3200Message, length: Int) throws {
        let frame = try #require(Data(hex: hex))
        let response = try #require(RCSPFrame.Response(frame: frame))

        #expect(response.group == UInt8(group))
        #expect(response.type == message.rawValue)
        #expect(response.message == message)
        #expect(Int(response.declaredLength) == length)
        #expect(response.frame.count == length)
        #expect(response.hasConsistentLength)
    }

    /// Ersetzt die Integritätsprüfung, die Responses mangels Checksum nicht haben.
    @Test("Längenangabe aus Offset 7 deckt einen inkonsistenten Frame auf")
    func inconsistentLengthIsDetected() throws {
        let frame = try #require(Data(hex: "09ff0000010b030a002100"))  // gibt 10 an, ist 11
        let response = try #require(RCSPFrame.Response(frame: frame))

        #expect(response.declaredLength == 10)
        #expect(response.frame.count == 11)
        #expect(!response.hasConsistentLength)
    }

    @Test("Zu kurzer Frame und Command-Präfix ergeben keine Response")
    func rejectsNonResponses() {
        #expect(RCSPFrame.Response(frame: Data([0x09, 0xFF, 0x00, 0x00, 0x01, 0x1A, 0x0E])) == nil)
        #expect(RCSPFrame.Response(frame: Data(hex: "08ee000000010203")!) == nil)
        #expect(RCSPFrame.Response(frame: Data()) == nil)
    }

    @Test("File-Header-Fixture trägt Typ 0x07 und Länge 97")
    func fileHeaderResponseShape() throws {
        let frame = try Fixture.fileHeaderResponse()
        let response = try #require(RCSPFrame.Response(frame: frame))

        #expect(response.group == 0x1A)
        #expect(response.message == .fileDetail)
        #expect(response.declaredLength == 97)
        #expect(response.hasConsistentLength)
    }

    // MARK: - Commands

    /// Achtung: Der in `docs/d3200_protocol_spec.md` §4 angegebene Base64-Token
    /// dekodiert zu **19** Byte, nicht zu den dort ursprünglich genannten 20.
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

    /// Commands tragen dieselbe Struktur wie Responses: `00 group type sub …`.
    @Test("Command-Gruppe und -Typ spiegeln sich im Response-Kopf")
    func commandMirrorsResponseHeader() throws {
        let detail = Data(D3200Commands.fileDetail(fileID: 0).dropFirst(4))
        let header = try #require(RCSPFrame.Response(frame: try Fixture.fileHeaderResponse()))

        #expect(detail[1] == header.group)  // 0x1a
        #expect(detail[2] == header.type)   // 0x07
    }

    // MARK: - Dateiliste

    /// Echte Frames vom eigenen Gerät (2026-10-13), einmal mit einer und
    /// einmal mit zwei Aufnahmen. Byte 7 wächst mit (28 → 36), der Typ 0x0e
    /// bleibt – das belegt zugleich die Schrittweite 8 der Einträge.
    static let liveListOneEntry = Data(hex:
        "09ff0000011a0e1c00" +            // Präfix, Flag, Gruppe 1a, Typ 0e, Länge 28
        "0100" +                          // Eintragszähler LE16 = 1
        "4b4a7b69" + "84030000" +         // file_id, size = 900
        "0000000000000000" + "4e"         // Padding, Rest
    )!

    static let liveListTwoEntries = Data(hex:
        "09ff0000011a0e2400" +            // Länge 36
        "0200" +                          // Eintragszähler LE16 = 2
        "4b4a7b69" + "84030000" +         // Aufnahme 1: 2026-01-29,   900 B
        "9296ce6a" + "f4330000" +         // Aufnahme 2: 2026-10-13, 13300 B
        "0000000000000000" + "de"         // Padding, Rest
    )!

    @Test("Listen-Antwort mit einem Eintrag")
    func liveListOneEntryParsing() throws {
        let response = try #require(RCSPFrame.Response(frame: Self.liveListOneEntry))
        #expect(response.message == .fileList)
        #expect(response.declaredLength == 28)
        #expect(response.hasConsistentLength)
        #expect(D3200Recording.declaredCount(response: Self.liveListOneEntry) == 1)

        let recordings = D3200Recording.parseList(response: Self.liveListOneEntry)
        #expect(recordings.count == 1)
        #expect(recordings[0].fileID == 0x697B_4A4B)
        #expect(recordings[0].durationMilliseconds == 900)
        #expect(recordings[0].duration == 0.9)
        #expect(recordings[0].frameCount == 45)
        #expect(recordings[0].recordedAt == Date(timeIntervalSince1970: 1_769_687_627))
    }

    /// Der Frame, der die Schrittweite entschieden hat: zwei Einträge liegen
    /// direkt hintereinander auf Offset 11 und 19.
    @Test("Listen-Antwort mit zwei Einträgen belegt Schrittweite 8")
    func liveListTwoEntriesParsing() throws {
        let response = try #require(RCSPFrame.Response(frame: Self.liveListTwoEntries))
        #expect(response.message == .fileList)
        #expect(response.declaredLength == 36)
        #expect(response.hasConsistentLength)
        // Gleiche Nachricht, nur länger – darum darf nicht auf 6/7 dispatcht werden.
        #expect(response.type == Self.liveListOneEntry[6])
        #expect(D3200Recording.declaredCount(response: Self.liveListTwoEntries) == 2)

        let recordings = D3200Recording.parseList(response: Self.liveListTwoEntries)
        #expect(recordings.count == 2)
        #expect(recordings[0].fileID == 0x697B_4A4B)
        #expect(recordings[0].durationMilliseconds == 900)
        // 665 Pakete à 20 ms – am Gerät heruntergeladen und von ffprobe
        // mit 13,3 s bestätigt.
        #expect(recordings[1].fileID == 0x6ACE_9692)
        #expect(recordings[1].durationMilliseconds == 13300)
        #expect(recordings[1].duration == 13.3)
        #expect(recordings[1].frameCount == 665)
        #expect(recordings[1].recordedAt == Date(timeIntervalSince1970: 1_791_923_858))
    }

    @Test("Padding hinter den Einträgen wird nicht als Eintrag gelesen")
    func paddingIsNotAnEntry() {
        #expect(D3200Recording.parseList(response: Self.liveListOneEntry).count == 1)
        #expect(D3200Recording.parseList(response: Self.liveListTwoEntries).count == 2)
    }

    @Test("Leere Listenseite liefert keine Einträge")
    func emptyFileListPage() throws {
        let frame = try #require(Data(hex: "09ff0000011a0e1400" + "0000" + "000000000000000000"))
        #expect(frame.count == 20)
        #expect(D3200Recording.declaredCount(response: frame) == 0)
        #expect(D3200Recording.parseList(response: frame).isEmpty)
    }

    @Test("Unplausible Einträge werden verworfen")
    func fileListRejectsImplausibleEntries() {
        var frame = Data([0x09, 0xFF, 0x00, 0x00, 0x01, 0x1A, 0x0E, 0x1C, 0x00, 0x02, 0x00])
        frame.append(littleEndian: UInt32(0x697B_4A4B))  // plausible file_id
        frame.append(littleEndian: UInt32(900))          // Dauer in ms
        frame.append(littleEndian: UInt32(42))           // unplausibel: zu kleine id
        frame.append(littleEndian: UInt32(100))

        let recordings = D3200Recording.parseList(response: frame)
        #expect(recordings.count == 1)
        #expect(recordings[0].fileID == 0x697B_4A4B)
    }

    // MARK: - Audio-Chunks

    /// Am Gerät verifiziert: 45 Chunks à 176 B. Ab Offset 12 steht ein
    /// kompletter 164-Byte-Frame des Rohformats, Offset 9 der Frame-Zähler.
    @Test("Audio-Chunk: 176 B Frame liefert 164 B Rohframe")
    func audioChunkPayload() throws {
        let head = try #require(Data(hex: "09ff0000011a08b000"))
        let rawFrame = Data([0x00, 0x04]) + Data(repeating: 0x5A, count: 160) + Data([0xC8, 0x12])
        let frame = head + Data([0x2C]) + Data([0x00, 0x00]) + rawFrame

        let response = try #require(RCSPFrame.Response(frame: frame))
        #expect(frame.count == 176)
        #expect(response.message == .audioChunk)
        #expect(response.declaredLength == 176)
        #expect(response.hasConsistentLength)
        #expect(D3200Client.chunkSequence(of: frame) == 44)

        let payload = D3200Client.audioPayload(from: frame)
        #expect(payload.count == D3200Crypto.rawFrameSize)
        #expect(payload == rawFrame)
        // Die ersten zwei Bytes sind die Frame-Flags (hier 0x0004 = letzter Frame).
        #expect(payload.prefix(2) == Data([0x00, 0x04]))
    }

    /// Am Gerät beobachtet: Größe LE32 auf Offset 10, danach die file_id.
    @Test("Transfer-Complete trägt Größe auf Offset 10 und die file_id")
    func transferCompleteLayout() throws {
        let frame = try #require(Data(hex: "09ff0000011a0a13000084030000" + "4b4a7b69" + "40"))
        let response = try #require(RCSPFrame.Response(frame: frame))

        #expect(response.message == .transferComplete)
        #expect(frame.littleEndianUInt32(at: D3200Message.transferComplete.payloadOffset) == 900)
        #expect(frame.littleEndianUInt32(at: 14) == 0x697B_4A4B)
    }
}
