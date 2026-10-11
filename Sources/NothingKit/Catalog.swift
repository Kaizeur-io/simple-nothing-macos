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

    /// Retrouve le modèle d'après le nom Bluetooth. Le plus long nom qui correspond l'emporte,
    /// pour que « Headphone (1) Pro » ne soit pas pris pour un « Headphone (1) ».
    public static func named(_ bluetoothName: String) -> Model? {
        let wanted = bluetoothName.lowercased()
        return all.filter { wanted.contains($0.fullName.lowercased()) && (wanted.contains("cmf") == ($0.brand == "CMF")) }
            .max { $0.name.count < $1.name.count }
    }
}
