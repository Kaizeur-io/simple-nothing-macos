import AppKit
import NothingKit
import SwiftUI

/// Carte flottante en haut à droite de l'écran, par-dessus toutes les apps : arrivée d'un appareil,
/// changement de mode au clavier. Elle ne prend pas le clavier et s'efface d'elle-même.
final class HUD {
    static let shared = HUD()

    private var panel: NSPanel?
    private var dismissal: DispatchWorkItem?
    /// Marge transparente autour de la carte, pour que son ombre ne soit pas coupée.
    static let margin: CGFloat = 36

    func show(_ content: some View, seconds: Double) {
        dismissal?.cancel()
        let host = NSHostingView(rootView: content.padding(Self.margin))
        let size = host.fittingSize
        guard let screen = NSScreen.main else { return }
        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.contentView = host
        let frame = CGRect(x: screen.visibleFrame.maxX - size.width + Self.margin - 14, y: screen.visibleFrame.maxY - size.height + Self.margin - 10,
                           width: size.width, height: size.height)
        if !panel.isVisible {
            panel.setFrame(frame.offsetBy(dx: 0, dy: 18), display: false)
            panel.alphaValue = 0
            panel.orderFrontRegardless()
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.32
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(frame, display: true)
            panel.animator().alphaValue = 1
        }
        let work = DispatchWorkItem { [weak self] in self?.hide() }
        dismissal = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    func hide() {
        dismissal?.cancel()
        guard let panel, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            panel.animator().alphaValue = 0
        }, completionHandler: {
            // Une nouvelle carte a pu arriver pendant le fondu : dans ce cas on ne touche à rien.
            guard panel.alphaValue == 0 else { return }
            panel.orderOut(nil)
            panel.contentView = nil
        })
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        return panel
    }
}

private struct HUDCard<Content: View>: View {
    var radius: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(Color.nBackground, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Color.nText.opacity(0.14), lineWidth: 1) }
            .shadow(color: .black.opacity(0.28), radius: 22, y: 12)
    }
}

/// « Votre casque vient de se connecter », à la manière des AirPods.
struct ArrivalCard: View {
    @ObservedObject var headset: Headset

    var body: some View {
        HUDCard(radius: 26) {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Circle().fill(Color.nGreen).frame(width: 6, height: 6)
                    Caps("Connecté", size: 10)
                }
                DevicePicture(model: headset.shownModel).frame(height: 150).padding(.top, 14).padding(.bottom, 10)
                Text(headset.name).font(.nSerif(25)).foregroundStyle(Color.nText).lineLimit(1).minimumScaleFactor(0.7)
                if let level = headset.state.mainBattery {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        DotNumber(value: level.percent, size: 36)
                        Text("%").font(.nMono(13))
                    }
                    .foregroundStyle(level.percent <= 15 ? Color.nRed : Color.nText).padding(.top, 10)
                }
                if let noise = headset.state.noise {
                    Text(tr("Réduction du bruit") + " : " + tr(noise.summary).lowercased()).font(.system(size: 12)).foregroundStyle(Color.nMuted).padding(.top, 6)
                }
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 18).frame(width: 300)
        }
        .onTapGesture {
            HUD.shared.hide()
            AppDelegate.showMainWindow()
        }
    }
}

/// Confirmation d'un changement de mode fait au clavier.
struct ModeToast: View {
    let mode: NoiseMode

    var body: some View {
        HUDCard(radius: 22) {
            HStack(spacing: 14) {
                Image(systemName: mode.symbol).font(.system(size: 17)).foregroundStyle(Color.nOnText).frame(width: 44, height: 44).background(Color.nText, in: Circle())
                VStack(alignment: .leading, spacing: 5) {
                    Caps("Réduction du bruit", size: 9)
                    Text(tr(mode.summary)).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.nText)
                }
                Spacer(minLength: 0)
            }
            .padding(14).frame(width: 270)
        }
    }
}
