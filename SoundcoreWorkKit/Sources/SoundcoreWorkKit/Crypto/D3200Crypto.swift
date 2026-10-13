import CryptoKit
import Foundation

/// Kryptografie des Soundcore Work (D3200) – siehe `docs/d3200_protocol_spec.md` §6.
public enum D3200Crypto {
    /// Geräteübergreifend fixe HKDF-Parameter (Spec §6.2).
    public static let hkdfSalt = Data([0x01, 0x02, 0x03])
    public static let hkdfInfo = Data([0x01, 0x02, 0x03])

    /// Klartext-Hülle vor dem File-Key (Spec §6.3).
    public static let fileKeyMagic = Data("soundcored3200".utf8)

    /// Länge eines Opus-Pakets im Audio-Stream.
    public static let opusPacketSize = 160
    /// Framegröße im gespeicherten Rohformat: 2 B Präfix + 160 B Nutzlast + 2 B Suffix.
    public static let rawFrameSize = 164

    public enum Failure: Error, LocalizedError, Equatable {
        case invalidSharedSecretLength(Int)
        case devicePublicKeyNotFound
        case invalidNonceLength(Int)
        case invalidEncryptedFileKeyLength(Int)
        case fileKeyMagicMismatch(Data)
        case truncatedRawStream(Int)

        public var errorDescription: String? {
            switch self {
            case .invalidSharedSecretLength(let length):
                "ECDH-Shared-Secret muss 32 Byte lang sein (war \(length))."
            case .devicePublicKeyNotFound:
                "In der Handshake-Antwort war kein gültiger P-256-Punkt zu finden."
            case .invalidNonceLength(let length):
                "Nonce muss 16 Byte lang sein (war \(length))."
            case .invalidEncryptedFileKeyLength(let length):
                "Verpackter File-Key muss 46 Byte lang sein (war \(length))."
            case .fileKeyMagicMismatch:
                "File-Key-Hülle beginnt nicht mit \"soundcored3200\" – Session-Key passt nicht."
            case .truncatedRawStream(let length):
                "Roh-Stream ist kein Vielfaches von \(rawFrameSize) Byte (war \(length))."
            }
        }
    }

    // MARK: - Session-Key

    /// Leitet den Session-Key (`qc_key`) aus dem ECDH-Shared-Secret ab (Spec §6.2).
    public static func sessionKey(sharedSecret: Data) throws -> Data {
        guard sharedSecret.count == 32 else {
            throw Failure.invalidSharedSecretLength(sharedSecret.count)
        }
        let derived = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: sharedSecret),
            salt: hkdfSalt,
            info: hkdfInfo,
            outputByteCount: 32
        )
        return derived.withUnsafeBytes { Data($0) }
    }

    // MARK: - ECDH

    /// Erzeugt ein frisches P-256-Keypair für den Handshake.
    public static func makeKeyPair() -> P256.KeyAgreement.PrivateKey {
        P256.KeyAgreement.PrivateKey()
    }

    /// Eigener Public Key als 64 Byte `X‖Y` big-endian, so wie das `014b`-Command sie erwartet.
    public static func rawPublicKey(_ privateKey: P256.KeyAgreement.PrivateKey) -> Data {
        privateKey.publicKey.rawRepresentation
    }

    /// Liest den Geräte-Public-Key aus der `014b`-Handshake-Antwort (Spec §6.1).
    ///
    /// Der SEC1-Marker `0x04` liegt beim eigenen Gerät auf Offset 9; weitere
    /// beobachtete Offsets werden als Fallback geprüft und der Punkt jeweils
    /// gegen die Kurve validiert.
    public static func parseDevicePublicKey(from response: Data) throws -> P256.KeyAgreement.PublicKey {
        let bytes = Data(response)
        for offset in [9, 8, 10, 6, 7] {
            guard offset >= 0, offset + 65 <= bytes.count else { continue }
            let start = bytes.startIndex + offset
            guard bytes[start] == 0x04 else { continue }
            let point = Data(bytes[start ..< start + 65])
            if let key = try? P256.KeyAgreement.PublicKey(x963Representation: point) {
                return key
            }
        }
        throw Failure.devicePublicKeyNotFound
    }

    /// ECDH-Shared-Secret (X-Koordinate, 32 Byte).
    public static func sharedSecret(
        privateKey: P256.KeyAgreement.PrivateKey,
        devicePublicKey: P256.KeyAgreement.PublicKey
    ) throws -> Data {
        let secret = try privateKey.sharedSecretFromKeyAgreement(with: devicePublicKey)
        return secret.withUnsafeBytes { Data($0) }
    }

    // MARK: - File-Key

    /// Entpackt den Per-File-Key aus dem File-Header (Spec §6.3).
    public static func unwrapFileKey(header: D3200FileHeader, sessionKey: Data) throws -> Data {
        guard header.sessionNonce.count == 16 else {
            throw Failure.invalidNonceLength(header.sessionNonce.count)
        }
        guard header.encryptedFileKey.count == 46 else {
            throw Failure.invalidEncryptedFileKeyLength(header.encryptedFileKey.count)
        }
        let plaintext = try AESCTR.crypt(
            key: sessionKey,
            iv: header.sessionNonce,
            data: header.encryptedFileKey
        )
        let magic = plaintext.prefix(fileKeyMagic.count)
        guard magic == fileKeyMagic else {
            throw Failure.fileKeyMagicMismatch(Data(magic))
        }
        return Data(plaintext.dropFirst(fileKeyMagic.count))
    }

    // MARK: - Audio

    /// AES-CTR-Startzähler für ein Audio-Paket: `nonce[0..<12] ‖ BE32(seq * 10)` (Spec §6.4).
    public static func audioCounter(nonce: Data, sequence: Int) throws -> Data {
        guard nonce.count == 16 else { throw Failure.invalidNonceLength(nonce.count) }
        var counter = Data(nonce.prefix(12))
        let value = UInt32(truncatingIfNeeded: sequence * 10)
        counter.append(contentsOf: [
            UInt8(truncatingIfNeeded: value >> 24),
            UInt8(truncatingIfNeeded: value >> 16),
            UInt8(truncatingIfNeeded: value >> 8),
            UInt8(truncatingIfNeeded: value),
        ])
        return counter
    }

    /// Entschlüsselt eine einzelne 160-Byte-Nutzlast zu einem Opus-Paket.
    ///
    /// - Parameter sequence: Paket-Index im Stream, beginnend bei 0.
    public static func decryptPacket(
        _ payload: Data,
        sequence: Int,
        fileKey: Data,
        nonce: Data
    ) throws -> Data {
        try AESCTR.crypt(
            key: fileKey,
            iv: audioCounter(nonce: nonce, sequence: sequence),
            data: payload
        )
    }

    /// Entschlüsselt den gespeicherten Roh-Stream (164-Byte-Frames) zu Opus-Paketen (Spec §6.4).
    public static func decryptRawStream(
        _ raw: Data,
        fileKey: Data,
        nonce: Data
    ) throws -> [Data] {
        guard raw.count % rawFrameSize == 0 else {
            throw Failure.truncatedRawStream(raw.count)
        }
        let bytes = Data(raw)
        let frameCount = bytes.count / rawFrameSize
        var packets: [Data] = []
        packets.reserveCapacity(frameCount)
        for index in 0 ..< frameCount {
            let frameStart = bytes.startIndex + index * rawFrameSize
            let payloadStart = frameStart + 2
            let payload = Data(bytes[payloadStart ..< payloadStart + opusPacketSize])
            packets.append(
                try decryptPacket(payload, sequence: index, fileKey: fileKey, nonce: nonce)
            )
        }
        return packets
    }
}
