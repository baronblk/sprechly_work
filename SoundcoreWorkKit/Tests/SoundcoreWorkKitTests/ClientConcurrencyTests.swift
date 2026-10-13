import Foundation
import Testing

@testable import SoundcoreWorkKit

/// Transport, der wie das Gerät auf Befehle antwortet – mit einer Verzögerung,
/// damit sich nebenläufige Befehlsfolgen überhaupt verschränken können.
private final class ScriptedTransport: DeviceTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var sinks: [UUID: AsyncStream<Data>.Continuation] = [:]
    private(set) var sentCommands: [Data] = []

    /// Verzögerung zwischen Befehl und Antwort.
    let latency: Duration

    init(latency: Duration = .milliseconds(20)) {
        self.latency = latency
    }

    func connect() async throws {}

    func disconnect() async {
        let sinks = lock.withLock { Array(self.sinks.values) }
        for sink in sinks { sink.finish() }
    }

    func notifications() -> AsyncStream<Data> {
        let id = UUID()
        return AsyncStream(bufferingPolicy: .unbounded) { continuation in
            lock.withLock { sinks[id] = continuation }
            continuation.onTermination = { [weak self] _ in
                self?.lock.withLock { self?.sinks[id] = nil }
            }
        }
    }

    func send(_ frame: Data) async throws {
        lock.withLock { sentCommands.append(frame) }
        guard frame.count > 6 else { return }
        let group = frame[5]
        let type = frame[6]

        // Antwort wie das echte Gerät: nach kurzer Zeit, asynchron.
        Task { [latency] in
            try? await Task.sleep(for: latency)
            self.emit(Self.reply(group: group, type: type))
        }
    }

    private func emit(_ frame: Data) {
        let sinks = lock.withLock { Array(self.sinks.values) }
        for sink in sinks { sink.yield(frame) }
    }

    /// Antworten mit korrekter Gruppe, Typ und Längenbyte.
    static func reply(group: UInt8, type: UInt8) -> Data {
        switch (group, type) {
        case (0x01, 0x01):
            DeviceInfoTests.deviceInfoFrame
        case (0x01, 0x03):
            Data(hex: "09ff0000010103" + "0c" + "00" + "0909" + "2b")!
        case (0x01, 0xA6):
            Data(hex: "09ff00000101a60a00ba")!
        case (0x0B, 0x03):
            Data(hex: "09ff0000010b030a0021")!
        case (0x1A, 0x0E):
            FrameTests.liveListTwoEntries
        default:
            Data([0x09, 0xFF, 0x00, 0x00, 0x01, group, type, 0x0A, 0x00, 0x00])
        }
    }
}

/// Der Fehler am Gerät kam daher, dass die nebenherlaufende Geräte-Info-Abfrage
/// die Antwort einer anderen Befehlsfolge abgefangen hat.
@Suite("Client: nebenläufige Befehle")
struct ClientConcurrencyTests {
    @Test("Geräte-Info und Dateiliste gleichzeitig stören sich nicht")
    func concurrentCommandsDoNotStealReplies() async throws {
        let transport = ScriptedTransport()
        let client = D3200Client(transport: transport)
        try await client.connect()

        async let info = client.fetchDeviceInfo()
        async let recordings = client.listRecordings(maxPages: 1)

        let (loadedInfo, loadedRecordings) = try await (info, recordings)

        #expect(loadedInfo.firmwareVersion == "03.36")
        #expect(loadedInfo.battery.percent == 100)
        #expect(loadedRecordings.count == 2)
        await client.disconnect()
    }

    @Test("Viele parallele Abfragen laufen alle durch")
    func manyConcurrentQueries() async throws {
        let transport = ScriptedTransport(latency: .milliseconds(5))
        let client = D3200Client(transport: transport)
        try await client.connect()

        try await withThrowingTaskGroup(of: Int.self) { group in
            for _ in 0 ..< 8 {
                group.addTask { try await client.fetchDeviceInfo().battery.percent }
                group.addTask { try await client.listRecordings(maxPages: 1).count }
            }
            var results: [Int] = []
            for try await value in group { results.append(value) }
            // 8× Akku (100) und 8× Anzahl Aufnahmen (2)
            #expect(results.count == 16)
            #expect(results.filter { $0 == 100 }.count == 8)
            #expect(results.filter { $0 == 2 }.count == 8)
        }
        await client.disconnect()
    }

    @Test("Auth und Time-Sync bleiben in ihrer Reihenfolge")
    func sequentialCommandsStillWork() async throws {
        let transport = ScriptedTransport()
        let client = D3200Client(transport: transport)
        try await client.connect()

        try await client.authenticate()
        try await client.syncTime(date: Date(timeIntervalSince1970: 1_769_687_627))

        #expect(transport.sentCommands.count == 2)
        #expect(transport.sentCommands[0][6] == 0x03)  // Auth
        #expect(transport.sentCommands[1][6] == 0xA6)  // Time-Sync
        await client.disconnect()
    }
}

/// Der Live-Status muss sofort kommen, nicht erst wenn zufällig ein Befehl
/// auf eine Antwort wartet.
@Suite("Client: unaufgeforderte Ereignisse")
struct ClientEventTests {
    /// Transport, der Pushes schickt, ohne dass etwas angefragt wurde.
    private final class PushingTransport: DeviceTransport, @unchecked Sendable {
        private let lock = NSLock()
        private var sinks: [UUID: AsyncStream<Data>.Continuation] = [:]

        func connect() async throws {}
        func disconnect() async {
            let sinks = lock.withLock { Array(self.sinks.values) }
            for sink in sinks { sink.finish() }
        }
        func send(_ frame: Data) async throws {}

        func notifications() -> AsyncStream<Data> {
            let id = UUID()
            return AsyncStream(bufferingPolicy: .unbounded) { continuation in
                lock.withLock { sinks[id] = continuation }
                continuation.onTermination = { [weak self] _ in
                    self?.lock.withLock { self?.sinks[id] = nil }
                }
            }
        }

        func push(_ frame: Data) {
            let sinks = lock.withLock { Array(self.sinks.values) }
            for sink in sinks { sink.yield(frame) }
        }
    }

    @Test("Push ohne laufenden Befehl wird zum Ereignis")
    func pushArrivesWithoutPendingCommand() async throws {
        let transport = PushingTransport()
        let client = D3200Client(transport: transport)
        try await client.connect()
        let events = await client.events()

        // Kein Befehl unterwegs – trotzdem muss das Ereignis ankommen.
        transport.push(EventTests.newRecordingFrame)

        var received: D3200Event?
        for await event in events {
            received = event
            break
        }
        #expect(received == .recordingState(fileID: 0x6ACE_9A36, state: .newRecording))
        await client.disconnect()
    }

    @Test("Start, Pause und Stop kommen als Statuswechsel an")
    func statusChangesArrive() async throws {
        let transport = PushingTransport()
        let client = D3200Client(transport: transport)
        try await client.connect()
        let events = await client.events()

        transport.push(EventTests.startAckFrame)
        transport.push(EventTests.pauseAckFrame)
        transport.push(EventTests.stopAckFrame)

        var statuses: [D3200RecordStatus] = []
        for await event in events {
            if case .recordStatus(let status, _, _) = event { statuses.append(status) }
            if statuses.count == 3 { break }
        }
        #expect(statuses == [.recording, .paused, .stopped])
        await client.disconnect()
    }
}

/// Der Fehler im Feld: Nach einem Timeout lag die verspätete Antwort in der
/// Warteschlange, und jeder folgende Befehl las sie als seine eigene. In der
/// App zeigte sich das als „Unerwartete Nachricht (Gruppe 0x2e, Typ 0x1)".
@Suite("Client: Versatz nach Nachzüglern")
struct ClientStaleFrameTests {
    private final class ReplayTransport: DeviceTransport, @unchecked Sendable {
        private let lock = NSLock()
        private var sinks: [UUID: AsyncStream<Data>.Continuation] = [:]
        /// Frames, die vor der Antwort eingeschoben werden.
        var prefixFrames: [Data] = []

        func connect() async throws {}
        func disconnect() async {
            let sinks = lock.withLock { Array(self.sinks.values) }
            for sink in sinks { sink.finish() }
        }

        func notifications() -> AsyncStream<Data> {
            let id = UUID()
            return AsyncStream(bufferingPolicy: .unbounded) { continuation in
                lock.withLock { sinks[id] = continuation }
                continuation.onTermination = { [weak self] _ in
                    self?.lock.withLock { self?.sinks[id] = nil }
                }
            }
        }

        func send(_ frame: Data) async throws {
            guard frame.count > 6 else { return }
            let group = frame[5], type = frame[6]
            let extras = lock.withLock {
                let pending = prefixFrames
                prefixFrames = []
                return pending
            }
            Task {
                try? await Task.sleep(for: .milliseconds(10))
                for extra in extras { self.emit(extra) }
                self.emit(ScriptedTransportReply.reply(group: group, type: type))
            }
        }

        func push(_ frame: Data) {
            emit(frame)
        }

        private func emit(_ frame: Data) {
            let sinks = lock.withLock { Array(self.sinks.values) }
            for sink in sinks { sink.yield(frame) }
        }
    }

    @Test("Eine fremde Antwort vor der eigenen entgleist den Befehl nicht")
    func straggingReplyIsSkipped() async throws {
        let transport = ReplayTransport()
        let client = D3200Client(transport: transport)
        try await client.connect()

        // Vor der Geräte-Info trifft die verspätete ECDH-Antwort ein – genau
        // der Fall aus dem Screenshot.
        transport.prefixFrames = [Data(hex: "09ff0000012e016b00")! + Data(repeating: 0x11, count: 98)]

        let info = try await client.fetchDeviceInfo()
        #expect(info.firmwareVersion == "03.36")
        await client.disconnect()
    }

    @Test("Ein Frame aus einer früheren Folge verschiebt die nächste nicht")
    func pendingFrameDoesNotShiftTheNextCommand() async throws {
        let transport = ReplayTransport()
        let client = D3200Client(transport: transport)
        try await client.connect()

        // Nachzügler ohne laufenden Befehl – landet in der Warteschlange.
        transport.push(Data(hex: "09ff0000012e016b00")! + Data(repeating: 0x22, count: 98))
        try await Task.sleep(for: .milliseconds(30))

        // Der nächste Befehl muss trotzdem seine eigene Antwort bekommen.
        let info = try await client.fetchDeviceInfo()
        #expect(info.serialNumber == "32007ce9131d272b")
        await client.disconnect()
    }
}

/// Antworten für die Test-Transporte.
enum ScriptedTransportReply {
    static func reply(group: UInt8, type: UInt8) -> Data {
        switch (group, type) {
        case (0x01, 0x01): DeviceInfoTests.deviceInfoFrame
        case (0x01, 0xA6): Data(hex: "09ff00000101a60a00ba")!
        case (0x0B, 0x03): Data(hex: "09ff0000010b030a0021")!
        case (0x1A, 0x0E): FrameTests.liveListTwoEntries
        default: Data([0x09, 0xFF, 0x00, 0x00, 0x01, group, type, 0x0A, 0x00, 0x00])
        }
    }
}
