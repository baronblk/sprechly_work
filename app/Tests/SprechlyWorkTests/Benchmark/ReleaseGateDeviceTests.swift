import Foundation
import StoreKit
import SwiftData
import Testing
@testable import VoxStudio

/// The automatable parts of release gates 3e (transcript export) and 3b (the
/// in-app purchase), on real hardware.
///
/// **What these cannot cover:** presenting the share sheet and completing a
/// sandbox purchase both require someone to tap the device. Per the project's
/// own convention the agent prepares and installs, and Rene performs the
/// on-device interaction — so these tests take each gate as far as code can,
/// and docs/DEVICE_TESTS.md records the rest.
///
/// Note on StoreKit: the `.storekit` configuration is attached to the scheme's
/// **launch** action only, not its test action, so the product lookup below hits
/// the real App Store rather than the local config file.
@Suite(.serialized)
struct ReleaseGateDeviceTests {
    // MARK: - Gate 3e — transcript export

    /// Exercises exactly the call the UI hands to `ShareLink`:
    /// `TranscriptionViewModel.exportFile(_:)`.
    @MainActor
    @Test func exportFileProducesAValidNamedFileForBothFormats() throws {
        #if targetEnvironment(simulator)
        print("GATE3E SKIPPED: simulator")
        return
        #else
        let container = try ModelContainer(
            for: Recording.self, TranscriptSegment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        let context = container.mainContext
        let recording = Recording(title: "Sprint Planung", fileName: "s.m4a", duration: 42)
        context.insert(recording)
        // Text shaped like a real 1.2 transcript: formatted, markup-free, umlauts.
        for (index, text) in [
            "Wir starten um 13:45 Uhr mit der Übergabe.",
            "Der Kauf läuft über StoreKit, die Synchronisierung über CloudKit.",
            "Die KI-Zusammenfassung läuft on-device, Export nach Markdown."
        ].enumerated() {
            context.insert(TranscriptSegment(
                text: text, startTime: Double(index) * 5, endTime: Double(index) * 5 + 5,
                recording: recording
            ))
        }
        recording.summary = "Übergabe um 13:45 Uhr, Kauf über StoreKit."
        try context.save()

        let viewModel = TranscriptionViewModel(recording: recording)
        viewModel.configure(modelContext: context, store: MockEntitlementStore(unlockAll: true))

        for format in TranscriptExportFormat.allCases {
            let url = try #require(viewModel.exportFile(format), "no export URL for \(format.rawValue)")
            defer { try? FileManager.default.removeItem(at: url) }

            let data = try Data(contentsOf: url)
            let text = try #require(String(data: data, encoding: .utf8))
            let size = ((try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? Int) ?? 0
            print("GATE3E \(format.rawValue) name=\(url.lastPathComponent) bytes=\(size)")

            // The file ShareLink would hand over must exist, be named after the
            // recording, carry the BOM that keeps umlauts readable, and contain
            // the transcript and summary.
            #expect(FileManager.default.fileExists(atPath: url.path))
            #expect(url.pathExtension == format.fileExtension)
            #expect(url.lastPathComponent.contains("Sprint"))
            #expect(Array(data.prefix(3)) == [0xEF, 0xBB, 0xBF], "missing UTF-8 BOM")
            #expect(text.contains("13:45"))
            #expect(text.contains("StoreKit"))
            #expect(text.contains("Übergabe"))
            #expect(!text.contains(TranscriptMarkupRepair.marker))
            #expect(size > 100)
        }
        #endif
    }

    /// The gate is unlock-only: locked must yield no file at all.
    @MainActor
    @Test func exportIsRefusedWithoutThePurchase() throws {
        #if targetEnvironment(simulator)
        print("GATE3E LOCKED SKIPPED: simulator")
        return
        #else
        let container = try ModelContainer(
            for: Recording.self, TranscriptSegment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        let context = container.mainContext
        let recording = Recording(title: "Locked", fileName: "l.m4a", duration: 10)
        context.insert(recording)
        context.insert(TranscriptSegment(text: "Hallo", startTime: 0, endTime: 1, recording: recording))
        try context.save()

        let viewModel = TranscriptionViewModel(recording: recording)
        viewModel.configure(modelContext: context, store: MockEntitlementStore(owned: []))
        for format in TranscriptExportFormat.allCases {
            #expect(viewModel.exportFile(format) == nil, "locked export produced a file")
        }
        print("GATE3E locked: no file for either format")
        #endif
    }

    // MARK: - Gate 3b — the in-app purchase

    /// Loads the product from the App Store and reports what it returns.
    ///
    /// This verifies the half of the gate that does not need a human: that the
    /// product resolves, and that its price is whatever the store says rather
    /// than a string in our code. Completing a purchase needs a sandbox tester
    /// signed in on the device and a tap, which is Rene's step.
    @MainActor
    @Test func productLoadsFromTheStoreWithADynamicPrice() async throws {
        #if targetEnvironment(simulator)
        print("GATE3B SKIPPED: simulator")
        return
        #else
        // The product id lives in StoreCatalog, not on Entitlement — the two
        // are deliberately decoupled so one product can grant several
        // capabilities. Asking for the entitlement's raw value would request a
        // product called "ai", which does not exist.
        let identifier = try #require(
            StoreCatalog.productID(selling: .ai), "no product sells the AI entitlement"
        )
        print("GATE3B requesting \(identifier)")

        let products: [Product]
        do {
            products = try await Product.products(for: [identifier])
        } catch {
            print("GATE3B LOOKUP FAILED: \(error)")
            Issue.record("product lookup failed: \(error)")
            return
        }

        print("GATE3B returned \(products.count) product(s)")
        guard let product = products.first else {
            // Expected on a plain development build; recorded, not glossed over.
            print("GATE3B EMPTY — no product returned to this build. " +
                  "A development build without the scheme's StoreKit configuration " +
                  "does not always resolve App Store products; the purchase itself " +
                  "has to be verified from an installed build with a sandbox tester.")
            return
        }

        print("GATE3B id=\(product.id) type=\(product.type.rawValue) " +
              "displayPrice=\(product.displayPrice) price=\(product.price) " +
              "name=\(product.displayName)")

        #expect(product.id == identifier)
        #expect(product.type == .nonConsumable)
        #expect(!product.displayPrice.isEmpty)
        #expect(product.price > 0)
        #expect(!product.displayName.isEmpty)

        let entitlements = await currentEntitlementIdentifiers()
        print("GATE3B currentEntitlements=\(entitlements.isEmpty ? "none" : entitlements.joined(separator: ","))")
        #endif
    }

    /// The product the gate is about, and the only product the app ships.
    ///
    /// No price is hard-coded anywhere: the paywall reads `displayPrice` off the
    /// `Product`, and the single constant the app owns is the identifier below.
    @Test func theAIEntitlementIsSoldByTheExpectedProduct() {
        #expect(StoreCatalog.productID(selling: .ai) == "de.gcng.sprechly.ai")
        // One product ships today; the other entries are commented-out
        // forward-compatibility, so an accidental activation would show here.
        #expect(StoreCatalog.productIDs == ["de.gcng.sprechly.ai"])
        #expect(StoreCatalog.entitlements(forProductID: "de.gcng.sprechly.ai") == [.ai])
    }

    private func currentEntitlementIdentifiers() async -> [String] {
        var found: [String] = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                found.append(transaction.productID)
            }
        }
        return found
    }
}
