import Foundation

/// Process-wide single-playback coordinator. Each `PlaybackViewModel` has its own
/// engine (one per detail view), so without coordination several can play at once
/// — SwiftUI's `onDisappear` is too unreliable in a `NavigationSplitView` to stop
/// the previous one. Whoever starts playing stops whoever was playing before, so
/// at most one recording is ever audible.
@MainActor
final class NowPlaying {
    static let shared = NowPlaying()
    private init() {}

    private var currentOwner: ObjectIdentifier?
    private var stopCurrent: (() -> Void)?

    /// Register `owner` as the active player; stops the previously active one.
    func began(owner: AnyObject, stop: @escaping () -> Void) {
        let previous = stopCurrent
        currentOwner = ObjectIdentifier(owner)
        stopCurrent = stop
        previous?()
    }

    /// Clear the registration if `owner` is still the active player.
    func ended(owner: AnyObject) {
        guard currentOwner == ObjectIdentifier(owner) else { return }
        currentOwner = nil
        stopCurrent = nil
    }

    /// Stop whatever is currently playing (e.g. when returning to the list).
    func stopAll() {
        let stop = stopCurrent
        currentOwner = nil
        stopCurrent = nil
        stop?()
    }
}
