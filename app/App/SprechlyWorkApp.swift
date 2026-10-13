import SwiftData
import SwiftUI

@main
struct SprechlyWorkApp: App {
    @State private var appState = AppState(store: StoreManager())
    private let modelContainer: ModelContainer = {
        #if DEBUG
        if DemoSeed.isRequested {
            // Skip onboarding so screenshots land on real content.
            UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
            // Isolated in-memory store for screenshots/demos — never iCloud.
            let container = PersistenceController.inMemoryContainer()
            DemoSeed.populate(ModelContext(container))
            return container
        }
        #endif
        return PersistenceController.makeContainer()
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(appState.store)
                .environment(appState.rating)
                .modelContainer(modelContainer)
                .tint(Theme.Colors.accent)
                .preferredColorScheme(.dark)
                .task {
                    guard !isRunningTests else { return }
                    appState.syncMonitor.start()
                    await appState.store.start()
                }
        }
    }

    /// True while running under XCTest/Swift Testing, so the app does not
    /// initialize StoreKit before a test's `SKTestSession` takes over.
    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
