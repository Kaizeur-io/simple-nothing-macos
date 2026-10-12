import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var headset: Headset
    @AppStorage("section") private var section = Pane.listen
    @ObservedObject private var language = Language.shared

    private var connected: Bool { headset.status == .connected }

    var body: some View {
        HStack(spacing: 10) {
            DevicePanel(headset: headset)
            VStack(spacing: 10) {
                tabs
                Group {
                    // Sans appareil, on n'affiche pas de réglages inventés : seulement quoi faire.
                    // Ceux de l'app, eux, restent là.
                    switch section {
                    case .app: AppSection()
                    case _ where !connected: missing
                    case .listen: ListenSection(headset: headset)
                    case .controls: ControlsSection(headset: headset)
                    case .link: LinkSection(headset: headset)
                    case .device: DeviceSection(headset: headset)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        // Le contenu monte sous la barre de titre masquée ; la fenêtre fait 920 × 620 en tout.
        .padding(10).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.nBackground).ignoresSafeArea()
        .frame(width: 920, height: 620 - 28)
        .id(language.code)  // changer de langue redessine tout
    }

    private var missing: some View {
        Card {
            VStack(spacing: 0) {
                Image(systemName: headset.status == .unauthorized ? "lock" : "headphones").font(.system(size: 24)).foregroundStyle(Color.nMuted)
                    .frame(width: 68, height: 68).background(Color.nWell, in: Circle())
                Text(tr(headset.status == .unauthorized ? "Bluetooth non autorisé" : headset.status == .connecting ? "Connexion en cours…" : "Aucun appareil connecté"))
                    .font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.nText).padding(.top, 18)
                if headset.status != .connecting {
                    Text(tr(headset.hint)).font(.system(size: 12)).foregroundStyle(Color.nMuted).multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true).frame(maxWidth: 340).padding(.top, 6)
                    HStack(spacing: 8) {
                        if headset.canConnect { PillButton(label: "Connecter", prominent: true, action: headset.connect) }
                        PillButton(label: headset.status == .unauthorized ? "Ouvrir les réglages" : "Réglages Bluetooth", prominent: !headset.canConnect) {
                            NSWorkspace.shared.open(headset.settingsURL)
                        }
                    }
                    .padding(.top, 18)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity).padding(.bottom, 30)
        }
    }

    private var tabs: some View {
        HStack(spacing: 2) {
            ForEach(Pane.allCases, id: \.self) { item in
                Button { section = item } label: {
                    // Le libellé gras, invisible, réserve la largeur : la barre ne bouge pas quand on change d'onglet.
                    Text(tr(item.label)).font(.system(size: 12, weight: .semibold)).hidden()
                        .overlay {
                            Text(tr(item.label)).font(.system(size: 12, weight: section == item ? .semibold : .regular))
                                .foregroundStyle(section == item ? Color.nOnText : Color.nText).fixedSize()
                        }
                        .padding(.horizontal, 14).frame(height: 28)
                        .background(section == item ? Color.nText : .clear, in: Capsule()).contentShape(Capsule())
                }
                .buttonStyle(.plain).accessibilityAddTraits(section == item ? .isSelected : [])
            }
        }
        .padding(3).background(Color.nSurface, in: Capsule()).frame(height: 34)
    }
}
