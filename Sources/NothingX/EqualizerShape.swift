import NothingKit
import SwiftUI

/// Les trois lobes de l'égaliseur de Nothing : médiums en haut, graves à gauche, aigus à droite.
struct EqualizerShape: View {
    let preset: Preset

    private static let axes: [(x: Double, y: Double, label: String)] = [(0, -1, "Médiums"), (-0.866, 0.5, "Graves"), (0.866, 0.5, "Aigus")]

    var body: some View {
        let values = [preset.shape.mid, preset.shape.bass, preset.shape.treble]
        Canvas { context, size in
            let unit = size.width / 320
            let centre = CGPoint(x: 160 * unit, y: 170 * unit)
            func circle(_ at: CGPoint, _ radius: Double) -> Path {
                Path(ellipseIn: CGRect(x: at.x - radius * unit, y: at.y - radius * unit, width: radius * 2 * unit, height: radius * 2 * unit))
            }
            func point(_ axis: Int, _ distance: Double) -> CGPoint {
                CGPoint(x: centre.x + Self.axes[axis].x * distance * unit, y: centre.y + Self.axes[axis].y * distance * unit)
            }

            context.fill(circle(CGPoint(x: 160 * unit, y: 160 * unit), 156), with: .color(.nWell))

            // Les lobes fusionnent : flou puis seuil sur l'opacité.
            var blob = context
            blob.addFilter(.shadow(color: .black.opacity(0.18), radius: 5 * unit, y: 2 * unit))
            blob.addFilter(.alphaThreshold(min: 0.5, color: .nBlob))
            blob.addFilter(.blur(radius: 9 * unit))
            blob.drawLayer { layer in
                layer.fill(circle(centre, 46), with: .color(.white))
                for axis in 0..<3 { layer.fill(circle(point(axis, 42 + values[axis] * 6), 36), with: .color(.white)) }
            }

            for axis in 0..<3 {
                for distance in [38.0, 74, 110] { context.fill(circle(point(axis, distance), 2.2), with: .color(.nMuted.opacity(0.45))) }
                context.fill(circle(point(axis, 42 + values[axis] * 6 + 34), 5), with: .color(.nText))
            }
            context.fill(circle(centre, 9), with: .color(.nRed))

            let labels: [(at: CGPoint, turn: Double)] = [(CGPoint(x: 160, y: 26), 0), (CGPoint(x: 44, y: 236), 60), (CGPoint(x: 276, y: 236), -60)]
            for axis in 0..<3 {
                var turned = context
                turned.translateBy(x: labels[axis].at.x * unit, y: labels[axis].at.y * unit)
                turned.rotate(by: .degrees(labels[axis].turn))
                turned.draw(Text(Self.axes[axis].label.uppercased()).font(.nMono(8 * unit)).tracking(1.2 * unit).foregroundStyle(Color.nMuted), at: .zero)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .animation(.easeInOut(duration: 0.35), value: preset)
        .accessibilityLabel("Courbe d'égalisation : \(preset.label)")
    }
}
