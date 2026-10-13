import Foundation

/// Abstraktion des Geräte-Transports, damit `D3200Client` ohne echte Hardware testbar bleibt.
public protocol DeviceTransport: Sendable {
    /// Verbindet und macht den Transport sendebereit (bei BLE: inkl. aktivierter Notifications).
    func connect() async throws
    func disconnect() async
    /// Sendet einen fertigen RCSP-Frame.
    func send(_ frame: Data) async throws
    /// Ein neuer Stream der eingehenden Frames. Mehrfachaufrufe liefern unabhängige Streams.
    func notifications() -> AsyncStream<Data>
}

/// Fehler, die jeder Transport melden kann.
public enum TransportError: Error, LocalizedError, Equatable {
    case bluetoothUnavailable(String)
    case deviceNotFound
    case notConnected
    case characteristicsMissing
    case connectionFailed(String)
    case timedOut

    public var errorDescription: String? {
        switch self {
        case .bluetoothUnavailable(let reason):
            "Bluetooth nicht verfügbar: \(reason)"
        case .deviceNotFound:
            "Kein Soundcore Work in Reichweite. Ist das Gerät noch mit dem Handy verbunden?"
        case .notConnected:
            "Nicht verbunden."
        case .characteristicsMissing:
            "Write- oder Notify-Characteristic nicht gefunden."
        case .connectionFailed(let reason):
            "Verbindung fehlgeschlagen: \(reason)"
        case .timedOut:
            "Zeitüberschreitung."
        }
    }
}
