import AppKit
import NothingKit
import SwiftUI

struct DevicePanel: View {
    @ObservedObject var headset: Headset

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

    private var hero: some View {
        DevicePicture(model: headset.shownModel, large: true).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private var battery: some View {
        if connected, headset.state.battery.count > 1 {
            BatterySplit(battery: headset.state.battery)
        } else if connected, let level = headset.state.mainBattery {
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

/// Écouteurs : un niveau par écouteur et un pour le boîtier.
struct BatterySplit: View {
    let battery: [Battery]

    private var parts: [(label: String, level: Battery)] {
        let names: [(Battery.Slot, String)] = [(.left, "G"), (.right, "D"), (.charger, "Boîtier")]
        return names.compactMap { slot, label in battery.first { $0.kind == slot }.map { (label, $0) } }
    }

    var body: some View {
        HStack(spacing: 16) {
            ForEach(parts, id: \.label) { part in
                VStack(spacing: 6) {
                    Capsule().fill(Color.nTrack).frame(width: 34, height: 3)
                        .overlay(alignment: .leading) {
                            Capsule().fill(part.level.percent <= 15 ? Color.nRed : Color.nText).frame(width: 34 * Double(part.level.percent) / 100)
                        }
                    Text(tr(part.label) + " " + tr("%d %%", part.level.percent) + (part.level.charging ? " ⚡" : ""))
                        .font(.nMono(10)).foregroundStyle(Color.nText).lineLimit(1).fixedSize()
                }
                .accessibilityElement(children: .ignore).accessibilityLabel(tr(part.label) + " " + tr("Batterie %d %%", part.level.percent))
            }
        }
    }
}
