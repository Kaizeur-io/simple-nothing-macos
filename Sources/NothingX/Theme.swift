import AppKit
import SwiftUI

extension Color {
    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }

    static let nBackground = adaptive(0xF0F0F0, 0x000000)
    static let nSurface = adaptive(0xFFFFFF, 0x1B1B1B)
    static let nWell = adaptive(0xF0F0F0, 0x2C2C2C)
    static let nText = adaptive(0x1B1B1B, 0xFFFFFF)
    static let nMuted = adaptive(0x6E6E6E, 0x9C9C9C)
    static let nTrack = adaptive(0xE4E4E4, 0x343434)
    static let nOnText = adaptive(0xFFFFFF, 0x000000)
    static let nBlob = adaptive(0xF6F6F6, 0x333333)
    static let nRed = adaptive(0xD71921, 0xD71921)
    static let nGreen = adaptive(0x1FA84F, 0x1FA84F)
}

extension Font {
    static func nSerif(_ size: CGFloat) -> Font { .custom("Bodoni 72", size: size) }
    static func nMono(_ size: CGFloat) -> Font { .system(size: size, design: .monospaced) }
}

/// Étiquette en capitales espacées, la signature typographique de Nothing.
struct Caps: View {
    let text: String
    var size: CGFloat = 9
    var color = Color.nMuted

    init(_ text: String, size: CGFloat = 9, color: Color = .nMuted) {
        (self.text, self.size, self.color) = (text, size, color)
    }

    var body: some View {
        Text(text.uppercased()).font(.nMono(size)).tracking(size * 0.18).foregroundStyle(color).lineLimit(1)
    }
}

struct Card<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content.padding(padding).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.nSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct CardHead: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.nText)
            Text(subtitle).font(.system(size: 11)).foregroundStyle(Color.nMuted).lineLimit(1)
        }
    }
}

/// Bouton rond avec sa légende : modes de bruit, modes d'audio spatial.
struct ModeButton: View {
    let symbol: String
    let label: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: symbol).font(.system(size: 17)).frame(width: 46, height: 46)
                    .foregroundStyle(isOn ? Color.nOnText : Color.nText)
                    .background(isOn ? Color.nText : Color.nWell, in: Circle())
                Text(label).font(.system(size: 11, weight: isOn ? .semibold : .regular))
                    .foregroundStyle(isOn ? Color.nText : Color.nMuted).lineLimit(1)
            }
            .frame(maxWidth: .infinity).contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

struct NothingToggle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 12) {
                configuration.label
                Capsule().fill(configuration.isOn ? Color.nText : Color.nTrack).frame(width: 44, height: 26)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle().fill(configuration.isOn ? Color.nOnText : .white).frame(width: 20, height: 20).padding(3)
                    }
                    .animation(.easeOut(duration: 0.18), value: configuration.isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityAddTraits(configuration.isOn ? .isSelected : [])
    }
}

/// Liste groupée : lignes séparées par un filet, sur une carte.
struct RowGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            _VariadicView.Tree(Divided()) { content }
        }
        .background(Color.nSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private struct Divided: _VariadicView_MultiViewRoot {
        func body(children: _VariadicView.Children) -> some View {
            ForEach(children) { child in
                child
                if child.id != children.last?.id { Rectangle().fill(Color.nTrack).frame(height: 1).padding(.leading, 16) }
            }
        }
    }
}

struct Row<Trailing: View>: View {
    var symbol: String?
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            if let symbol { Image(systemName: symbol).font(.system(size: 14)).foregroundStyle(Color.nText).frame(width: 22) }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13)).foregroundStyle(Color.nText)
                if let subtitle { Text(subtitle).font(.system(size: 11)).foregroundStyle(Color.nMuted) }
            }
            Spacer(minLength: 12)
            trailing
        }
        .padding(.horizontal, 16).frame(minHeight: 48)
    }
}

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Caps(text, size: 10).padding(.leading, 4).padding(.top, 6) }
}
