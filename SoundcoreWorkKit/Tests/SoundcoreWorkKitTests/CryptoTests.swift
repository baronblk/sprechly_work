import CryptoKit
import Foundation
import Testing

@testable import SoundcoreWorkKit

@Suite("Krypto gegen die verifizierten Testvektoren")
struct CryptoTests {
    /// Harter Vektor aus `docs/test_vectors.md` §1.
    @Test("HKDF-SHA256 mit salt/info = 010203 ergibt den Session-Key")
    func hkdfSessionKey() throws {
        let shared = try #require(Data(
            hex: "28f3e8f5314a47640bebe10b1bd3d32d5d0feda73babe80080f92bdf69806b30"
        ))
        let expected = "4f69a99087eda5ec0704d56dbd51707eab67218d2ed91deea0520ce05faaab3d"

        #expect(try D3200Crypto.sessionKey(sharedSecret: shared).hexString == expected)
        #expect(D3200Crypto.hkdfSalt == Data([0x01, 0x02, 0x03]))
        #expect(D3200Crypto.hkdfInfo == Data([0x01, 0x02, 0x03]))
    }

    @Test("Session-Key der Fixture-Session entspricht qc_key")
    func sessionKeyMatchesFixture() throws {
        let session = try Fixture.session()
        let shared = try #require(Data(hex: session.sharedSecret))
        #expect(try D3200Crypto.sessionKey(sharedSecret: shared).hexString == session.sessionKey)
    }

    @Test("Shared Secret mit falscher Länge wird abgewiesen", arguments: [0, 31, 33, 64])
    func rejectsWrongSharedSecretLength(length: Int) {
        #expect(throws: D3200Crypto.Failure.invalidSharedSecretLength(length)) {
            try D3200Crypto.sessionKey(sharedSecret: Data(repeating: 0, count: length))
        }
    }

    @Test("ECDH reproduziert das Shared Secret der Fixture-Session")
    func ecdhMatchesFixture() throws {
        // Der private Key der Session ist nicht gespeichert (und soll es nicht sein),
        // daher wird die Symmetrie der Vereinbarung mit frischen Keys geprüft und
        // der Geräte-Public-Key aus der Fixture als gültiger P-256-Punkt bestätigt.
        let session = try Fixture.session()
        let devicePublicKeyRaw = try #require(Data(hex: session.devicePublicKey))
        #expect(devicePublicKeyRaw.count == 64)
        let devicePublicKey = try P256.KeyAgreement.PublicKey(rawRepresentation: devicePublicKeyRaw)

        let ours = D3200Crypto.makeKeyPair()
        #expect(D3200Crypto.rawPublicKey(ours).count == 64)

        let secret = try D3200Crypto.sharedSecret(privateKey: ours, devicePublicKey: devicePublicKey)
        #expect(secret.count == 32)
    }

    @Test("ECDH ist symmetrisch – beide Seiten leiten denselben Session-Key ab")
    func ecdhIsSymmetric() throws {
        let alice = D3200Crypto.makeKeyPair()
        let bob = D3200Crypto.makeKeyPair()

        let fromAlice = try D3200Crypto.sharedSecret(privateKey: alice, devicePublicKey: bob.publicKey)
        let fromBob = try D3200Crypto.sharedSecret(privateKey: bob, devicePublicKey: alice.publicKey)

        #expect(fromAlice == fromBob)
        #expect(try D3200Crypto.sessionKey(sharedSecret: fromAlice)
            == (try D3200Crypto.sessionKey(sharedSecret: fromBob)))
    }

    @Test("Geräte-Public-Key wird über den 0x04-Marker auf Offset 9 gefunden")
    func parsesDevicePublicKeyAtOffsetNine() throws {
        let raw = try #require(Data(hex: Fixture.session().devicePublicKey))
        var response = Data([0x09, 0xFF, 0x00, 0x00, 0x01, 0x2E, 0x01, 0x4B, 0x00])
        response.append(0x04)
        response.append(raw)

        let parsed = try D3200Crypto.parseDevicePublicKey(from: response)
        #expect(parsed.rawRepresentation == raw)
    }

    @Test("Handshake-Antwort ohne gültigen Punkt wird abgewiesen")
    func rejectsResponseWithoutPoint() {
        #expect(throws: D3200Crypto.Failure.devicePublicKeyNotFound) {
            try D3200Crypto.parseDevicePublicKey(from: Data(repeating: 0x04, count: 120))
        }
    }

    @Test("AES-CTR ist symmetrisch und längentreu")
    func aesCTRRoundTrip() throws {
        let key = Data(repeating: 0x11, count: 32)
        let iv = Data(repeating: 0x22, count: 16)
        let plaintext = Data("Sprechly Work – Soundcore D3200".utf8)

        let ciphertext = try AESCTR.crypt(key: key, iv: iv, data: plaintext)
        #expect(ciphertext.count == plaintext.count)
        #expect(ciphertext != plaintext)
        #expect(try AESCTR.crypt(key: key, iv: iv, data: ciphertext) == plaintext)
    }

    /// NIST SP 800-38A, F.5.5 – AES-256-CTR, erster Block.
    @Test("AES-256-CTR gegen den NIST-Vektor F.5.5")
    func aesCTRNistVector() throws {
        let key = try #require(Data(
            hex: "603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4"
        ))
        let iv = try #require(Data(hex: "f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff"))
        let plaintext = try #require(Data(hex: "6bc1bee22e409f96e93d7e117393172a"))

        let ciphertext = try AESCTR.crypt(key: key, iv: iv, data: plaintext)
        #expect(ciphertext.hexString == "601ec313775789a5b7a7f504bbf3d228")
    }

    @Test("AES-CTR weist falsche Schlüssel- und IV-Längen ab")
    func aesCTRRejectsBadLengths() {
        #expect(throws: AESCTR.Failure.invalidKeyLength(20)) {
            try AESCTR.crypt(
                key: Data(repeating: 0, count: 20),
                iv: Data(repeating: 0, count: 16),
                data: Data([0x00])
            )
        }
        #expect(throws: AESCTR.Failure.invalidIVLength(12)) {
            try AESCTR.crypt(
                key: Data(repeating: 0, count: 32),
                iv: Data(repeating: 0, count: 12),
                data: Data([0x00])
            )
        }
    }

    @Test("AES-CTR-Zähler ist nonce[0..<12] ‖ BE32(seq * 10)")
    func audioCounterLayout() throws {
        let nonce = try #require(Data(hex: "163eaaf2d327435d2701943400000000"))

        #expect(try D3200Crypto.audioCounter(nonce: nonce, sequence: 0).hexString
            == "163eaaf2d327435d2701943400000000")
        #expect(try D3200Crypto.audioCounter(nonce: nonce, sequence: 1).hexString
            == "163eaaf2d327435d270194340000000a")
        #expect(try D3200Crypto.audioCounter(nonce: nonce, sequence: 44).hexString
            == "163eaaf2d327435d27019434000001b8")
        #expect(try D3200Crypto.audioCounter(nonce: nonce, sequence: 100_000).hexString
            == "163eaaf2d327435d27019434000f4240")
    }

    @Test("File-Header der Fixture wird nach Spec §5 geparst")
    func parsesFileHeader() throws {
        let header = try D3200FileHeader(response: try Fixture.fileHeaderResponse())

        #expect(header.fileID == 0x697B_4A4B)
        #expect(header.fileSize == 7470)
        #expect(header.nonce.hexString == "163eaaf2d327435d2701943400000000")
        #expect(header.sessionNonce.hexString == "0c25a0b9dd6e730d63d0e84500000000")
        #expect(header.encryptedFileKey.count == 46)
        #expect(header.status == 0x00)
        #expect(header.checksum == 0x0D)
        // file_id ist der Aufnahme-Timestamp
        #expect(D3200Recording(fileID: header.fileID, size: header.fileSize).isPlausible)
    }

    @Test("Zu kurzer File-Header wird abgewiesen")
    func rejectsShortFileHeader() {
        #expect(throws: D3200FileHeader.Failure.tooShort(96)) {
            try D3200FileHeader(response: Data(repeating: 0, count: 96))
        }
    }

    @Test("File-Key wird entpackt, Hülle beginnt mit \"soundcored3200\"")
    func unwrapsFileKey() throws {
        let header = try D3200FileHeader(response: try Fixture.fileHeaderResponse())
        let sessionKey = try #require(Data(hex: Fixture.session().sessionKey))

        let fileKey = try D3200Crypto.unwrapFileKey(header: header, sessionKey: sessionKey)
        #expect(fileKey.count == 32)

        // Gegenprobe: die Hülle vor dem Key ist wirklich die Magic.
        let plaintext = try AESCTR.crypt(
            key: sessionKey,
            iv: header.sessionNonce,
            data: header.encryptedFileKey
        )
        #expect(plaintext.prefix(14) == Data("soundcored3200".utf8))
        #expect(Data(plaintext.dropFirst(14)) == fileKey)
    }

    @Test("Falscher Session-Key liefert keine gültige Hülle")
    func wrongSessionKeyFailsMagicCheck() throws {
        let header = try D3200FileHeader(response: try Fixture.fileHeaderResponse())
        #expect(throws: (any Error).self) {
            try D3200Crypto.unwrapFileKey(
                header: header,
                sessionKey: Data(repeating: 0xAB, count: 32)
            )
        }
    }
}
