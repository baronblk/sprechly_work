import Foundation
import SwiftData
import os

/// Bridges file-based audio with CloudKit-synced `audioData` so the rest of the
/// app keeps working with on-disk files:
/// - local file present but no `audioData` → load it (so CloudKit uploads it);
/// - `audioData` present but no local file (synced from another device) → write
///   the file (so playback/editor/transcription find it).
///
/// Runs on a background `ModelContext` (its own context, off the main actor).
///
/// **Memory:** audio blobs are large (an hour is ~55 MB), and this runs on every
/// launch, foreground and remote change. Each recording is therefore saved
/// individually so SwiftData can flush the blob to external storage and release
/// it, instead of holding the entire library in memory until one final save.
enum CloudAudioReconciler {
    private static let logger = Logger(subsystem: "de.gcng.sprechly.work", category: "CloudSync")

    /// Fire-and-forget reconcile (launch, remote change, foreground).
    static func reconcile(container: ModelContainer) {
        Task.detached(priority: .utility) { run(container: container) }
    }

    /// Awaitable reconcile for a manual "refresh now" action.
    static func reconcileNow(container: ModelContainer) async {
        await Task.detached(priority: .utility) { run(container: container) }.value
    }

    private static func run(container: ModelContainer) {
        let context = ModelContext(container)
        let store = RecordingFileStore()
        guard let recordings = try? context.fetch(FetchDescriptor<Recording>()) else { return }

        for recording in recordings where !recording.fileName.isEmpty {
            let url = store.audioURL(forFileName: recording.fileName)
            let exists = FileManager.default.fileExists(atPath: url.path)

            if exists, recording.audioData == nil {
                // `.mappedIfSafe` lets the kernel page the file in instead of
                // copying the whole thing onto the heap.
                guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { continue }
                recording.audioData = data
                save(context, for: recording)
            } else if !exists, let data = recording.audioData {
                do {
                    try data.write(to: url, options: .atomic)
                } catch {
                    logger.error(
                        "Reconcile write failed: \(error.localizedDescription, privacy: .public)"
                    )
                }
            }
        }
    }

    /// Persists one recording, keeping the peak footprint at roughly a single
    /// audio file rather than the whole library.
    private static func save(_ context: ModelContext, for recording: Recording) {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            // Don't let one bad row abort the sweep — drop the pending change
            // and carry on with the next recording.
            context.rollback()
            logger.error("Reconcile save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
