import Foundation

/// Fernsteuerbare Aktionen der Geräteaufnahme (Spec §7a).
///
/// Resume trägt dasselbe Byte wie Start – das Gerät leitet aus seinem
/// vorherigen Status ab, was gemeint ist.
public enum D3200RecordAction: UInt8, Sendable, CaseIterable {
    /// Beenden. Im Community-Katalog nicht enthalten – der Wert ist der
    /// Statuscode 0 und wurde am eigenen Gerät gegengeprüft.
    case stop = 0x00
    case start = 0x01
    case pause = 0x02

    /// Fortsetzen nach einer Pause; identisch zu `start`.
    public static let resume = D3200RecordAction.start
}

/// Aufnahmestatus des Geräts, aus Offset 9 einer `recordControl`-Nachricht.
///
/// Alle drei Werte sind am eigenen Gerät verifiziert: Start-Command → 1,
/// Pause-Command → 2, Stop an der Hardwaretaste → 0.
public struct D3200RecordStatus: RawRepresentable, Sendable, Equatable, Hashable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) { self.rawValue = rawValue }

    /// Keine Aufnahme; bei einem Stop folgen Dauer und `file_id`.
    public static let stopped = D3200RecordStatus(rawValue: 0)
    public static let recording = D3200RecordStatus(rawValue: 1)
    public static let paused = D3200RecordStatus(rawValue: 2)

    public var isRecording: Bool { self == .recording }
    public var isPaused: Bool { self == .paused }
}

/// Code aus dem `recordingState`-Push (Gruppe 0x1a, Typ 0x06).
///
/// **Nicht** der Aufnahmestatus – dieser Push kündigt eine neu angelegte
/// Aufnahme an und trug in allen Beobachtungen den Wert 2, auch während
/// das Gerät lief. Der Status steht in `D3200RecordStatus`.
public struct D3200RecordingState: RawRepresentable, Sendable, Equatable, Hashable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) { self.rawValue = rawValue }

    /// Der einzige bisher beobachtete Wert.
    public static let newRecording = D3200RecordingState(rawValue: 2)

    public var announcesNewRecording: Bool { self == .newRecording }
}

/// Ein unaufgefordertes Ereignis des Geräts.
///
/// Diese Pushes kommen ohne Anforderung über die Notify-Characteristic,
/// sobald am Gerät selbst etwas passiert. Sie sind die Grundlage dafür,
/// dass die App live mitbekommt, wenn am Work eine Aufnahme startet.
public enum D3200Event: Sendable, Equatable {
    /// Status einer Aufnahme hat sich geändert (Gruppe 0x1a, Typ 0x06).
    case recordingState(fileID: UInt32, state: D3200RecordingState)

    /// Aufnahmestatus des Geräts (Gruppe 0x18, Typ 0x82).
    ///
    /// Kommt sowohl als Bestätigung eines eigenen Befehls als auch, wenn am
    /// Gerät selbst gestoppt wird. Beim Stop liefert das Gerät zusätzlich
    /// Dauer in ganzen Sekunden und `file_id`; die Liste nennt die Dauer genauer.
    case recordStatus(status: D3200RecordStatus, seconds: UInt32?, fileID: UInt32?)

    /// Alles, was noch nicht zugeordnet ist – bewusst durchgereicht, damit
    /// weitere Tasten und Statusmeldungen sichtbar bleiben.
    case unknown(group: UInt8, type: UInt8, data: Data)

    /// Nachrichtentypen, die unaufgefordert eintreffen und daher nie als
    /// Antwort auf einen Befehl gewertet werden dürfen.
    public static let unsolicitedTypes: Set<D3200Message> = [.recordingState, .recordControl]

    /// Baut ein Ereignis aus einer unaufgeforderten Nachricht.
    public init?(response: RCSPFrame.Response) {
        switch response.message {
        case .recordingState:
            let offset = D3200Message.recordingState.payloadOffset
            guard let fileID = response.frame.littleEndianUInt32(at: offset),
                  let state = response.frame.littleEndianUInt32(at: offset + 4)
            else { return nil }
            self = .recordingState(fileID: fileID, state: D3200RecordingState(rawValue: state))

        case .recordControl:
            // Offset 9 trägt den Status. Nur die Stop-Meldung des Geräts ist
            // lang genug, um danach Dauer (11) und file_id (15) zu tragen;
            // die Bestätigung eines eigenen Befehls ist nur 12 B lang.
            let offset = D3200Message.recordControl.payloadOffset
            let base = response.frame.startIndex + offset
            guard base < response.frame.endIndex else { return nil }
            let status = D3200RecordStatus(rawValue: response.frame[base])
            self = .recordStatus(
                status: status,
                seconds: response.frame.littleEndianUInt32(at: 11),
                fileID: response.frame.littleEndianUInt32(at: 15)
            )

        default:
            return nil
        }
    }

    /// Die `file_id`, auf die sich das Ereignis bezieht.
    public var fileID: UInt32? {
        switch self {
        case .recordingState(let fileID, _): fileID
        case .recordStatus(_, _, let fileID): fileID
        case .unknown: nil
        }
    }
}
