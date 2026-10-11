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

    var model: Model? { Model.named(name) }

    /// Ce qu'il faut faire quand aucun appareil n'est affiché.
    var hint: String {
        switch status {
        case .unauthorized: "Bluetooth n'est pas autorisé pour cette app : Réglages › Confidentialité et sécurité › Bluetooth."
        case .connecting: "Connexion en cours…"
        default: "Allumez votre appareil et reliez-le au Mac dans Réglages › Bluetooth."
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

    /// Toutes les trames reçues, pour le diagnostic.
    var onFrame: ((Frame) -> Void)?
    /// Un appareil vient de se relier au Mac (et non : l'app l'a trouvé déjà là en démarrant).
    var onArrival: (() -> Void)?

    private var link: Link?
    private var connectWatch: IOBluetoothUserNotification?
    private var disconnectWatch: IOBluetoothUserNotification?
    private var poll: Timer?
    private var permission: BluetoothPermission?
    private var announceArrival = false
    private var dualPages = 0
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
            self.poll = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in self?.link?.send(Read.battery.rawValue) }
        }
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
            return
        }
        let link = Link(device: device)
        link.onOpen = { [weak self] in
            self?.status = .connected
            Read.allCases.forEach { link.send($0.rawValue) }
            self?.requestDualDevices()
        }
        link.onFrame = { [weak self] frame in self?.receive(frame) }
        link.onClose = { [weak self] in self?.detach(retry: device.isConnected()) }
        guard link.open() else { return }
        self.link = link
        name = device.name ?? ""
        address = (device.addressString ?? "").uppercased().replacingOccurrences(of: "-", with: ":")
        status = .connecting
        disconnectWatch = device.register(forDisconnectNotification: self, selector: #selector(deviceDisconnected(_:device:)))
    }

    private func receive(_ frame: Frame) {
        let news = state.apply(frame)
        onFrame?(frame)
        if frame.command == Query.dualDevices & 0x7FFF, news, dualPages < 20 {
            // La liste arrive par pages : tant qu'il y a du nouveau, on demande la suite.
            dualPages += 1
            link?.send(Query.dualDevices, [UInt8(state.dualDevices.count & 0xFF)])
        }
        if frame.command == Push.dualDevice { requestDualDevices() }
        if announceArrival, state.mainBattery != nil {
            announceArrival = false
            onArrival?()
        }
    }

    private func requestDualDevices() {
        state.dualDevices.removeAll()
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
        if retry { DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in self?.attach() } }
    }

    @objc private func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        // L'appareil met un instant à ouvrir son service après la connexion audio.
        if link == nil { announceArrival = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.attach() }
    }

    @objc private func deviceDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        detach(retry: false)
    }

    private func loadDemo() {
        name = "CMF Headphone Pro"
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
