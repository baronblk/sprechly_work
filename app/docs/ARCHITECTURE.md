# Architecture

Layering (top depends on bottom only):

```
View (SwiftUI, stateless)
  → ViewModel (@Observable, @MainActor)
    → Service / Engine (actor or struct, thread-safe)
      → DataSource (SwiftData, AVFoundation, FileManager, StoreKit, CloudKit)
```

## Project generation

The Xcode project is generated from `project.yml` and is **not** committed:

```sh
brew install xcodegen   # once, if missing
xcodegen generate
open VoxStudio.xcodeproj
```

## Modules

- `App/` — entry point (`VoxStudioApp`), app-wide state (`AppState`), routing (`AppRoute`), placeholder `RootView`.
- `DesignSystem/` — semantic theme tokens (`Theme`), reusable components.
- `Features/Monetization/` — `Entitlement`, `EntitlementProviding`, `StoreManager`, `EntitlementGate`.
- `Engine/`, `Transcription/`, `Persistence/`, `Resources/` — added in later slices.

## Monetization

See CLAUDE.md §9a. `StoreManager` (`@MainActor @Observable`) is the single source of truth for entitlements, derived live from `Transaction.currentEntitlements` and kept current through a long-lived `Transaction.updates` listener. `EntitlementProviding` is the protocol seam that view models and tests depend on (never the concrete class). The reusable `gate(_:onLocked:action:)` helper and the `.requiresEntitlement(...)` view modifier are the hooks Phase 3 attaches to every AI entry point.

## Testing

Swift Testing only. `MockEntitlementStore` covers gating logic without StoreKit. A StoreKit Testing integration test (`SKTestSession` + `Configuration/VoxStudio.storekit`) exercises the real purchase → entitlement path. Assertions use `StoreManager.owned` (the raw StoreKit-derived set), which is unaffected by the `UNLOCK_ALL` debug override.
