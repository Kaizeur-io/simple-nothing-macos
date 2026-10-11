import AppKit
import NothingKit
import SwiftUI

/// Coloris du CMF Headphone Pro. Les images sont copiées dans l'app par tools/app.sh quand elles existent.
enum Finish: String, CaseIterable {
    case darkGrey = "dark-grey", lightGrey = "light-grey", lightGreen = "light-green"

    var label: String { self == .darkGrey ? "Gris foncé" : self == .lightGrey ? "Gris clair" : "Vert clair" }
    var swatch: Color { Color(red: red, green: green, blue: blue) }
    private var red: Double { self == .darkGrey ? 0.18 : self == .lightGrey ? 0.84 : 0.66 }
    private var green: Double { self == .darkGrey ? 0.18 : self == .lightGrey ? 0.84 : 0.82 }
    private var blue: Double { self == .darkGrey ? 0.21 : self == .lightGrey ? 0.83 : 0.78 }

    /// Vue de trois quarts, pour la fenêtre.
    var image: NSImage? { Self.cached("cmf-headphone-pro-\(rawValue)") }
    /// Vue de face, plus lisible en petit.
    var frontImage: NSImage? { Self.cached("cmf-headphone-pro-front-\(rawValue)") ?? image }

    /// Les images sont lues une seule fois : l'écran se redessine à chaque réponse de l'appareil.
    private static var cache: [String: NSImage?] = [:]
    private static func cached(_ name: String) -> NSImage? {
        if let known = cache[name] { return known }
        let image = Bundle.main.image(forResource: name)
        cache[name] = image
        return image
    }
}

struct DevicePanel: View {
    @ObservedObject var headset: Headset
    @AppStorage("finish") private var finish = Finish.darkGrey

    private var connected: Bool { headset.status == .connected }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 34)
            hero.frame(maxHeight: 250).padding(.horizontal, 26).opacity(connected ? 1 : 0.35)
            Spacer(minLength: 16)
            Text(headset.name.isEmpty ? tr("Aucun appareil") : headset.name).font(.nSerif(23)).foregroundStyle(Color.nText)
                .lineLimit(1).minimumScaleFactor(0.7).padding(.horizontal, 14)
            battery.padding(.top, 12).frame(height: 52, alignment: .top)
            Spacer(minLength: 10)
            footer
        }
        .padding(.bottom, 14).frame(width: 250).frame(maxHeight: .infinity)
        .background(Color.nSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder private var hero: some View {
        if headset.model == .headphonePro || headset.name.isEmpty, let image = finish.image {
            Image(nsImage: image).resizable().interpolation(.high).scaledToFit()
        } else {
            DeviceGlyph(isHeadphones: headset.model?.isHeadphones != false).padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder private var battery: some View {
        if connected, let level = headset.state.mainBattery {
            VStack(spacing: 7) {
                Capsule().fill(Color.nTrack).frame(width: 44, height: 3)
                    .overlay(alignment: .leading) {
                        Capsule().fill(level.percent <= 15 ? Color.nRed : Color.nText).frame(width: 44 * Double(level.percent) / 100)
                    }
                Text(tr("%d %%", level.percent) + (level.charging ? " · " + tr("en charge") : "")).font(.nMono(11)).foregroundStyle(Color.nText)
            }
            .accessibilityElement(children: .ignore).accessibilityLabel(tr("Batterie %d %%", level.percent))
        } else if !connected {
            Text(tr(headset.hint)).font(.system(size: 11)).foregroundStyle(Color.nMuted).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 22)
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Circle().fill(connected ? Color.nGreen : Color.nMuted).frame(width: 5, height: 5)
            Caps(headset.statusLabel)
            Spacer()
            if connected { Caps([headset.state.codec?.name, headset.state.firmware].compactMap { $0 }.joined(separator: " · ")) }
        }
        .padding(.horizontal, 16)
    }
}
