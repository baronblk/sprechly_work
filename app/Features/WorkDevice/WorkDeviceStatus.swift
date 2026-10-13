import Foundation
import SoundcoreWorkKit

/// Verbindungszustand des Soundcore Work, wie ihn die UI zeigt.
enum WorkConnectionStatus: Equatable, Sendable {
    case disconnected
    case connecting
    case ready
    case failed(String)

    var isBusy: Bool { self == .connecting }

    var label: String {
        switch self {
        case .disconnected: String(localized: "Nicht verbunden")
        case .connecting: String(localized: "Verbinde …")
        case .ready: String(localized: "Verbunden")
        case .failed: String(localized: "Fehler")
        }
    }
}

/// Was am Gerät gerade passiert – gespeist aus den unaufgeforderten Pushes.
///
/// Das Gerät meldet nur Start und Ende. Eine Pause am Gerät erzeugt **kein**
/// Ereignis, deshalb gibt es hier bewusst keinen Pause-Zustand: er wäre geraten.
enum WorkLiveActivity: Equatable, Sendable {
    case idle
    /// Am Gerät läuft eine Aufnahme. `startedAt` ist der Empfang des Pushes –
    /// das Gerät beginnt rund 2 s früher, daher ist diese Zeit nur eine Anzeige.
    case recording(fileID: UInt32, startedAt: Date)
    /// Gerade fertig geworden; die maßgebliche Dauer kommt vom Gerät.
    case finished(fileID: UInt32, duration: TimeInterval)

    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }
}

/// Eine Aufnahme auf dem Gerät, angereichert um ihren Import-Zustand.
struct WorkRecordingItem: Identifiable, Equatable, Sendable {
    enum ImportState: Equatable, Sendable {
        case notImported
        case downloading(progress: Double)
        case converting
        case imported(recordingID: UUID)
        case failed(String)
    }

    let recording: D3200Recording
    var importState: ImportState = .notImported

    var id: UInt32 { recording.fileID }

    /// Hex-Schreibweise der `file_id`, wie sie auch im Gerätelog auftaucht.
    var identifierText: String { String(format: "%08x", recording.fileID) }

    var isBusy: Bool {
        switch importState {
        case .downloading, .converting: true
        case .notImported, .imported, .failed: false
        }
    }
}
