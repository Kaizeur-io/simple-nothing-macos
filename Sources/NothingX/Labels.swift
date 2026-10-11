import NothingKit

// Libellés de l'app mobile, en français.

extension NoiseMode {
    var levelLabel: String {
        switch self {
        case .low: "Bas"
        case .mid: "Moyen"
        case .high: "Haut"
        case .adaptive: "Adaptatif"
        case .off, .transparency: ""
        }
    }

    var summary: String {
        switch self {
        case .off: "Désactivée"
        case .transparency: "Mode transparence"
        default: tr("Activée · %@", tr(levelLabel))
        }
    }

    static let levels: [NoiseMode] = [.low, .mid, .high, .adaptive]
}

extension Preset {
    var label: String {
        switch self {
        case .dirac: "Dirac Opteo"
        case .pop: "Pop"
        case .rock: "Rock"
        case .electronic: "Électronique"
        case .vocal: "Améliorer les voix"
        case .classical: "Classique"
        case .custom: "Personnalisé"
        }
    }

    /// Version courte, pour le panneau de la barre des menus.
    var shortLabel: String {
        switch self {
        case .electronic: "Électro"
        case .vocal: "Voix"
        case .custom: "Perso"
        default: label
        }
    }

    /// Ordre de l'app mobile.
    static let shown: [Preset] = [.pop, .rock, .electronic, .vocal, .classical, .custom]

    /// Allure de la courbe : médiums, graves, aigus. Sert au dessin, pas au son.
    var shape: (mid: Double, bass: Double, treble: Double) {
        switch self {
        case .pop: (4, 1, 1)
        case .rock: (-1, 4, 3)
        case .electronic: (-3, 5, 4)
        case .vocal: (5, -3, -1)
        case .classical: (1, -1, 4)
        case .dirac, .custom: (0, 0, 0)
        }
    }
}

extension SpatialMode {
    var summary: String {
        switch self {
        case .off: "Désactivé"
        case .fixed: "Mode fixe"
        case .headTracked: "Suivi de tête"
        case .concert: "Mode concert"
        case .theatre: "Mode théâtre"
        case .game: "Mode jeu"
        }
    }
}

extension SpatialMode {
    var shortLabel: String {
        switch self {
        case .off: "Désactivé"
        case .concert: "Concert"
        case .theatre: "Théâtre"
        default: summary
        }
    }
}

extension ButtonMapping.Control {
    /// Actions proposées par l'app mobile pour cette commande.
    var actions: [(label: String, code: UInt8)] {
        switch self {
        case .buttonPress, .buttonHold:
            [("Assistant vocal", ButtonMapping.Action.voiceAssistant), ("Contrôle du bruit", ButtonMapping.Action.noiseControl),
             ("Audio spatial", ButtonMapping.Action.spatialAudio), ("Micro activé/coupé", ButtonMapping.Action.microphone),
             ("Préréglage d'égaliseur", ButtonMapping.Action.preset), ("Aucune action", ButtonMapping.Action.none)]
        case .slider:
            [("Réglage des basses", ButtonMapping.Action.bass), ("Réglage des aigus", ButtonMapping.Action.treble)]
        case .rollerHold:
            [("Contrôle du bruit", ButtonMapping.Action.noiseControl), ("Aucune action", ButtonMapping.Action.none)]
        }
    }

    func label(for code: UInt8) -> String {
        if ButtonMapping.Action.noiseControlAll.contains(code) { return "Contrôle du bruit" }
        return actions.first { $0.code == code }?.label ?? String(format: "0x%02X", code)
    }
}
