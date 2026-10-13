import Foundation

/// An unlockable capability. Decoupled from App Store product ids (see
/// `StoreCatalog`) so a single product — e.g. a future "Pro" bundle — can grant
/// several capabilities at once.
///
/// `.translation` and `.video` are defined for forward-compatibility; today the
/// app ships only `.ai` (transcription, summaries, translation and export are
/// all gated on it). When those features get their own products, add the mapping
/// in `StoreCatalog` and switch the relevant gates.
enum Entitlement: String, CaseIterable, Sendable {
    case ai
    case translation
    case video
}
