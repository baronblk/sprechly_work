import AudioToolbox
import Foundation

/// Schreibt rohe Opus-Pakete in einen CAF-Container.
///
/// AVFoundation kann Ogg/Opus auf iOS nicht verlässlich lesen, Opus **im
/// CAF-Container** dagegen schon – das ist Apples eigener Weg für Opus.
/// `AudioFileWritePackets` legt die Paket-Tabelle selbst an, deshalb kommt
/// hier kein handgeschriebener Container zum Einsatz.
///
/// Am eigenen Gerät gegengeprüft: die 45 Pakete der Referenz-Aufnahme ergeben
/// eine CAF-Datei, die `AVAudioFile` als 2 ch / 48 kHz / opus mit
/// 43200 Frames öffnet (0,9 s).
public struct CAFOpusWriter: Sendable {
    /// Opus dekodiert intern immer auf 48 kHz.
    public static let sampleRate: Double = 48000
    /// Samples pro Paket (20 ms bei 48 kHz).
    public static let framesPerPacket: UInt32 = 960

    public enum Failure: Error, LocalizedError, Equatable {
        case noPackets
        case createFailed(status: OSStatus)
        case writeFailed(status: OSStatus)
        case incompleteWrite(written: Int, expected: Int)

        public var errorDescription: String? {
            switch self {
            case .noPackets:
                "Keine Opus-Pakete zum Schreiben."
            case .createFailed(let status):
                "CAF-Datei konnte nicht angelegt werden (OSStatus \(status))."
            case .writeFailed(let status):
                "Opus-Pakete konnten nicht geschrieben werden (OSStatus \(status))."
            case .incompleteWrite(let written, let expected):
                "Nur \(written) von \(expected) Paketen geschrieben."
            }
        }
    }

    public var channels: UInt32

    public init(channels: UInt32 = 2) {
        self.channels = channels
    }

    /// Schreibt `packets` als CAF/Opus nach `url`. Eine vorhandene Datei wird ersetzt.
    public func write(packets: [Data], to url: URL) throws {
        guard !packets.isEmpty else { throw Failure.noPackets }

        var format = AudioStreamBasicDescription(
            mSampleRate: Self.sampleRate,
            mFormatID: kAudioFormatOpus,
            mFormatFlags: 0,
            mBytesPerPacket: 0,       // variable Paketgröße
            mFramesPerPacket: Self.framesPerPacket,
            mBytesPerFrame: 0,
            mChannelsPerFrame: channels,
            mBitsPerChannel: 0,
            mReserved: 0
        )

        var file: AudioFileID?
        let createStatus = AudioFileCreateWithURL(
            url as CFURL, kAudioFileCAFType, &format, [.eraseFile], &file
        )
        guard createStatus == noErr, let file else {
            throw Failure.createFailed(status: createStatus)
        }
        defer { AudioFileClose(file) }

        // Pakete zu einem Block zusammenfassen und je Paket beschreiben.
        var blob = Data()
        blob.reserveCapacity(packets.reduce(0) { $0 + $1.count })
        var descriptions: [AudioStreamPacketDescription] = []
        descriptions.reserveCapacity(packets.count)
        for packet in packets {
            descriptions.append(AudioStreamPacketDescription(
                mStartOffset: Int64(blob.count),
                mVariableFramesInPacket: 0,
                mDataByteSize: UInt32(packet.count)
            ))
            blob.append(packet)
        }

        var written = UInt32(packets.count)
        let writeStatus = blob.withUnsafeBytes { bytes -> OSStatus in
            guard let base = bytes.baseAddress else { return kAudio_ParamError }
            return AudioFileWritePackets(
                file, false, UInt32(blob.count), descriptions, 0, &written, base
            )
        }
        guard writeStatus == noErr else { throw Failure.writeFailed(status: writeStatus) }
        guard Int(written) == packets.count else {
            throw Failure.incompleteWrite(written: Int(written), expected: packets.count)
        }
    }
}

public extension D3200Download {
    /// Schreibt die Aufnahme als CAF/Opus – das Format, das AVFoundation
    /// auf iOS lesen kann.
    func writeCAFOpus(to url: URL, writer: CAFOpusWriter = CAFOpusWriter()) throws {
        try writer.write(packets: opusPackets, to: url)
    }
}
