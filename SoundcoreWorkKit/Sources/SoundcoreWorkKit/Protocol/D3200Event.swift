import Foundation

/// Statuscode einer Aufnahme aus dem `recordingState`-Push.
///
/// Am Gerät ist bisher nur `2` beim **Start** einer Aufnahme beobachtet.
/// Darum ein `RawRepresentable` statt eines Enums: unbekannte Codes gehen
/// unverändert durch, statt auf einen falschen Fall abgebildet zu werden.
public struct D3200RecordingState: RawRepresentable, Sendable, Equatable, Hashable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) { self.rawValue = rawValue }

    /// Beim Drücken der Aufnahmetaste beobachtet (2026-10-13).
    public static let recording = D3200RecordingState(rawValue: 2)

    /// Ob dieser Code als „Gerät nimmt auf" gilt.
    public var isRecording: Bool { self == .recording }
}

/// Ein unaufgefordertes Ereignis des Geräts.
///
/// Diese Pushes kommen ohne Anforderung über die Notify-Characteristic,
/// sobald am Gerät selbst etwas passiert. Sie sind die Grundlage dafür,
/// dass die App live mitbekommt, wenn am Work eine Aufnahme startet.
public enum D3200Event: Sendable, Equatable {
    /// Status einer Aufnahme hat sich geändert (Gruppe 0x1a, Typ 0x06).
    case recordingState(fileID: UInt32, state: D3200RecordingState)

    /// Eine Aufnahme ist fertig (Gruppe 0x18, Typ 0x82).
    /// Die Dauer kommt in ganzen Sekunden – die Liste liefert sie genauer.
    case recordingFinished(fileID: UInt32, seconds: UInt32)

    /// Alles, was noch nicht zugeordnet ist – bewusst durchgereicht, damit
    /// weitere Tasten und Statusmeldungen sichtbar bleiben.
    case unknown(group: UInt8, type: UInt8, data: Data)

    /// Nachrichtentypen, die unaufgefordert eintreffen und daher nie als
    /// Antwort auf einen Befehl gewertet werden dürfen.
    public static let unsolicitedTypes: Set<D3200Message> = [.recordingState, .recordingFinished]

    /// Baut ein Ereignis aus einer unaufgeforderten Nachricht.
    public init?(response: RCSPFrame.Response) {
        switch response.message {
        case .recordingState:
            let offset = D3200Message.recordingState.payloadOffset
            guard let fileID = response.frame.littleEndianUInt32(at: offset),
                  let state = response.frame.littleEndianUInt32(at: offset + 4)
            else { return nil }
            self = .recordingState(fileID: fileID, state: D3200RecordingState(rawValue: state))

        case .recordingFinished:
            let offset = D3200Message.recordingFinished.payloadOffset
            guard let seconds = response.frame.littleEndianUInt32(at: offset),
                  let fileID = response.frame.littleEndianUInt32(at: offset + 4)
            else { return nil }
            self = .recordingFinished(fileID: fileID, seconds: seconds)

        default:
            return nil
        }
    }

    /// Die `file_id`, auf die sich das Ereignis bezieht.
    public var fileID: UInt32? {
        switch self {
        case .recordingState(let fileID, _), .recordingFinished(let fileID, _): fileID
        case .unknown: nil
        }
    }
}
