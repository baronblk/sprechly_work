import CommonCrypto
import Foundation

/// AES im Counter-Mode (CTR, Big-Endian-Zähler).
///
/// CryptoKit kennt kein CTR, daher CommonCrypto. CTR ist symmetrisch –
/// Ent- und Verschlüsseln sind dieselbe Operation.
public enum AESCTR {
    public enum Failure: Error, LocalizedError, Equatable {
        case invalidKeyLength(Int)
        case invalidIVLength(Int)
        case cryptorFailed(status: Int32)

        public var errorDescription: String? {
            switch self {
            case .invalidKeyLength(let length):
                "AES-Schlüssel muss 16, 24 oder 32 Byte lang sein (war \(length))."
            case .invalidIVLength(let length):
                "AES-CTR-IV muss 16 Byte lang sein (war \(length))."
            case .cryptorFailed(let status):
                "CommonCrypto-Fehler \(status)."
            }
        }
    }

    /// Ver-/Entschlüsselt `data` mit AES-CTR.
    /// - Parameters:
    ///   - key: 16, 24 oder 32 Byte.
    ///   - iv: 16 Byte Startzähler.
    public static func crypt(key: Data, iv: Data, data: Data) throws -> Data {
        guard [kCCKeySizeAES128, kCCKeySizeAES192, kCCKeySizeAES256].contains(key.count) else {
            throw Failure.invalidKeyLength(key.count)
        }
        guard iv.count == kCCBlockSizeAES128 else {
            throw Failure.invalidIVLength(iv.count)
        }
        guard !data.isEmpty else { return Data() }

        var cryptor: CCCryptorRef?
        let createStatus = key.withUnsafeBytes { keyBytes in
            iv.withUnsafeBytes { ivBytes in
                CCCryptorCreateWithMode(
                    CCOperation(kCCEncrypt),
                    CCMode(kCCModeCTR),
                    CCAlgorithm(kCCAlgorithmAES),
                    CCPadding(ccNoPadding),
                    ivBytes.baseAddress,
                    keyBytes.baseAddress,
                    key.count,
                    nil, 0,  // tweak (nur XTS)
                    0,       // numRounds: 0 = Standard
                    CCModeOptions(kCCModeOptionCTR_BE),
                    &cryptor
                )
            }
        }
        guard createStatus == kCCSuccess, let cryptor else {
            throw Failure.cryptorFailed(status: createStatus)
        }
        defer { CCCryptorRelease(cryptor) }

        var output = Data(count: data.count)
        var moved = 0
        let updateStatus = data.withUnsafeBytes { input in
            output.withUnsafeMutableBytes { out in
                CCCryptorUpdate(
                    cryptor,
                    input.baseAddress, data.count,
                    out.baseAddress, data.count,
                    &moved
                )
            }
        }
        guard updateStatus == kCCSuccess else {
            throw Failure.cryptorFailed(status: updateStatus)
        }
        // CTR ist ein Stream-Mode: Ein- und Ausgabelänge sind immer gleich,
        // CCCryptorFinal liefert hier nichts nach.
        return output.prefix(moved)
    }
}
