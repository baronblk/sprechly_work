import Foundation
import Speech
import Testing
@testable import SprechlyWork

struct TranscriptionLocaleTests {
    @Test func supportsGermanAndEnglish() {
        let ids = TranscriptionLocale.supported.map(\.identifier)
        #expect(ids.contains("de-DE"))
        #expect(ids.contains("en-US"))
    }

    @Test func isDataDrivenList() {
        // A list, not two hardwired branches — adding a language is one entry.
        #expect(TranscriptionLocale.supported.count >= 2)
    }
}

struct TranscriptionAssetStateTests {
    @Test func mapsInventoryStatus() {
        #expect(TranscriptionAssetState.from(.installed) == .installed)
        #expect(TranscriptionAssetState.from(.supported) == .notInstalled)
        #expect(TranscriptionAssetState.from(.unsupported) == .unsupported)
        if case .downloading = TranscriptionAssetState.from(.downloading) {} else {
            Issue.record("downloading status should map to .downloading")
        }
    }

    @Test func onlyInstalledIsReady() {
        #expect(TranscriptionAssetState.installed.isReady)
        #expect(!TranscriptionAssetState.notInstalled.isReady)
        #expect(!TranscriptionAssetState.downloading(progress: 0.9).isReady)
    }
}
