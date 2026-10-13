import AVFoundation
import Foundation
import SoundcoreWorkKit
import os

/// Bringt eine Aufnahme des Soundcore Work ins Format der Bibliothek.
///
/// Persistenz-agnostisch: der Service liefert nur Dateiname und Dauer, das
/// ViewModel legt den `Recording`-Datensatz an.
///
/// Weg: Opus-Pakete → CAF/Opus → verlustfreies 48-kHz-Mono-CAF → M4A.
/// Der Zwischenschritt über CAF/Opus ist nötig, weil AVFoundation Ogg/Opus
/// auf iOS nicht liest, Opus im CAF-Container dagegen schon.
actor WorkImportService {
    /// Ergebnis eines Imports, bereit für den `Recording`-Datensatz.
    struct Converted: Sendable {
        let fileName: String
        let duration: TimeInterval
    }

    enum ImportError: Error, LocalizedError {
        case conversionFailed(underlying: String)

        var errorDescription: String? {
            switch self {
            case .conversionFailed(let underlying):
                String(localized: "Die Aufnahme konnte nicht importiert werden: \(underlying)")
            }
        }
    }

    private let fileStore: RecordingFileStore
    private let importer = AudioImportService()
    private let exporter = AudioExportService()
    private let logger = Logger(subsystem: "de.gcng.sprechly.work", category: "WorkImport")

    init(fileStore: RecordingFileStore = RecordingFileStore()) {
        self.fileStore = fileStore
    }

    /// Schreibt den Download in die Bibliothek und liefert Dateiname und Dauer.
    func convert(_ download: D3200Download) async throws -> Converted {
        let opusURL = fileStore.temporaryURL(pathExtension: "caf")
        let working = fileStore.temporaryURL(pathExtension: "caf")
        let target = fileStore.makeRecordingTarget()

        defer {
            fileStore.removeTemporary(opusURL)
            fileStore.removeTemporary(working)
        }

        do {
            try download.writeCAFOpus(to: opusURL)
            let duration = try await importer.importToRecordingFormat(opusURL, to: working)
            try await exporter.export(workingURL: working, format: .m4a, to: target.temporaryURL)
            try fileStore.finalize(temporaryURL: target.temporaryURL, fileName: target.fileName)

            logger.info("""
            Aufnahme \(String(format: "%08x", download.header.fileID), privacy: .public) \
            importiert (\(download.opusPackets.count) Pakete, \(duration, format: .fixed(precision: 1)) s)
            """)
            return Converted(fileName: target.fileName, duration: duration)
        } catch {
            fileStore.removeTemporary(target.temporaryURL)
            logger.error("Import fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            throw ImportError.conversionFailed(underlying: error.localizedDescription)
        }
    }

    /// Titel für eine importierte Geräte-Aufnahme.
    static func title(for recording: D3200Recording) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return String(localized: "Work \(formatter.string(from: recording.recordedAt))")
    }
}
