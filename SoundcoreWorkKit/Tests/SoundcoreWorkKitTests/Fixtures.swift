import Foundation

/// Zugriff auf die Referenz-Fixtures (Kopien aus `fixtures/` im Projekt-Root).
enum Fixture {
    enum Failure: Error, LocalizedError {
        case missing(String)

        var errorDescription: String? {
            switch self {
            case .missing(let name): "Fixture \(name) fehlt im Test-Bundle."
            }
        }
    }

    static func data(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: nil) else {
            throw Failure.missing(name)
        }
        return try Data(contentsOf: url)
    }

    static func fileHeaderResponse() throws -> Data { try data("detail_post_ecdh_4b4a7b69.bin") }
    static func rawAudio() throws -> Data { try data("raw_4b4a7b69.bin") }
    static func expectedOgg() throws -> Data { try data("decrypted_4b4a7b69.ogg") }

    struct Session: Decodable {
        let sharedSecret: String
        let sessionKey: String
        let devicePublicKey: String
        let ourPublicKey: String

        enum CodingKeys: String, CodingKey {
            case sharedSecret = "shared_secret"
            case sessionKey = "qc_key"
            case devicePublicKey = "device_pubkey"
            case ourPublicKey = "our_pubkey"
        }
    }

    static func session() throws -> Session {
        try JSONDecoder().decode(Session.self, from: data("session_4b4a7b69.json"))
    }
}

extension Data {
    /// Hex-String → Data; `nil` bei ungültiger Eingabe.
    init?(hex: String) {
        guard hex.count.isMultiple(of: 2) else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index ..< next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        self = Data(bytes)
    }

    var hexString: String { map { String(format: "%02x", $0) }.joined() }
}
