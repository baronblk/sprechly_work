import Foundation
import SoundcoreWorkKit

@main
enum D3200CTL {
    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard !arguments.contains("--help"), !arguments.contains("-h") else {
            print(usage)
            return
        }

        let command = arguments.first(where: { !$0.hasPrefix("-") }) ?? "list"
        let verbose = !arguments.contains("--quiet")
        let outputDirectory = URL(
            fileURLWithPath: value(of: "--out", in: arguments) ?? FileManager.default.currentDirectoryPath
        )
        let requestedID = arguments
            .drop(while: { $0 != command })
            .dropFirst()
            .first(where: { !$0.hasPrefix("-") })

        let transport = TracingTransport(wrapping: BLETransport(), verbose: verbose)
        let client = D3200Client(transport: transport)

        do {
            note("Scan nach dem Soundcore Work … (muss vom Handy getrennt sein)")
            try await client.connect()
            note("verbunden")

            try await client.authenticate()
            note("Auth bestätigt")

            try await client.syncTime()
            note("Zeit synchronisiert")

            let recordings = try await client.listRecordings()
            note("\(recordings.count) Aufnahmen:")
            let formatter = ISO8601DateFormatter()
            for recording in recordings {
                print(String(
                    format: "  %08x  %8d B  %@",
                    recording.fileID, recording.size, formatter.string(from: recording.recordedAt)
                ))
            }

            if command == "pull" {
                guard let target = pick(requestedID, from: recordings) else {
                    note("keine passende Aufnahme – Abbruch")
                    await finish(client, transport, code: 1)
                }
                note("ECDH-Handshake …")
                try await client.performKeyExchange()
                note("Session-Key abgeleitet")

                note("Download \(String(format: "%08x", target.fileID)) …")
                let reporter = ProgressReporter()
                let download = try await client.download(fileID: target.fileID) { done, total in
                    reporter.report(done: done, total: total)
                }
                note("\(download.opusPackets.count) Opus-Pakete entschlüsselt")

                let ogg = try download.oggOpus()
                let url = outputDirectory.appendingPathComponent(
                    String(format: "%08x.ogg", download.header.fileID)
                )
                try ogg.write(to: url)
                note("geschrieben: \(url.path) (\(ogg.count) B)")
            }

            await finish(client, transport, code: 0)
        } catch {
            note("FEHLER: \(error.localizedDescription)")
            await finish(client, transport, code: 1)
        }
    }

    /// Zielaufnahme wählen: explizite Hex-ID, sonst die neueste.
    static func pick(_ requested: String?, from recordings: [D3200Recording]) -> D3200Recording? {
        guard let requested else { return recordings.max(by: { $0.fileID < $1.fileID }) }
        guard let wanted = UInt32(requested.replacingOccurrences(of: "0x", with: ""), radix: 16) else {
            note("'\(requested)' ist keine Hex-file-id")
            return nil
        }
        return recordings.first { $0.fileID == wanted }
    }

    static func finish(
        _ client: D3200Client,
        _ transport: TracingTransport,
        code: Int32
    ) async -> Never {
        await client.disconnect()
        let report = transport.frameReport
        if !report.isEmpty {
            note("Frame-Längen pro Opcode:")
            FileHandle.standardError.write(Data((report + "\n").utf8))
        }
        exit(code)
    }

    static func value(of flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    static func note(_ message: String) {
        FileHandle.standardError.write(Data("[*] \(message)\n".utf8))
    }

    /// Druckt den Fortschritt in 10-%-Schritten; der Callback ist @Sendable,
    /// daher liegt der Zähler hinter einem Lock.
    final class ProgressReporter: @unchecked Sendable {
        private let lock = NSLock()
        private var lastDecile = -1

        func report(done: Int, total: Int) {
            let decile = total > 0 ? (done * 10 / total) : 0
            let shouldPrint = lock.withLock {
                guard decile != lastDecile else { return false }
                lastDecile = decile
                return true
            }
            guard shouldPrint else { return }
            FileHandle.standardError.write(Data("  \(done)/\(total) B\n".utf8))
        }
    }

    static let usage = """
    d3200ctl – Live-Test-Harness für SoundcoreWorkKit am echten Soundcore Work.

    Vor jedem Lauf: das Gerät vom Handy trennen (BLE erlaubt nur eine Verbindung).

      d3200ctl list                    Scan, Auth, Time-Sync, Aufnahmeliste
      d3200ctl pull [<file-id-hex>]    dazu ECDH + Download; ohne ID die neueste

    Optionen
      --out <dir>   Zielordner für die .ogg-Datei (Standard: aktueller Ordner)
      --quiet       kein Frame-Trace auf stderr
    """
}
