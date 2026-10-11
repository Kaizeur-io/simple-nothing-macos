import NothingKit
import SwiftUI

enum Pane: String, CaseIterable {
    case listen, controls, link, device

    var label: String {
        switch self {
        case .listen: "Écoute"
        case .controls: "Commandes"
        case .link: "Connexion"
        case .device: "Appareil"
        }
    }
}

// MARK: Écoute

struct ListenSection: View {
    @ObservedObject var headset: Headset
    @AppStorage("lastNoiseLevel") private var lastLevel = Int(NoiseMode.high.rawValue)

    private var noise: NoiseMode { headset.state.noise ?? .off }
    private var preset: Preset { headset.state.preset ?? .pop }
    private var spatial: SpatialMode { headset.state.spatial ?? .off }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                noiseCard
                spatialCard.frame(width: 232)
            }
            .frame(height: 180)
            equalizerCard
            HStack(spacing: 10) {
                Card(padding: 0) {
                    Row(symbol: "person.wave.2", title: "Son personnalisé",
                        subtitle: headset.state.soundProfile == true ? "Activé" : "Calibrage depuis l'app mobile") { EmptyView() }
                        .frame(maxHeight: .infinity)
                }
                Card(padding: 0) {
                    Toggle(isOn: Binding(get: { headset.state.lowLatency ?? false }, set: headset.setLowLatency)) {
                        HStack(spacing: 12) {
                            Image(systemName: "timer").font(.system(size: 14)).foregroundStyle(Color.nText).frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Mode de faible latence").font(.system(size: 13)).foregroundStyle(Color.nText)
                                Text(headset.state.lowLatency == true ? "Activé" : "Désactivé").font(.system(size: 11)).foregroundStyle(Color.nMuted)
                            }
                            Spacer()
                        }
                    }
                    .toggleStyle(NothingToggle()).padding(.horizontal, 16).frame(maxHeight: .infinity)
                }
            }
            .frame(height: 62)
        }
    }

    private var noiseCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                CardHead(title: "Réduction du bruit", subtitle: noise.summary)
                HStack(spacing: 0) {
                    ModeButton(symbol: "ear.badge.waveform", label: "Réduction", isOn: noise.isCancelling) {
                        if !noise.isCancelling { headset.setNoise(NoiseMode(rawValue: UInt8(lastLevel)) ?? .high) }
                    }
                    ModeButton(symbol: "person.wave.2", label: "Transparence", isOn: noise == .transparency) { headset.setNoise(.transparency) }
                    ModeButton(symbol: "circle.slash", label: "Désactivé", isOn: noise == .off) { headset.setNoise(.off) }
                }
                HStack(spacing: 4) {
                    ForEach(NoiseMode.levels, id: \.self) { level in
                        Button {
                            lastLevel = Int(level.rawValue)
                            headset.setNoise(level)
                        } label: {
                            VStack(spacing: 6) {
                                Capsule().fill(noise == level ? Color.nText : Color.nTrack).frame(height: 3)
                                Text(level.levelLabel).font(.system(size: 10, weight: noise == level ? .semibold : .regular))
                                    .foregroundStyle(noise == level ? Color.nText : Color.nMuted)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).accessibilityAddTraits(noise == level ? .isSelected : [])
                    }
                }
                .opacity(noise.isCancelling ? 1 : 0.45)
            }
        }
        .onChange(of: noise) { _, mode in if mode.isCancelling { lastLevel = Int(mode.rawValue) } }
    }

    private var spatialCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                CardHead(title: "Audio spatial", subtitle: spatial.summary)
                HStack(spacing: 0) {
                    ModeButton(symbol: "music.mic", label: "Concert", isOn: spatial == .concert) { headset.setSpatial(.concert) }
                    ModeButton(symbol: "theatermasks", label: "Théâtre", isOn: spatial == .theatre) { headset.setSpatial(.theatre) }
                    ModeButton(symbol: "circle.slash", label: "Désactivé", isOn: spatial == .off) { headset.setSpatial(.off) }
                }
            }
        }
    }

    private var equalizerCard: some View {
        Card {
            HStack(spacing: 22) {
                EqualizerShape(preset: preset).padding(.vertical, -4)
                VStack(alignment: .leading, spacing: 14) {
                    CardHead(title: "Égaliseur", subtitle: preset == .custom ? "Personnalisé · courbe réglée dans l'app mobile" : preset.label)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())], spacing: 8) {
                        ForEach(Preset.shown, id: \.self) { item in
                            Button { headset.setPreset(item) } label: {
                                Caps(item.label, size: 9, color: preset == item ? .white : .nText)
                                    .frame(maxWidth: .infinity).frame(height: 32)
                                    .background(preset == item ? Color.nRed : Color.nWell, in: Capsule())
                            }
                            .buttonStyle(.plain).accessibilityAddTraits(preset == item ? .isSelected : [])
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: Commandes

struct ControlsSection: View {
    @ObservedObject var headset: Headset

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Bouton")
            RowGroup {
                Row(symbol: "hand.tap", title: "Appuyez une fois") { menu(.buttonPress) }
                Row(symbol: "hand.tap.fill", title: "Appuyez longuement") { menu(.buttonHold) }
            }
            SectionTitle("Curseur d'énergie")
            RowGroup {
                Row(symbol: "slider.horizontal.3", title: "Curseur") { menu(.slider) }
            }
            SectionTitle("Molette de défilement")
            RowGroup {
                Row(symbol: "hand.tap.fill", title: "Appuyez longuement", subtitle: "Alterne entre les modes de bruit") { menu(.rollerHold) }
                Row(symbol: "dial.low", title: "Gestes fixes",
                    subtitle: "1 appui : lecture/pause · 2 : suivant · 3 : précédent · défilement : volume") { EmptyView() }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder private func menu(_ control: ButtonMapping.Control) -> some View {
        if let gesture = headset.state.gesture(control) {
            Menu {
                ForEach(control.actions, id: \.code) { action in
                    Button(action.label) {
                        // Le contrôle du bruit a plusieurs codes selon les modes parcourus : on garde celui en place.
                        let both = ButtonMapping.Action.noiseControlAll
                        if !(both.contains(action.code) && both.contains(gesture.action)) { headset.setAction(action.code, for: control) }
                    }
                }
            } label: {
                Text(control.label(for: gesture.action)).font(.system(size: 12))
            }
            .menuStyle(.borderlessButton).fixedSize()
        } else {
            Text("–").foregroundStyle(Color.nMuted)
        }
    }
}

// MARK: Connexion

struct LinkSection: View {
    @ObservedObject var headset: Headset

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Double connexion")
            RowGroup {
                Toggle(isOn: Binding(get: { headset.state.dualConnection ?? false }, set: headset.setDualConnection)) {
                    HStack(spacing: 12) {
                        Image(systemName: "square.2.layers.3d").font(.system(size: 14)).foregroundStyle(Color.nText).frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Double connexion").font(.system(size: 13)).foregroundStyle(Color.nText)
                            Text("Reste relié à deux appareils à la fois").font(.system(size: 11)).foregroundStyle(Color.nMuted)
                        }
                        Spacer()
                    }
                }
                .toggleStyle(NothingToggle()).padding(.horizontal, 16).frame(minHeight: 48)
            }
            SectionTitle("Qualité audio")
            RowGroup {
                Row(symbol: "waveform", title: "Codec", subtitle: "LDAC indisponible : macOS ne le propose pas en Bluetooth") {
                    Text(headset.state.codec?.name ?? "–").font(.nMono(12)).foregroundStyle(Color.nMuted)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: Appareil

struct DeviceSection: View {
    @ObservedObject var headset: Headset
    @AppStorage("finish") private var finish = Finish.darkGrey

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Informations")
            RowGroup {
                Row(title: "Modèle") { value(headset.model.map { "\($0.fullName) · \($0.id)" } ?? headset.name) }
                if headset.model == .headphonePro {
                    Row(title: "Couleur") {
                        HStack(spacing: 8) {
                            ForEach(Finish.allCases, id: \.self) { item in
                                Button { finish = item } label: {
                                    Circle().fill(item.swatch).frame(width: 18, height: 18)
                                        .overlay { Circle().strokeBorder(Color.nTrack, lineWidth: 1) }
                                        .padding(3).overlay { Circle().strokeBorder(finish == item ? Color.nText : .clear, lineWidth: 1.5) }
                                }
                                .buttonStyle(.plain).accessibilityLabel(item.label).accessibilityAddTraits(finish == item ? .isSelected : [])
                            }
                        }
                    }
                }
                Row(title: "N° de série") { value(headset.state.serial ?? "–") }
                Row(title: "Adresse Bluetooth") { value(headset.address) }
                Row(title: "Firmware") { value(headset.state.firmware ?? "–") }
            }
            if let model = headset.model, !model.verified {
                Text("Ce modèle n'a pas encore été vérifié : certains réglages peuvent manquer.")
                    .font(.system(size: 11)).foregroundStyle(Color.nMuted).padding(.leading, 4)
            }
            Spacer(minLength: 0)
        }
    }

    private func value(_ text: String) -> some View {
        Text(text).font(.nMono(12)).foregroundStyle(Color.nMuted).textSelection(.enabled)
    }
}
