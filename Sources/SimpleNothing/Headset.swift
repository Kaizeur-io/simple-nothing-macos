import CoreBluetooth
import Foundation
import IOBluetooth
import NothingKit

/// L'appareil relié au Mac, son état, et les réglages qu'on lui envoie.
final class Headset: NSObject, ObservableObject {
    enum Status { case absent, connecting, connected, unauthorized }

    @Published private(set) var status = Status.absent
    @Published private(set) var state = DeviceState()
    @Published private(set) var name = ""
    @Published private(set) var address = ""
    /// Ce qui sonne en ce moment, à la demande de l'utilisateur.
    @Published private(set) var ringing: RingTarget?

    var model: Model? { Model.named(name) }
    /// Réglages à proposer ; ceux du dernier appareil vu quand aucun n'est relié.
    var capabilities: Capabilities { (name.isEmpty ? shownModel : model)?.capabilities ?? Capabilities() }
    /// Le modèle à dessiner : celui qui est relié, sinon le dernier qu'on a vu.
    var shownModel: Model? { model ?? Model.named(UserDefaults.standard.string(forKey: "lastDevice") ?? "") }

    /// Ce qu'il faut faire quand aucun appareil n'est affiché.
    var hint: String {
        switch status {
        case .unauthorized: "Bluetooth n'est pas autorisé pour cette app : Réglages › Confidentialité et sécurité › Bluetooth."
        case .connecting: "Connexion en cours…"
        default:
            connectFailed ? "Appareil introuvable : vérifiez qu'il est allumé et à portée."
                : canConnect ? "Allumez votre appareil, puis cliquez sur Connecter."
                : "Allumez votre appareil et reliez-le au Mac dans Réglages › Bluetooth."
        }
    }

    var statusLabel: String {
        switch status {
        case .connected: "Connecté"
        case .connecting: "Connexion en cours"
        case .unauthorized: "Non autorisé"
        case .absent: "Déconnecté"
        }
    }

    /// Le volet des réglages à ouvrir pour débloquer la situation.
    var settingsURL: URL {
        URL(string: status == .unauthorized ? "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth" : "x-apple.systempreferences:com.apple.BluetoothSettings")!
    }

    /// Un appareil déjà jumelé au Mac est connu : on peut proposer de s'y relier depuis l'app.
    var canConnect: Bool { status == .absent && UserDefaults.standard.string(forKey: "lastDevice") != nil }

    /// Toutes les trames reçues, pour le diagnostic.
    var onFrame: ((Frame) -> Void)?
    /// Un appareil vient de se relier au Mac (et non : l'app l'a trouvé déjà là en démarrant).
    var onArrival: (() -> Void)?
    /// La batterie vient de passer sous le seuil d'alerte.
    var onLowBattery: ((Int) -> Void)?

    private var link: Link?
    private var connectWatch: IOBluetoothUserNotification?
    private var disconnectWatch: IOBluetoothUserNotification?
    private var poll: Timer?
    private var permission: BluetoothPermission?
    private var announceArrival = false
    /// macOS signale aussi, à l'inscription, les appareils déjà reliés : ceux-là ne sont pas des arrivées.
    private var watchingArrivals = false
    private var dualPages = 0
    /// Tentatives d'ouverture du canal restées sans succès : chacune attend deux fois plus que la précédente.
    private var failures = 0
    private var opening: Date?
    private var lowBatteryTold = false
    /// La dernière demande de connexion faite depuis l'app n'a pas abouti.
    private var connectFailed = false
    private var ringStop: DispatchWorkItem?
    private let isDemo: Bool

    init(demo: Bool = false) {
        isDemo = demo
        super.init()
        if demo { loadDemo() }
    }

    func start() {
        guard !isDemo, permission == nil else { return }
        let permission = BluetoothPermission()
        self.permission = permission
        permission.request { [weak self] allowed in
            guard let self else { return }
            guard allowed else { return self.status = .unauthorized }
            self.connectWatch = IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(self.deviceConnected(_:device:)))
            self.attach()
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in self?.watchingArrivals = true }
            // L'appareil annonce de lui-même sa batterie quand elle change : cette relecture n'est qu'un filet.
            self.poll = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in self?.link?.send(Read.battery.rawValue) }
        }
    }

    /// À la fermeture de l'app : on rend le canal au lieu de laisser macOS constater sa disparition.
    func stop() {
        poll?.invalidate()
        connectWatch?.unregister()
        disconnectWatch?.unregister()
        ring(nil)
        link?.close()
        link = nil
    }

    // MARK: Connexion au Mac

    /// Relie au Mac l'appareil jumelé, comme le ferait le menu Bluetooth de macOS. On vise le dernier
    /// appareil vu ; la suite (canal, état, carte) passe par le chemin habituel des arrivées.
    func connect() {
        guard canConnect, !isDemo else { return }
        let paired = ((IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []).filter { $0.getServiceRecord(for: nothingService) != nil }
        let last = UserDefaults.standard.string(forKey: "lastDevice")
        guard let device = paired.first(where: { $0.name == last }) ?? paired.first else { return failConnect() }
        Journal.note("connexion demandée depuis l'app")
        connectFailed = false
        status = .connecting
        if device.isConnected() { return attach() }
        if device.openConnection(self) != kIOReturnSuccess { failConnect() }
    }

    @objc private func connectionComplete(_ device: IOBluetoothDevice, status result: IOReturn) {
        guard result == kIOReturnSuccess else { return failConnect() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.attach() }
    }

    private func failConnect() {
        Journal.note("connexion demandée : appareil introuvable")
        guard link == nil else { return }
        connectFailed = true
        status = .absent
    }

    /// Détache l'appareil du Mac : notre canal d'abord, puis la liaison Bluetooth elle-même.
    func disconnect() {
        guard let device = link?.device else { return }
        Journal.note("déconnexion demandée depuis l'app")
        ring(nil)
        detach(retry: false)
        device.closeConnection()
    }

    // MARK: Réglages

    func setNoise(_ mode: NoiseMode) {
        state.noise = mode
        write(.noise, [0x01, mode.rawValue, 0x00], thenRead: .noise)
    }

    func setPreset(_ preset: Preset) {
        state.preset = preset
        write(.preset, [preset.rawValue, 0x00], thenRead: .preset)
    }

    func setSpatial(_ mode: SpatialMode) {
        state.spatial = mode
        write(.spatial, mode.bytes, thenRead: .spatial)
    }

    func setLowLatency(_ on: Bool) {
        state.lowLatency = on
        write(.lowLatency, [on ? 0x01 : 0x02, 0x00], thenRead: .lowLatency)
    }

    func setDualConnection(_ on: Bool) {
        state.dualConnection = on
        write(.dualConnection, [on ? 0x01 : 0x00], thenRead: .dualConnection)
    }

    /// Relie ou détache un des appareils que le casque connaît. La liste est relue ensuite.
    func setDualDevice(_ device: DualDevice, connected: Bool) {
        guard let index = state.dualDevices.firstIndex(of: device) else { return }
        state.dualDevices[index].isConnected = connected
        link?.send(Write.dualDevice.rawValue, device.writePayload(connect: connected))
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in self?.requestDualDevices(reset: false) }
    }

    func setBass(on: Bool, level: UInt8? = nil) {
        let level = level ?? state.bassLevel ?? capabilities.bassSteps.first ?? 0
        (state.bassEnabled, state.bassLevel) = (on, level)
        write(.bass, [on ? 0x01 : 0x00, level], thenRead: .bass)
    }

    func setWearDetection(_ on: Bool) {
        state.wearDetection = on
        write(.wearDetection, [0x00, 0x00, on ? 0x01 : 0x00], thenRead: .wearDetection)
    }

    /// Fait sonner l'appareil pour le retrouver, ou l'arrête avec `nil`. La sonnerie est forte :
    /// elle s'arrête d'elle-même au bout de trente secondes.
    func ring(_ target: RingTarget?) {
        ringStop?.cancel()
        if let ringing { link?.send(Write.ring.rawValue, ringing.payload(on: false)) }
        ringing = target
        guard let target else { return }
        link?.send(Write.ring.rawValue, target.payload(on: true))
        let stop = DispatchWorkItem { [weak self] in self?.ring(nil) }
        ringStop = stop
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: stop)
    }

    func setCustomEQ(_ curve: CustomEQ) {
        state.customEQ = curve
        write(.customEQ, curve.payload, thenRead: .customEQ)
    }

    /// Passe au mode de bruit suivant : réduction, transparence, désactivé. Renvoie le mode choisi.
    @discardableResult
    func cycleNoise() -> NoiseMode? {
        guard status == .connected, let noise = state.noise else { return nil }
        let last = NoiseMode(rawValue: UInt8(UserDefaults.standard.integer(forKey: "lastNoiseLevel"))) ?? .high
        let next: NoiseMode = noise.isCancelling ? .transparency : noise == .transparency ? .off : last.isCancelling ? last : .high
        setNoise(next)
        return next
    }

    func setAction(_ action: UInt8, for control: ButtonMapping.Control) {
        guard let index = state.gestures.firstIndex(where: { $0.control == control }) else { return }
        state.gestures[index].action = action
        write(.gesture, state.gestures[index].writePayload(action: action), thenRead: .gestures)
    }

    /// Même chose pour un geste quelconque, repéré par son appareil, son bouton et son type.
    func setAction(_ action: UInt8, for mapping: ButtonMapping) {
        guard let index = state.gestures.firstIndex(where: { ($0.device, $0.button, $0.type) == (mapping.device, mapping.button, mapping.type) }) else { return }
        state.gestures[index].action = action
        write(.gesture, state.gestures[index].writePayload(action: action), thenRead: .gestures)
    }

    /// Après chaque écriture on relit la valeur : l'écran montre ce que l'appareil a réellement retenu.
    private func write(_ command: Write, _ payload: [UInt8], thenRead read: Read) {
        guard let link else { return }
        link.send(command.rawValue, payload)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak link] in link?.send(read.rawValue) }
    }

    // MARK: Liaison

    private func attach() {
        guard link == nil else { return }
        let paired = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
        guard let device = paired.first(where: { $0.isConnected() && $0.getServiceRecord(for: nothingService) != nil }) else {
            announceArrival = false
            if status == .connecting { status = .absent }
            return
        }
        let link = Link(device: device)
        link.onOpen = { [weak self] in
            guard let self else { return }
            Journal.note(String(format: "canal ouvert en %.1f s", Date().timeIntervalSince(self.opening ?? Date())))
            self.status = .connected
            self.connectFailed = false
            // On ne demande pas ce que le modèle n'a pas.
            let caps = self.capabilities
            let skipped = [caps.wearDetection ? nil : Read.wearDetection, caps.bassSteps.isEmpty ? Read.bass : nil].compactMap { $0 }
            Read.allCases.filter { !skipped.contains($0) }.forEach { link.send($0.rawValue) }
            self.requestDualDevices()
        }
        link.onFrame = { [weak self] frame in self?.receive(frame) }
        link.onClose = { [weak self] in
            Journal.note("canal fermé")
            self?.detach(retry: device.isConnected())
        }
        opening = Date()
        guard link.open() else {
            Journal.note("ouverture du canal refusée")
            return retryLater()
        }
        self.link = link
        // Une ouverture qui ne répond jamais ne doit pas laisser l'app sur « connexion… » indéfiniment.
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self, weak link] in
            guard let self, let link, self.link === link, self.status != .connected else { return }
            Journal.note("ouverture du canal sans réponse")
            self.detach(retry: device.isConnected())
        }
        name = device.name ?? ""
        UserDefaults.standard.set(name, forKey: "lastDevice")
        address = (device.addressString ?? "").uppercased().replacingOccurrences(of: "-", with: ":")
        status = .connecting
        disconnectWatch = device.register(forDisconnectNotification: self, selector: #selector(deviceDisconnected(_:device:)))
    }

    private func receive(_ frame: Frame) {
        // On ne publie que ce qui change : une réponse identique ne redessine rien.
        var next = state
        let news = next.apply(frame)
        if next != state { state = next }
        onFrame?(frame)
        if frame.command == Query.dualDevices & 0x7FFF, news, dualPages < 20 {
            // La liste arrive par pages : tant qu'il y a du nouveau, on demande la suite.
            dualPages += 1
            link?.send(Query.dualDevices, [UInt8(state.dualDevices.count & 0xFF)])
        }
        failures = 0
        if frame.command == Push.dualDevice { requestDualDevices() }
        if let level = state.mainBattery {
            if level.charging || level.percent > 25 {
                lowBatteryTold = false
            } else if level.percent <= 20, !lowBatteryTold {
                lowBatteryTold = true
                // À la connexion, la carte d'arrivée affiche déjà le niveau.
                if !announceArrival { onLowBattery?(level.percent) }
            }
        }
        if announceArrival, state.mainBattery != nil {
            announceArrival = false
            Journal.note("état reçu, carte de connexion")
            onArrival?()
        }
    }

    private func requestDualDevices(reset: Bool = true) {
        if reset { state.dualDevices.removeAll() }
        dualPages = 1
        link?.send(Query.dualDevices, [0])
    }

    private func detach(retry: Bool) {
        link?.close()
        link = nil
        disconnectWatch?.unregister()
        disconnectWatch = nil
        status = .absent
        state = DeviceState()
        ringStop?.cancel()
        ringing = nil
        lowBatteryTold = false
        if retry { retryLater() }
    }

    /// Nouvel essai après un échec, de plus en plus espacé (3, 6, 12… secondes), puis on renonce
    /// jusqu'à la prochaine connexion : insister occuperait la radio Bluetooth pour rien.
    private func retryLater() {
        guard failures < 6 else { return Journal.note("abandon après \(failures) essais") }
        let delay = min(60, 3 * pow(2, Double(failures)))
        failures += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.attach() }
    }

    @objc private func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        guard link == nil, device.getServiceRecord(for: nothingService) != nil else { return }
        // Au lancement, macOS rejoue les connexions déjà établies : rien de neuf, un simple rattrapage suffit.
        guard watchingArrivals else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in self?.attach() }
            return
        }
        // L'app le dit tout de suite ; le canal, lui, attend un instant que l'appareil ait ouvert son
        // service. Quatre secondes d'attente ont été essayées pour ménager la radio : le journal n'a
        // montré aucun gain, seulement une app qui semblait ne pas voir l'appareil.
        guard status != .connecting else { return }  // macOS annonce souvent la même arrivée deux fois
        Journal.note("appareil relié")
        Journal.watchMainThread(for: 30)
        failures = 0
        announceArrival = true
        status = .connecting
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.attach() }
    }

    @objc private func deviceDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        Journal.note("appareil parti")
        detach(retry: false)
    }

    private func loadDemo() {
        name = Launch.value("--demo-name") ?? "CMF Headphone Pro"
        address = "00:00:00:00:00:00"
        status = .connected
        let replies: [(UInt16, [UInt8])] = [
            (0x4007, [0x01, 0x06, 0x2D]), (0x4042, Array("1.0.1.49".utf8)), (0x4006, [0x01] + Array("6,4,CI0000000000000000".utf8)),
            (0x401E, [0x01, 0x01, 0x00]), (0x4050, [0x03]), (0x404F, [0x02, 0x00]), (0x4041, [0x00]), (0x4027, [0x01]),
            (0x4029, [0x00]), (0x405A, [0x00]),
            (0x4028, [0x00, 0x00, 0x02, 0x11, 0, 0, 0, 0, 0, 1, 0x0B] + Array("MacBook Pro".utf8) + [0x00, 0, 0, 0, 0, 0, 2, 0x09] + Array("Phone (3)".utf8)),
            (0x4018, [0x04, 0x06, 0x0A, 0x07, 0x01, 0x06, 0x0A, 0x01, 0x0B, 0x06, 0x05, 0x01, 0x23, 0x06, 0x01, 0x07, 0x16]),
        ]
        for (command, payload) in replies { state.apply(Frame(command: command, payload: payload)) }
        if model?.isHeadphones == false {
            state.apply(Frame(command: 0x4007, payload: [0x03, 0x02, 0x50, 0x03, 0x4B, 0x04, 0xBC]))
            let side: [UInt8] = [0x01, 0x02, 0x09, 0x01, 0x03, 0x08, 0x01, 0x07, 0x16, 0x01, 0x09, 0x01]
            state.apply(Frame(command: 0x4018, payload: [0x08] + [0x02, 0x03].flatMap { device in stride(from: 0, to: 12, by: 3).flatMap { [device] + side[$0..<($0 + 3)] } }))
        }
        if let level = capabilities.bassSteps.dropFirst().first { state.apply(Frame(command: 0x404E, payload: [0x01, level])) }
        if capabilities.wearDetection { state.apply(Frame(command: 0x400E, payload: [0x00, 0x00, 0x01])) }
        if Launch.arguments.contains("--demo-absent") { (status, state) = (.absent, DeviceState()) }
        if let percent = Launch.value("--demo-battery").flatMap(UInt8.init) { state.apply(Frame(command: 0x4007, payload: [0x01, 0x06, percent])) }
        if CommandLine.arguments.contains("--demo-custom") {
            state.preset = .custom
            state.customEQ = CustomEQ(mid: 2, bass: -3, treble: 5)
        }
    }
}

/// Demande l'accord Bluetooth sans figer l'app. Le premier appel à IOBluetooth attend la réponse
/// de l'utilisateur sur le fil principal : on ne s'en sert donc qu'une fois l'accord donné.
private final class BluetoothPermission: NSObject, CBCentralManagerDelegate {
    private var manager: CBCentralManager?
    private var answer: ((Bool) -> Void)?

    func request(_ answer: @escaping (Bool) -> Void) {
        switch CBCentralManager.authorization {
        case .allowedAlways: answer(true)
        case .denied, .restricted: answer(false)
        default:
            self.answer = answer
            manager = CBCentralManager(delegate: self, queue: .main, options: [CBCentralManagerOptionShowPowerAlertKey: false])
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard CBCentralManager.authorization != .notDetermined else { return }
        answer?(CBCentralManager.authorization == .allowedAlways)
        answer = nil
        manager = nil
    }
}
