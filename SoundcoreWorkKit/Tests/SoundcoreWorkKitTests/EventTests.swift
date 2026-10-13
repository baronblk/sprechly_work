import Foundation
import Testing

@testable import SoundcoreWorkKit

/// Frames aus den Läufen am eigenen Gerät (2026-10-13): Start und Ende per
/// Hardwaretaste sowie die Antworten auf die ferngesteuerten Befehle.
@Suite("Geräte-Ereignisse und Record-Control")
struct EventTests {
    /// Gruppe 1a, Typ 06: kündigt eine neu angelegte Aufnahme an.
    static let newRecordingFrame = Data(hex:
        "09ff0000011a061200" + "369ace6a" + "02000000" + "45"
    )!

    /// Gruppe 18, Typ 82, 20 B: Stop an der Hardwaretaste.
    /// Status 0 auf Offset 9, Dauer auf 11, file_id auf 15.
    static let stoppedFrame = Data(hex:
        "09ff00000118821400" + "00" + "01" + "0b000000" + "369ace6a" + "cb"
    )!

    /// Antwort auf das Start-Command (12 B, Status 1).
    static let startAckFrame = Data(hex: "09ff0000011882" + "0c" + "00" + "01" + "9040")!

    /// Antwort auf das Pause-Command (12 B, Status 2).
    static let pauseAckFrame = Data(hex: "09ff0000011882" + "0c" + "00" + "02" + "9344")!

    // MARK: - Status

    @Test("Statuswerte sind am Gerät belegt")
    func statusValues() {
        #expect(D3200RecordStatus.stopped.rawValue == 0)
        #expect(D3200RecordStatus.recording.rawValue == 1)
        #expect(D3200RecordStatus.paused.rawValue == 2)
        #expect(D3200RecordStatus.recording.isRecording)
        #expect(D3200RecordStatus.paused.isPaused)
        #expect(!D3200RecordStatus.stopped.isRecording)
    }

    @Test("Start-Bestätigung meldet Status 1")
    func decodesStartAck() throws {
        let response = try #require(RCSPFrame.Response(frame: Self.startAckFrame))
        #expect(response.group == 0x18)
        #expect(response.message == .recordControl)
        #expect(response.declaredLength == 12)
        #expect(response.hasConsistentLength)

        guard case .recordStatus(let status, let seconds, let fileID) =
            try #require(D3200Event(response: response))
        else { return #expect(Bool(false), "kein recordStatus") }

        #expect(status == .recording)
        // Die kurze Bestätigung trägt weder Dauer noch file_id.
        #expect(seconds == nil)
        #expect(fileID == nil)
    }

    @Test("Pause-Bestätigung meldet Status 2")
    func decodesPauseAck() throws {
        let response = try #require(RCSPFrame.Response(frame: Self.pauseAckFrame))
        guard case .recordStatus(let status, _, _) =
            try #require(D3200Event(response: response))
        else { return #expect(Bool(false), "kein recordStatus") }
        #expect(status == .paused)
    }

    @Test("Stop am Gerät meldet Status 0 mit Dauer und file_id")
    func decodesStop() throws {
        let response = try #require(RCSPFrame.Response(frame: Self.stoppedFrame))
        #expect(response.declaredLength == 20)
        #expect(response.hasConsistentLength)

        guard case .recordStatus(let status, let seconds, let fileID) =
            try #require(D3200Event(response: response))
        else { return #expect(Bool(false), "kein recordStatus") }

        #expect(status == .stopped)
        // Die Liste nennt für diese Aufnahme 11,1 s – der Push rundet ab.
        #expect(seconds == 11)
        #expect(fileID == 0x6ACE_9A36)
    }

    // MARK: - Neue Aufnahme

    @Test("Push 0x1a/0x06 kündigt eine neue Aufnahme an – kein Status")
    func decodesNewRecording() throws {
        let response = try #require(RCSPFrame.Response(frame: Self.newRecordingFrame))
        #expect(response.group == 0x1A)
        #expect(response.message == .recordingState)

        let event = try #require(D3200Event(response: response))
        #expect(event == .recordingState(fileID: 0x6ACE_9A36, state: .newRecording))
        #expect(event.fileID == 0x6ACE_9A36)
    }

    @Test("Der Code 2 dieses Pushes ist nicht der Aufnahmestatus")
    func codeIsNotStatus() {
        // Beide tragen die 2, meinen aber Verschiedenes: hier „neue Aufnahme",
        // im Record-Control-Kanal „Pause".
        #expect(D3200RecordingState.newRecording.rawValue == 2)
        #expect(D3200RecordStatus.paused.rawValue == 2)
        #expect(D3200RecordingState.newRecording.announcesNewRecording)
    }

    // MARK: - Commands

    /// Antwort auf das Stop-Command (12 B, Status 0).
    static let stopAckFrame = Data(hex: "09ff0000011882" + "0c" + "00" + "00" + "9140")!

    @Test("Stop-Bestätigung meldet Status 0")
    func decodesStopAck() throws {
        let response = try #require(RCSPFrame.Response(frame: Self.stopAckFrame))
        #expect(response.message == .recordControl)
        guard case .recordStatus(let status, _, _) =
            try #require(D3200Event(response: response))
        else { return #expect(Bool(false), "kein recordStatus") }
        #expect(status == .stopped)
    }

    @Test("Record-Control-Command: 11 B, Länge auf Offset 7", arguments: [
        (D3200RecordAction.stop, UInt8(0x00)),
        (D3200RecordAction.start, UInt8(0x01)),
        (D3200RecordAction.pause, UInt8(0x02)),
    ])
    func buildsRecordControlCommand(action: D3200RecordAction, payload: UInt8) {
        let frame = D3200Commands.recordControl(action)

        #expect(frame.count == 11)
        #expect(frame.prefix(4) == Data([0x08, 0xEE, 0x00, 0x00]))
        #expect(frame[5] == 0x18)   // Gruppe
        #expect(frame[6] == 0x82)   // Typ
        #expect(frame[7] == 11)     // Länge = Framelänge
        #expect(frame[9] == payload)
        #expect(frame.last == RCSPFrame.checksum(Data(frame.dropFirst(4).dropLast())))
    }

    /// Der am Gerät tatsächlich gesendete Start-Frame.
    @Test("Start-Command entspricht dem verifizierten Frame")
    func startCommandMatchesDevice() throws {
        #expect(D3200Commands.recordControl(.start) == Data(hex: "08ee0000001882" + "0b" + "00" + "01" + "90"))
        #expect(D3200Commands.recordControl(.pause) == Data(hex: "08ee0000001882" + "0b" + "00" + "02" + "93"))
        // Stop steht nicht im Community-Katalog, wurde aber am Gerät bestätigt.
        #expect(D3200Commands.recordControl(.stop) == Data(hex: "08ee0000001882" + "0b" + "00" + "00" + "91"))
    }

    @Test("Resume ist derselbe Befehl wie Start")
    func resumeEqualsStart() {
        #expect(D3200RecordAction.resume == .start)
        #expect(D3200Commands.recordControl(.resume) == D3200Commands.recordControl(.start))
    }

    // MARK: - Abgrenzung

    @Test("Beide Push-Typen gelten als unaufgefordert")
    func unsolicitedTypes() {
        #expect(D3200Event.unsolicitedTypes == [.recordingState, .recordControl])
        #expect(!D3200Event.unsolicitedTypes.contains(.fileList))
        #expect(!D3200Event.unsolicitedTypes.contains(.audioChunk))
    }

    @Test("Antwort auf einen Befehl ergibt kein Ereignis")
    func commandResponseIsNotAnEvent() throws {
        let response = try #require(RCSPFrame.Response(frame: try Fixture.fileHeaderResponse()))
        #expect(D3200Event(response: response) == nil)
    }

    @Test("0x18 ist die Gruppe, nicht der Typ")
    func groupIsNotType() throws {
        let response = try #require(RCSPFrame.Response(frame: Self.stoppedFrame))
        #expect(response.group == 0x18)
        #expect(response.type == 0x82)
        #expect(D3200Message(group: 0x82, type: 0x18) == nil)
    }

    /// Der Typ allein genügt nicht: `0x01` ist in Gruppe `0x2e` die
    /// ECDH-Antwort und in Gruppe `0x01` die Geräte-Info.
    @Test("Gleicher Typ in verschiedenen Gruppen ist eine andere Nachricht")
    func typeAloneIsAmbiguous() {
        #expect(D3200Message(group: 0x2E, type: 0x01) == .keyExchange)
        #expect(D3200Message(group: 0x01, type: 0x01) == .deviceInfo)
        #expect(D3200Message(group: 0x2E, type: 0x01) != D3200Message(group: 0x01, type: 0x01))
        // Auch 0x03 doppelt belegt: Auth (0x0b) gegen Akku (0x01).
        #expect(D3200Message(group: 0x0B, type: 0x03) == .auth)
        #expect(D3200Message(group: 0x01, type: 0x03) == .battery)
        #expect(D3200Message(group: 0x99, type: 0x99) == nil)
    }

    @Test("Abfrage-Commands sind 10 B und tragen Gruppe und Typ", arguments: [
        D3200Message.deviceInfo, .battery, .charging,
    ])
    func buildsQueryCommand(message: D3200Message) {
        let frame = D3200Commands.query(message)
        #expect(frame.count == 10)
        #expect(frame[5] == message.group)
        #expect(frame[6] == message.type)
        #expect(frame[7] == 10)  // Länge = Framelänge
        #expect(frame.last == RCSPFrame.checksum(Data(frame.dropFirst(4).dropLast())))
    }
}

/// Löschen ist unwiderruflich – der Befehl muss exakt stimmen.
@Suite("Aufnahme löschen")
struct DeleteCommandTests {
    @Test("Lösch-Command: Gruppe 0x1a, Typ 0x10, file_id als LE32")
    func buildsDeleteCommand() {
        let frame = D3200Commands.deleteRecording(fileID: 0x697B_4A4B)

        #expect(frame.count == 14)
        #expect(frame.prefix(4) == Data([0x08, 0xEE, 0x00, 0x00]))
        #expect(frame[5] == 0x1A)
        #expect(frame[6] == 0x10)
        #expect(frame[7] == 14)  // Länge = Framelänge
        // file_id little-endian, wie überall im Protokoll
        #expect(Data(frame.dropFirst(9).dropLast()) == Data([0x4B, 0x4A, 0x7B, 0x69]))
        #expect(frame.last == RCSPFrame.checksum(Data(frame.dropFirst(4).dropLast())))
    }

    @Test("Verschiedene Aufnahmen ergeben verschiedene Befehle")
    func distinctPerRecording() {
        #expect(D3200Commands.deleteRecording(fileID: 0x697B_4A4B)
            != D3200Commands.deleteRecording(fileID: 0x6ACE_9692))
    }

    @Test("Der Typ kollidiert mit keinem anderen")
    func typeIsDistinct() {
        #expect(D3200Message(group: 0x1A, type: 0x10) == .deleteFile)
        #expect(D3200Message.deleteFile.group == 0x1A)
        #expect(D3200Message.deleteFile.type == 0x10)
        // Nicht mit dem Download verwechseln.
        #expect(D3200Message(group: 0x1A, type: 0x07) == .fileDetail)
    }

    @Test("Löschen ist kein unaufgefordertes Ereignis")
    func notAnEvent() {
        #expect(!D3200Event.unsolicitedTypes.contains(.deleteFile))
    }
}
