// Fabrique les visuels produit de la maquette à partir des sources locales :
//   - les captures de l'app mobile (sources/captures/267xx.jpg), recadrées puis détourées ;
//   - les images récupérées sur le site Nothing (sources/site/ ; PNG déjà transparents : rognés et réduits ;
//     photos studio sur fond uni : détourées).
// Ces sources ne sont pas dans le dépôt : chacun fournit les siennes.
// À lancer depuis la racine du projet :  swiftc -O tools/build-assets.swift -o .build/build-assets && .build/build-assets
//
// Détourage : le masque de sujet de Vision est juste mais flou (une rampe d'une vingtaine de pixels),
// ce qui laisse un halo de la couleur du fond. On le durcit, et quand le fond est uni on s'appuie
// sur l'écart de couleur avec le fond pour retrouver le bord exact et retirer le fond des pixels mixtes.

import AppKit
import CoreImage
import UniformTypeIdentifiers
import Vision

let root = FileManager.default.currentDirectoryPath
let capturesDir = "\(root)/sources/captures"
let siteDir = "\(root)/sources/site"
let outDir = "\(root)/maquette/assets"
let maxSide: CGFloat = 1000
let fm = FileManager.default
let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

// ---------- Outils image ----------
func load(_ path: String) -> CGImage? {
    NSImage(contentsOfFile: path)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
}

func bitmap(_ w: Int, _ h: Int) -> CGContext {
    CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: sRGB,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

func smoothstep(_ a: Float, _ b: Float, _ x: Float) -> Float {
    let t = max(0, min(1, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)
}

/// Masque de sujet de Vision, ramené à la taille de l'image (valeurs 0…1).
func subjectMask(_ cg: CGImage) throws -> [Float]? {
    let handler = VNImageRequestHandler(cgImage: cg)
    let request = VNGenerateForegroundInstanceMaskRequest()
    try handler.perform([request])
    guard let obs = request.results?.first, !obs.allInstances.isEmpty else { return nil }
    let buf = try obs.generateScaledMaskForImage(forInstances: obs.allInstances, from: handler)
    CVPixelBufferLockBaseAddress(buf, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(buf, .readOnly) }
    let mw = CVPixelBufferGetWidth(buf), mh = CVPixelBufferGetHeight(buf), bpr = CVPixelBufferGetBytesPerRow(buf)
    let isFloat = CVPixelBufferGetPixelFormatType(buf) == kCVPixelFormatType_OneComponent32Float
    let base = CVPixelBufferGetBaseAddress(buf)!
    var mask = [Float](repeating: 0, count: cg.width * cg.height)
    for y in 0..<cg.height {
        let row = base.advanced(by: min(mh - 1, y * mh / cg.height) * bpr)
        for x in 0..<cg.width {
            let mx = min(mw - 1, x * mw / cg.width)
            mask[y * cg.width + x] = isFloat ? row.assumingMemoryBound(to: Float32.self)[mx]
                                             : Float(row.assumingMemoryBound(to: UInt8.self)[mx]) / 255
        }
    }
    return mask
}

/// Détoure le sujet d'une image opaque et renvoie l'image rognée à ses bords.
func cutOut(_ cg: CGImage) throws -> CGImage? {
    guard let mask = try subjectMask(cg) else { return nil }
    let w = cg.width, h = cg.height
    let ctx = bitmap(w, h)
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
    let p = ctx.data!.bindMemory(to: UInt8.self, capacity: w * h * 4)

    // Couleur du fond, et à quel point il est uni.
    var sum = [Double](repeating: 0, count: 3), sq = [Double](repeating: 0, count: 3), n = 0.0
    for i in 0..<(w * h) where mask[i] < 0.02 {
        for c in 0..<3 { let v = Double(p[i * 4 + c]); sum[c] += v; sq[c] += v * v }
        n += 1
    }
    let bg = sum.map { Float($0 / max(n, 1)) }
    let spread = (0..<3).map { c in (sq[c] / max(n, 1) - pow(sum[c] / max(n, 1), 2)).squareRoot() }.max() ?? 99
    let uniform = n > 500 && spread < 14
    func dist(_ i: Int) -> Float {
        max(abs(Float(p[i * 4]) - bg[0]), abs(Float(p[i * 4 + 1]) - bg[1]), abs(Float(p[i * 4 + 2]) - bg[2]))
    }
    // Si le sujet contient lui-même des zones de la couleur du fond (casque sombre sur fond noir,
    // plastique blanc sur fond blanc), la couleur ne peut pas trancher seule : on garde le masque durci.
    var inside = 0.0, lookalike = 0.0
    if uniform {
        for i in 0..<(w * h) where mask[i] > 0.97 { inside += 1; if dist(i) < 16 { lookalike += 1 } }
    }
    let colourDecides = uniform && inside > 0 && lookalike / inside < 0.03

    var minX = w, minY = h, maxX = -1, maxY = -1
    for y in 0..<h {
        for x in 0..<w {
            let i = y * w + x, m = mask[i]
            var a: Float
            if m <= 0.06 { a = 0 } else if m >= 0.94 { a = 1 } else {
                let key = uniform ? smoothstep(14, 44, dist(i)) * smoothstep(0.06, 0.2, m) : 0
                let hard = colourDecides ? smoothstep(0.86, 0.94, m) : smoothstep(0.5, 0.72, m)
                a = max(key, hard)
            }
            for c in 0..<3 {
                var v = Float(p[i * 4 + c])
                if uniform && a > 0 && a < 1 { v = max(0, min(255, (v - (1 - a) * bg[c]) / a)) }
                p[i * 4 + c] = UInt8(v * a)
            }
            p[i * 4 + 3] = UInt8(a * 255)
            if a > 0.04 {
                if x < minX { minX = x }; if x > maxX { maxX = x }
                if y < minY { minY = y }; if y > maxY { maxY = y }
            }
        }
    }
    guard maxX >= 0 else { return nil }
    return ctx.makeImage()?.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1))
}

/// Cadre des pixels visibles d'une image déjà transparente, ou nil si elle est opaque.
func visibleBox(_ cg: CGImage) -> CGRect? {
    let w = cg.width, h = cg.height
    let ctx = bitmap(w, h)
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
    let p = ctx.data!.bindMemory(to: UInt8.self, capacity: w * h * 4)
    var minX = w, minY = h, maxX = -1, maxY = -1, clear = 0
    for y in 0..<h {
        for x in 0..<w {
            if p[(y * w + x) * 4 + 3] > 10 {
                if x < minX { minX = x }; if x > maxX { maxX = x }
                if y < minY { minY = y }; if y > maxY { maxY = y }
            } else { clear += 1 }
        }
    }
    guard maxX >= 0, Double(clear) / Double(w * h) > 0.05 else { return nil }
    return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
}

func save(_ cg: CGImage, _ path: String) {
    let k = min(1, maxSide / CGFloat(max(cg.width, cg.height)))
    let w = Int(CGFloat(cg.width) * k), h = Int(CGFloat(cg.height) * k)
    let ctx = bitmap(w, h)
    ctx.interpolationQuality = .high
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
    print("  \((path as NSString).lastPathComponent)  \(w)x\(h)")
}

// ---------- 1. Captures de l'app mobile ----------
// Coordonnées relevées sur des vignettes de 508 px de large, ramenées aux captures de 1280 px.
struct Crop { let file: String; let x: CGFloat; let y: CGFloat; let w: CGFloat; let h: CGFloat; let name: String }
let k: CGFloat = 1280.0 / 508.0
func card(_ file: String, col: Int, top: CGFloat, _ name: String) -> Crop {
    Crop(file: file, x: (col == 0 ? 20 : 257) + 14, y: top + 6, w: 203, h: min(172, 1082 - (top + 6)), name: "cat-" + name)
}
let crops: [Crop] = [
    Crop(file: "26728", x: 96, y: 236, w: 316, h: 348, name: "headphone-pro"),
    Crop(file: "26748", x: 150, y: 212, w: 210, h: 300, name: "headphone-pro-slider"),
    Crop(file: "26750", x: 150, y: 212, w: 210, h: 300, name: "headphone-pro-button"),
    Crop(file: "26751", x: 150, y: 212, w: 210, h: 300, name: "headphone-pro-button-hold"),
    card("26741", col: 0, top: 200, "ear-open"), card("26741", col: 1, top: 200, "ear"),
    card("26741", col: 0, top: 437, "ear-a"), card("26741", col: 1, top: 437, "ear-1"),
    card("26741", col: 0, top: 673, "ear-2"), card("26741", col: 1, top: 673, "ear-stick"),
    card("26742", col: 0, top: 375, "headphone-1"), card("26742", col: 1, top: 375, "headphone-1-pro"),
    card("26742", col: 0, top: 612, "ear-3"), card("26742", col: 1, top: 612, "headphone-a"),
    card("26742", col: 0, top: 849, "ear-3a"),
    card("26743", col: 0, top: 200, "buds-pro-2"), card("26743", col: 1, top: 200, "buds"),
    card("26743", col: 0, top: 437, "neckband-pro"), card("26743", col: 1, top: 437, "buds-pro"),
    card("26743", col: 0, top: 674, "buds-2"), card("26743", col: 1, top: 674, "buds-2a"),
    card("26743", col: 0, top: 911, "buds-2-plus"), card("26743", col: 1, top: 911, "watch-pro"),
    card("26744", col: 0, top: 375, "watch-pro-2"), card("26744", col: 1, top: 375, "watch-3-pro"),
    card("26744", col: 0, top: 612, "cmf-headphone-pro"), card("26744", col: 1, top: 612, "buds-neo"),
    card("26744", col: 0, top: 849, "clip-pro"),
]

try? fm.createDirectory(atPath: "\(outDir)/products", withIntermediateDirectories: true)
print("Captures de l'app")
for c in crops {
    let rect = CGRect(x: c.x * k, y: c.y * k, width: c.w * k, height: c.h * k).integral
    guard let cg = load("\(capturesDir)/\(c.file).jpg")?.cropping(to: rect) else { print("  manquant : \(c.file).jpg"); continue }
    if let cut = try? cutOut(cg) { save(cut, "\(outDir)/\(c.name).png") } else { print("  sujet introuvable : \(c.name)") }
}

// ---------- 2. Images du site ----------
func slug(_ file: String) -> String {
    var s = (file as NSString).deletingPathExtension
    for pattern in ["^imgi_[0-9]+_", "_[0-9a-f]{8}-[0-9a-f-]{27}$", "^0000s_[0-9]{4}_", "-3_4-view-thumbnail", "-1352x1352"] {
        s = s.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }
    s = s.lowercased().replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
    return s.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
}

// Le site sert chaque image en de nombreuses tailles : on garde la plus lourde de chacune.
var best: [String: (path: String, size: Int)] = [:]
for f in (try? fm.contentsOfDirectory(atPath: siteDir)) ?? [] {
    let ext = (f as NSString).pathExtension.lowercased()
    guard ["png", "jpeg", "jpg"].contains(ext) else { continue }
    let key = slug(f) + (ext == "png" ? "" : "~jpg")
    let size = (try? fm.attributesOfItem(atPath: "\(siteDir)/\(f)")[.size] as? Int) ?? 0
    if size > (best[key]?.size ?? -1) { best[key] = ("\(siteDir)/\(f)", size) }
}
print("Images du site")
for (key, item) in best.sorted(by: { $0.key < $1.key }) {
    guard let cg = load(item.path) else { print("  illisible : \(key)"); continue }
    let plain = key.replacingOccurrences(of: "~jpg", with: "")
    let name = key.hasSuffix("~jpg") && best[plain] != nil ? plain + "-studio" : plain
    if let box = visibleBox(cg), let cropped = cg.cropping(to: box) {
        save(cropped, "\(outDir)/products/\(name).png")
    } else if let cut = try? cutOut(cg) {
        save(cut, "\(outDir)/products/\(name).png")
    } else {
        print("  sujet introuvable : \(key)")
    }
}
