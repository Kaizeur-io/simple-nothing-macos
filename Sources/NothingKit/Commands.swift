// Numéros de commande et valeurs échangées. Les lectures ont été relevées sur un CMF Headphone Pro ;
// les écritures viennent de la documentation communautaire (docs/protocole.md).

public enum Read: UInt16, CaseIterable, Sendable {
    case battery = 0xC007, firmware = 0xC042, identity = 0xC006, noise = 0xC01E, preset = 0xC050
    case spatial = 0xC04F, lowLatency = 0xC041, bass = 0xC04E, gestures = 0xC018
    case dualConnection = 0xC027, codec = 0xC029, soundProfile = 0xC05A

    /// La réponse porte le même numéro, bit de poids fort baissé.
    public var reply: UInt16 { rawValue & 0x7FFF }
}

public enum Write: UInt16, Sendable {
    case noise = 0xF00F, preset = 0xF01D, spatial = 0xF052, lowLatency = 0xF040
    case gesture = 0xF003, dualConnection = 0xF01A
}

/// Envois spontanés de l'appareil, sans requête.
public enum Push {
    public static let battery: UInt16 = 0xE001
    public static let noise: UInt16 = 0xE003
}

public enum NoiseMode: UInt8, CaseIterable, Sendable {
    case high = 0x01, mid = 0x02, low = 0x03, adaptive = 0x04, off = 0x05, transparency = 0x07

    public var isCancelling: Bool { self != .off && self != .transparency }
}

public enum Preset: UInt8, CaseIterable, Sendable {
    case dirac = 0, rock = 1, electronic = 2, pop = 3, vocal = 4, classical = 5, custom = 6
}

public enum SpatialMode: Equatable, Sendable {
    case off, fixed, headTracked, concert, theatre, game

    /// Sur le fil : mode, puis suivi de tête.
    public var bytes: [UInt8] {
        switch self {
        case .off: [0, 0]
        case .fixed: [1, 0]
        case .headTracked: [1, 1]
        case .concert: [2, 0]
        case .theatre: [3, 0]
        case .game: [4, 0]
        }
    }

    public init?(bytes: [UInt8]) {
        guard bytes.count >= 2 else { return nil }
        switch (bytes[0], bytes[1]) {
        case (0, _): self = .off
        case (1, 1): self = .headTracked
        case (1, _): self = .fixed
        case (2, _): self = .concert
        case (3, _): self = .theatre
        case (4, _): self = .game
        default: return nil
        }
    }
}

public enum Codec: UInt8, Sendable {
    case aac = 0, lhdc = 1, ldac = 2

    public var name: String { ["AAC", "LHDC", "LDAC"][Int(rawValue)] }
}

public struct Battery: Equatable, Sendable {
    public enum Slot: UInt8, Sendable { case left = 0x02, right = 0x03, charger = 0x04, headset = 0x06 }

    public var slot: UInt8
    public var percent: Int
    public var charging: Bool

    public var kind: Slot? { Slot(rawValue: slot) }
}

/// Une commande physique : quel bouton, quel geste, quelle action.
public struct ButtonMapping: Equatable, Sendable {
    public var device: UInt8
    public var button: UInt8
    public var type: UInt8
    public var action: UInt8

    public init(device: UInt8, button: UInt8, type: UInt8, action: UInt8) {
        (self.device, self.button, self.type, self.action) = (device, button, type, action)
    }

    public enum Control: CaseIterable, Sendable {
        case buttonPress, buttonHold, slider, rollerHold

        var button: UInt8 { self == .slider ? 0x05 : self == .rollerHold ? 0x01 : 0x0A }
        var type: UInt8 { self == .buttonHold || self == .rollerHold ? 0x07 : 0x01 }
    }

    public var control: Control? { Control.allCases.first { $0.button == button && $0.type == type } }

    public enum Action {
        public static let none: UInt8 = 0x01, voiceAssistant: UInt8 = 0x0B, noiseControl: UInt8 = 0x0A
        public static let spatialAudio: UInt8 = 0x1B, microphone: UInt8 = 0x1D, preset: UInt8 = 0x22
        public static let bass: UInt8 = 0x23, treble: UInt8 = 0x24
        /// Le contrôle du bruit prend quatre valeurs selon les modes que le geste fait défiler.
        public static let noiseControlAll: Set<UInt8> = [0x0A, 0x14, 0x15, 0x16]
    }

    /// Données de l'écriture qui remplace l'action de ce geste.
    public func writePayload(action: UInt8) -> [UInt8] { [0x01, device, button, type, action] }
}
