import Foundation

/// Flags-Byte auf Offset 1 jedes 164-Byte-Rohframes (Spec §6.4a).
///
/// Die Bits sind am Gerät gemessen, nicht aus einer Referenz übernommen:
/// `.first`/`.last` zeigen sich in jeder Aufnahme genau einmal, `.marked`
/// kam in einer 45-s-Testaufnahme achtmal – genau dann, wenn auf das Gerät
/// geklopft wurde. Die Klopfmarkierung erzeugt also **kein** BLE-Event und
/// keinen eigenen Slice-Typ; sie steht nur hier und wird erst beim Download
/// sichtbar.
public struct D3200FrameFlags: OptionSet, Sendable, Hashable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    /// Klopfmarkierung: an dieser Stelle hat der Nutzer auf das Gerät geklopft.
    public static let marked = D3200FrameFlags(rawValue: 0x01)
    /// Erster Frame der Aufnahme.
    public static let first = D3200FrameFlags(rawValue: 0x02)
    /// Letzter Frame der Aufnahme.
    public static let last = D3200FrameFlags(rawValue: 0x04)

    /// Liest die Flags aller Frames eines Roh-Streams in Reihenfolge.
    ///
    /// Ein unvollständiger letzter Frame wird ignoriert, damit die Funktion
    /// auch auf einem abgebrochenen Transfer noch etwas Brauchbares liefert.
    public static func sequence(rawStream raw: Data) -> [D3200FrameFlags] {
        let bytes = Data(raw)
        let frameCount = bytes.count / D3200Crypto.rawFrameSize
        return (0 ..< frameCount).map { index in
            D3200FrameFlags(rawValue: bytes[bytes.startIndex + index * D3200Crypto.rawFrameSize + 1])
        }
    }

    /// Zeitpunkte der Klopfmarkierungen, in Sekunden ab Aufnahmebeginn.
    public static func markers(rawStream raw: Data) -> [TimeInterval] {
        sequence(rawStream: raw).enumerated().compactMap { index, flags in
            flags.contains(.marked) ? Double(index) * D3200Recording.secondsPerFrame : nil
        }
    }
}
