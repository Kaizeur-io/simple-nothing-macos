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
    var image: NSImage? { Bundle.main.image(forResource: "cmf-headphone-pro-\(rawValue)") }
    /// Vue de face, plus lisible en petit.
    var frontImage: NSImage? { Bundle.main.image(forResource: "cmf-headphone-pro-front-\(rawValue)") ?? image }
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
            battery.padding(.top, 12).frame(height: 40, alignment: .top)
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
            Image(systemName: headset.model?.isHeadphones == false ? "earbuds" : "headphones").font(.system(size: 110, weight: .ultraLight))
                .foregroundStyle(Color.nText).frame(maxWidth: .infinity, maxHeight: .infinity)
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
            Text(tr(headset.status == .connecting ? "Connexion en cours…" : "Allumez votre appareil et reliez-le\nau Mac dans Réglages › Bluetooth."))
                .font(.system(size: 11)).foregroundStyle(Color.nMuted).multilineTextAlignment(.center)
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Circle().fill(connected ? Color.nGreen : Color.nMuted).frame(width: 5, height: 5)
            Caps(connected ? "Connecté" : headset.status == .connecting ? "Connexion en cours" : "Déconnecté")
            Spacer()
            if connected { Caps([headset.state.codec?.name, headset.state.firmware].compactMap { $0 }.joined(separator: " · ")) }
        }
        .padding(.horizontal, 16)
    }
}
