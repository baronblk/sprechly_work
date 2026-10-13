import Foundation
import SoundcoreWorkKit

/// Legt sich um einen echten Transport und protokolliert jeden Frame.
///
/// Beantwortet die offenen Punkte aus `SoundcoreWorkKit/README.md`: Wie lang
/// sind die `08b0`-Frames wirklich, welchen Opcode trägt die Listen-Antwort,
/// und kommt nach dem `0761` ohne zweite Anforderung ein Chunk-Stream.
final class TracingTransport: DeviceTransport, @unchecked Sendable {
    private let base: DeviceTransport
    private let stats = Stats()
    private let verbose: Bool

    init(wrapping base: DeviceTransport, verbose: Bool) {
        self.base = base
        self.verbose = verbose
    }

    /// Längenverteilung pro Opcode, damit der Chunk-Zuschnitt belegt ist.
    final class Stats: @unchecked Sendable {
        private let lock = NSLock()
        private var counts: [UInt16: [Int: Int]] = [:]
        private var order: [UInt16] = []

        func record(opcode: UInt16?, length: Int) {
            let key = opcode ?? 0xFFFF
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
                    let name = key == 0xFFFF ? "(zu kurz)" : String(format: "%04x", key)
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

    func notifications() -> AsyncStream<Data> {
        let inner = base.notifications()
        return AsyncStream(bufferingPolicy: .unbounded) { continuation in
            let task = Task {
                for await frame in inner {
                    stats.record(opcode: RCSPFrame.opcode(of: frame), length: frame.count)
                    log("←", frame)
                    continuation.yield(frame)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func log(_ direction: String, _ frame: Data) {
        guard verbose else { return }
        let opcode = RCSPFrame.opcode(of: frame).map { String(format: "%04x", $0) } ?? "----"
        // Kurze Frames vollständig dumpen – sie tragen die Layouts, die wir
        // gegen die Spec prüfen. Audio-Chunks nur anreißen.
        let limit = frame.count <= 64 ? frame.count : 16
        let head = frame.prefix(limit).map { String(format: "%02x", $0) }.joined(separator: " ")
        let tail = frame.count > limit
            ? " … \(String(format: "%02x", frame[frame.index(before: frame.endIndex)]))"
            : ""
        FileHandle.standardError.write(Data(
            "\(direction) op=\(opcode) len=\(frame.count)  \(head)\(tail)\n".utf8
        ))
    }
}
