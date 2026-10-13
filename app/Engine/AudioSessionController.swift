import AVFoundation
import Foundation

/// Session lifecycle events the UI/engines react to.
enum AudioSessionEvent: Sendable {
    case interruptionBegan
    case interruptionEnded(shouldResume: Bool)
    /// A device was connected or disconnected; the input chain must be rebuilt.
    case routeChanged
}

/// Configures `AVAudioSession` and surfaces interruption/route-change events as
/// an `AsyncStream`. Session category is process-global, so the methods are
/// stateless.
struct AudioSessionController: Sendable {
    /// Record + playback, suitable for background recording and Bluetooth.
    func activateForRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.allowBluetoothHFP, .allowBluetoothA2DP, .defaultToSpeaker]
        )
        try session.setActive(true)
    }

    func activateForPlayback() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
    }

    func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    /// Holds observer tokens so they can be removed when the stream ends.
    private final class ObserverBox: @unchecked Sendable {
        var tokens: [NSObjectProtocol] = []
    }

    /// Emits interruption and disconnect events until the stream is cancelled.
    func events() -> AsyncStream<AudioSessionEvent> {
        AsyncStream { continuation in
            let center = NotificationCenter.default
            let box = ObserverBox()

            let interruption = center.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: nil,
                queue: nil
            ) { note in
                guard let info = note.userInfo,
                      let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
                switch type {
                case .began:
                    continuation.yield(.interruptionBegan)
                case .ended:
                    let options = (info[AVAudioSessionInterruptionOptionKey] as? UInt)
                        .map(AVAudioSession.InterruptionOptions.init(rawValue:)) ?? []
                    continuation.yield(.interruptionEnded(shouldResume: options.contains(.shouldResume)))
                @unknown default:
                    break
                }
            }

            let route = center.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: nil,
                queue: nil
            ) { note in
                guard let info = note.userInfo,
                      let raw = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
                      let reason = AVAudioSession.RouteChangeReason(rawValue: raw) else { return }
                if reason == .oldDeviceUnavailable || reason == .newDeviceAvailable {
                    continuation.yield(.routeChanged)
                }
            }

            box.tokens = [interruption, route]
            continuation.onTermination = { _ in
                let center = NotificationCenter.default
                box.tokens.forEach(center.removeObserver)
            }
        }
    }
}
