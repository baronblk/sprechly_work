import SwiftUI

/// Canvas-based waveform. In live mode `progress` is nil; in playback mode
/// `progress` (0...1) draws the cursor and tints the played portion, and an
/// `onScrub` handler enables seeking by drag/tap.
///
/// `markers` are seconds from the start (tap markers of a Soundcore Work
/// import) and need `duration` to be positioned.
struct WaveformView: View {
    let buckets: [WaveformBucket]
    var progress: Double? = nil
    var markers: [TimeInterval] = []
    var duration: TimeInterval = 0
    var onScrub: ((Double) -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                draw(in: &context, size: size)
            }
            .contentShape(Rectangle())
            .gesture(scrubGesture(width: geo.size.width))
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Wellenform"))
        .accessibilityValue(Text(progress.map { String(localized: "\(Int($0 * 100)) Prozent") } ?? String(localized: "Aufnahme")))
        .accessibilityHint(markers.isEmpty ? Text("") : Text("\(markers.count) Markierungen"))
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        guard !buckets.isEmpty else { return }
        let columnWidth = size.width / CGFloat(buckets.count)
        let barWidth = Swift.max(1, columnWidth * 0.6)
        let midY = size.height / 2
        let cursorX = progress.map { CGFloat($0) * size.width }

        for (index, bucket) in buckets.enumerated() {
            let amplitude = CGFloat(Swift.max(abs(bucket.min), abs(bucket.max)))
            let height = Swift.max(barWidth, amplitude * size.height)
            let x = CGFloat(index) * columnWidth + (columnWidth - barWidth) / 2
            let rect = CGRect(x: x, y: midY - height / 2, width: barWidth, height: height)
            let path = Path(roundedRect: rect, cornerRadius: barWidth / 2)

            let played = cursorX.map { x <= $0 } ?? false
            let color = played ? Theme.Colors.accent : Theme.Colors.textSecondary
            context.fill(path, with: .color(color))
        }

        drawMarkers(in: &context, size: size)

        if let cursorX {
            var line = Path()
            line.move(to: CGPoint(x: cursorX, y: 0))
            line.addLine(to: CGPoint(x: cursorX, y: size.height))
            context.stroke(line, with: .color(Theme.Colors.textPrimary), lineWidth: 2)
        }
    }

    /// Tap markers as a short stem with a dot on top, so they read as a
    /// separate layer rather than as part of the waveform.
    private func drawMarkers(in context: inout GraphicsContext, size: CGSize) {
        guard duration > 0, !markers.isEmpty else { return }
        let stemHeight = size.height * 0.28
        let dotSize: CGFloat = 6

        for marker in markers {
            let x = CGFloat(marker / duration) * size.width
            guard x >= 0, x <= size.width else { continue }

            var stem = Path()
            stem.move(to: CGPoint(x: x, y: 0))
            stem.addLine(to: CGPoint(x: x, y: stemHeight))
            context.stroke(stem, with: .color(Theme.Colors.accent.opacity(0.6)), lineWidth: 1.5)

            let dot = CGRect(
                x: x - dotSize / 2, y: 0, width: dotSize, height: dotSize
            )
            context.fill(Path(ellipseIn: dot), with: .color(Theme.Colors.accent))
        }
    }

    private func scrubGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard let onScrub, width > 0 else { return }
                let fraction = Swift.min(1, Swift.max(0, value.location.x / width))
                onScrub(Double(fraction))
            }
    }
}
