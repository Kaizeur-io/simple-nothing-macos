import NothingKit
import SwiftUI

/// Les trois lobes de l'égaliseur de Nothing : médiums en haut, graves à gauche, aigus à droite.
/// Avec `edit`, les trois points se déplacent à la souris le long de leur axe.
struct EqualizerShape: View, Animatable {
    var mid: Double
    var bass: Double
    var treble: Double
    var name = ""
    /// Appelé pendant le glissement, puis une dernière fois avec `true` quand on relâche.
    var edit: ((CustomEQ, Bool) -> Void)?

    @State private var grabbed: Int?

    init(_ curve: CustomEQ, name: String = "", edit: ((CustomEQ, Bool) -> Void)? = nil) {
        (mid, bass, treble, self.name, self.edit) = (curve.mid, curve.bass, curve.treble, name, edit)
    }

    var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { AnimatablePair(mid, AnimatablePair(bass, treble)) }
        set { (mid, bass, treble) = (newValue.first, newValue.second.first, newValue.second.second) }
    }

    private static let axes: [(x: Double, y: Double, label: String)] = [(0, -1, "Médiums"), (-0.866, 0.5, "Graves"), (0.866, 0.5, "Aigus")]
    private static let centre = CGPoint(x: 160, y: 170)
    /// Distance du point de réglage au centre, dans le repère de 320 unités du dessin.
    private static func reach(_ value: Double) -> Double { 76 + value * 6 }

    var body: some View {
        let values = [mid, bass, treble]
        GeometryReader { geometry in
            let unit = geometry.size.width / 320
            Canvas { context, _ in
                func circle(_ at: CGPoint, _ radius: Double) -> Path {
                    Path(ellipseIn: CGRect(x: (at.x - radius) * unit, y: (at.y - radius) * unit, width: radius * 2 * unit, height: radius * 2 * unit))
                }
                func point(_ axis: Int, _ distance: Double) -> CGPoint {
                    CGPoint(x: Self.centre.x + Self.axes[axis].x * distance, y: Self.centre.y + Self.axes[axis].y * distance)
                }

                context.fill(circle(CGPoint(x: 160, y: 160), 156), with: .color(.nWell))

                // Les lobes fusionnent : flou puis seuil sur l'opacité.
                var blob = context
                blob.addFilter(.shadow(color: .black.opacity(0.18), radius: 5 * unit, y: 2 * unit))
                blob.addFilter(.alphaThreshold(min: 0.5, color: .nBlob))
                blob.addFilter(.blur(radius: 9 * unit))
                blob.drawLayer { layer in
                    layer.fill(circle(Self.centre, 46), with: .color(.white))
                    for axis in 0..<3 { layer.fill(circle(point(axis, Self.reach(values[axis]) - 34), 36), with: .color(.white)) }
                }

                for axis in 0..<3 {
                    for distance in [38.0, 74, 110] { context.fill(circle(point(axis, distance), 2.2), with: .color(.nMuted.opacity(0.45))) }
                    context.fill(circle(point(axis, Self.reach(values[axis])), edit == nil ? 5 : grabbed == axis ? 9 : 7), with: .color(.nText))
                }
                context.fill(circle(Self.centre, 9), with: .color(.nRed))

                let labels: [(at: CGPoint, turn: Double)] = [(CGPoint(x: 160, y: 26), 0), (CGPoint(x: 44, y: 236), 60), (CGPoint(x: 276, y: 236), -60)]
                for axis in 0..<3 {
                    var turned = context
                    turned.translateBy(x: labels[axis].at.x * unit, y: labels[axis].at.y * unit)
                    turned.rotate(by: .degrees(labels[axis].turn))
                    let value = edit == nil ? "" : String(format: " %+.0f", values[axis])
                    turned.draw(Text(tr(Self.axes[axis].label).uppercased() + value).font(.nMono(8 * unit)).tracking(1.2 * unit).foregroundStyle(Color.nMuted), at: .zero)
                }
            }
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in move(drag, unit: unit, done: false) }.onEnded { drag in move(drag, unit: unit, done: true) },
                     including: edit == nil ? .none : .all)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel(tr("Courbe d'égalisation : %@", tr(name)))
    }

    private func move(_ drag: DragGesture.Value, unit: Double, done: Bool) {
        var values = [mid, bass, treble]
        func offset(_ location: CGPoint) -> CGPoint { CGPoint(x: location.x / unit - Self.centre.x, y: location.y / unit - Self.centre.y) }
        if grabbed == nil {
            // On saisit le point le plus proche de l'endroit où le glissement a commencé.
            let start = offset(drag.startLocation)
            let nearest = (0..<3).map { axis -> (Int, Double) in
                let reach = Self.reach(values[axis])
                return (axis, hypot(start.x - Self.axes[axis].x * reach, start.y - Self.axes[axis].y * reach))
            }.min { $0.1 < $1.1 }!
            guard nearest.1 < 40 else { return }
            grabbed = nearest.0
        }
        guard let axis = grabbed else { return }
        let here = offset(drag.location)
        let along = here.x * Self.axes[axis].x + here.y * Self.axes[axis].y
        values[axis] = min(max(((along - 76) / 6).rounded(), CustomEQ.range.lowerBound), CustomEQ.range.upperBound)
        if done { grabbed = nil }
        edit?(CustomEQ(mid: values[0], bass: values[1], treble: values[2]), done)
    }
}
