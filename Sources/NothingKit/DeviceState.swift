/// Ce que l'on sait de l'appareil. Chaque champ reste vide tant que l'appareil ne l'a pas donné.
public struct DeviceState: Equatable, Sendable {
    public var battery: [Battery] = []
    public var firmware: String?
    public var serial: String?
    public var noise: NoiseMode?
    public var preset: Preset?
    public var spatial: SpatialMode?
    public var lowLatency: Bool?
    public var bassEnabled: Bool?
    /// Niveau du renfort des basses tel qu'il circule ; `Capabilities.bassSteps` donne les valeurs possibles.
    public var bassLevel: UInt8?
    public var wearDetection: Bool?
    public var gestures: [ButtonMapping] = []
    public var dualConnection: Bool?
    public var codec: Codec?
    public var soundProfile: Bool?
    public var customEQ: CustomEQ?
    public var dualDevices: [DualDevice] = []

    public init() {}

    /// Niveau à afficher : le casque, ou à défaut l'écouteur le plus faible.
    public var mainBattery: Battery? {
        battery.first { $0.kind == .headset } ?? battery.filter { $0.kind != .charger }.min { $0.percent < $1.percent }
    }

    public func gesture(_ control: ButtonMapping.Control) -> ButtonMapping? { gestures.first { $0.control == control } }

    /// Intègre une trame reçue. Renvoie faux si elle ne nous apprend rien.
    @discardableResult
    public mutating func apply(_ frame: Frame) -> Bool {
        let data = frame.payload
        switch frame.command {
        case Read.battery.reply, Push.battery:
            guard let count = data.first, data.count >= 1 + Int(count) * 2 else { return false }
            battery = (0..<Int(count)).map { i in
                Battery(slot: data[1 + i * 2], percent: Int(data[2 + i * 2] & 0x7F), charging: data[2 + i * 2] & 0x80 != 0)
            }
        case Read.firmware.reply:
            firmware = String(decoding: data, as: UTF8.self)
        case Read.identity.reply:
            // Lignes « type,rang,valeur » ; le rang 4 est le numéro de série.
            let lines = String(decoding: data.dropFirst(), as: UTF8.self).split(whereSeparator: \.isNewline)
            for line in lines {
                let fields = line.split(separator: ",", maxSplits: 2)
                if fields.count == 3, fields[1] == "4" { serial = String(fields[2]) }
            }
        case Read.noise.reply, Push.noise:
            guard data.count > 1, let mode = NoiseMode(rawValue: data[1]) else { return false }
            noise = mode
        case Read.preset.reply:
            guard let byte = data.first, let value = Preset(rawValue: byte) else { return false }
            preset = value
        case Read.spatial.reply:
            guard let mode = SpatialMode(bytes: data) else { return false }
            spatial = mode
        case Read.lowLatency.reply:
            guard let byte = data.first else { return false }
            lowLatency = byte == 1
        case Read.bass.reply:
            guard data.count >= 2 else { return false }
            bassEnabled = data[0] == 1
            bassLevel = data[1]
        case Read.wearDetection.reply:
            guard data.count >= 3 else { return false }
            wearDetection = data[2] == 1
        case Read.gestures.reply:
            guard let count = data.first, data.count >= 1 + Int(count) * 4 else { return false }
            gestures = (0..<Int(count)).map { i in
                ButtonMapping(device: data[1 + i * 4], button: data[2 + i * 4], type: data[3 + i * 4], action: data[4 + i * 4])
            }
        case Read.dualConnection.reply:
            guard let byte = data.first else { return false }
            dualConnection = byte == 1
        case Read.codec.reply:
            guard let byte = data.first, let value = Codec(rawValue: byte) else { return false }
            codec = value
        case Read.soundProfile.reply:
            guard let byte = data.first else { return false }
            soundProfile = byte == 1
        case Read.customEQ.reply:
            customEQ = CustomEQ(payload: data)
        case Query.dualDevices & 0x7FFF:
            return addDualDevices(data)
        default:
            return false
        }
        return true
    }

    /// Une page de la liste : deux octets d'en-tête, le nombre d'appareils, puis pour chacun un octet
    /// d'état, six d'adresse, la longueur du nom et le nom. Renvoie vrai s'il y avait du nouveau,
    /// auquel cas il faut demander la page suivante.
    private mutating func addDualDevices(_ data: [UInt8]) -> Bool {
        guard data.count > 2 else { return false }
        var offset = 3, added = false
        for _ in 0..<Int(data[2]) {
            guard offset + 8 <= data.count else { break }
            let length = Int(data[offset + 7] & 0x7F)
            guard offset + 8 + length <= data.count else { break }
            let device = DualDevice(address: data[(offset + 1)...(offset + 6)].map { ($0 < 16 ? "0" : "") + String($0, radix: 16, uppercase: true) }.joined(separator: ":"),
                                    name: String(decoding: data[(offset + 8)..<(offset + 8 + length)], as: UTF8.self),
                                    isConnected: data[offset] & 0x0F != 0, isSelf: data[offset] & 0xF0 != 0)
            if let index = dualDevices.firstIndex(where: { $0.address == device.address }) {
                dualDevices[index] = device
            } else {
                dualDevices.append(device)
                added = true
            }
            offset += 8 + length
        }
        return added
    }
}
