import SoundcoreWorkKit
import SwiftUI

/// Kompakte Karte für den Aufnahme-Screen: zeigt den Zustand des Soundcore
/// Work und öffnet beim Antippen die Dateiliste.
///
/// Gesteuert wird die Aufnahme über den zentralen Transport darunter – die
/// Karte hat bewusst keine eigenen Aufnahme-Buttons, sonst gäbe es zwei.
/// Erscheint nur, wenn das Gerät verbunden ist; verbunden wird in den
/// Einstellungen.
struct WorkDeviceCard: View {
    @Environment(WorkDeviceViewModel.self) private var work
    @State private var showRecordings = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            header
            statusRow
            importRow
            if let info = work.deviceInfo { storageRow(info) }
        }
        .padding(Theme.Spacing.md)
        .background(background, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .animation(.easeOut(duration: 0.2), value: work.recentlyImported?.id)
        .onTapGesture { showRecordings = true }
        .sheet(isPresented: $showRecordings) {
            NavigationStack { WorkRecordingsSheet() }
        }
        .accessibilityHint(Text("Öffnet die Aufnahmen auf dem Gerät"))
    }

    private var background: Color {
        work.liveActivity.isRecording ? Theme.Colors.destructive.opacity(0.12) : Theme.Colors.surface
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .foregroundStyle(Theme.Colors.accent)
            Text("Soundcore Work")
                .font(Theme.Font.cardTitle)
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            if let info = work.deviceInfo {
                batteryBadge(percent: info.battery.percent, isCharging: info.isCharging)
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    /// Statuszeile mit der Fernsteuerung. Stop fehlt bewusst – dafür kennt das
    /// Gerät keinen Befehl, das geht nur über die Taste am Work.
    private var statusRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            statusIndicator
            Text(work.liveActivity.label)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            if case .finished = work.liveActivity {
                Text("Importieren")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.accent)
            }
        }
    }

    @ViewBuilder private var statusIndicator: some View {
        switch work.liveActivity {
        case .recording:
            Circle().fill(Theme.Colors.destructive).frame(width: 10, height: 10)
        case .paused:
            Image(systemName: "pause.circle.fill").foregroundStyle(Theme.Colors.accent)
        case .finished:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.Colors.success)
        case .idle:
            Circle().fill(Theme.Colors.textSecondary).frame(width: 8, height: 8)
        }
    }

    /// Zeigt, was der automatische Import gerade tut. Ohne das liefe er
    /// unsichtbar, denn die Dateiliste ist dabei normalerweise zu.
    @ViewBuilder private var importRow: some View {
        if let laufend = work.activeImport {
            HStack(spacing: Theme.Spacing.sm) {
                ProgressView().controlSize(.small)
                VStack(alignment: .leading, spacing: 2) {
                    Text(importLabel(for: laufend.importState))
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    if case .downloading(let fortschritt) = laufend.importState {
                        ProgressView(value: fortschritt)
                            .tint(Theme.Colors.accent)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(importLabel(for: laufend.importState)))
        } else if let fertig = work.recentlyImported {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.Colors.success)
                Text("\(TimeFormatting.timecode(fertig.recording.duration)) in der Bibliothek")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .transition(.opacity)
        } else if let gescheitert = work.failedImport,
                  case .failed(let grund) = gescheitert.importState {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.Colors.destructive)
                Text(grund)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.destructive)
                    .lineLimit(2)
            }
        }
    }

    private func importLabel(for state: WorkRecordingItem.ImportState) -> String {
        switch state {
        case .downloading(let fortschritt):
            String(localized: "Hole Aufnahme … \(Int(fortschritt * 100)) %")
        case .converting:
            String(localized: "Wandle um …")
        default:
            String(localized: "Importiere …")
        }
    }

    private func storageRow(_ info: D3200DeviceInfo) -> some View {
        let used = ByteCountFormatter.string(fromByteCount: info.usedStorageBytes, countStyle: .file)
        let total = ByteCountFormatter.string(fromByteCount: info.totalStorageBytes, countStyle: .file)
        return HStack {
            Text("\(used) von \(total)")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            if info.caseBattery.percent > 0 {
                Label {
                    Text("\(info.caseBattery.percent) %")
                } icon: {
                    Image(systemName: "case.fill")
                }
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .accessibilityLabel(Text("Ladecase \(info.caseBattery.percent) Prozent"))
            }
        }
    }

    private func batteryBadge(percent: Int, isCharging: Bool) -> some View {
        HStack(spacing: 2) {
            Image(systemName: isCharging ? "battery.100.bolt" : batterySymbol(percent))
                .foregroundStyle(percent <= 20 ? Theme.Colors.destructive : Theme.Colors.success)
            Text("\(percent) %")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textPrimary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(isCharging ? "Akku \(percent) Prozent, lädt" : "Akku \(percent) Prozent"))
    }

    private func batterySymbol(_ percent: Int) -> String {
        switch percent {
        case ..<13: "battery.0percent"
        case ..<38: "battery.25percent"
        case ..<63: "battery.50percent"
        case ..<88: "battery.75percent"
        default: "battery.100percent"
        }
    }
}
