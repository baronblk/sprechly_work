import Foundation
import os

/// Ergebnis eines Downloads.
public struct D3200Download: Sendable {
    public let header: D3200FileHeader
    /// Entschlüsselte Opus-Pakete à 160 Byte, in Reihenfolge.
    public let opusPackets: [Data]

    /// Verpackt die Pakete in einen Ogg/Opus-Container.
    public func oggOpus(writer: OggOpusWriter = OggOpusWriter()) throws -> Data {
        try writer.makeFile(packets: opusPackets)
    }
}

/// Orchestriert die Gerätesequenz aus `docs/d3200_protocol_spec.md` §3.
///
/// ```swift
/// let client = D3200Client(transport: BLETransport())
/// try await client.connect()
/// try await client.authenticate()
/// try await client.syncTime()
/// let recordings = try await client.listRecordings()
/// try await client.performKeyExchange()   // zwingend VOR dem ersten Download
/// let download = try await client.download(fileID: recordings[0].fileID)
/// try download.oggOpus().write(to: url)
/// ```
public actor D3200Client {
    public enum ClientError: Error, LocalizedError, Equatable {
        case notConnected
        case keyExchangeMissing
        case unexpectedMessage(group: UInt8, type: UInt8)
        case malformedFrame(declared: UInt8, actual: Int)
        case chunkOutOfOrder(expected: UInt8, got: UInt8)
        case streamEnded
        case concurrentRead
        case incompleteAudio(bytes: Int)
        case truncatedTransfer(got: Int, expected: Int)

        public var errorDescription: String? {
            switch self {
            case .notConnected:
                "Client ist nicht verbunden – zuerst connect() aufrufen."
            case .keyExchangeMissing:
                "ECDH-Handshake fehlt – performKeyExchange() vor dem Download aufrufen."
            case .unexpectedMessage(let group, let type):
                "Unerwartete Nachricht (Gruppe 0x\(String(group, radix: 16)), "
                    + "Typ 0x\(String(type, radix: 16)))."
            case .malformedFrame(let declared, let actual):
                "Frame gibt \(declared) Byte an, hat aber \(actual)."
            case .streamEnded:
                "Die Verbindung wurde während des Transfers beendet."
            case .concurrentRead:
                "Es läuft bereits eine Leseanforderung – Befehle müssen sequenziell laufen."
            case .chunkOutOfOrder(let expected, let got):
                "Audio-Chunk außer Reihe: erwartet #\(expected), erhalten #\(got)."
            case .incompleteAudio(let bytes):
                "Audio-Stream endete mit \(bytes) Byte und ist kein Vielfaches von "
                    + "\(D3200Crypto.rawFrameSize)."
            case .truncatedTransfer(let got, let expected):
                "Transfer unvollständig: \(got) von \(expected) Byte."
            }
        }
    }

    private let logger = Logger(subsystem: "de.gcng.sprechly.work", category: "D3200Client")
    private let transport: DeviceTransport
    private let responseTimeout: Duration

    private var pumpTask: Task<Void, Never>?
    private var pending: [Data] = []
    private var waiter: CheckedContinuation<Data, Error>?
    private var waitGeneration = 0
    private var eventSinks: [UUID: AsyncStream<D3200Event>.Continuation] = [:]
    /// Serialisiert ganze Befehlsfolgen (siehe `runExclusively`).
    private var isRunningCommand = false
    private var commandQueue: [CheckedContinuation<Void, Never>] = []
    private var streamDidEnd = false
    private var sessionKey: Data?

    public init(transport: DeviceTransport, responseTimeout: Duration = .seconds(15)) {
        self.transport = transport
        self.responseTimeout = responseTimeout
    }

    /// Ob der ECDH-Handshake gelaufen ist.
    public var hasSessionKey: Bool { sessionKey != nil }

    /// Strom der unaufgeforderten Geräte-Ereignisse.
    ///
    /// Damit merkt die App live, wenn am Work selbst eine Aufnahme startet
    /// oder endet. Mehrfachaufrufe liefern unabhängige Ströme.
    public func events() -> AsyncStream<D3200Event> {
        let id = UUID()
        return AsyncStream(bufferingPolicy: .unbounded) { continuation in
            eventSinks[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeEventSink(id) }
            }
        }
    }

    private func removeEventSink(_ id: UUID) {
        eventSinks[id] = nil
    }

    private func emit(_ event: D3200Event) {
        logger.info("Geräte-Ereignis: \(String(describing: event), privacy: .public)")
        for sink in eventSinks.values { sink.yield(event) }
    }

    // MARK: - Verbindung

    public func connect() async throws {
        try await transport.connect()
        let stream = transport.notifications()
        streamDidEnd = false
        pending.removeAll()
        pumpTask = Task { [weak self] in
            for await frame in stream {
                await self?.ingest(frame)
            }
            await self?.finishStream()
        }
    }

    public func disconnect() async {
        pumpTask?.cancel()
        pumpTask = nil
        await transport.disconnect()
        finishStream()
        for sink in eventSinks.values { sink.finish() }
        eventSinks.removeAll()
        sessionKey = nil
    }

    // MARK: - Befehle (Spec §3)

    /// Schritt 2: Auth mit statischem Token.
    public func authenticate() async throws {
        try await runExclusively {
            try await transport.send(D3200Commands.auth())
            _ = try await nextMessage(expecting: [.auth])
        }
    }

    /// Schritt 3: Time-Sync.
    public func syncTime(date: Date = Date()) async throws {
        try await runExclusively {
            try await transport.send(D3200Commands.timeSync(date: date))
            _ = try await nextMessage(expecting: [.timeSync])
        }
    }

    /// Schritt 4: Dateiliste, paginiert bis zur ersten leeren Seite.
    public func listRecordings(maxPages: Int = 16) async throws -> [D3200Recording] {
        try await runExclusively {
            var recordings: [D3200Recording] = []
            for page in 0 ..< maxPages {
                try await transport.send(D3200Commands.listFiles(page: UInt8(truncatingIfNeeded: page)))
                let response = try await nextMessage(expecting: [.fileList])
                let items = D3200Recording.parseList(response: response.frame)
                // Eine leere Seite beendet die Liste.
                if items.isEmpty { break }
                recordings.append(contentsOf: items)
            }
            logger.info("\(recordings.count) Aufnahmen gelistet")
            return recordings
        }
    }

    /// Schritt 5: ECDH-Handshake. Muss **vor** der ersten Detail-Anforderung laufen,
    /// sonst stößt diese sofort den Download an und verschluckt die Handshake-Antwort.
    public func performKeyExchange() async throws {
        try await runExclusively {
            let privateKey = D3200Crypto.makeKeyPair()
            try await transport.send(
                D3200Commands.keyExchange(publicKey: D3200Crypto.rawPublicKey(privateKey))
            )
            let response = try await nextMessage(expecting: [.keyExchange])
            let devicePublicKey = try D3200Crypto.parseDevicePublicKey(from: response.frame)
            let shared = try D3200Crypto.sharedSecret(
                privateKey: privateKey,
                devicePublicKey: devicePublicKey
            )
            sessionKey = try D3200Crypto.sessionKey(sharedSecret: shared)
            logger.info("Session-Key abgeleitet")
        }
    }

    /// Fragt den Gerätezustand ab: Akku, Laden, Firmware, Seriennummer,
    /// Speicher und Ladecase (Spec §7b).
    ///
    /// Manche Firmwares aktualisieren nur auf Abfrage – für eine Live-Anzeige
    /// regelmäßig aufrufen (die Hersteller-App pollt rund alle 15 s).
    public func fetchDeviceInfo() async throws -> D3200DeviceInfo {
        try await runExclusively {
            try await transport.send(D3200Commands.deviceInfo())
            let response = try await nextMessage(expecting: [.deviceInfo])
            return try D3200DeviceInfo(response: response.frame)
        }
    }

    /// Nur die beiden Akkustände (kürzere Antwort als die volle Geräte-Info).
    public func fetchBattery() async throws -> D3200PowerStatus {
        try await runExclusively {
            try await transport.send(D3200Commands.battery())
            let response = try await nextMessage(expecting: [.battery])
            guard let status = D3200PowerStatus(response: response.frame) else {
                throw ClientError.unexpectedMessage(group: response.group, type: response.type)
            }
            return status
        }
    }

    /// Schickt eine Abfrage ohne Nutzdaten; die Antwort kommt über `events()`
    /// bzw. den laufenden Mitschnitt.
    public func sendQuery(_ message: D3200Message) async throws {
        try await transport.send(D3200Commands.query(message))
    }

    /// Steuert die Aufnahme am Gerät fern (Spec §7a).
    ///
    /// Die Antwort kommt als unaufgefordertes Ereignis über `events()`,
    /// nicht als direkte Rückgabe – das Gerät meldet seinen Status auf
    /// derselben Gruppe/Typ.
    public func sendRecordControl(_ action: D3200RecordAction) async throws {
        try await transport.send(D3200Commands.recordControl(action))
        logger.info("Record-Control gesendet: \(String(describing: action), privacy: .public)")
    }

    /// Schritte 6–8: Detail anfordern, Chunks sammeln, entschlüsseln.
    ///
    /// - Parameter progress: `(empfangene Bytes, erwartete Bytes)`. Die erwartete
    ///   Zahl ist exakt: `frameCount * 164` aus dem File-Header.
    public func download(
        fileID: UInt32,
        progress: (@Sendable (Int, Int) -> Void)? = nil
    ) async throws -> D3200Download {
        try await runExclusively {
            guard let sessionKey else { throw ClientError.keyExchangeMissing }

            try await transport.send(D3200Commands.fileDetail(fileID: fileID))

            let headerMessage = try await nextMessage(expecting: [.fileDetail])
            let header = try D3200FileHeader(response: headerMessage.frame)
            let fileKey = try D3200Crypto.unwrapFileKey(header: header, sessionKey: sessionKey)
            logger.info("File-Key entpackt (file_id=\(header.fileID), size=\(header.fileSize))")

            var raw = Data()
            var chunkIndex = 0
            collect: while true {
                let response = try await nextMessage(expecting: [.audioChunk, .transferComplete])
                switch response.message {
                case .audioChunk:
                    // Der Zähler im Frame sichert die Reihenfolge ab; er ist ein
                    // Byte breit und läuft nach 256 Frames über.
                    let expected = UInt8(truncatingIfNeeded: chunkIndex)
                    if let sequence = Self.chunkSequence(of: response.frame), sequence != expected {
                        throw ClientError.chunkOutOfOrder(expected: expected, got: sequence)
                    }
                    raw.append(Self.audioPayload(from: response.frame))
                    chunkIndex += 1
                    progress?(raw.count, header.expectedRawBytes)
                case .transferComplete:
                    let size = response.frame.littleEndianUInt32(at: D3200Message.transferComplete.payloadOffset)
                    logger.info("Transfer fertig, Gerät meldet Größe \(size ?? 0)")
                    break collect
                default:
                    continue  // transferInit – nur eine Ankündigung
                }
            }

            guard raw.count % D3200Crypto.rawFrameSize == 0, !raw.isEmpty else {
                throw ClientError.incompleteAudio(bytes: raw.count)
            }
            // Der File-Header gibt die Frameanzahl vor; damit fällt ein abgebrochener
            // Transfer auf, statt eine zu kurze Aufnahme zu liefern.
            guard raw.count == header.expectedRawBytes else {
                throw ClientError.truncatedTransfer(got: raw.count, expected: header.expectedRawBytes)
            }

            // Die Chunks sind exakt das gespeicherte Rohformat, daher derselbe
            // Entschlüsselungsweg wie im Offline-Test gegen die Fixtures.
            let packets = try D3200Crypto.decryptRawStream(
                raw,
                fileKey: fileKey,
                nonce: header.nonce
            )
            logger.info("\(packets.count) Opus-Pakete entschlüsselt")
            return D3200Download(header: header, opusPackets: packets)
        }
    }

    /// Nutzlast eines `08b0`-Chunks: ab Offset 12 steht ein vollständiger
    /// 164-Byte-Frame des Rohformats (2 B Flags, 160 B Audio, 2 B Rest).
    ///
    /// Am Gerät verifiziert: 45 Chunks à 176 B ergeben 7380 B – genau den
    /// Roh-Stream der Referenz-Aufnahme. Ein Checksum-Byte am Frame-Ende gibt
    /// es nicht; die Nutzlast reicht bis zum letzten Byte.
    static func audioPayload(from frame: Data) -> Data {
        Data(frame.dropFirst(D3200Message.audioChunk.payloadOffset))
    }

    /// Frame-Zähler eines `08b0`-Chunks (Offset 9, beginnt bei 0).
    static func chunkSequence(of frame: Data) -> UInt8? {
        let offset = frame.startIndex + 9
        guard offset < frame.endIndex else { return nil }
        return frame[offset]
    }

    // MARK: - Befehlsfolgen serialisieren

    /// Führt eine komplette Befehlsfolge exklusiv aus.
    ///
    /// Der Actor allein genügt dafür **nicht**: Er serialisiert nur den
    /// Methodeneintritt, und jedes `await` innerhalb einer Folge – Befehl
    /// senden, auf Antwort warten – ist ein Punkt, an dem eine zweite Folge
    /// startet. Beide greifen dann abwechselnd Frames aus demselben Strom.
    ///
    /// Am Gerät beobachtet: Eine nebenherlaufende Geräte-Info-Abfrage hat die
    /// Antwort des Handshakes abgefangen, der Session-Key war falsch und das
    /// Entpacken des File-Keys schlug fehl („Hülle beginnt nicht mit
    /// soundcored3200").
    private func runExclusively<T>(_ body: () async throws -> T) async rethrows -> T {
        while isRunningCommand {
            await withCheckedContinuation { commandQueue.append($0) }
        }
        isRunningCommand = true
        defer {
            isRunningCommand = false
            if !commandQueue.isEmpty { commandQueue.removeFirst().resume() }
        }
        return try await body()
    }

    // MARK: - Frame-Pumpe

    /// Nimmt jeden eingehenden Frame entgegen.
    ///
    /// Unaufgeforderte Pushes werden **hier** zu Ereignissen, nicht erst in
    /// `nextMessage`. Sonst entstünden sie nur, solange gerade ein Befehl auf
    /// Antwort wartet – der Live-Status käme also bloß im Takt des nächsten
    /// Befehls statt sofort.
    private func ingest(_ frame: Data) {
        if let response = RCSPFrame.Response(frame: frame),
           let message = response.message,
           D3200Event.unsolicitedTypes.contains(message) {
            emit(D3200Event(response: response)
                ?? .unknown(group: response.group, type: response.type, data: response.frame))
            return
        }
        if let continuation = takeWaiter() {
            continuation.resume(returning: frame)
        } else {
            pending.append(frame)
        }
    }

    private func finishStream() {
        streamDidEnd = true
        takeWaiter()?.resume(throwing: ClientError.streamEnded)
    }

    private func takeWaiter() -> CheckedContinuation<Data, Error>? {
        defer { waiter = nil }
        return waiter
    }

    private func timeOutWait(generation: Int) {
        guard waitGeneration == generation, let continuation = takeWaiter() else { return }
        continuation.resume(throwing: TransportError.timedOut)
    }

    /// Nächste Nachricht; überspringt unaufgeforderte Metadaten-Pushes und
    /// prüft die Längenangabe aus Offset 7.
    private func nextMessage() async throws -> RCSPFrame.Response {
        while true {
            let frame = try await rawFrame()
            guard let response = RCSPFrame.Response(frame: frame) else {
                logger.warning("Frame zu kurz für einen Response-Kopf (\(frame.count) B)")
                continue
            }
            guard response.hasConsistentLength else {
                throw ClientError.malformedFrame(
                    declared: response.declaredLength,
                    actual: response.frame.count
                )
            }
            // Pushes sind hier nicht mehr zu erwarten: `ingest` fängt sie ab,
            // bevor sie in den Befehlsfluss geraten.
            return response
        }
    }

    /// Nächste Nachricht eines der erwarteten Typen; Pushes werden übersprungen.
    private func nextMessage(
        expecting types: Set<D3200Message>
    ) async throws -> RCSPFrame.Response {
        let response = try await nextMessage()
        guard let message = response.message, types.contains(message) else {
            throw ClientError.unexpectedMessage(group: response.group, type: response.type)
        }
        return response
    }

    private func rawFrame() async throws -> Data {
        if !pending.isEmpty { return pending.removeFirst() }
        if streamDidEnd { throw ClientError.streamEnded }
        guard waiter == nil else { throw ClientError.concurrentRead }

        waitGeneration += 1
        let generation = waitGeneration
        let watchdog = Task { [responseTimeout] in
            try? await Task.sleep(for: responseTimeout)
            self.timeOutWait(generation: generation)
        }
        defer { watchdog.cancel() }

        return try await withCheckedThrowingContinuation { continuation in
            waiter = continuation
        }
    }
}
