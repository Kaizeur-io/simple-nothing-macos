// Dessine l'icône de l'application : un casque en matrice de points, sans aucun élément de marque.
//
//   swiftc tools/make-icon.swift -o .build/make-icon && .build/make-icon .build/icone.png
//
// tools/app.sh s'en charge. Pour une autre icône, placez un PNG carré dans originaux/icone.png.

import AppKit

let pattern = [
    "...#####...",
    "..#.....#..",
    ".#.......#.",
    ".#.......#.",
    ".#.......#.",
    "##.......##",
    "###..o..###",
    "###.....###",
    "###.....###",
    ".##.....##.",
]

let size = 1024.0
let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { _ in
    // Gabarit des icônes macOS : un carré arrondi de 824 points, centré.
    let plate = NSRect(x: 100, y: 100, width: 824, height: 824)
    NSColor(srgbRed: 0.07, green: 0.07, blue: 0.07, alpha: 1).setFill()
    NSBezierPath(roundedRect: plate, xRadius: 186, yRadius: 186).fill()

    let step = 46.0, dot = 34.0
    let left = (size - step * Double(pattern[0].count - 1)) / 2
    let top = (size - step * Double(pattern.count - 1)) / 2
    for (row, line) in pattern.enumerated() {
        for (column, mark) in line.enumerated() where mark != "." {
            (mark == "o" ? NSColor(srgbRed: 0.84, green: 0.1, blue: 0.13, alpha: 1) : NSColor.white).setFill()
            NSBezierPath(ovalIn: NSRect(x: left + step * Double(column) - dot / 2, y: top + step * Double(row) - dot / 2, width: dot, height: dot)).fill()
        }
    }
    return true
}

guard let output = CommandLine.arguments.dropFirst().first,
      let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8, samplesPerPixel: 4,
                                    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
      let context = NSGraphicsContext(bitmapImageRep: bitmap) else { exit(1) }
NSGraphicsContext.current = context
image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
context.flushGraphics()
try bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: output))
