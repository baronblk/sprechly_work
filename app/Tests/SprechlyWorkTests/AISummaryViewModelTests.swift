import Foundation
import SwiftData
import Testing
@testable import VoxStudio

// MARK: - Mock

private final class MockSummarizer: AISummarizing, @unchecked Sendable {
    var availabilityValue: AIAvailability = .available
    var result: Result<RecordingInsights, AISummaryError> =
        .success(RecordingInsights(title: "Titel", summary: "Zusammenfassung"))
    private(set) var summarizeCount = 0

    func availability() async -> AIAvailability { availabilityValue }

    private(set) var lastStyle: SummaryStyle?
    func summarize(transcript: String, style: SummaryStyle) async throws -> RecordingInsights {
        summarizeCount += 1
        lastStyle = style
        switch result {
        case .success(let insights): return insights
        case .failure(let error): throw error
        }
    }

    var translationResult = "translated"
    private(set) var lastTranslationLanguage: String?
    func translate(_ text: String, to language: String) async throws -> String {
        lastTranslationLanguage = language
        return translationResult
    }
}

// MARK: - Tests

@MainActor
struct AISummaryViewModelTests {
    /// Returns the container too so it outlives the test (a dangling container
    /// resets the context and SIGTRAPs).
    private func makeRecording() throws -> (Recording, ModelContainer) {
        let container = try ModelContainer(
            for: Recording.self, TranscriptSegment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let recording = Recording(title: "Aufnahme", fileName: "a.m4a", duration: 5)
        container.mainContext.insert(recording)
        return (recording, container)
    }

    @Test func lockedShowsPaywallAndDoesNotGenerate() async throws {
        let (recording, container) = try makeRecording()
        let mock = MockSummarizer()
        let vm = AISummaryViewModel(recording: recording, service: mock)
        vm.configure(modelContext: container.mainContext, store: MockEntitlementStore())

        await vm.generate()

        #expect(vm.showPaywall)
        #expect(mock.summarizeCount == 0)
        #expect(recording.summary == nil)
    }

    @Test func unlockedGeneratesAndPersists() async throws {
        let (recording, container) = try makeRecording()
        let mock = MockSummarizer()
        let vm = AISummaryViewModel(recording: recording, service: mock)
        vm.configure(modelContext: container.mainContext, store: MockEntitlementStore(unlockAll: true))

        await vm.generate()

        #expect(vm.phase == .done)
        #expect(recording.aiTitle == "Titel")
        #expect(recording.summary == "Zusammenfassung")
        #expect(mock.summarizeCount == 1)
        #expect(!vm.showPaywall)
    }

    @Test func regeneratingExistingSummaryIsFreeWhenLocked() async throws {
        let (recording, container) = try makeRecording()
        recording.summary = "alt"
        let mock = MockSummarizer()
        mock.result = .success(RecordingInsights(title: "Neu", summary: "neu"))
        let vm = AISummaryViewModel(recording: recording, service: mock)
        vm.configure(modelContext: container.mainContext, store: MockEntitlementStore())

        await vm.generate()

        #expect(!vm.showPaywall)
        #expect(recording.summary == "neu")
        #expect(mock.summarizeCount == 1)
    }

    @Test func applyTitleCopiesAITitleToRecording() async throws {
        let (recording, container) = try makeRecording()
        recording.aiTitle = "KI-Titel"
        let vm = AISummaryViewModel(recording: recording, service: MockSummarizer())
        vm.configure(modelContext: container.mainContext, store: MockEntitlementStore(unlockAll: true))

        #expect(vm.canApplyTitle)
        vm.applyTitle()

        #expect(recording.title == "KI-Titel")
        #expect(!vm.canApplyTitle) // title now equals aiTitle
    }

    @Test func generationFailureSetsFailedPhase() async throws {
        let (recording, container) = try makeRecording()
        let mock = MockSummarizer()
        mock.result = .failure(.unavailable(.modelNotReady))
        let vm = AISummaryViewModel(recording: recording, service: mock)
        vm.configure(modelContext: container.mainContext, store: MockEntitlementStore(unlockAll: true))

        await vm.generate()

        #expect(vm.phase == .failed)
        #expect(vm.errorMessage != nil)
        #expect(recording.summary == nil)
    }

    @Test func generateUsesSelectedStyle() async throws {
        let (recording, container) = try makeRecording()
        let mock = MockSummarizer()
        let vm = AISummaryViewModel(recording: recording, service: mock)
        vm.configure(modelContext: container.mainContext, store: MockEntitlementStore(unlockAll: true))

        vm.style = .minutes
        await vm.generate()

        #expect(mock.lastStyle == .minutes)
    }

    @Test func translateLockedShowsPaywall() async throws {
        let (recording, container) = try makeRecording()
        let mock = MockSummarizer()
        let vm = AISummaryViewModel(recording: recording, service: mock)
        vm.configure(modelContext: container.mainContext, store: MockEntitlementStore())

        await vm.translate(transcript: "Hallo", to: TranslationLanguage(code: "en"))

        #expect(vm.showPaywall)
        #expect(vm.translatedText == nil)
    }

    @Test func translateUnlockedProducesText() async throws {
        let (recording, container) = try makeRecording()
        let mock = MockSummarizer()
        mock.translationResult = "Hello"
        let vm = AISummaryViewModel(recording: recording, service: mock)
        vm.configure(modelContext: container.mainContext, store: MockEntitlementStore(unlockAll: true))

        await vm.translate(transcript: "Hallo", to: TranslationLanguage(code: "en"))

        #expect(vm.translatedText == "Hello")
        #expect(vm.translationLanguage?.code == "en")
        #expect(!vm.isTranslating)
    }

    @Test func translatePersistsToRecording() async throws {
        let (recording, container) = try makeRecording()
        let mock = MockSummarizer()
        mock.translationResult = "Hello"
        let vm = AISummaryViewModel(recording: recording, service: mock)
        vm.configure(modelContext: container.mainContext, store: MockEntitlementStore(unlockAll: true))

        await vm.translate(transcript: "Hallo", to: TranslationLanguage(code: "en"))

        #expect(recording.translation == "Hello")
        #expect(recording.translationLanguageCode == "en")
    }

    @Test func restoresPersistedTranslationOnInit() async throws {
        let (recording, container) = try makeRecording()
        recording.translation = "Bonjour"
        recording.translationLanguageCode = "fr"

        let vm = AISummaryViewModel(recording: recording, service: MockSummarizer())

        #expect(vm.translatedText == "Bonjour")
        #expect(vm.translationLanguage?.code == "fr")
        _ = container // keep the store alive for the test's duration
    }

    @Test func refreshAvailabilityPropagates() async throws {
        let (recording, container) = try makeRecording()
        let mock = MockSummarizer()
        mock.availabilityValue = .appleIntelligenceNotEnabled
        let vm = AISummaryViewModel(recording: recording, service: mock)
        vm.configure(modelContext: container.mainContext, store: MockEntitlementStore(unlockAll: true))

        await vm.refreshAvailability()

        #expect(vm.availability == .appleIntelligenceNotEnabled)
    }
}
