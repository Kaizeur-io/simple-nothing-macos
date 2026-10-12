import AppKit
import NothingKit
import SwiftUI

/// Photos des appareils, quand l'app en contient : `device-<modèle>-<couleur>.png` pour la vue de
/// face et, s'il y en a une, `device-<modèle>-<couleur>-34.png` pour la vue de trois quarts.
/// Elles appartiennent à Nothing et ne sont pas dans le dépôt : tools/install.sh va les chercher,
/// tools/build-app.sh les range dans l'app. Sans elles, `DeviceGlyph` dessine l'appareil.
final class DeviceArt: ObservableObject {
    static let shared = DeviceArt()

    /// Couleurs disponibles par modèle, d'après les fichiers présents.
    private let available: [String: [String]]
    /// Couleur choisie par modèle.
    @Published private var chosen: [String: String]
    /// Les images sont lues une seule fois : l'écran se redessine à chaque réponse de l'appareil.
    private var cache: [String: NSImage?] = [:]

    private init() {
        var found: [String: Set<String>] = [:]
        for url in Bundle.main.urls(forResourcesWithExtension: "png", subdirectory: nil) ?? [] {
            let parts = url.deletingPathExtension().lastPathComponent.split(separator: "-")
            if parts.count >= 3, parts[0] == "device" { found[String(parts[1]), default: []].insert(String(parts[2])) }
        }
        // Le noir d'abord, c'est le coloris le plus répandu ; le reste par ordre alphabétique.
        available = found.mapValues { $0.sorted { ($0 == "black" ? 0 : 1, $0) < ($1 == "black" ? 0 : 1, $1) } }
        chosen = UserDefaults.standard.dictionary(forKey: "colours") as? [String: String] ?? [:]
    }

    func colours(for model: Model?) -> [String] { model.flatMap { available[$0.id] } ?? [] }

    func colour(for model: Model?) -> String? {
        let all = colours(for: model)
        return model.flatMap { chosen[$0.id] }.flatMap { all.contains($0) ? $0 : nil } ?? all.first
    }

    func choose(_ colour: String, for model: Model) {
        chosen[model.id] = colour
        UserDefaults.standard.set(chosen, forKey: "colours")
    }

    /// Vue de face, lisible en petit : barre des menus, carte de connexion.
    func front(for model: Model?) -> NSImage? { image(model, suffix: "") ?? image(model, suffix: "-34") }
    /// Vue pour la fenêtre : de trois quarts s'il y en a une.
    func hero(for model: Model?) -> NSImage? { image(model, suffix: "-34") ?? image(model, suffix: "") }

    private func image(_ model: Model?, suffix: String) -> NSImage? {
        guard let model, let colour = colour(for: model) else { return nil }
        let name = "device-\(model.id)-\(colour)\(suffix)"
        if let known = cache[name] { return known }
        let image = Bundle.main.image(forResource: name)
        cache[name] = image
        return image
    }

    /// Nom à lire (accessibilité) et teinte de la pastille, d'après le nom de couleur des fichiers.
    static func label(_ colour: String) -> String {
        ["black": "Noir", "white": "Blanc", "grey": "Gris", "silver": "Argent", "green": "Vert", "blue": "Bleu",
         "orange": "Orange", "yellow": "Jaune", "pink": "Rose"][colour] ?? colour.capitalized
    }

    static func swatch(_ colour: String) -> Color {
        let hex: UInt32 = ["black": 0x2D2F36, "white": 0xE6E6E3, "grey": 0x9A9C9E, "silver": 0xC9CBCC, "green": 0xA8D2C6, "blue": 0x7FA6D9,
                           "orange": 0xF26B2A, "yellow": 0xF3CF1D, "pink": 0xF2B8C6][colour] ?? 0x9A9C9E
        return Color(red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

/// L'appareil tel qu'on peut le montrer : sa photo, ou à défaut son dessin en points.
struct DevicePicture: View {
    let model: Model?
    /// Vue de trois quarts si possible (fenêtre), sinon de face.
    var large = false
    @ObservedObject private var art = DeviceArt.shared

    var body: some View {
        if let image = large ? art.hero(for: model) : art.front(for: model) {
            Image(nsImage: image).resizable().interpolation(.high).scaledToFit()
        } else {
            DeviceGlyph(isHeadphones: model?.isHeadphones != false).padding(large ? 28 : 6)
        }
    }
}
