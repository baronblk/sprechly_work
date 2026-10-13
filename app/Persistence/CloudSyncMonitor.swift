import CoreData
import Foundation
import Observation

/// App-wide observer of CloudKit sync activity (via the Core Data CloudKit event
/// notification SwiftData posts under the hood). Exposes current activity, the
/// last successful upload/download (persisted across launches) and a short event
/// log so the user can see whether sync is happening and whether it failed.
@MainActor
@Observable
final class CloudSyncMonitor {
    enum Activity: Equatable { case idle, uploading, downloading }

    struct Event: Identifiable {
        let id = UUID()
        let date: Date
        let text: String
    }

    private(set) var activity: Activity = .idle
    private(set) var lastError: String?
    private(set) var events: [Event] = []

    private(set) var lastUpload: Date? {
        didSet { defaults.set(lastUpload, forKey: "sync.lastUpload") }
    }
    private(set) var lastDownload: Date? {
        didSet { defaults.set(lastDownload, forKey: "sync.lastDownload") }
    }

    private let defaults = UserDefaults.standard
    private var task: Task<Void, Never>?

    init() {
        lastUpload = defaults.object(forKey: "sync.lastUpload") as? Date
        lastDownload = defaults.object(forKey: "sync.lastDownload") as? Date
    }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            let name = NSPersistentCloudKitContainer.eventChangedNotification
            for await note in NotificationCenter.default.notifications(named: name) {
                guard let self else { return }
                guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event else { continue }
                self.apply(event)
            }
        }
    }

    private func apply(_ event: NSPersistentCloudKitContainer.Event) {
        let kind: String
        switch event.type {
        case .setup: kind = String(localized: "Einrichtung")
        case .import: kind = String(localized: "Download")
        case .export: kind = String(localized: "Upload")
        @unknown default: kind = String(localized: "Sync")
        }

        if event.endDate == nil {
            switch event.type {
            case .export: activity = .uploading
            case .import: activity = .downloading
            default: break
            }
            log(String(localized: "\(kind) gestartet"))
            return
        }

        activity = .idle
        if let error = event.error {
            lastError = error.localizedDescription
            log(String(localized: "\(kind) fehlgeschlagen"))
        } else {
            lastError = nil
            if event.type == .export { lastUpload = event.endDate }
            if event.type == .import { lastDownload = event.endDate }
            log(String(localized: "\(kind) abgeschlossen"))
        }
    }

    private func log(_ text: String) {
        events.insert(Event(date: Date(), text: text), at: 0)
        if events.count > 12 { events.removeLast(events.count - 12) }
    }
}
