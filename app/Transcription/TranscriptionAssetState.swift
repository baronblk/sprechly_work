import Speech

/// The full state space of a language model's on-device assets — explicit, not a
/// Bool. The asset download (hundreds of MB) is its own state machine: every
/// state needs defined UI/error behavior, including a mid-download failure and a
/// full disk (see docs/DECISIONS.md).
enum TranscriptionAssetState: Equatable, Sendable {
    case unsupported
    case notInstalled
    case downloading(progress: Double)
    case installed
    case failed(message: String)
    case insufficientStorage

    var isReady: Bool { self == .installed }

    /// Maps the system inventory status to a starting state.
    static func from(_ status: AssetInventory.Status) -> TranscriptionAssetState {
        switch status {
        case .unsupported: return .unsupported
        case .supported: return .notInstalled
        case .downloading: return .downloading(progress: 0)
        case .installed: return .installed
        @unknown default: return .unsupported
        }
    }
}
