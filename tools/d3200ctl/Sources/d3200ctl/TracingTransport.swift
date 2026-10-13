import Foundation
import SoundcoreWorkKit

/// Legt sich um einen echten Transport und protokolliert jeden Frame.
///
/// Dient der Protokoll-Verifikation: zeigt Gruppe, Typ und die vom Gerät
/// angegebene Länge jedes Frames und meldet, wenn die Länge nicht passt.
final class TracingTransport: DeviceTransport, @unchecked Sendable {
    private let base: DeviceTransport
    private let stats = Stats()
    private let verbose: Bool
    private let lock = NSLock()
    private var sinks: [UUID: AsyncStream<Data>.Continuation] = [:]
    private var tap: Task<Void, Never>?

    init(wrapping base: DeviceTransport, verbose: Bool) {
        self.base = base
        self.verbose = verbose
    }

    /// Längenverteilung pro Opcode, damit der Chunk-Zuschnitt belegt ist.
    final class Stats: @unchecked Sendable {
        private let lock = NSLock()
        private var counts: [UInt16: [Int: Int]] = [:]
        private var order: [UInt16] = []

        func record(group: UInt8?, type: UInt8?, length: Int) {
            let key = (group.map { UInt16($0) << 8 } ?? 0xFF00) | (type.map(UInt16.init) ?? 0x00FF)
            lock.withLock {
                if counts[key] == nil { order.append(key) }
                counts[key, default: [:]][length, default: 0] += 1
            }
        }

        func count(group: UInt8, type: UInt8) -> Int {
            let key = UInt16(group) << 8 | UInt16(type)
            return lock.withLock { (counts[key] ?? [:]).values.reduce(0, +) }
        }

        func report() -> String {
            lock.withLock {
                order.map { key in
                    let lengths = (counts[key] ?? [:])
                        .sorted { $0.key < $1.key }
                        .map { "\($0.key) B ×\($0.value)" }
                        .joined(separator: ", ")
                    let group = UInt8(key >> 8)
                    let type = UInt8(key & 0xFF)
                    let name = key == 0xFF_FF
                        ? "(zu kurz)"
                        : String(format: "grp 0x%02x typ 0x%02x %@", group, type,
                                 D3200Message(group: group, type: type)
                                     .map { "(\($0))" } ?? "(unbekannt)")
                    return "  \(name): \(lengths)"
                }.joined(separator: "\n")
            }
        }
    }

    var frameReport: String { stats.report() }

    /// Wie viele Frames dieses Typs bisher ankamen. Grundlage der
    /// Realtime-Probe: Der eigene Zähler über einen zweiten Stream hat
    /// gelogen, diese Zählung sitzt im einzigen Tap und stimmt.
    func count(of message: D3200Message) -> Int {
        stats.count(group: message.group, type: message.type)
    }

    func connect() async throws { try await base.connect() }
    func disconnect() async { await base.disconnect() }

    func send(_ frame: Data) async throws {
        log("→", frame)
        try await base.send(frame)
    }

    /// Zählt und protokolliert **einmal** pro Frame und verteilt danach an
    /// alle Abnehmer. Früher lag die Zählung im Stream-Closure und lief
    /// dadurch pro Konsument – mit Client und Monitor am selben Transport
    /// erschien jeder Frame doppelt.
    private func startTapIfNeeded() {
        lock.withLock {
            guard tap == nil else { return }
            let inner = base.notifications()
            tap = Task { [weak self] in
                for await frame in inner {
                    guard let self else { return }
                    let response = RCSPFrame.Response(frame: frame)
                    stats.record(group: response?.group, type: response?.type, length: frame.count)
                    log("←", frame)
                    let sinks = lock.withLock { Array(self.sinks.values) }
                    for sink in sinks { sink.yield(frame) }
                }
                guard let self else { return }
                let sinks = lock.withLock { Array(self.sinks.values) }
                for sink in sinks { sink.finish() }
            }
        }
    }

    func notifications() -> AsyncStream<Data> {
        let id = UUID()
        let stream = AsyncStream(bufferingPolicy: .unbounded) { (continuation: AsyncStream<Data>.Continuation) in
            lock.withLock { sinks[id] = continuation }
            continuation.onTermination = { [weak self] _ in
                self?.lock.withLock { self?.sinks[id] = nil }
            }
        }
        startTapIfNeeded()
        return stream
    }

    private func log(_ direction: String, _ frame: Data) {
        guard verbose else { return }
        let label: String
        if let response = RCSPFrame.Response(frame: frame) {
            let name = response.message.map(String.init(describing:)) ?? "?"
            let mismatch = response.hasConsistentLength ? "" : " LÄNGE!"
            label = String(
                format: "grp=%02x typ=%02x(%@) len=%d/%d%@",
                response.group, response.type, name,
                response.declaredLength, frame.count, mismatch
            )
        } else {
            label = "command len=\(frame.count)"
        }
        // Kurze Frames vollständig dumpen – sie tragen die Layouts, die wir
        // gegen die Spec prüfen. Audio-Chunks nur anreißen.
        let limit = frame.count <= 128 ? frame.count : 16
        let head = frame.prefix(limit).map { String(format: "%02x", $0) }.joined(separator: " ")
        let tail = frame.count > limit
            ? " … \(String(format: "%02x", frame[frame.index(before: frame.endIndex)]))"
            : ""
        FileHandle.standardError.write(Data("\(direction) \(label)  \(head)\(tail)\n".utf8))
    }
}


extension Data {
    /// Hängt einen 32-Bit-Wert little-endian an.
    mutating func append(littleEndianBytes value: UInt32) {
        append(contentsOf: (0 ..< 4).map { UInt8(truncatingIfNeeded: value >> (8 * $0)) })
    }
}
