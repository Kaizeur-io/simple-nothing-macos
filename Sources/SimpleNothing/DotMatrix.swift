import SwiftUI

/// Dessins en matrice de points, faits maison : ils remplacent les images et la police à points de
/// Nothing quand celles-ci ne sont pas fournies (voir « Ce qui reste hors du dépôt » dans le README).
struct DotMatrix: Shape {
    /// Lignes de même longueur ; tout caractère autre que « . » est un point.
    let rows: [String]
    /// Part du pas occupée par un point.
    var fill = 0.76

    func path(in rect: CGRect) -> Path {
        let columns = rows.map(\.count).max() ?? 1
        let step = min(rect.width / Double(columns), rect.height / Double(rows.count))
        let origin = CGPoint(x: rect.midX - step * Double(columns) / 2, y: rect.midY - step * Double(rows.count) / 2)
        var path = Path()
        for (row, line) in rows.enumerated() {
            for (column, mark) in line.enumerated() where mark != "." {
                let inset = step * (1 - fill) / 2
                path.addEllipse(in: CGRect(x: origin.x + step * Double(column) + inset, y: origin.y + step * Double(row) + inset,
                                           width: step * fill, height: step * fill))
            }
        }
        return path
    }

    static let headphones = ["...#####...", "..#.....#..", ".#.......#.", ".#.......#.", ".#.......#.", "##.......##", "###.....###", "###.....###", "###.....###", ".##.....##."]
    static let earbuds = [".##.....##.", "####...####", "####...####", ".###...###.", "..##...##..", "..##...##..", "..##...##..", "..#.....#.."]

    private static let digits: [Character: [String]] = [
        "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
        "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
        "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
        "3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
        "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
        "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
        "6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
        "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
        "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
        "9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
    ]

    /// Un nombre, chiffre après chiffre, séparés d'une colonne vide.
    static func number(_ value: Int) -> DotMatrix {
        let glyphs = String(value).compactMap { digits[$0] }
        return DotMatrix(rows: (0..<7).map { row in glyphs.map { $0[row] }.joined(separator: ".") }, fill: 0.86)
    }
}

/// Grand nombre à points : la police de Nothing si elle est là, sinon notre propre matrice.
struct DotNumber: View {
    let value: Int
    let size: CGFloat

    var body: some View {
        if Typeface.dot != nil {
            Text("\(value)").font(.nDot(size))
        } else {
            let shape = DotMatrix.number(value)
            shape.frame(width: size * 0.72 * Double(shape.rows[0].count) / 7, height: size * 0.72)
        }
    }
}

/// L'appareil dessiné en points, quand on n'a pas sa photo.
struct DeviceGlyph: View {
    let isHeadphones: Bool

    var body: some View {
        DotMatrix(rows: isHeadphones ? DotMatrix.headphones : DotMatrix.earbuds).fill(Color.nText)
            .overlay {
                // Le point rouge de l'icône de l'app.
                if isHeadphones { DotMatrix(rows: (0..<10).map { $0 == 6 ? ".....#....." : "..........." }).fill(Color.nRed) }
            }
            .aspectRatio(isHeadphones ? 1.1 : 1.375, contentMode: .fit)
            .accessibilityHidden(true)
    }
}
