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
    private var noise: NoiseMode { headset.state.noise ?? .off }
    private var preset: Preset { headset.state.preset ?? .pop }
    private var spatial: SpatialMode { headset.state.spatial ?? .off }

    /// Courbe en cours de glissement, avant d'être envoyée.
    @State private var draft: CustomEQ?
    private var curve: CustomEQ {
        preset == .custom ? draft ?? headset.state.customEQ ?? CustomEQ(mid: 0, bass: 0, treble: 0) : preset.shape
    }

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
                    ToggleRow(symbol: "timer", title: "Mode de faible latence", subtitle: headset.state.lowLatency == true ? "Activé" : "Désactivé",
                              isOn: headset.state.lowLatency ?? false, set: headset.setLowLatency)
                        .padding(.horizontal, 16).frame(maxHeight: .infinity)
                }
            }
            .frame(height: 62)
        }
    }

    private var noiseCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                CardHead(title: "Réduction du bruit", subtitle: noise.summary)
                NoiseControls(headset: headset)
            }
        }
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
                EqualizerShape(curve, name: preset.label, edit: preset != .custom ? nil : { curve, done in
                    draft = done ? nil : curve
                    if done { headset.setCustomEQ(curve) }
                })
                .animation(.easeInOut(duration: 0.35), value: preset).padding(.vertical, -4)
                VStack(alignment: .leading, spacing: 14) {
                    CardHead(title: "Égaliseur", subtitle: preset == .custom ? "Personnalisé · déplacez les trois points" : preset.label)
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
            // Le contrôle du bruit a plusieurs codes selon les modes parcourus : on garde celui en place.
            let noiseCodes = ButtonMapping.Action.noiseControlAll
            ValueMenu(value: control.label(for: gesture.action), options: control.actions.map { action in
                (action.label, { if !(noiseCodes.contains(action.code) && noiseCodes.contains(gesture.action)) { headset.setAction(action.code, for: control) } })
            })
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
                ToggleRow(symbol: "square.2.layers.3d", title: "Double connexion", subtitle: "Reste relié à deux appareils à la fois",
                          isOn: headset.state.dualConnection ?? false, set: headset.setDualConnection)
                    .padding(.horizontal, 16).frame(minHeight: 48)
            }
            if headset.state.dualConnection == true, !headset.state.dualDevices.isEmpty {
                SectionTitle("Appareils reliés")
                RowGroup {
                    ForEach(headset.state.dualDevices, id: \.address) { device in
                        Row(symbol: device.isSelf ? "laptopcomputer" : "dot.radiowaves.left.and.right", title: device.name.isEmpty ? device.address : device.name,
                            subtitle: device.isSelf ? "Cet ordinateur" : nil) {
                            Caps(device.isConnected ? "Connecté" : "Enregistré", color: device.isConnected ? .nText : .nMuted)
                        }
                    }
                }
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
    @AppStorage("shortcutEnabled") private var shortcutEnabled = true
    @AppStorage("arrivalCard") private var arrivalCard = true
    @State private var opensAtLogin = AppDelegate.opensAtLogin
    @State private var loginRefused = false

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
                                .buttonStyle(.plain).accessibilityLabel(tr(item.label)).accessibilityAddTraits(finish == item ? .isSelected : [])
                            }
                        }
                    }
                }
                Row(title: "N° de série") { value(headset.state.serial ?? "–") }
                Row(title: "Adresse Bluetooth") { value(headset.address) }
                Row(title: "Firmware") { value(headset.state.firmware ?? "–") }
            }
            SectionTitle("Application")
            RowGroup {
                ToggleRow(symbol: "power", title: "Ouvrir au démarrage du Mac",
                          subtitle: loginRefused ? "Refusé par macOS : installez d'abord l'app dans Applications" : "Reste dans la barre des menus, sans fenêtre",
                          isOn: opensAtLogin) { wanted in
                    loginRefused = !AppDelegate.setOpensAtLogin(wanted)
                    opensAtLogin = AppDelegate.opensAtLogin
                }
                .padding(.horizontal, 16).frame(minHeight: 48)
                ToggleRow(symbol: "keyboard", title: "Changer de mode de bruit au clavier", subtitle: "Raccourci ⌃⌥A, actif dans toutes les apps",
                          isOn: shortcutEnabled) { shortcutEnabled = $0; AppDelegate.applyShortcut() }
                    .padding(.horizontal, 16).frame(minHeight: 48)
                ToggleRow(symbol: "rectangle.topthird.inset.filled", title: "Carte à la connexion", subtitle: "S'affiche quand l'appareil se relie au Mac",
                          isOn: arrivalCard) { arrivalCard = $0 }
                    .padding(.horizontal, 16).frame(minHeight: 48)
            }
            if let model = headset.model, !model.verified {
                Text(tr("Ce modèle n'a pas encore été vérifié : certains réglages peuvent manquer."))
                    .font(.system(size: 11)).foregroundStyle(Color.nMuted).padding(.leading, 4)
            }
            Spacer(minLength: 0)
        }
    }

    private func value(_ text: String) -> some View {
        Text(text).font(.nMono(12)).foregroundStyle(Color.nMuted).textSelection(.enabled)
    }
}
