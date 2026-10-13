import Foundation
import Testing
@testable import VoxStudio

private final class MockTranscriptionService: TranscriptionProviding, @unchecked Sendable {
    var states: [String: TranscriptionAssetState] = [:]
    var installed: [Locale] = []
    var installScript: [TranscriptionAssetState] = [.downloading(progress: 0.5), .installed]

    func assetState(for locale: Locale) async -> TranscriptionAssetState {
        states[locale.identifier] ?? .notInstalled
    }

    func installAssets(for locale: Locale) -> AsyncStream<TranscriptionAssetState> {
        let script = installScript
        return AsyncStream { continuation in
            for state in script { continuation.yield(state) }
            continuation.finish()
        }
    }

    func transcribe(fileAt url: URL, locale: Locale) -> AsyncThrowingStream<TranscriptDraft, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func supportedLocales() async -> [Locale] { TranscriptionLocale.supported }
    func installedLocales() async -> [Locale] { installed }
}

@MainActor
struct TranscriptionSetupViewModelTests {
    private func waitUntil(_ condition: @escaping () -> Bool) async -> Bool {
        for _ in 0..<200 {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    @Test func refreshMarksInstalledLocales() async {
        let mock = MockTranscriptionService()
        mock.installed = [Locale(identifier: "de-DE")]
        let vm = TranscriptionSetupViewModel(service: mock)

        await vm.refresh()

        #expect(vm.entries.first { $0.locale.identifier == "de-DE" }?.state == .installed)
        #expect(vm.entries.first { $0.locale.identifier == "en-US" }?.state == .notInstalled)
    }

    @Test func searchFiltersEntries() async {
        let mock = MockTranscriptionService()
        let vm = TranscriptionSetupViewModel(service: mock)
        await vm.refresh()

        vm.searchText = "Deutsch"
        #expect(vm.filteredEntries.allSatisfy { $0.displayName.localizedCaseInsensitiveContains("Deutsch") })
        #expect(!vm.filteredEntries.isEmpty)
    }

    @Test func downloadProgressesToInstalled() async {
        let mock = MockTranscriptionService()
        mock.installScript = [.downloading(progress: 0.3), .downloading(progress: 0.8), .installed]
        let vm = TranscriptionSetupViewModel(service: mock)
        await vm.refresh()
        let locale = TranscriptionLocale.supported[0]

        vm.download(locale)

        #expect(await waitUntil { vm.entries.first { $0.locale == locale }?.state == .installed })
    }

    @Test func downloadFailureSurfaces() async {
        let mock = MockTranscriptionService()
        mock.installScript = [.downloading(progress: 0.2), .insufficientStorage]
        let vm = TranscriptionSetupViewModel(service: mock)
        await vm.refresh()
        let locale = TranscriptionLocale.supported[0]

        vm.download(locale)

        #expect(await waitUntil { vm.entries.first { $0.locale == locale }?.state == .insufficientStorage })
    }
}
