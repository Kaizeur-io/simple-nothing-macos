import AppKit
import NothingKit
import SwiftUI

/// Le panneau qui s'ouvre depuis la barre des menus : l'essentiel sans ouvrir la fenêtre.
struct MenuBarPanel: View {
    @ObservedObject var headset: Headset
    @ObservedObject private var language = Language.shared

    private var connected: Bool { headset.status == .connected }
    private var state: DeviceState { headset.state }

    var body: some View {
        VStack(spacing: 0) {
            header.padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 12)
            if connected {
                if state.battery.count > 1 {
                    BatterySplit(battery: state.battery).frame(maxWidth: .infinity).padding(.bottom, 12)
                }
                if headset.capabilities.noiseControl {
                    rule
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Caps("Réduction du bruit")
                            Spacer()
                            Caps((state.noise ?? .off).summary, color: .nText)
                        }
                        NoiseControls(headset: headset)
                    }
                    .padding(16)
                }
                rule
                VStack(alignment: .leading, spacing: 10) {
                    Caps("Égaliseur")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                        ForEach(Preset.shown, id: \.self) { preset in
                            chip(preset.shortLabel, isOn: state.preset == preset) { headset.setPreset(preset) }
                        }
                    }
                    if !headset.capabilities.spatial.isEmpty {
                        Caps("Audio spatial").padding(.top, 6)
                        HStack(spacing: 6) {
                            ForEach(headset.capabilities.spatial + [.off], id: \.self) { mode in
                                chip(mode.shortLabel, isOn: state.spatial == mode, tint: .nText) { headset.setSpatial(mode) }
                            }
                        }
                    }
                }
                .padding(16)
                rule
                ToggleRow(title: "Mode de faible latence", isOn: state.lowLatency ?? false, set: headset.setLowLatency)
                    .padding(.horizontal, 16).frame(height: 46)
            } else {
                rule
                VStack(alignment: .leading, spacing: 12) {
                    Text(tr(headset.hint))
                        .font(.system(size: 12)).foregroundStyle(Color.nMuted).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        if headset.canConnect {
                            Button(action: headset.connect) {
                                Caps("Connecter", size: 9, color: .nOnText).padding(.horizontal, 16).frame(height: 30).background(Color.nText, in: Capsule())
                            }
                        }
                        Button {
                            NSWorkspace.shared.open(headset.settingsURL)
                        } label: {
                            let main = !headset.canConnect
                            Caps(headset.status == .unauthorized ? "Ouvrir les réglages" : "Réglages Bluetooth", size: 9, color: main ? .nOnText : .nText)
                                .padding(.horizontal, 16).frame(height: 30).background(main ? Color.nText : Color.nWell, in: Capsule())
                        }
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(16)
            }
            rule
            HStack {
                Button { AppDelegate.showMainWindow() } label: {
                    HStack(spacing: 6) {
                        Text(tr("Ouvrir %@", appName)).font(.system(size: 12, weight: .medium))
                        Image(systemName: "arrow.up.right").font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(Color.nText).contentShape(Rectangle())
                }
                .keyboardShortcut("o")
                Spacer()
                if connected {
                    Button(action: headset.disconnect) {
                        Text(tr("Déconnecter")).font(.system(size: 12)).foregroundStyle(Color.nMuted).contentShape(Rectangle())
                    }
                    .padding(.trailing, 12)
                }
                Button { NSApp.terminate(nil) } label: {
                    Text(tr("Quitter")).font(.system(size: 12)).foregroundStyle(Color.nMuted).contentShape(Rectangle())
                }
                .keyboardShortcut("q")
            }
            .buttonStyle(.plain).padding(.horizontal, 16).frame(height: 42)
        }
        .frame(width: 320).background(Color.nSurface).id(language.code)
    }

    private var rule: some View { Rectangle().fill(Color.nTrack).frame(height: 1) }

    private var header: some View {
        HStack(spacing: 12) {
            DevicePicture(model: headset.shownModel).frame(width: 64, height: 64).opacity(connected ? 1 : 0.35)
            VStack(alignment: .leading, spacing: 6) {
                Text(headset.name.isEmpty ? tr("Aucun appareil") : headset.name).font(.nSerif(18)).foregroundStyle(Color.nText)
                    .lineLimit(1).minimumScaleFactor(0.75)
                HStack(spacing: 5) {
                    Circle().fill(connected ? Color.nGreen : Color.nMuted).frame(width: 5, height: 5)
                    Caps(headset.statusLabel)
                    if connected, let codec = state.codec { Caps("· " + codec.name) }
                }
            }
            Spacer(minLength: 4)
            if connected, let level = state.mainBattery {
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        DotNumber(value: level.percent, size: 30)
                        Text("%").font(.nMono(11))
                    }
                    .foregroundStyle(level.percent <= 15 ? Color.nRed : Color.nText)
                    Capsule().fill(Color.nTrack).frame(width: 46, height: 3)
                        .overlay(alignment: .leading) {
                            Capsule().fill(level.percent <= 15 ? Color.nRed : Color.nText).frame(width: 46 * Double(level.percent) / 100)
                        }
                    if level.charging { Caps("en charge", size: 8) }
                }
                .accessibilityElement(children: .ignore).accessibilityLabel(tr("Batterie %d %%", level.percent))
            }
        }
    }

    /// Pastille de choix, dans le style des préréglages de la fenêtre.
    private func chip(_ label: String, isOn: Bool, tint: Color = .nRed, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Caps(label, size: 8.5, color: isOn ? (tint == .nRed ? .white : .nOnText) : .nText)
                .frame(maxWidth: .infinity).frame(height: 28).background(isOn ? tint : Color.nWell, in: Capsule()).contentShape(Capsule())
        }
        .buttonStyle(.plain).accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
