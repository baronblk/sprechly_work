import SwiftUI

/// Waveform with two draggable trim handles. The trimmed-out regions are dimmed
/// and the selection is outlined. Handle math uses the pure `TrimGeometry` /
/// `TrimBounds`, so positions map exactly to time.
struct TrimmableWaveformView: View {
    let buckets: [WaveformBucket]
    let duration: TimeInterval
    @Binding var start: TimeInterval
    @Binding var end: TimeInterval

    private let handleWidth: CGFloat = 16
    private let space = "trim"

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let startX = TrimGeometry.x(forTime: start, width: width, duration: duration)
            let endX = TrimGeometry.x(forTime: end, width: width, duration: duration)

            ZStack(alignment: .topLeading) {
                WaveformView(buckets: buckets)

                Theme.Colors.background.opacity(0.6).frame(width: startX)
                Theme.Colors.background.opacity(0.6)
                    .frame(width: max(0, width - endX))
                    .offset(x: endX)

                Rectangle()
                    .stroke(Theme.Colors.accent, lineWidth: 2)
                    .frame(width: max(0, endX - startX), height: height)
                    .offset(x: startX)

                handle(centerX: startX, height: height, label: String(localized: "Anfang")) { time in
                    start = max(0, min(time, end - TrimBounds.minimumLength))
                }
                handle(centerX: endX, height: height, label: String(localized: "Ende")) { time in
                    end = min(duration, max(time, start + TrimBounds.minimumLength))
                }
            }
            .coordinateSpace(name: space)
        }
    }

    private func handle(
        centerX: CGFloat,
        height: CGFloat,
        label: String,
        onMove: @escaping (TimeInterval) -> Void
    ) -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            RoundedRectangle(cornerRadius: 5)
                .fill(Theme.Colors.accent)
                .frame(width: handleWidth, height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Theme.Colors.textPrimary)
                        .frame(width: 2, height: height * 0.4)
                )
                .position(x: centerX, y: height / 2)
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named(space))
                        .onChanged { value in
                            onMove(TrimGeometry.time(forX: value.location.x, width: width, duration: duration))
                        }
                )
                .accessibilityLabel(Text("\(label)-Markierung"))
        }
    }
}
