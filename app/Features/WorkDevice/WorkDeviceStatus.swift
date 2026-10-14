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

/// Was am Gerät gerade passiert – gespeist aus dem Record-Control-Kanal.
///
/// Alle drei Zustände sind am Gerät verifiziert (Statusbyte 0/1/2). Die
/// Fernsteuerung kann sie auch selbst auslösen.
enum WorkLiveActivity: Equatable, Sendable {
    case idle
    /// Es läuft eine Aufnahme. `since` ist der Empfang der Statusmeldung –
    /// das Gerät beginnt rund 2 s früher, die Zeit ist also eine Anzeige.
    case recording(since: Date)
    /// Aufnahme pausiert; `elapsed` friert die bis dahin gelaufene Zeit ein.
    case paused(elapsed: TimeInterval)
    /// Beim Verbinden vorgefunden: Das Gerät meldet eine offene Aufnahme,
    /// deren Beginn niemand kennt.
    ///
    /// Am Gerät geprüft (2026-10-14): Der Startzeitpunkt wird genau einmal
    /// gesendet – als Ereignis beim Start – und ist danach nicht mehr
    /// erfragbar; weder `1a/06` noch `18/82` beantworten eine Abfrage mit
    /// Inhalt, und eine laufende Aufnahme steht nicht in der Dateiliste.
    /// `detectedAt` ist deshalb nur eine **Untergrenze**: Länger als seitdem
    /// läuft sie mindestens.
    case openRecording(detectedAt: Date)
    /// Gerade beendet; die Dauer meldet das Gerät.
    case finished(fileID: UInt32?, duration: TimeInterval)

    var isRecording: Bool {
        switch self {
        case .recording, .openRecording: true
        default: false
        }
    }

    /// Ob die angezeigte Laufzeit der Wahrheit entspricht. Bei einer
    /// vorgefundenen Aufnahme ist sie nur eine Untergrenze und wird deshalb
    /// als solche beschriftet.
    var hasKnownStart: Bool {
        if case .openRecording = self { return false }
        return true
    }

    var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }

    /// Ob gerade eine Aufnahme offen ist (läuft oder pausiert).
    var isActive: Bool { isRecording || isPaused }

    var label: String {
        switch self {
        case .idle: String(localized: "Bereit")
        case .recording: String(localized: "Aufnahme läuft")
        case .openRecording: String(localized: "Aufnahme läuft")
        case .paused: String(localized: "Pausiert")
        case .finished: String(localized: "Aufnahme fertig")
        }
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
