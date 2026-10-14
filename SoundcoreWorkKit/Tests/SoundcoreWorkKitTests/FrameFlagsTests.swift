import Foundation
import Testing

@testable import SoundcoreWorkKit

/// Das Flags-Byte auf Offset 1 jedes Rohframes – darin steckt die
/// Klopfmarkierung (Spec §6.4a).
@Suite("Frame-Flags und Klopfmarkierungen")
struct FrameFlagsTests {
    private let raw: Data

    init() throws {
        raw = try Fixture.rawAudio()
    }

    @Test("Referenz-Aufnahme: erster Frame .first, letzter .last, Rest leer")
    func fixtureFlagSequence() throws {
        let flags = D3200FrameFlags.sequence(rawStream: raw)
        #expect(flags.count == 45)
        #expect(flags.first == .first)
        #expect(flags.last == .last)
        #expect(flags.dropFirst().dropLast().allSatisfy { $0.isEmpty })
    }

    @Test("Referenz-Aufnahme enthält keine Klopfmarkierung")
    func fixtureHasNoMarkers() {
        #expect(D3200FrameFlags.markers(rawStream: raw).isEmpty)
    }

    /// Die Frame-Indizes stammen aus dem Live-Lauf am Gerät: 45-s-Aufnahme,
    /// achtmal geklopft, Flag 0x01 auf genau diesen Frames.
    @Test("Marken werden zu Sekunden ab Aufnahmebeginn")
    func markersBecomeTimestamps() throws {
        let measured = [527, 641, 777, 915, 1020, 1138, 1262, 1376]
        var stream = Data(repeating: 0, count: 2250 * D3200Crypto.rawFrameSize)
        stream[1] = D3200FrameFlags.first.rawValue
        stream[(2250 - 1) * D3200Crypto.rawFrameSize + 1] = D3200FrameFlags.last.rawValue
        for index in measured {
            stream[index * D3200Crypto.rawFrameSize + 1] = D3200FrameFlags.marked.rawValue
        }

        let markers = D3200FrameFlags.markers(rawStream: stream)
        #expect(markers.count == 8)
        #expect(markers == measured.map { Double($0) * 0.02 })
        // Die Marken lagen zwischen 10,5 s und 27,5 s.
        #expect(markers.first.map { abs($0 - 10.54) < 0.01 } == true)
        #expect(markers.last.map { abs($0 - 27.52) < 0.01 } == true)
    }

    @Test("Marke kann mit .first oder .last zusammenfallen")
    func markerCombinesWithPositionBits() {
        var stream = Data(repeating: 0, count: 2 * D3200Crypto.rawFrameSize)
        stream[1] = D3200FrameFlags([.first, .marked]).rawValue
        stream[D3200Crypto.rawFrameSize + 1] = D3200FrameFlags([.last, .marked]).rawValue

        let flags = D3200FrameFlags.sequence(rawStream: stream)
        #expect(flags[0].contains(.first))
        #expect(flags[0].contains(.marked))
        #expect(flags[1].contains(.last))
        #expect(D3200FrameFlags.markers(rawStream: stream) == [0.0, 0.02])
    }

    @Test("Unvollständiger letzter Frame wird ignoriert")
    func ignoresPartialTrailingFrame() {
        var stream = Data(repeating: 0, count: D3200Crypto.rawFrameSize + 7)
        stream[1] = D3200FrameFlags.marked.rawValue
        #expect(D3200FrameFlags.sequence(rawStream: stream).count == 1)
        #expect(D3200FrameFlags.markers(rawStream: stream) == [0.0])
    }
}
