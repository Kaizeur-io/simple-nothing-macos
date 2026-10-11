import AppKit
import NothingKit
import SwiftUI

/// Le panneau de la barre des menus : l'essentiel sans ouvrir la fenêtre.
struct MenuBarPanel: View {
    @ObservedObject var headset: Headset
    @Environment(\.openWindow) private var openWindow

    private var noise: NoiseMode { headset.state.noise ?? .off }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(headset.name.isEmpty ? "Aucun appareil" : headset.name).font(.nSerif(19)).foregroundStyle(Color.nText).lineLimit(1)
                Spacer()
                if let level = headset.state.mainBattery { Text("\(level.percent) %").font(.nMono(12)).foregroundStyle(Color.nText) }
            }
            if headset.status == .connected {
                VStack(alignment: .leading, spacing: 10) {
                    Caps(noise.summary)
                    HStack(spacing: 0) {
                        ModeButton(symbol: "ear.badge.waveform", label: "Réduction", isOn: noise.isCancelling) {
                            if !noise.isCancelling { headset.setNoise(.high) }
                        }
                        ModeButton(symbol: "person.wave.2", label: "Transparence", isOn: noise == .transparency) { headset.setNoise(.transparency) }
                        ModeButton(symbol: "circle.slash", label: "Désactivé", isOn: noise == .off) { headset.setNoise(.off) }
                    }
                }
            } else {
                Text("Allumez votre appareil et reliez-le au Mac dans Réglages › Bluetooth.")
                    .font(.system(size: 11)).foregroundStyle(Color.nMuted).fixedSize(horizontal: false, vertical: true)
            }
            Rectangle().fill(Color.nTrack).frame(height: 1)
            HStack {
                Button("Ouvrir Nothing X") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                Spacer()
                Button("Quitter") { NSApp.terminate(nil) }.keyboardShortcut("q")
            }
            .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Color.nText)
        }
        .padding(16).frame(width: 280).background(Color.nSurface)
    }
}
