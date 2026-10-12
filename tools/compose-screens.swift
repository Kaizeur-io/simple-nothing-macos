// Compose les visuels de présentation à partir des captures de l'app : fenêtre, panneau de la
// barre des menus et cartes posés sur un fond uni à trame de points.
//
//   .build/compose-screens <dossier des captures> <dossier de sortie>
//
// Lancé par tools/make-screens.sh, qui prend d'abord les captures.

import AppKit

let arguments = CommandLine.arguments
guard arguments.count >= 3 else { print("usage : compose-screens <captures> <sortie>"); exit(1) }
let captures = URL(fileURLWithPath: arguments[1]), output = URL(fileURLWithPath: arguments[2])

func load(_ name: String) -> CGImage {
    guard let image = NSImage(contentsOf: captures.appendingPathComponent(name + ".png"))?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("capture manquante : \(name).png")
        exit(1)
    }
    return image
}

/// Une carte flottante sans la marge transparente de sa capture (36 points, soit 72 pixels).
func loadCard(_ name: String) -> CGImage {
    let image = load(name)
    return image.cropping(to: CGRect(x: 72, y: 72, width: image.width - 144, height: image.height - 144)) ?? image
}

func colour(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// Une image en construction. L'origine est en haut à gauche, les mesures en pixels.
final class Canvas {
    let context: CGContext
    let width: CGFloat, height: CGFloat

    /// `ink` : fond noir pour mettre en valeur l'interface claire ; sinon fond papier pour l'interface sombre.
    init(width: Int, height: Int, ink: Bool) {
        (self.width, self.height) = (CGFloat(width), CGFloat(height))
        context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.translateBy(x: 0, y: self.height)
        context.scaleBy(x: 1, y: -1)
        context.setFillColor(colour(ink ? 0x0D0D0D : 0xE9E9E6))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        // Trame de points, clin d'œil à la matrice de l'app.
        context.setFillColor(colour(ink ? 0x242424 : 0xD3D3CF))
        let step: CGFloat = 36
        for row in 0...Int(self.height / step) {
            for column in 0...Int(self.width / step) {
                context.fillEllipse(in: CGRect(x: CGFloat(column) * step + 16, y: CGFloat(row) * step + 16, width: 5, height: 5))
            }
        }
    }

    private func draw(_ image: CGImage, in rect: CGRect) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
    }

    private func shadow(_ scale: CGFloat) {
        context.setShadow(offset: CGSize(width: 0, height: -44 * scale), blur: 110 * scale, color: colour(0x000000, 0.42))
    }

    /// La fenêtre de l'app : coins arrondis, ombre portée, boutons de fenêtre redessinés pour qu'ils
    /// soient les mêmes sur toutes les captures.
    func window(_ image: CGImage, x: CGFloat, y: CGFloat, scale: CGFloat = 1, dark: Bool) {
        let rect = CGRect(x: x, y: y, width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
        let shape = CGPath(roundedRect: rect, cornerWidth: 34 * scale, cornerHeight: 34 * scale, transform: nil)
        context.saveGState()
        shadow(scale)
        context.addPath(shape)
        context.setFillColor(colour(dark ? 0x000000 : 0xF0F0F0))
        context.fillPath()
        context.restoreGState()
        context.saveGState()
        context.addPath(shape)
        context.clip()
        draw(image, in: rect)
        for (index, hex) in [0xFF5F57, 0xFEBC2E, dark ? 0x4A4A4A : 0xD4D4D4].enumerated() {
            context.setFillColor(colour(UInt32(hex)))
            context.fillEllipse(in: CGRect(x: x + (15 + CGFloat(index) * 40) * scale, y: y + 15 * scale, width: 26 * scale, height: 26 * scale))
        }
        context.restoreGState()
        context.addPath(shape)
        context.setStrokeColor(colour(dark ? 0xFFFFFF : 0x000000, dark ? 0.16 : 0.10))
        context.setLineWidth(2)
        context.strokePath()
    }

    /// Le panneau de la barre des menus : la capture a déjà ses coins, on lui ajoute son ombre.
    func panel(_ image: CGImage, x: CGFloat, y: CGFloat, scale: CGFloat = 1) {
        context.saveGState()
        shadow(scale * 0.8)
        draw(image, in: CGRect(x: x, y: y, width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale))
        context.restoreGState()
    }

    /// Les cartes flottantes. Leur capture garde une marge pour l'ombre, coupée net au bord : on ne
    /// garde que la carte et on refait l'ombre.
    func card(_ image: CGImage, x: CGFloat, y: CGFloat, radius: CGFloat) {
        let rect = CGRect(x: x, y: y, width: CGFloat(image.width), height: CGFloat(image.height))
        let shape = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        context.saveGState()
        shadow(0.6)
        context.addPath(shape)
        context.setFillColor(colour(0x000000))
        context.fillPath()
        context.restoreGState()
        context.saveGState()
        context.addPath(shape)
        context.clip()
        draw(image, in: rect)
        context.restoreGState()
    }

    func text(_ string: String, x: CGFloat, y: CGFloat, font: NSFont, hex: UInt32, tracking: CGFloat = 0) {
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: NSColor(cgColor: colour(hex))!, .kern: tracking]).draw(at: CGPoint(x: x, y: y))
        NSGraphicsContext.current = previous
    }

    func save(_ name: String) {
        guard let image = context.makeImage(), let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { exit(1) }
        try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try? data.write(to: output.appendingPathComponent(name + ".png"))
        print("  \(name).png  \(image.width) × \(image.height)")
    }
}

// MARK: Pour le dépôt

// 1. L'essentiel : la fenêtre et le panneau de la barre des menus.
do {
    let canvas = Canvas(width: 2880, height: 1800, ink: false)
    canvas.window(load("en-listen-dark"), x: 220, y: 280, dark: true)
    let menu = load("en-menu-dark")
    canvas.panel(menu, x: 2880 - 220 - CGFloat(menu.width), y: (1800 - CGFloat(menu.height)) / 2 + 30)
    canvas.save("presentation")
}

// 2. Clair et sombre, côte à côte.
do {
    let canvas = Canvas(width: 2880, height: 1280, ink: true)
    canvas.context.setFillColor(colour(0xE9E9E6))
    canvas.context.fill(CGRect(x: 1440, y: 0, width: 1440, height: 1280))
    canvas.context.setFillColor(colour(0xD3D3CF))
    for row in 0...35 { for column in 40...80 { canvas.context.fillEllipse(in: CGRect(x: CGFloat(column) * 36 + 16, y: CGFloat(row) * 36 + 16, width: 5, height: 5)) } }
    let scale: CGFloat = 0.68, width = 1840 * scale, height = 1240 * scale
    canvas.window(load("en-listen-light"), x: (1440 - width) / 2, y: (1280 - height) / 2, scale: scale, dark: false)
    canvas.window(load("en-listen-dark"), x: 1440 + (1440 - width) / 2, y: (1280 - height) / 2, scale: scale, dark: true)
    canvas.save("presentation-clair-sombre")
}

// 3. Les autres onglets.
do {
    let canvas = Canvas(width: 2880, height: 2000, ink: true)
    let scale: CGFloat = 0.7, width = 1840 * scale, height = 1240 * scale
    let gapX = (2880 - 2 * width) / 3, gapY = (2000 - 2 * height) / 3
    for (index, name) in ["en-controls-light", "en-link-light", "en-device-light", "en-app-light"].enumerated() {
        canvas.window(load(name), x: gapX + CGFloat(index % 2) * (width + gapX), y: gapY + CGFloat(index / 2) * (height + gapY), scale: scale, dark: false)
    }
    canvas.save("presentation-onglets")
}

// 4. Hors de la fenêtre : carte de connexion, panneau, confirmations.
do {
    let canvas = Canvas(width: 2880, height: 1400, ink: false)
    let hud = loadCard("en-hud-dark"), menu = load("en-menu-dark"), toast = loadCard("en-toast-dark"), battery = loadCard("en-battery-dark")
    let gap: CGFloat = 200, total = CGFloat(hud.width + menu.width + toast.width) + 2 * gap
    var x = (2880 - total) / 2
    canvas.card(hud, x: x, y: (1400 - CGFloat(hud.height)) / 2, radius: 52)
    x += CGFloat(hud.width) + gap
    canvas.panel(menu, x: x, y: (1400 - CGFloat(menu.height)) / 2)
    x += CGFloat(menu.width) + gap
    let space: CGFloat = 56, stack = CGFloat(toast.height + battery.height) + space
    canvas.card(toast, x: x, y: (1400 - stack) / 2, radius: 44)
    canvas.card(battery, x: x, y: (1400 - stack) / 2 + CGFloat(toast.height) + space, radius: 44)
    canvas.save("presentation-barre-des-menus")
}

// MARK: Pour les réseaux

// Format 16:9 : une phrase, puis la fenêtre et le panneau, centrés.
do {
    let language = "en", tagline = "Your Nothing and CMF headphones, finally on the Mac."
    let canvas = Canvas(width: 2400, height: 1350, ink: false)
    let window = load("\(language)-listen-dark"), menu = load("\(language)-menu-dark")
    let windowScale: CGFloat = 0.8, menuScale: CGFloat = 0.84, overlap: CGFloat = 22
    let left = (2400 - (CGFloat(window.width) * windowScale + CGFloat(menu.width) * menuScale - overlap)) / 2, top: CGFloat = 300
    canvas.text("Simple Nothing", x: left - 4, y: 64, font: .systemFont(ofSize: 80, weight: .semibold), hex: 0x111111, tracking: -1.5)
    canvas.text(tagline, x: left, y: 172, font: .systemFont(ofSize: 34, weight: .regular), hex: 0x5C5C58)
    let label = "FREE AND OPEN SOURCE  ·  MACOS 14+  ·  UNOFFICIAL"
    let mono = NSFont.monospacedSystemFont(ofSize: 20, weight: .regular)
    let labelWidth = NSAttributedString(string: label, attributes: [.font: mono, .kern: 3.2]).size().width
    canvas.text(label, x: 2400 - left - labelWidth, y: 122, font: mono, hex: 0x5C5C58, tracking: 3.2)
    canvas.window(window, x: left, y: top, scale: windowScale, dark: true)
    canvas.panel(menu, x: left + CGFloat(window.width) * windowScale - overlap,
                 y: top + (CGFloat(window.height) * windowScale - CGFloat(menu.height) * menuScale) / 2, scale: menuScale)
    canvas.save("x")
}
