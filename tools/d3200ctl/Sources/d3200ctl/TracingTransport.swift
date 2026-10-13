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

        func record(type: UInt8?, length: Int) {
            let key = type.map(UInt16.init) ?? 0xFFFF
            lock.withLock {
                if counts[key] == nil { order.append(key) }
                counts[key, default: [:]][length, default: 0] += 1
            }
        }

        func report() -> String {
            lock.withLock {
                order.map { key in
                    let lengths = (counts[key] ?? [:])
                        .sorted { $0.key < $1.key }
                        .map { "\($0.key) B ×\($0.value)" }
                        .joined(separator: ", ")
                    let name = key == 0xFFFF
                        ? "(zu kurz)"
                        : String(format: "Typ 0x%02x %@", key,
                                 D3200Message(rawValue: UInt8(key))
                                     .map { "(\($0))" } ?? "(unbekannt)")
                    return "  \(name): \(lengths)"
                }.joined(separator: "\n")
            }
        }
    }

    var frameReport: String { stats.report() }

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
                    stats.record(type: RCSPFrame.Response(frame: frame)?.type, length: frame.count)
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
        let limit = frame.count <= 64 ? frame.count : 16
        let head = frame.prefix(limit).map { String(format: "%02x", $0) }.joined(separator: " ")
        let tail = frame.count > limit
            ? " … \(String(format: "%02x", frame[frame.index(before: frame.endIndex)]))"
            : ""
        FileHandle.standardError.write(Data("\(direction) \(label)  \(head)\(tail)\n".utf8))
    }
}
