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
                    switch section {
                    case .listen: ListenSection(headset: headset)
                    case .controls: ControlsSection(headset: headset)
                    case .link: LinkSection(headset: headset)
                    case .device: DeviceSection(headset: headset)
                    case .app: AppSection()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                // Les réglages de l'app restent utilisables sans appareil relié.
                .disabled(!connected && section != .app).opacity(connected || section == .app ? 1 : 0.4)
            }
        }
        // Le contenu monte sous la barre de titre masquée ; la fenêtre fait 920 × 620 en tout.
        .padding(10).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.nBackground).ignoresSafeArea()
        .frame(width: 920, height: 620 - 28)
        .id(language.code)  // changer de langue redessine tout
    }

    private var tabs: some View {
        HStack(spacing: 2) {
            ForEach(Pane.allCases, id: \.self) { item in
                Button { section = item } label: {
                    Text(tr(item.label)).font(.system(size: 12, weight: section == item ? .semibold : .regular))
                        .foregroundStyle(section == item ? Color.nOnText : Color.nText)
                        .padding(.horizontal, 14).frame(height: 28)
                        .background(section == item ? Color.nText : .clear, in: Capsule()).contentShape(Capsule())
                }
                .buttonStyle(.plain).accessibilityAddTraits(section == item ? .isSelected : [])
            }
        }
        .padding(3).background(Color.nSurface, in: Capsule()).frame(height: 34)
    }
}
