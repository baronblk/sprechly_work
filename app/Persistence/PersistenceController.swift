import Foundation
import SwiftData
import os

/// Builds the SwiftData container with a deterministic store location.
///
/// On iOS, `Library/Application Support` is **not** created automatically
/// (unlike Documents/Caches). We create it explicitly and point the store at a
/// named URL there, which avoids the first-launch CoreData recovery noise and
/// gives a stable basis for later CloudKit. On failure we fall back to an
/// in-memory store and log a fault — never `fatalError` (§3).
enum PersistenceController {
    private static let logger = Logger(subsystem: "de.gcng.sprechly.work", category: "Persistence")
    private static var schema: Schema { Schema([Recording.self, TranscriptSegment.self]) }

    /// Ensures `Application Support` exists and returns the store URL inside it.
    static func storeURL(inApplicationSupport appSupport: URL) throws -> URL {
        try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport.appendingPathComponent("VoxStudio.store")
    }

    /// The system Application Support directory, created if missing.
    static func applicationSupportDirectory() throws -> URL {
        try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    }

    private static let cloudKitContainerID = "iCloud.de.gcng.sprechly.work"

    /// User preference for iCloud sync (default on). Applied at container
    /// creation, so changes take effect on the next launch.
    static let syncPreferenceKey = "icloudSyncEnabled"
    static var isCloudSyncEnabled: Bool {
        UserDefaults.standard.object(forKey: syncPreferenceKey) == nil
            ? true
            : UserDefaults.standard.bool(forKey: syncPreferenceKey)
    }

    /// On-disk store. `cloudKit: true` enables CloudKit sync (private database);
    /// otherwise CloudKit is explicitly **off** (default `.automatic` would turn
    /// it on whenever the entitlement is present, which crashes on an
    /// incompatible schema).
    static func container(at url: URL, cloudKit: Bool) throws -> ModelContainer {
        let config = ModelConfiguration(
            url: url,
            cloudKitDatabase: cloudKit ? .private(cloudKitContainerID) : .none
        )
        return try ModelContainer(for: schema, configurations: config)
    }

    static func inMemoryContainer() -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            logger.fault("In-memory store unavailable: \(error.localizedDescription, privacy: .public)")
            return try! ModelContainer(for: schema, configurations: config)
        }
    }

    /// Production container: CloudKit-synced on-disk store, falling back to a
    /// local-only on-disk store (never crashes if CloudKit is unavailable), then
    /// in-memory as the last resort.
    static func makeContainer() -> ModelContainer {
        do {
            let appSupport = try applicationSupportDirectory()
            let url = try storeURL(inApplicationSupport: appSupport)
            #if targetEnvironment(simulator)
            // The Simulator/CI build is unsigned (no iCloud entitlement);
            // attempting CloudKit there traps. Use a local-only store.
            return try container(at: url, cloudKit: false)
            #else
            guard isCloudSyncEnabled else {
                return try container(at: url, cloudKit: false)
            }
            do {
                return try container(at: url, cloudKit: true)
            } catch {
                logger.error("CloudKit store unavailable, using local-only: \(error.localizedDescription, privacy: .public)")
                return try container(at: url, cloudKit: false)
            }
            #endif
        } catch {
            logger.fault("On-disk store unavailable, using in-memory fallback: \(error.localizedDescription, privacy: .public)")
            return inMemoryContainer()
        }
    }
}
