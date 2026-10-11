import Foundation
import NothingKit

/// Essaie chaque réglage sur l'appareil relié : l'écrit, relit la réponse, puis remet la valeur d'origine.
/// Sert à confirmer les écritures sur un modèle avant de s'y fier. Lancé par `--verify <fichier>`.
final class Verification {
    private let headset: Headset
    private let report: String
    private var lines: [String] = []
    private var received: [Frame] = []

    init(headset: Headset, report: String) {
        self.headset = headset
        self.report = report
    }

    func run() {
        headset.onFrame = { [weak self] frame in
            self?.received.append(frame)
            self?.lines.append(String(format: "    ← 0x%04X  ", frame.command) + frame.payload.map { String(format: "%02x", $0) }.joined(separator: " "))
        }
        Task { @MainActor in
            for _ in 0..<40 where headset.status != .connected || headset.state.gestures.isEmpty { await pause(0.25) }
            guard headset.status == .connected else { return finish("Aucun appareil relié.") }
            await pause(1.5)
            let start = headset.state
            lines.append("Appareil : \(headset.name), firmware \(start.firmware ?? "?")")

            if let noise = start.noise {
                let other: NoiseMode = noise == .transparency ? .off : .transparency
                await check("réduction du bruit", set: { self.headset.setNoise(other) }, expect: { $0.noise == other })
                await check("réduction du bruit, retour", set: { self.headset.setNoise(noise) }, expect: { $0.noise == noise })
            }
            if let preset = start.preset {
                let other: Preset = preset == .rock ? .pop : .rock
                await check("égaliseur", set: { self.headset.setPreset(other) }, expect: { $0.preset == other })
                await check("égaliseur, retour", set: { self.headset.setPreset(preset) }, expect: { $0.preset == preset })
            }
            if let spatial = start.spatial {
                let other: SpatialMode = spatial == .theatre ? .concert : .theatre
                await check("audio spatial", set: { self.headset.setSpatial(other) }, expect: { $0.spatial == other })
                await check("audio spatial, retour", set: { self.headset.setSpatial(spatial) }, expect: { $0.spatial == spatial })
            }
            if let latency = start.lowLatency {
                await check("faible latence", set: { self.headset.setLowLatency(!latency) }, expect: { $0.lowLatency == !latency })
                await check("faible latence, retour", set: { self.headset.setLowLatency(latency) }, expect: { $0.lowLatency == latency })
            }
            if let hold = start.gesture(.buttonHold) {
                let other = hold.action == ButtonMapping.Action.microphone ? ButtonMapping.Action.none : ButtonMapping.Action.microphone
                await check("commande (appui long)", set: { self.headset.setAction(other, for: .buttonHold) }, expect: { $0.gesture(.buttonHold)?.action == other })
                await check("commande, retour", set: { self.headset.setAction(hold.action, for: .buttonHold) }, expect: { $0.gesture(.buttonHold)?.action == hold.action })
            }
            lines.append("Non essayé : double connexion (peut couper la liaison).")
            finish(nil)
        }
    }

    /// Le verdict se lit dans les trames reçues après l'écriture, pas dans l'état affiché, qui anticipe.
    @MainActor private func check(_ name: String, set: () -> Void, expect: (DeviceState) -> Bool) async {
        received.removeAll()
        lines.append("\(name) :")
        set()
        await pause(1.6)
        var heard = DeviceState()
        received.forEach { heard.apply($0) }
        lines.append("    → \(expect(heard) ? "confirmé" : "NON CONFIRMÉ")")
    }

    private func pause(_ seconds: Double) async { try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) }

    private func finish(_ error: String?) {
        if let error { lines.append(error) }
        try? (lines.joined(separator: "\n") + "\n").write(toFile: report, atomically: true, encoding: .utf8)
        exit(error == nil ? 0 : 1)
    }
}
