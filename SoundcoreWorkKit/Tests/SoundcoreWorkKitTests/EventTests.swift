import Foundation
import Testing

@testable import SoundcoreWorkKit

/// Die beiden unaufgeforderten Pushes, die am Gerät beobachtet wurden
/// (2026-10-13): Start und Ende einer Aufnahme von 11,1 s.
@Suite("Unaufgeforderte Geräte-Ereignisse")
struct EventTests {
    /// `09ff0000011a061200` + file_id + state + Restbyte
    static let recordingStartedFrame = Data(hex:
        "09ff0000011a061200" +   // Gruppe 1a, Typ 06, Länge 18
        "369ace6a" +             // file_id LE32 = 0x6ace9a36
        "02000000" +             // Statuscode LE32 = 2
        "45"
    )!

    /// Gruppe 18, Typ 82, Länge 20; Dauer auf Offset 11, file_id auf 15.
    static let recordingFinishedFrame = Data(hex:
        "09ff00000118821400" +   // Präfix, Flag, Gruppe 18, Typ 82, Länge 20, 00
        "0001" +                 // Offset 9/10
        "0b000000" +             // Dauer LE32 = 11 Sekunden
        "369ace6a" +             // file_id LE32 = 0x6ace9a36
        "cb"
    )!

    @Test("Start-Push: Typ 0x06 mit file_id und Statuscode 2")
    func decodesRecordingStart() throws {
        let response = try #require(RCSPFrame.Response(frame: Self.recordingStartedFrame))
        #expect(response.group == 0x1A)
        #expect(response.message == .recordingState)
        #expect(response.declaredLength == 18)
        #expect(response.hasConsistentLength)

        let event = try #require(D3200Event(response: response))
        #expect(event == .recordingState(fileID: 0x6ACE_9A36, state: .recording))
        #expect(event.fileID == 0x6ACE_9A36)
    }

    @Test("Ende-Push: Typ 0x82 mit Dauer in Sekunden und file_id")
    func decodesRecordingFinished() throws {
        let response = try #require(RCSPFrame.Response(frame: Self.recordingFinishedFrame))
        #expect(response.group == 0x18)
        #expect(response.message == .recordingFinished)
        #expect(response.declaredLength == 20)
        #expect(response.frame.count == 20)
        #expect(response.hasConsistentLength)

        let event = try #require(D3200Event(response: response))
        // Die Liste meldete für diese Aufnahme 11,1 s – der Push rundet auf Sekunden ab.
        #expect(event == .recordingFinished(fileID: 0x6ACE_9A36, seconds: 11))
    }

    @Test("Statuscode: bekannt ist nur 2 = nimmt auf")
    func recordingStateCodes() {
        #expect(D3200RecordingState.recording.rawValue == 2)
        #expect(D3200RecordingState.recording.isRecording)
        // Unbekannte Codes gehen unverändert durch, statt falsch gedeutet zu werden.
        let unknown = D3200RecordingState(rawValue: 7)
        #expect(!unknown.isRecording)
        #expect(unknown.rawValue == 7)
    }

    @Test("Beide Push-Typen gelten als unaufgefordert")
    func unsolicitedTypes() {
        #expect(D3200Event.unsolicitedTypes == [.recordingState, .recordingFinished])
        // Antworten auf Befehle dürfen nicht als Ereignis gelten.
        #expect(!D3200Event.unsolicitedTypes.contains(.fileList))
        #expect(!D3200Event.unsolicitedTypes.contains(.audioChunk))
    }

    @Test("Antwort auf einen Befehl ergibt kein Ereignis")
    func commandResponseIsNotAnEvent() throws {
        let response = try #require(RCSPFrame.Response(frame: try Fixture.fileHeaderResponse()))
        #expect(D3200Event(response: response) == nil)
    }

    /// Der Typ 0x82 lag in der Spec als „`18 82` Transfer-Init" – dabei ist
    /// 0x18 die Gruppe. Beim Download taucht der Typ nie auf.
    @Test("0x18 ist die Gruppe, nicht der Typ")
    func groupIsNotType() throws {
        let response = try #require(RCSPFrame.Response(frame: Self.recordingFinishedFrame))
        #expect(response.group == 0x18)
        #expect(response.type == 0x82)
        #expect(D3200Message(rawValue: 0x18) == nil)
    }
}
