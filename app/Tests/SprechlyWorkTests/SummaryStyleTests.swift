import Testing
@testable import VoxStudio

struct SummaryStyleTests {
    @Test func allStylesHaveTitleIconAndInstructions() {
        for style in SummaryStyle.allCases {
            #expect(!style.icon.isEmpty)
            #expect(!style.instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    @Test func includesNewStyles() {
        let ids = Set(SummaryStyle.allCases.map(\.id))
        #expect(ids.isSuperset(of: ["summary", "minutes", "bullets", "keypoints", "cleanup"]))
    }

    @Test func cleanupInstructionPreservesMeaning() {
        // The cleanup style must instruct to keep content/meaning, not rewrite.
        #expect(SummaryStyle.cleanup.instructions.localizedCaseInsensitiveContains("bewahre"))
    }
}
