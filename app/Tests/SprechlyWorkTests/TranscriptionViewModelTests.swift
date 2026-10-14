import Foundation
import SwiftData
import Testing
@testable import SprechlyWork

private enum StubError: Error { case aborted }

private final class StubTranscription: TranscriptionProviding, @unchecked Sendable {
    var installed: Set<String> = ["de-DE", "en-US"]
    var drafts: [TranscriptDraft] = []
    /// Antwort je Sprache – für die Spracherkennung, die dieselbe Datei in
    /// mehreren Sprachen probiert.
    var draftsByLocale: [String: [TranscriptDraft]] = [:]
    /// Mitschrift, welche Sprachen abgefragt wurden.
    var requestedLocales: [String] = []
    /// If set, throw after yielding this many drafts (simulates an aborted run).
    var throwAfter: Int?

    func assetState(for locale: Locale) async -> TranscriptionAssetState {
        installed.contains(locale.identifier) ? .installed : .notInstalled
    }

    func installAssets(for locale: Locale) -> AsyncStream<TranscriptionAssetState> {
        AsyncStream { $0.finish() }
    }

    /// Dieselbe Quelle wie `assetState`, damit die Sprachauswahl im ViewModel
    /// überhaupt etwas zu wählen hat.
    func installedLocales() async -> [Locale] {
        installed.sorted().map { Locale(identifier: $0) }
    }

    func transcribe(fileAt url: URL, locale: Locale) -> AsyncThrowingStream<TranscriptDraft, Error> {
        requestedLocales.append(locale.identifier)
        let drafts = draftsByLocale[locale.identifier] ?? self.drafts
        let throwAfter = self.throwAfter
        return AsyncThrowingStream { continuation in
            for (index, draft) in drafts.enumerated() {
                if let throwAfter, index >= throwAfter {
                    continuation.finish(throwing: StubError.aborted)
                    return
                }
                continuation.yield(draft)
            }
            if throwAfter != nil {
                continuation.finish(throwing: StubError.aborted)
            } else {
                continuation.finish()
            }
        }
    }
}

@MainActor
struct TranscriptionViewModelTests {
    // Keep the container alive for the test's lifetime — returning only its
    // mainContext would deallocate the container and dangle the context.
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Recording.self, TranscriptSegment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeRecording(in context: ModelContext) -> Recording {
        let recording = Recording(title: "R", fileName: "r.m4a", duration: 30)
        context.insert(recording)
        return recording
    }

    @Test func transcribePersistsSortedSegments() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let recording = makeRecording(in: context)
        let stub = StubTranscription()
        stub.drafts = [
            TranscriptDraft(text: "zwei", startTime: 2, endTime: 3),
            TranscriptDraft(text: "eins", startTime: 0, endTime: 1)
        ]
        let vm = TranscriptionViewModel(recording: recording, service: stub)
        vm.configure(modelContext: context, store: MockEntitlementStore(unlockAll: true))

        await vm.transcribe()

        #expect(vm.phase == .done)
        #expect(vm.segments.map(\.text) == ["eins", "zwei"]) // sorted by start
    }

    @Test func reTranscribeReplacesNotDuplicates() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let recording = makeRecording(in: context)
        let stub = StubTranscription()
        stub.drafts = [TranscriptDraft(text: "a", startTime: 0, endTime: 1),
                       TranscriptDraft(text: "b", startTime: 1, endTime: 2)]
        let vm = TranscriptionViewModel(recording: recording, service: stub)
        vm.configure(modelContext: context, store: MockEntitlementStore(unlockAll: true))
        await vm.transcribe()
        #expect(recording.segmentList.count == 2)

        stub.drafts = [TranscriptDraft(text: "c", startTime: 0, endTime: 1)]
        await vm.transcribe()

        #expect(recording.segmentList.count == 1)
        #expect(recording.segmentList.first?.text == "c")
    }

    @Test func abortedReTranscriptionKeepsOldSegments() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let recording = makeRecording(in: context)
        let stub = StubTranscription()
        stub.drafts = [TranscriptDraft(text: "alt1", startTime: 0, endTime: 1),
                       TranscriptDraft(text: "alt2", startTime: 1, endTime: 2)]
        let vm = TranscriptionViewModel(recording: recording, service: stub)
        vm.configure(modelContext: context, store: MockEntitlementStore(unlockAll: true))
        await vm.transcribe()
        #expect(recording.segmentList.count == 2)

        // A second run that aborts mid-stream must not touch the old segments.
        stub.drafts = [TranscriptDraft(text: "neu1", startTime: 0, endTime: 1),
                       TranscriptDraft(text: "neu2", startTime: 1, endTime: 2),
                       TranscriptDraft(text: "neu3", startTime: 2, endTime: 3)]
        stub.throwAfter = 1
        await vm.transcribe()

        #expect(vm.phase == .failed)
        #expect(recording.segmentList.count == 2)
        #expect(Set(recording.segmentList.map(\.text)) == ["alt1", "alt2"])
    }

    // MARK: - Sprache pro Aufnahme

    @Test func transcriptionStoresTheLanguageItUsed() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let recording = makeRecording(in: context)
        #expect(recording.transcriptionLanguage == nil)

        let stub = StubTranscription()
        stub.drafts = [TranscriptDraft(text: "hallo", startTime: 0, endTime: 1)]
        let vm = TranscriptionViewModel(recording: recording, service: stub)
        vm.configure(modelContext: context, store: MockEntitlementStore(unlockAll: true))
        vm.locale = Locale(identifier: "en-US")

        await vm.transcribe()

        #expect(vm.phase == .done)
        #expect(recording.transcriptionLanguage == "en-US")
    }

    /// Ein gesperrter Lauf speichert nichts – auch nicht die Sprache.
    @Test func previewRunDoesNotStoreTheLanguage() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let recording = makeRecording(in: context)

        let stub = StubTranscription()
        stub.drafts = [TranscriptDraft(text: "hallo", startTime: 0, endTime: 1)]
        let vm = TranscriptionViewModel(recording: recording, service: stub)
        vm.configure(modelContext: context, store: MockEntitlementStore(unlockAll: false))
        vm.locale = Locale(identifier: "en-US")

        await vm.transcribe()

        #expect(vm.phase == .preview)
        #expect(recording.transcriptionLanguage == nil)
    }

    @Test func rememberedLanguageWinsOverTheDeviceLanguage() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let recording = makeRecording(in: context)
        recording.transcriptionLanguage = "en-US"

        let vm = TranscriptionViewModel(recording: recording, service: StubTranscription())
        vm.configure(modelContext: context, store: MockEntitlementStore(unlockAll: true))
        await vm.loadInstalledLocales()

        // Das Testgerät läuft auf Deutsch; die Aufnahme bleibt trotzdem englisch.
        #expect(vm.locale.identifier == "en-US")
    }

    // MARK: - Spracherkennung

    /// Englisch gesprochen auf einem deutschen Gerät: ohne Erkennung liefe das
    /// deutsche Modell und produzierte Unsinn.
    @Test func detectionSwitchesToTheSpokenLanguage() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let recording = makeRecording(in: context)

        let stub = StubTranscription()
        stub.draftsByLocale = [
            "de-DE": [TranscriptDraft(
                text: "The Dogs are in sareointan the container runs in Docker today.",
                startTime: 0, endTime: 4
            )],
            "en-US": [TranscriptDraft(
                text: "The docs are in SharePoint and the container runs in Docker today.",
                startTime: 0, endTime: 4
            )]
        ]
        let vm = TranscriptionViewModel(recording: recording, service: stub)
        vm.configure(modelContext: context, store: MockEntitlementStore(unlockAll: true))
        await vm.loadInstalledLocales()
        vm.locale = Locale(identifier: "de-DE")

        await vm.transcribe()

        #expect(vm.locale.identifier == "en-US")
        #expect(vm.detectedLocale?.identifier == "en-US")
        #expect(recording.transcriptionLanguage == "en-US")
        #expect(vm.phase == .done)
    }

    /// Eine Aufnahme mit bekannter Sprache wird nicht erneut befragt – das
    /// wäre jedes Mal ein zusätzlicher Lauf je Kandidat.
    @Test func detectionIsSkippedWhenTheLanguageIsKnown() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let recording = makeRecording(in: context)
        recording.transcriptionLanguage = "en-US"

        let stub = StubTranscription()
        stub.drafts = [TranscriptDraft(text: "hallo", startTime: 0, endTime: 1)]
        let vm = TranscriptionViewModel(recording: recording, service: stub)
        vm.configure(modelContext: context, store: MockEntitlementStore(unlockAll: true))
        await vm.loadInstalledLocales()

        await vm.transcribe()

        #expect(stub.requestedLocales == ["en-US"])
        #expect(vm.detectedLocale == nil)
    }

    /// Unentschieden heißt: bei der bisherigen Wahl bleiben, nicht raten.
    @Test func undecidedDetectionKeepsTheCurrentLanguage() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let recording = makeRecording(in: context)

        let stub = StubTranscription()
        stub.drafts = [TranscriptDraft(text: "Ja.", startTime: 0, endTime: 1)]  // zu kurz
        let vm = TranscriptionViewModel(recording: recording, service: stub)
        vm.configure(modelContext: context, store: MockEntitlementStore(unlockAll: true))
        await vm.loadInstalledLocales()
        vm.locale = Locale(identifier: "de-DE")

        await vm.transcribe()

        #expect(vm.locale.identifier == "de-DE")
        #expect(vm.detectedLocale == nil)
        #expect(vm.phase == .done)
    }

    @Test func rememberedLanguageFallsBackToAnotherRegion() {
        let de_AT = Locale(identifier: "de-AT")
        let en = Locale(identifier: "en-US")
        // Gemerkt war de-DE, installiert ist nur de-AT – Deutsch bleibt Deutsch.
        #expect(
            TranscriptionViewModel.defaultLocale(
                installed: [en, de_AT], preferred: ["en-US"], remembered: "de-DE"
            )?.identifier == "de-AT"
        )
    }

    @Test func rememberedLanguageIsIgnoredWhenItsModelIsGone() {
        let de = Locale(identifier: "de-DE")
        // Das gemerkte Modell wurde gelöscht – dann entscheidet wieder das Gerät.
        #expect(
            TranscriptionViewModel.defaultLocale(
                installed: [de], preferred: ["de-DE"], remembered: "fr-FR"
            )?.identifier == "de-DE"
        )
    }

    @Test func defaultLocalePicksDevicePreferredLanguage() {
        let de = Locale(identifier: "de-DE")
        let en = Locale(identifier: "en-US")
        #expect(TranscriptionViewModel.defaultLocale(installed: [de, en], preferred: ["de-DE"])?.identifier == "de-DE")
        #expect(TranscriptionViewModel.defaultLocale(installed: [de, en], preferred: ["en-GB"])?.identifier == "en-US")
        #expect(TranscriptionViewModel.defaultLocale(installed: [de, en], preferred: ["fr-FR"])?.identifier == "de-DE")
        #expect(TranscriptionViewModel.defaultLocale(installed: [], preferred: ["de-DE"]) == nil)
    }
}
