/// Ce qu'un modèle sait faire, d'après la configuration que l'app officielle embarque pour chacun.
/// Sert à ne proposer que les réglages qui existent ; un modèle inconnu garde les valeurs par défaut.
public struct Capabilities: Equatable, Sendable {
    public var noiseControl = true
    /// Modes d'audio spatial proposés, hors « désactivé ». Vide : pas d'audio spatial.
    public var spatial: [SpatialMode] = []
    /// Niveaux du renfort des basses, tels qu'ils circulent. Vide : pas de renfort.
    public var bassSteps: [UInt8] = []
    public var wearDetection = true
    public var ring: [RingTarget] = [.left, .right]
    public var dualConnection = true
    /// Changer la double connexion fait redémarrer l'appareil.
    public var dualReboots = false

    public init() {}

    static let fiveSteps: [UInt8] = [2, 4, 6, 8, 10], threeSteps: [UInt8] = [0, 5, 10]
}

/// Modèles connus. Seul le CMF Headphone Pro a été vérifié sur un appareil réel.
public struct Model: Equatable, Sendable {
    public var id: String
    public var name: String
    public var brand: String
    public var isHeadphones: Bool
    public var verified = false

    public static let headphonePro = Model(id: "B175", name: "Headphone Pro", brand: "CMF", isHeadphones: true, verified: true)

    public static let all: [Model] = [
        headphonePro,
        Model(id: "B170", name: "Headphone (1)", brand: "Nothing", isHeadphones: true),
        Model(id: "B192", name: "Headphone (1) Pro", brand: "Nothing", isHeadphones: true),
        Model(id: "B186", name: "Headphone (a)", brand: "Nothing", isHeadphones: true),
        Model(id: "B181", name: "Ear (1)", brand: "Nothing", isHeadphones: false),
        Model(id: "B155", name: "Ear (2)", brand: "Nothing", isHeadphones: false),
        Model(id: "B157", name: "Ear (stick)", brand: "Nothing", isHeadphones: false),
        Model(id: "B171", name: "Ear", brand: "Nothing", isHeadphones: false),
        Model(id: "B162", name: "Ear (a)", brand: "Nothing", isHeadphones: false),
        Model(id: "B174", name: "Ear (open)", brand: "Nothing", isHeadphones: false),
        Model(id: "B173", name: "Ear (3)", brand: "Nothing", isHeadphones: false),
        Model(id: "B190", name: "Ear (3a)", brand: "Nothing", isHeadphones: false),
        Model(id: "B163", name: "Buds Pro", brand: "CMF", isHeadphones: false),
        Model(id: "B168", name: "Buds", brand: "CMF", isHeadphones: false),
        Model(id: "B172", name: "Buds Pro 2", brand: "CMF", isHeadphones: false),
        Model(id: "B179", name: "Buds 2", brand: "CMF", isHeadphones: false),
        Model(id: "B184", name: "Buds 2 Plus", brand: "CMF", isHeadphones: false),
        Model(id: "B185", name: "Buds 2a", brand: "CMF", isHeadphones: false),
        Model(id: "B189", name: "Clip Pro", brand: "CMF", isHeadphones: false),
        Model(id: "B193", name: "Buds Neo", brand: "CMF", isHeadphones: false),
    ]

    public var fullName: String { brand == "Nothing" ? name : "\(brand) \(name)" }

    public var capabilities: Capabilities {
        var caps = Capabilities()
        if isHeadphones { caps.ring = [.headset] }
        switch id {
        case "B175": (caps.spatial, caps.wearDetection) = ([.concert, .theatre], false)
        case "B170": (caps.spatial, caps.bassSteps) = ([.headTracked, .fixed], Capabilities.fiveSteps)
        case "B192": caps.spatial = [.headTracked, .fixed]
        case "B186": (caps.spatial, caps.bassSteps, caps.wearDetection) = ([.concert, .theatre], Capabilities.threeSteps, false)
        case "B181": (caps.ring, caps.dualConnection) = ([.legacy], false)
        case "B155": caps.dualReboots = true
        case "B157": (caps.noiseControl, caps.dualConnection) = (false, false)
        case "B171", "B162": caps.bassSteps = Capabilities.fiveSteps
        case "B174": (caps.noiseControl, caps.wearDetection) = (false, false)
        case "B173", "B179", "B184": (caps.spatial, caps.bassSteps) = ([.fixed], Capabilities.fiveSteps)
        case "B190": caps.spatial = [.fixed]
        case "B163": caps.dualConnection = false
        case "B168": (caps.bassSteps, caps.dualReboots) = (Capabilities.fiveSteps, true)
        case "B172": (caps.spatial, caps.bassSteps, caps.dualReboots) = ([.fixed], Capabilities.fiveSteps, true)
        case "B185": (caps.bassSteps, caps.wearDetection) = (Capabilities.fiveSteps, false)
        case "B189": (caps.noiseControl, caps.spatial, caps.bassSteps, caps.wearDetection) = (false, [.fixed], Capabilities.threeSteps, false)
        default: break
        }
        return caps
    }

    /// Retrouve le modèle d'après le nom Bluetooth. Le plus long nom qui correspond l'emporte,
    /// pour que « Headphone (1) Pro » ne soit pas pris pour un « Headphone (1) ».
    public static func named(_ bluetoothName: String) -> Model? {
        let wanted = bluetoothName.lowercased()
        return all.filter { wanted.contains($0.fullName.lowercased()) && (wanted.contains("cmf") == ($0.brand == "CMF")) }
            .max { $0.name.count < $1.name.count }
    }
}

extension Model {
    /// Actions que l'app officielle propose pour un geste, d'après sa configuration par modèle.
    /// Vide : le geste n'est pas réglable, ou on ne sait pas ce qu'il accepte.
    public func actions(for mapping: ButtonMapping) -> [UInt8] {
        typealias A = ButtonMapping.Action
        let none = [A.none], tracks = [A.previous, A.next, A.voiceAssistant], volume = [A.volumeUp, A.volumeDown]
        if isHeadphones {
            switch (mapping.button, mapping.type) {
            case (0x05, _): return [A.bass, A.treble]
            case (0x01, 0x07): return [A.noiseControl] + none
            case (0x0A, 0x07) where id == "B192": return [A.voiceAssistant, A.noiseControl, A.microphone] + none
            case (0x0A, 0x01), (0x0A, 0x07):
                let extra = ["B170", "B175"].contains(id) ? A.spatialAudio : A.camera
                return [A.voiceAssistant, A.noiseControl, extra, A.microphone] + (id == "B192" ? [] : [A.preset]) + none
            default: return []
            }
        }
        // Écouteurs : seuls les gestes sur la tige se règlent ici, pas ceux du boîtier.
        guard mapping.button == 0x01, mapping.device == Battery.Slot.left.rawValue || mapping.device == Battery.Slot.right.rawValue else { return [] }
        let noise = capabilities.noiseControl ? [A.noiseControl] : []
        let recent = ["B173", "B190"].contains(id)
        if brand == "CMF" {
            let off = id == "B163" ? [] : none
            switch mapping.type {
            case 0x02: return (id == "B189" ? [] : [A.playPause]) + tracks + off
            case 0x03: return tracks + off
            case 0x07: return id == "B189" ? volume + [A.voiceAssistant] + none : noise + [A.voiceAssistant] + off
            case 0x09: return volume + [A.voiceAssistant] + none
            default: return []
            }
        }
        switch mapping.type {
        case 0x02: return id == "B181" ? [] : tracks
        case 0x03: return tracks + (recent || id == "B181" ? none : [])
        case 0x07:
            if id == "B181" { return noise + none }
            return noise + volume + [A.voiceAssistant] + (recent ? [A.microphone] + none : [])
        case 0x09: return id == "B181" ? [] : noise + volume + [A.voiceAssistant] + none
        default: return []
        }
    }
}
