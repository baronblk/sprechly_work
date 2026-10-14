import Foundation

/// App-weite Schalter, die in den Einstellungen umgelegt werden.
enum AppSettings {
    /// Verhindert den Bildschirm-Timeout, solange Sprechly im Vordergrund ist.
    ///
    /// Gilt bewusst nur für die aktive App: Im Hintergrund oder nach dem
    /// Schließen gibt die App den Timeout wieder frei, sonst bliebe das
    /// Display auch dann wach, wenn Sprechly gar nicht benutzt wird.
    static let keepScreenAwakeKey = "keepScreenAwake"
}
