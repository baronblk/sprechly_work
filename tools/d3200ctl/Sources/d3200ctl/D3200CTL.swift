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

        let positional = positionalArguments(in: arguments)
        let command = positional.first ?? "list"
        let requestedID = positional.dropFirst().first
        let verbose = !arguments.contains("--quiet")
        let seconds = value(of: "--seconds", in: arguments).flatMap(Int.init) ?? 120
        let outputDirectory = URL(
            fileURLWithPath: value(of: "--out", in: arguments) ?? FileManager.default.currentDirectoryPath
        )

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

            if command == "record" {
                let action: D3200RecordAction
                switch requestedID {
                case "start", "resume", nil: action = .start
                case "pause": action = .pause
                default:
                    note("'\(requestedID ?? "")' ist weder start, resume noch pause")
                    await finish(client, transport, code: 1)
                }
                note("sende Record-Control \(action) …")
                try await client.sendRecordControl(action)
                note("gesendet – lausche \(seconds) s auf die Antwort des Geräts")
                try await monitor(transport: transport, seconds: seconds)
                await finish(client, transport, code: 0)
            }

            if command == "monitor" {
                note("lausche \(seconds) s auf unaufgeforderte Frames.")
                note("Drücke JETZT am Work die Aufnahmetaste, sprich kurz, stoppe wieder.")
                try await monitor(transport: transport, seconds: seconds)
                await finish(client, transport, code: 0)
            }

            let recordings = try await client.listRecordings()
            note("\(recordings.count) Aufnahmen:")
            let formatter = ISO8601DateFormatter()
            for recording in recordings {
                print(String(
                    format: "  %08x  %7.1f s  %4d Frames  %@",
                    recording.fileID, recording.duration, recording.frameCount,
                    formatter.string(from: recording.recordedAt)
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

    /// Lauscht auf alles, was das Gerät von sich aus schickt.
    ///
    /// Protokoll-Discovery: Gruppe, Typ, Länge und der vollständige Frame
    /// jedes Events mit Zeitstempel, damit sich Aufnahme-Start/-Stop,
    /// Tastendrücke und Statusmeldungen zuordnen lassen.
    static func monitor(transport: TracingTransport, seconds: Int) async throws {
        // Eigener Stream neben dem des Clients – TracingTransport verteilt an alle.
        let events = transport.notifications()
        let start = ContinuousClock.now

        let watchdog = Task {
            try? await Task.sleep(for: .seconds(seconds))
        }
        let printer = Task {
            for await frame in events {
                let elapsed = ContinuousClock.now - start
                let seconds = Double(elapsed.components.seconds)
                    + Double(elapsed.components.attoseconds) / 1e18
                let hex = frame.map { String(format: "%02x", $0) }.joined(separator: " ")
                let label: String
                if let response = RCSPFrame.Response(frame: frame) {
                    let name = response.message.map(String.init(describing:)) ?? "UNBEKANNT"
                    label = String(
                        format: "grp=%02x typ=%02x(%@) len=%d/%d",
                        response.group, response.type, name,
                        response.declaredLength, frame.count
                    )
                } else {
                    label = "kein Response-Kopf len=\(frame.count)"
                }
                print(String(format: "[%7.3fs] %@  %@", seconds, label, hex))
            }
        }
        _ = await watchdog.result
        printer.cancel()
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

    /// Flags mit eigenem Wert, damit der Wert nicht als Positionsargument gilt.
    static let flagsTakingValue: Set<String> = ["--out", "--seconds"]

    static func positionalArguments(in arguments: [String]) -> [String] {
        var positional: [String] = []
        var index = arguments.startIndex
        while index < arguments.endIndex {
            let argument = arguments[index]
            if flagsTakingValue.contains(argument) {
                index += 2
            } else if argument.hasPrefix("-") {
                index += 1
            } else {
                positional.append(argument)
                index += 1
            }
        }
        return positional
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
      d3200ctl monitor                 lauscht auf unaufgeforderte Frames
                                       (Aufnahme-Start/-Stop, Tasten, Status)
      d3200ctl record start|pause      steuert die Aufnahme fern und zeigt,
                                       was das Gerät daraufhin meldet

    Optionen
      --out <dir>   Zielordner für die .ogg-Datei (Standard: aktueller Ordner)
      --quiet       kein Frame-Trace auf stderr
      --seconds <n> Laufzeit von `monitor` (Standard 120)
    """
}
