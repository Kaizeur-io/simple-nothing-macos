// Numéros de commande et valeurs échangées. Les lectures ont été relevées sur un CMF Headphone Pro ;
// les écritures viennent de la documentation communautaire (docs/protocole.md).

public enum Read: UInt16, CaseIterable, Sendable {
    case battery = 0xC007, firmware = 0xC042, identity = 0xC006, noise = 0xC01E, preset = 0xC050
    case spatial = 0xC04F, lowLatency = 0xC041, bass = 0xC04E, gestures = 0xC018
    case dualConnection = 0xC027, codec = 0xC029, soundProfile = 0xC05A, customEQ = 0xC044
    case wearDetection = 0xC00E

    /// La réponse porte le même numéro, bit de poids fort baissé.
    public var reply: UInt16 { rawValue & 0x7FFF }
}

public enum Write: UInt16, Sendable {
    case noise = 0xF00F, preset = 0xF01D, spatial = 0xF052, lowLatency = 0xF040
    case gesture = 0xF003, dualConnection = 0xF01A, customEQ = 0xF041
    /// Relie ou détache un des appareils de la double connexion : 1 ou 0, puis son adresse.
    case dualDevice = 0xF01B
    /// Renfort des basses : activé, niveau.
    case bass = 0xF051
    /// Pause automatique quand on retire l'appareil : deux octets nuls, puis 1 ou 0.
    case wearDetection = 0xF004
    /// Fait sonner l'appareil pour le retrouver.
    case ring = 0xF002
}

/// Ce qu'on fait sonner. Le format de la commande dépend de la forme de l'appareil.
public enum RingTarget: Sendable {
    case headset, left, right
    /// Ear (1) : un seul octet, les deux écouteurs à la fois.
    case legacy

    public func payload(on: Bool) -> [UInt8] {
        let flag: UInt8 = on ? 1 : 0
        switch self {
        case .headset: return [Battery.Slot.headset.rawValue, flag]
        case .left: return [Battery.Slot.left.rawValue, flag]
        case .right: return [Battery.Slot.right.rawValue, flag]
        case .legacy: return [flag]
        }
    }
}

/// Lectures qui prennent un paramètre, envoyées à part.
public enum Query {
    /// Appareils de la double connexion, par pages : la donnée est le nombre d'appareils déjà reçus.
    public static let dualDevices: UInt16 = 0xC028
}

/// Envois spontanés de l'appareil, sans requête.
public enum Push {
    public static let battery: UInt16 = 0xE001
    public static let noise: UInt16 = 0xE003
    /// Un appareil de la double connexion vient de se relier ou de partir.
    public static let dualDevice: UInt16 = 0xE00E
}

public enum NoiseMode: UInt8, CaseIterable, Sendable {
    case high = 0x01, mid = 0x02, low = 0x03, adaptive = 0x04, off = 0x05, transparency = 0x07

    public var isCancelling: Bool { self != .off && self != .transparency }
}

public enum Preset: UInt8, CaseIterable, Sendable {
    case dirac = 0, rock = 1, electronic = 2, pop = 3, vocal = 4, classical = 5, custom = 6
}

public enum SpatialMode: Hashable, Sendable {
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

/// Un appareil que le casque connaît pour la double connexion.
public struct DualDevice: Equatable, Sendable {
    public var address: String
    public var name: String
    public var isConnected: Bool
    /// L'appareil depuis lequel on interroge le casque.
    public var isSelf: Bool

    /// Données de l'écriture qui relie ou détache cet appareil.
    public func writePayload(connect: Bool) -> [UInt8] {
        [connect ? 1 : 0] + address.split(separator: ":").compactMap { UInt8($0, radix: 16) }
    }
}

/// Courbe personnalisée : trois gains en décibels, de -6 à +6.
public struct CustomEQ: Equatable, Sendable {
    public var mid: Double
    public var bass: Double
    public var treble: Double

    public static let range = -6.0...6.0

    public init(mid: Double, bass: Double, treble: Double) {
        (self.mid, self.bass, self.treble) = (mid, bass, treble)
    }

    /// Les trois filtres du CMF Headphone Pro : type sur le fil, fréquence, facteur de qualité.
    private static let peak: (type: UInt8, frequency: Float, quality: Float) = (1, 980, 0.7)
    private static let highShelf: (type: UInt8, frequency: Float, quality: Float) = (2, 3500, 1.0)
    private static let lowShelf: (type: UInt8, frequency: Float, quality: Float) = (0, 140, 0.8)

    /// Nombre de filtres, gain d'ensemble, puis pour chaque filtre : type, gain, fréquence, qualité
    /// (flottants de 32 bits, petit-boutistes), et trois octets nuls par filtre en fin de trame.
    /// Le gain d'ensemble compense le plus fort relèvement pour ne pas saturer.
    public var payload: [UInt8] {
        let bands = [(Self.peak, mid), (Self.highShelf, treble), (Self.lowShelf, bass)]
        var bytes: [UInt8] = [UInt8(bands.count)] + Self.bytes(Float(-max(0, mid, bass, treble)))
        for (filter, gain) in bands {
            bytes += [filter.type] + Self.bytes(Float(gain)) + Self.bytes(filter.frequency) + Self.bytes(filter.quality)
        }
        return bytes + [UInt8](repeating: 0, count: bands.count * 3)
    }

    public init?(payload: [UInt8]) {
        guard let count = payload.first, count > 0, payload.count >= 5 + Int(count) * 13 else { return nil }
        var gains: [UInt8: Double] = [:]
        for band in 0..<Int(count) {
            let start = 5 + band * 13
            gains[payload[start]] = Double(Self.float(Array(payload[(start + 1)...(start + 4)])))
        }
        guard let mid = gains[Self.peak.type], let treble = gains[Self.highShelf.type], let bass = gains[Self.lowShelf.type] else { return nil }
        self.init(mid: mid, bass: bass, treble: treble)
    }

    private static func bytes(_ value: Float) -> [UInt8] { withUnsafeBytes(of: value.bitPattern.littleEndian) { Array($0) } }
    private static func float(_ bytes: [UInt8]) -> Float {
        Float(bitPattern: UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24)
    }
}
