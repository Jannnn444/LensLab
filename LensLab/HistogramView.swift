import SwiftUI
import UIKit

// MARK: - Histogram View
struct HistogramView: View {
    let image: UIImage?

    @State private var rChannel: [Int] = Array(repeating: 0, count: 256)
    @State private var gChannel: [Int] = Array(repeating: 0, count: 256)
    @State private var bChannel: [Int] = Array(repeating: 0, count: 256)

    var body: some View {
        Canvas { ctx, size in
            let maxVal = max(rChannel.max() ?? 1,
                            gChannel.max() ?? 1,
                            bChannel.max() ?? 1, 1)

            drawChannel(ctx: ctx, size: size, data: rChannel,
                        maxVal: maxVal, color: Color.red.opacity(0.5))
            drawChannel(ctx: ctx, size: size, data: gChannel,
                        maxVal: maxVal, color: Color.green.opacity(0.4))
            drawChannel(ctx: ctx, size: size, data: bChannel,
                        maxVal: maxVal, color: Color.blue.opacity(0.45))
        }
        .background(Color(hex: "#EDE5CF"))
        .cornerRadius(6)
        .task(id: image) { await computeHistogram() }
    }

    func drawChannel(ctx: GraphicsContext, size: CGSize,
                     data: [Int], maxVal: Int, color: Color) {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height))
        for (i, v) in data.enumerated() {
            let x = CGFloat(i) / 255 * size.width
            let y = size.height - CGFloat(v) / CGFloat(maxVal) * size.height
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.closeSubpath()
        ctx.fill(path, with: .color(color))
    }

    func computeHistogram() async {
        guard let img = image,
              let cgImg = img.cgImage else { return }

        let w = cgImg.width, h = cgImg.height
        guard let data = cgImg.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else { return }

        var r = Array(repeating: 0, count: 256)
        var g = Array(repeating: 0, count: 256)
        var b = Array(repeating: 0, count: 256)
        let bpp = cgImg.bitsPerPixel / 8

        for y in stride(from: 0, to: h, by: 4) {
            for x in stride(from: 0, to: w, by: 4) {
                let idx = (y * w + x) * bpp
                r[Int(ptr[idx])] += 1
                g[Int(ptr[idx+1])] += 1
                b[Int(ptr[idx+2])] += 1
            }
        }

        // Capture as immutable constants so Swift concurrency
        // doesn't complain about var capture across actor boundaries
        let finalR = r
        let finalG = g
        let finalB = b
        await MainActor.run {
            rChannel = finalR
            gChannel = finalG
            bChannel = finalB
        }
    }
}

// MARK: - Color Grading Wheel
struct ColorGradingWheel: View {
    let label: String
    @State private var dotOffset: CGSize = .zero

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Conic hue wheel
                Circle()
                    .fill(AngularGradient(
                        colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                        center: .center
                    ))
                // White center fade
                Circle()
                    .fill(RadialGradient(
                        colors: [.white, .white.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 28
                    ))
                Circle()
                    .strokeBorder(Theme.border, lineWidth: 1)

                // Dot
                Circle()
                    .fill(Color.white)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.3), lineWidth: 1))
                    .offset(dotOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { v in
                                let radius: CGFloat = 22
                                let dx = v.translation.width
                                let dy = v.translation.height
                                let dist = sqrt(dx*dx + dy*dy)
                                if dist <= radius {
                                    dotOffset = v.translation
                                } else {
                                    let angle = atan2(dy, dx)
                                    dotOffset = CGSize(
                                        width: cos(angle) * radius,
                                        height: sin(angle) * radius
                                    )
                                }
                            }
                    )
            }
            .frame(width: 56, height: 56)
            .shadow(color: Theme.accentDark.opacity(0.12), radius: 4, x: 0, y: 2)

            Text(label.uppercased())
                .font(.monoTiny)
                .kerning(0.8)
                .foregroundColor(Theme.muted)
        }
    }
}

// MARK: - Color Grading Panel
struct ColorGradingPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("COLOR GRADING")
                .font(.monoSmall)
                .kerning(1.2)
                .foregroundColor(Theme.muted)

            HStack(spacing: 0) {
                ColorGradingWheel(label: "Shadows")
                Spacer()
                ColorGradingWheel(label: "Midtones")
                Spacer()
                ColorGradingWheel(label: "Highlights")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
