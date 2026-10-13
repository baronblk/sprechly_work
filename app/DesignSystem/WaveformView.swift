import SwiftUI

/// Canvas-based waveform. In live mode `progress` is nil; in playback mode
/// `progress` (0...1) draws the cursor and tints the played portion, and an
/// `onScrub` handler enables seeking by drag/tap.
struct WaveformView: View {
    let buckets: [WaveformBucket]
    var progress: Double? = nil
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

        if let cursorX {
            var line = Path()
            line.move(to: CGPoint(x: cursorX, y: 0))
            line.addLine(to: CGPoint(x: cursorX, y: size.height))
            context.stroke(line, with: .color(Theme.Colors.textPrimary), lineWidth: 2)
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
