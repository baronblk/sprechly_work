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

            if command == "info" {
                // Roh abfragen: die Zuordnung der Felder wird an den echten
                // Bytes geprüft, nicht aus der Repo-Beschreibung übernommen.
                for message in [D3200Message.deviceInfo, .battery, .charging] {
                    note("frage \(message) ab …")
                    try await client.sendQuery(message)
                    try await Task.sleep(for: .seconds(2))
                }
                try await monitor(transport: transport, seconds: seconds)
                await finish(client, transport, code: 0)
            }

            if command == "record" {
                let action: D3200RecordAction
                switch requestedID {
                case "start", "resume", nil: action = .start
                case "pause": action = .pause
                case "stop": action = .stop
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

            if command == "delete" {
                guard let target = pick(requestedID, from: recordings) else {
                    note("keine passende Aufnahme – Abbruch")
                    await finish(client, transport, code: 1)
                }
                note("LÖSCHE \(String(format: "%08x", target.fileID)) – unwiderruflich")
                do {
                    try await client.deleteRecording(fileID: target.fileID)
                    note("Gerät hat bestätigt")
                } catch {
                    note("FEHLER: \(error.localizedDescription)")
                }
                let danach = try await client.listRecordings()
                note("danach \(danach.count) Aufnahmen; Ziel noch vorhanden: "
                    + "\(danach.contains { $0.fileID == target.fileID })")
                await finish(client, transport, code: 0)
            }

            if command == "flags" {
                // Jeder Audio-Frame trägt auf Offset 13 ein Flags-Byte.
                // Bekannt sind 02 (erster), 00 (Mitte), 04 (letzter).
                // Eine Klopfmarke müsste sich hier zeigen.
                note("ECDH-Handshake ...")
                try await client.performKeyExchange()
                guard let ziel = pick(requestedID, from: recordings) else {
                    note("keine passende Aufnahme")
                    await finish(client, transport, code: 1)
                }
                note("analysiere \(String(format: "%08x", ziel.fileID)) "
                    + "(\(String(format: "%.1f", ziel.duration)) s) ...")

                let flaggen = FlagCollector()
                let lauscher = Task {
                    for await frame in transport.notifications() {
                        guard RCSPFrame.Response(frame: frame)?.message == .audioChunk
                                || RCSPFrame.Response(frame: frame)?.message == .audioChunkMark,
                              frame.count > 13 else { continue }
                        flaggen.add(seq: Int(frame[9]), flag: frame[13])
                    }
                }
                _ = try? await client.download(fileID: ziel.fileID)
                try await Task.sleep(for: .seconds(1))
                lauscher.cancel()

                note("Flags-Byte über alle Frames:")
                for (flag, anzahl) in flaggen.verteilung() {
                    note(String(format: "  0x%02x  ×%d", flag, anzahl))
                }
                let auffaellig = flaggen.ungewoehnliche()
                note(auffaellig.isEmpty
                     ? "keine ungewöhnlichen Flags (nur 00/02/04)"
                     : "UNGEWÖHNLICH bei Frames: \(auffaellig.prefix(20).map { "#\($0.0)=0x\(String($0.1, radix: 16))" }.joined(separator: ", "))")
                await finish(client, transport, code: 0)
            }

            if command == "klopf" {
                note("ECDH-Handshake ...")
                try await client.performKeyExchange()
                try? await client.sendRecordControl(.stop)
                try await Task.sleep(for: .seconds(2))

                note("starte Aufnahme ...")
                try await client.sendRecordControl(.start)
                var fileID: UInt32?
                for await event in await client.events() {
                    if case .recordingState(let id, _) = event { fileID = id; break }
                }
                guard let fileID else { await finish(client, transport, code: 1) }
                note("laufende Aufnahme: \(String(format: "%08x", fileID))")
                note("")
                note(">>> JETZT ZWEIMAL AUFS MIKROFON KLOPFEN <<<")
                note(">>> gern mehrfach, mit Pausen dazwischen     <<<")
                note("")

                // Alles mitlesen, damit sich ein Ereignis dem Klopfen zuordnen lässt.
                let start = ContinuousClock.now
                let lauscher = Task {
                    for await frame in transport.notifications() {
                        guard let antwort = RCSPFrame.Response(frame: frame) else { continue }
                        let t = ContinuousClock.now - start
                        let sek = Double(t.components.seconds)
                            + Double(t.components.attoseconds) / 1e18
                        let name = antwort.message.map(String.init(describing:)) ?? "UNBEKANNT"
                        note(String(format: "  [%6.2fs] grp=%02x typ=%02x (%@) len=%d  %@",
                                    sek, antwort.group, antwort.type, name, frame.count,
                                    frame.prefix(24).map { String(format: "%02x", $0) }.joined(separator: " ")))
                    }
                }
                try await Task.sleep(for: .seconds(40))
                lauscher.cancel()

                note("stoppe die Aufnahme")
                try await client.sendRecordControl(.stop)
                try await Task.sleep(for: .seconds(4))

                note("lade die Aufnahme herunter und zähle die Slice-Typen ...")
                let vorher08 = transport.count(of: .audioChunk)
                let vorher12 = transport.count(of: .audioChunkMark)
                do {
                    let download = try await client.download(fileID: fileID)
                    note("\(download.opusPackets.count) Pakete geladen")
                } catch {
                    note("Download: \(error.localizedDescription)")
                }
                note("Slices beim Download: 0x08 = \(transport.count(of: .audioChunk) - vorher08), "
                    + "0x12 = \(transport.count(of: .audioChunkMark) - vorher12)")
                await finish(client, transport, code: 0)
            }

            if command == "phase1" {
                func slices() -> Int {
                    transport.count(of: .audioChunk) + transport.count(of: .audioChunkMark)
                }
                @discardableResult
                func beobachte(_ label: String, sekunden: Int) async throws -> Int {
                    var vorher = slices()
                    var gesamt = 0
                    for fenster in 1 ... (sekunden / 5) {
                        try await Task.sleep(for: .seconds(5))
                        let jetzt = slices()
                        gesamt += jetzt - vorher
                        note(String(format: "  %@ %2d-%2d s: %d Slices (0x08 gesamt %d, 0x12 gesamt %d)",
                                    label, (fenster - 1) * 5, fenster * 5, jetzt - vorher,
                                    transport.count(of: .audioChunk),
                                    transport.count(of: .audioChunkMark)))
                        vorher = jetzt
                    }
                    return gesamt
                }
                /// Wartet, bis nichts mehr fliesst - ein laufender Transfer
                /// ueberschwemmt sonst den Kanal und verschluckt alles andere.
                func warteBisRuhe() async throws {
                    var ruhig = 0
                    var letzter = slices()
                    while ruhig < 3 {
                        try await Task.sleep(for: .seconds(1))
                        let jetzt = slices()
                        ruhig = jetzt == letzter ? ruhig + 1 : 0
                        letzter = jetzt
                    }
                }
                func kurzeAufnahme() async -> D3200Recording? {
                    (try? await client.listRecordings())?
                        .filter { $0.duration <= 20 }
                        .min { $0.duration < $1.duration }
                }

                // Falls ein frueherer Lauf das Geraet aufnehmend hinterliess.
                try? await client.sendRecordControl(.stop)
                try await Task.sleep(for: .seconds(2))

                note("ECDH-Handshake ...")
                try await client.performKeyExchange()

                // Vergleichsaufnahme muss kurz sein, sonst blockiert ihr
                // Download alles Weitere.
                var vergleichsAufnahme = await kurzeAufnahme()
                if vergleichsAufnahme == nil {
                    note("keine kurze Aufnahme vorhanden - nehme 6 s auf")
                    try await client.sendRecordControl(.start)
                    try await Task.sleep(for: .seconds(6))
                    try await client.sendRecordControl(.stop)
                    for versuch in 1 ... 6 where vergleichsAufnahme == nil {
                        try await Task.sleep(for: .seconds(3))
                        vergleichsAufnahme = await kurzeAufnahme()
                        note("  Liste nach \(versuch * 3) s: \(vergleichsAufnahme == nil ? "noch nichts" : "da")")
                    }
                }
                guard let fertige = vergleichsAufnahme else {
                    note("keine kurze Aufnahme verfuegbar - Abbruch")
                    await finish(client, transport, code: 1)
                }

                note("VERGLEICH: \(String(format: "%08x", fertige.fileID)) "
                    + "(\(String(format: "%.1f", fertige.duration)) s) offline anfordern")
                try await transport.send(D3200Commands.fileTransfer(fileID: fertige.fileID))
                let vergleich = try await beobachte("offline ", sekunden: 10)
                guard vergleich > 0 else {
                    note("Vergleichsmessung lieferte nichts - Messung ungueltig, Abbruch.")
                    await finish(client, transport, code: 1)
                }
                note("Vergleich gueltig: \(vergleich) Slices. Warte, bis der Kanal frei ist ...")
                try await warteBisRuhe()

                note("starte Aufnahme am Geraet ...")
                try await client.sendRecordControl(.start)
                var laufendeID: UInt32?
                for await event in await client.events() {
                    if case .recordingState(let fileID, _) = event { laufendeID = fileID; break }
                }
                guard let laufendeID else { await finish(client, transport, code: 1) }
                note("laufende Aufnahme: \(String(format: "%08x", laufendeID))")
                try await Task.sleep(for: .seconds(5))

                let befehl = D3200Commands.fileTransfer(fileID: laufendeID, realtime: true)
                note("REALTIME: \(befehl.map { String(format: "%02x", $0) }.joined(separator: " "))")
                let vorRealtime = slices()
                try await transport.send(befehl)
                try await beobachte("realtime", sekunden: 30)
                let imRealtime = slices() - vorRealtime

                note(imRealtime > 0
                     ? "ERGEBNIS: \(imRealtime) Slices waehrend der laufenden Aufnahme."
                     : "ERGEBNIS: nichts - bei gueltigem Vergleich von \(vergleich) Slices.")

                note("stoppe die Aufnahme wieder")
                try? await client.sendRecordControl(.stop)
                try? await Task.sleep(for: .seconds(3))
                await finish(client, transport, code: 0)
            }

            if command == "rt" {
                // Ein Kandidat, sauber isoliert: nur dieses eine Byte setzen
                // und lange genug messen, um die Anlaufzeit zu erfassen.
                let offset = Int(requestedID ?? "9") ?? 9
                note("ECDH-Handshake …")
                try await client.performKeyExchange()
                note("starte Aufnahme …")
                try await client.sendRecordControl(.start)
                var liveFileID: UInt32?
                for await event in await client.events() {
                    if case .recordingState(let fileID, _) = event { liveFileID = fileID; break }
                }
                guard let liveFileID else { await finish(client, transport, code: 1) }
                try await Task.sleep(for: .seconds(5))

                var payload = Data([0x00, 0x1A, 0x07, 0x12, 0x00, 0x00, 0x00, 0x00, 0x00])
                if (8 ... 12).contains(offset) { payload[offset - 4] = 0x01 }
                payload.append(littleEndianBytes: liveFileID)
                note("sende mit Flag auf Offset \(offset) (0 = ohne Flag)")
                try await transport.send(RCSPFrame.command(payload: payload))

                var previous = transport.count(of: .audioChunk)
                for bucket in 1 ... 6 {
                    try await Task.sleep(for: .seconds(5))
                    let now = transport.count(of: .audioChunk)
                    note(String(format: "  %2d–%2d s: %d Chunks", (bucket - 1) * 5, bucket * 5, now - previous))
                    previous = now
                }

                note("stoppe die Aufnahme wieder")
                try? await client.sendRecordControl(.stop)
                try? await Task.sleep(for: .seconds(2))
                await finish(client, transport, code: 0)
            }

            if command == "realtime" {
                note("ECDH-Handshake …")
                try await client.performKeyExchange()
                note("starte Aufnahme am Gerät …")
                try await client.sendRecordControl(.start)

                var liveFileID: UInt32?
                for await event in await client.events() {
                    if case .recordingState(let fileID, _) = event { liveFileID = fileID; break }
                }
                guard let liveFileID else { await finish(client, transport, code: 1) }
                note("laufende Aufnahme: \(String(format: "%08x", liveFileID))")
                note("lasse sie 10 s laufen, damit Material da ist …")
                try await Task.sleep(for: .seconds(10))

                /// Sendet eine Variante und misst Chunks in zwei Zeitfenstern.
                /// Nur wenn im zweiten Fenster noch welche kommen, läuft der
                /// Strom wirklich weiter – sonst war es nur der Vorrat.
                func probe(_ label: String, payload: Data) async throws {
                    let before = transport.count(of: .audioChunk)
                    try await transport.send(RCSPFrame.command(payload: payload))
                    try await Task.sleep(for: .seconds(5))
                    let mid = transport.count(of: .audioChunk)
                    try await Task.sleep(for: .seconds(5))
                    let after = transport.count(of: .audioChunk)
                    note("\(label): Fenster 1 = \(mid - before), Fenster 2 = \(after - mid)"
                        + ((after - mid) > 0 ? "  ← läuft weiter!" : ""))
                }

                // Vergleichsmaß: die unveränderte Anforderung
                var plain = Data([0x00, 0x1A, 0x07, 0x12, 0x00, 0x00, 0x00, 0x00, 0x00])
                plain.append(littleEndianBytes: liveFileID)
                try await probe("ohne Flag           ", payload: plain)

                // Flag HINTER der file_id – im Katalog steht „fileId + realtimeFlag"
                for value in [UInt8(0x01), 0x02] {
                    var payload = Data([0x00, 0x1A, 0x07, 0x13, 0x00, 0x00, 0x00, 0x00, 0x00])
                    payload.append(littleEndianBytes: liveFileID)
                    payload.append(value)
                    try await probe("Flag hinter ID = \(value) ", payload: payload)
                }

                // Und nochmal die Bytes vor der ID, diesmal richtig gezählt
                for offset in 8 ... 12 {
                    var payload = Data([0x00, 0x1A, 0x07, 0x12, 0x00, 0x00, 0x00, 0x00, 0x00])
                    payload[offset - 4] = 0x01
                    payload.append(littleEndianBytes: liveFileID)
                    try await probe("Flag auf Offset \(offset)   ", payload: payload)
                }

                note("stoppe die Aufnahme wieder")
                try? await client.sendRecordControl(.stop)
                try? await Task.sleep(for: .seconds(2))
                await finish(client, transport, code: 0)
            }

            if command == "live" {
                // Prüft, ob das Gerät die gerade laufende Aufnahme streamt.
                // Dann gäbe es Pegel und später Live-Transkript.
                note("ECDH-Handshake …")
                try await client.performKeyExchange()

                let events = await client.events()
                note("starte Aufnahme am Gerät …")
                try await client.sendRecordControl(.start)

                note("warte auf die file_id der neuen Aufnahme …")
                var liveFileID: UInt32?
                for await event in events {
                    if case .recordingState(let fileID, _) = event {
                        liveFileID = fileID
                        break
                    }
                }
                guard let liveFileID else {
                    note("keine file_id erhalten")
                    await finish(client, transport, code: 1)
                }
                note("laufende Aufnahme: \(String(format: "%08x", liveFileID))")
                note("fordere sie an, während sie noch läuft …")

                do {
                    let download = try await client.download(fileID: liveFileID) { done, total in
                        FileHandle.standardError.write(Data("  \(done)/\(total) B\n".utf8))
                    }
                    note("Stream lieferte \(download.opusPackets.count) Pakete")
                } catch {
                    note("Anforderung ergab: \(error.localizedDescription)")
                }

                note("stoppe die Aufnahme wieder")
                try? await client.sendRecordControl(.stop)
                try? await Task.sleep(for: .seconds(2))
                await finish(client, transport, code: 0)
            }

            if command == "pullpolled" {
                // Bildet die App nach: im Hintergrund läuft die Geräte-Info-
                // Abfrage, währenddessen Handshake und Download.
                note("starte Geräte-Info-Polling alle 2 s …")
                let poller = Task {
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(2))
                        do {
                            let info = try await client.fetchDeviceInfo()
                            note("  poll: Akku \(info.battery.percent) %")
                        } catch {
                            note("  poll FEHLER: \(error.localizedDescription)")
                        }
                    }
                }
                note("ECDH-Handshake …")
                do {
                    try await client.performKeyExchange()
                    note("Session-Key abgeleitet")
                    guard let target = recordings.max(by: { $0.recordedAt < $1.recordedAt }) else {
                        await finish(client, transport, code: 1)
                    }
                    note("Download \(String(format: "%08x", target.fileID)) …")
                    let download = try await client.download(fileID: target.fileID)
                    note("OK – \(download.opusPackets.count) Pakete")
                } catch {
                    note("FEHLER: \(error.localizedDescription)")
                }
                poller.cancel()
                await finish(client, transport, code: 0)
            }

            if command == "pullmany" {
                // Prüft, ob ein Session-Key für mehrere Downloads in derselben
                // Verbindung gilt – genau das macht die App beim Mehrfach-Import.
                note("ECDH-Handshake (einmalig) …")
                try await client.performKeyExchange()
                let targets = recordings.sorted { $0.recordedAt > $1.recordedAt }.prefix(3)
                for (index, target) in targets.enumerated() {
                    note("Download \(index + 1)/\(targets.count): \(String(format: "%08x", target.fileID)) …")
                    do {
                        let download = try await client.download(fileID: target.fileID)
                        note("  OK – \(download.opusPackets.count) Pakete")
                    } catch {
                        note("  FEHLER: \(error.localizedDescription)")
                    }
                }
                await finish(client, transport, code: 0)
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
                if download.markers.isEmpty {
                    note("keine Klopfmarkierungen")
                } else {
                    note("\(download.markers.count) Klopfmarkierung(en) bei "
                        + download.markers.map { String(format: "%.1f s", $0) }
                            .joined(separator: ", "))
                }

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

    /// Sammelt die Flags-Bytes der Audio-Frames.
    final class FlagCollector: @unchecked Sendable {
        private let lock = NSLock()
        private var alle: [(Int, UInt8)] = []
        func add(seq: Int, flag: UInt8) { lock.withLock { alle.append((seq, flag)) } }
        func verteilung() -> [(UInt8, Int)] {
            lock.withLock {
                Dictionary(grouping: alle, by: \.1)
                    .map { ($0.key, $0.value.count) }
                    .sorted { $0.0 < $1.0 }
            }
        }
        func ungewoehnliche() -> [(Int, UInt8)] {
            lock.withLock { alle.enumerated().filter { ![0x00, 0x02, 0x04].contains($0.element.1) }
                .map { ($0.offset, $0.element.1) } }
        }
    }

    /// Zählt eingehende Audio-Chunks über Task-Grenzen hinweg.
    final class ChunkCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0
        func increment() { lock.withLock { count += 1 } }
        func reset() { lock.withLock { count = 0 } }
        var value: Int { lock.withLock { count } }
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
      d3200ctl info                    fragt Geräte-Info, Akku und Ladezustand
                                       ab und dumpt die Antworten roh
      d3200ctl delete <file-id-hex>    löscht eine Aufnahme – UNWIDERRUFLICH
      d3200ctl klopf                   nimmt auf, während du klopfst, und
                                       prüft, ob das BLE-Frames erzeugt
      d3200ctl flags [<file-id-hex>]   zählt das Flags-Byte aller Frames aus
                                       (Bit 0x01 = Klopfmarkierung)

    Optionen
      --out <dir>   Zielordner für die .ogg-Datei (Standard: aktueller Ordner)
      --quiet       kein Frame-Trace auf stderr
      --seconds <n> Laufzeit von `monitor` (Standard 120)
    """
}
