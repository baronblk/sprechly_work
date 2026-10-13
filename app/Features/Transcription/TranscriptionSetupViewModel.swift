import Foundation
import Observation

/// Drives the transcription setup screen: shows each supported locale's on-device
/// asset state and lets the user download the language model, reflecting the full
/// download state machine (not just "loading / done").
@MainActor
@Observable
final class TranscriptionSetupViewModel {
    struct LocaleEntry: Identifiable {
        let locale: Locale
        var state: TranscriptionAssetState
        var id: String { locale.identifier }
        var displayName: String { TranscriptionLocale.displayName(for: locale) }
    }

    private(set) var entries: [LocaleEntry] = []
    var searchText = ""

    /// Entries filtered by the search field (by localized language name).
    var filteredEntries: [LocaleEntry] {
        guard !searchText.isEmpty else { return entries }
        return entries.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    private let service: any TranscriptionProviding
    private var installTasks: [String: Task<Void, Never>] = [:]

    init(service: any TranscriptionProviding = SpeechTranscriptionService()) {
        self.service = service
    }

    func refresh() async {
        let supported = await service.supportedLocales()
        let installed = Set(await service.installedLocales().map(\.identifier))
        let list = supported.isEmpty ? TranscriptionLocale.supported : supported
        entries = list
            .sorted {
                TranscriptionLocale.displayName(for: $0)
                    .localizedCaseInsensitiveCompare(TranscriptionLocale.displayName(for: $1)) == .orderedAscending
            }
            .map { LocaleEntry(locale: $0, state: installed.contains($0.identifier) ? .installed : .notInstalled) }
    }

    func download(_ locale: Locale) {
        let id = locale.identifier
        installTasks[id]?.cancel()
        installTasks[id] = Task { [weak self] in
            guard let self else { return }
            for await state in self.service.installAssets(for: locale) {
                self.update(locale: locale, to: state)
            }
        }
    }

    private func update(locale: Locale, to state: TranscriptionAssetState) {
        guard let index = entries.firstIndex(where: { $0.locale == locale }) else { return }
        entries[index].state = state
    }
}
