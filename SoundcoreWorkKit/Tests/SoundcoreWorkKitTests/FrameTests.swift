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
        let date = Date(timeIntervalSince1970: 1_769_130_571)
        let payload = Data(D3200Commands.timeSync(date: date).dropFirst(4).dropLast())
        #expect(payload.count == 15)
        #expect(payload.prefix(5) == Data([0x00, 0x01, 0xA6, 0x14, 0x00]))
        #expect(payload.littleEndianUInt32(at: 5) == 1_769_130_571)
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

    @Test("Dateiliste: plausible Einträge werden erkannt, Müll verworfen")
    func fileListParsing() {
        var response = Data([0x09, 0xFF, 0x00, 0x00, 0x01, 0x1A, 0x0E, 0x0C, 0x00, 0x00])
        response.append(littleEndian: UInt32(0x697B_4A4B))  // plausible file_id
        response.append(littleEndian: UInt32(7470))
        response.append(littleEndian: UInt32(42))           // unplausibel: zu kleine id
        response.append(littleEndian: UInt32(100))

        let recordings = D3200Recording.parseList(response: response)
        #expect(recordings.count == 1)
        #expect(recordings.first?.fileID == 0x697B_4A4B)
        #expect(recordings.first?.size == 7470)
    }

    @Test("Leere Listenseite liefert keine Einträge")
    func emptyFileListPage() {
        let response = Data([0x09, 0xFF, 0x00, 0x00, 0x01, 0x1A, 0x0E, 0x0C, 0x00, 0x00])
        #expect(D3200Recording.parseList(response: response).isEmpty)
    }

    @Test("Audio-Chunk: Nutzlast ab Offset 12, Checksum-Byte wird verworfen")
    func audioChunkPayload() {
        let prefix = Data([0x09, 0xFF, 0x00, 0x00, 0x01, 0x1A, 0x08, 0xB0, 0x00, 0x00, 0x00, 0x00])
        let packet = Data(repeating: 0x5A, count: 160)

        #expect(D3200Client.audioPayload(from: prefix + packet) == packet)
        #expect(D3200Client.audioPayload(from: prefix + packet + Data([0x7F])) == packet)
    }
}
