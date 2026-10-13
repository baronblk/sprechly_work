import SwiftUI

/// Einstellungen rund um den Soundcore Work.
enum WorkSettings {
    /// Ob sich die App beim Öffnen selbst verbindet.
    static let autoConnectKey = "workAutoConnect"
}

/// Abschnitt „Soundcore Work" in den Einstellungen: hier wird verbunden.
///
/// Der Aufnahme-Screen zeigt danach eine Karte mit Zustand und Fernsteuerung.
struct WorkSettingsSection: View {
    @Environment(WorkDeviceViewModel.self) private var work
    @AppStorage(WorkSettings.autoConnectKey) private var autoConnect = false

    var body: some View {
        Section {
            HStack(spacing: Theme.Spacing.sm) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(work.connection.label)
                Spacer()
                if work.connection.isBusy { ProgressView().controlSize(.small) }
            }
            .accessibilityElement(children: .combine)

            if case .failed(let reason) = work.connection {
                Text(reason)
                    .font(.footnote)
                    .foregroundStyle(Theme.Colors.destructive)
            }

            if work.isReady {
                if let info = work.deviceInfo {
                    LabeledContent("Akku") {
                        Text(info.isCharging ? "\(info.battery.percent) % · lädt" : "\(info.battery.percent) %")
                    }
                    LabeledContent("Firmware") { Text(info.firmwareVersion) }
                    LabeledContent("Seriennummer") { Text(info.serialNumber) }
                }
                Button(role: .destructive) {
                    Task { await work.disconnect() }
                } label: {
                    Text("Trennen")
                }
            } else {
                Button {
                    Task { await work.connect() }
                } label: {
                    Text("Mit Work verbinden")
                }
                .disabled(work.connection.isBusy)
            }

            Toggle(isOn: $autoConnect) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Beim Öffnen verbinden")
                    Text("Versucht es still; findet die App den Work nicht, passiert nichts.")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        } header: {
            Text("Soundcore Work")
        } footer: {
            Text("Der Work erlaubt nur eine Bluetooth-Verbindung. Trenne ihn vorher vom Handy, sonst wird er nicht gefunden. Nach dem Verbinden erscheint er im Aufnahme-Screen.")
        }
    }

    private var statusColor: Color {
        switch work.connection {
        case .ready: Theme.Colors.success
        case .connecting: Theme.Colors.accent
        case .failed: Theme.Colors.destructive
        case .disconnected: Theme.Colors.textSecondary
        }
    }
}
