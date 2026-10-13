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
        case unexpectedFrame(opcode: UInt16?)
        case chunkOutOfOrder(expected: UInt8, got: UInt8)
        case streamEnded
        case concurrentRead
        case incompleteAudio(bytes: Int)

        public var errorDescription: String? {
            switch self {
            case .notConnected:
                "Client ist nicht verbunden – zuerst connect() aufrufen."
            case .keyExchangeMissing:
                "ECDH-Handshake fehlt – performKeyExchange() vor dem Download aufrufen."
            case .unexpectedFrame(let opcode):
                if let opcode {
                    "Unerwarteter Frame mit Opcode 0x\(String(opcode, radix: 16, uppercase: false))."
                } else {
                    "Unerwarteter, zu kurzer Frame."
                }
            case .streamEnded:
                "Die Verbindung wurde während des Transfers beendet."
            case .concurrentRead:
                "Es läuft bereits eine Leseanforderung – Befehle müssen sequenziell laufen."
            case .chunkOutOfOrder(let expected, let got):
                "Audio-Chunk außer Reihe: erwartet #\(expected), erhalten #\(got)."
            case .incompleteAudio(let bytes):
                "Audio-Stream endete mit \(bytes) Byte und ist kein Vielfaches von "
                    + "\(D3200Crypto.rawFrameSize)."
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
    private var streamDidEnd = false
    private var sessionKey: Data?

    public init(transport: DeviceTransport, responseTimeout: Duration = .seconds(15)) {
        self.transport = transport
        self.responseTimeout = responseTimeout
    }

    /// Ob der ECDH-Handshake gelaufen ist.
    public var hasSessionKey: Bool { sessionKey != nil }

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
        sessionKey = nil
    }

    // MARK: - Befehle (Spec §3)

    /// Schritt 2: Auth mit statischem Token.
    public func authenticate() async throws {
        try await transport.send(D3200Commands.auth())
        _ = try await nextFrame()
    }

    /// Schritt 3: Time-Sync.
    public func syncTime(date: Date = Date()) async throws {
        try await transport.send(D3200Commands.timeSync(date: date))
        _ = try await nextFrame()
    }

    /// Schritt 4: Dateiliste, paginiert bis zur ersten leeren Seite.
    public func listRecordings(maxPages: Int = 16) async throws -> [D3200Recording] {
        var recordings: [D3200Recording] = []
        for page in 0 ..< maxPages {
            try await transport.send(D3200Commands.listFiles(page: UInt8(truncatingIfNeeded: page)))
            let frame = try await nextFrame(expecting: [.fileList, .fileListEnd])
            if RCSPFrame.opcode(of: frame) == D3200Opcode.fileListEnd.rawValue { break }
            let items = D3200Recording.parseList(response: frame)
            if items.isEmpty { break }
            recordings.append(contentsOf: items)
        }
        logger.info("\(recordings.count) Aufnahmen gelistet")
        return recordings
    }

    /// Schritt 5: ECDH-Handshake. Muss **vor** der ersten Detail-Anforderung laufen,
    /// sonst stößt diese sofort den Download an und verschluckt die Handshake-Antwort.
    public func performKeyExchange() async throws {
        let privateKey = D3200Crypto.makeKeyPair()
        try await transport.send(
            D3200Commands.keyExchange(publicKey: D3200Crypto.rawPublicKey(privateKey))
        )
        let frame = try await nextFrame(expecting: [.keyExchange])
        let devicePublicKey = try D3200Crypto.parseDevicePublicKey(from: frame)
        let shared = try D3200Crypto.sharedSecret(
            privateKey: privateKey,
            devicePublicKey: devicePublicKey
        )
        sessionKey = try D3200Crypto.sessionKey(sharedSecret: shared)
        logger.info("Session-Key abgeleitet")
    }

    /// Schritte 6–8: Detail anfordern, Chunks sammeln, entschlüsseln.
    ///
    /// - Parameter progress: `(empfangene Bytes, laut File-Header erwartete Bytes)`.
    ///   Die erwartete Größe ist die Angabe des Geräts und nur eine Näherung.
    public func download(
        fileID: UInt32,
        progress: (@Sendable (Int, Int) -> Void)? = nil
    ) async throws -> D3200Download {
        guard let sessionKey else { throw ClientError.keyExchangeMissing }

        try await transport.send(D3200Commands.fileDetail(fileID: fileID))

        let headerFrame = try await nextFrame(expecting: [.fileDetail])
        let header = try D3200FileHeader(response: headerFrame)
        let fileKey = try D3200Crypto.unwrapFileKey(header: header, sessionKey: sessionKey)
        logger.info("File-Key entpackt (file_id=\(header.fileID), size=\(header.fileSize))")

        var raw = Data()
        var chunkIndex = 0
        collect: while true {
            let frame = try await nextFrame(expecting: [.audioChunk, .transferComplete, .transferInit])
            switch RCSPFrame.opcode(of: frame).flatMap(D3200Opcode.init(rawValue:)) {
            case .audioChunk:
                // Der Zähler im Frame sichert die Reihenfolge ab; er ist ein
                // Byte breit und läuft nach 256 Frames über.
                let expected = UInt8(truncatingIfNeeded: chunkIndex)
                if let sequence = Self.chunkSequence(of: frame), sequence != expected {
                    throw ClientError.chunkOutOfOrder(expected: expected, got: sequence)
                }
                raw.append(Self.audioPayload(from: frame))
                chunkIndex += 1
                progress?(raw.count, Int(header.fileSize))
            case .transferComplete:
                let size = frame.littleEndianUInt32(at: D3200Opcode.transferComplete.payloadOffset)
                logger.info("Transfer fertig, Gerät meldet Größe \(size ?? 0)")
                break collect
            default:
                continue  // transferInit – nur eine Ankündigung
            }
        }

        guard raw.count % D3200Crypto.rawFrameSize == 0, !raw.isEmpty else {
            throw ClientError.incompleteAudio(bytes: raw.count)
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

    /// Nutzlast eines `08b0`-Chunks: ab Offset 12 steht ein vollständiger
    /// 164-Byte-Frame des Rohformats (2 B Flags, 160 B Audio, 2 B Rest).
    ///
    /// Am Gerät verifiziert: 45 Chunks à 176 B ergeben 7380 B – genau den
    /// Roh-Stream der Referenz-Aufnahme. Ein Checksum-Byte am Frame-Ende gibt
    /// es nicht; die Nutzlast reicht bis zum letzten Byte.
    static func audioPayload(from frame: Data) -> Data {
        Data(frame.dropFirst(D3200Opcode.audioChunk.payloadOffset))
    }

    /// Frame-Zähler eines `08b0`-Chunks (Offset 9, beginnt bei 0).
    static func chunkSequence(of frame: Data) -> UInt8? {
        let offset = frame.startIndex + 9
        guard offset < frame.endIndex else { return nil }
        return frame[offset]
    }

    // MARK: - Frame-Pumpe

    private func ingest(_ frame: Data) {
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

    /// Nächster Frame; überspringt Metadaten-Pushes (Spec §2).
    private func nextFrame() async throws -> Data {
        while true {
            let frame = try await rawFrame()
            if RCSPFrame.opcode(of: frame) == D3200Opcode.metadataPush.rawValue { continue }
            return frame
        }
    }

    /// Nächster Frame mit einem der erwarteten Opcodes; Pushes werden übersprungen.
    private func nextFrame(expecting opcodes: Set<D3200Opcode>) async throws -> Data {
        while true {
            let frame = try await nextFrame()
            let raw = RCSPFrame.opcode(of: frame)
            guard let opcode = raw.flatMap(D3200Opcode.init(rawValue:)), opcodes.contains(opcode) else {
                throw ClientError.unexpectedFrame(opcode: raw)
            }
            return frame
        }
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
