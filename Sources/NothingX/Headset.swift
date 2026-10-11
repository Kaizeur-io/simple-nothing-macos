import Foundation
import IOBluetooth
import NothingKit

/// L'appareil relié au Mac, son état, et les réglages qu'on lui envoie.
final class Headset: NSObject, ObservableObject {
    enum Status { case absent, connecting, connected }

    @Published private(set) var status = Status.absent
    @Published private(set) var state = DeviceState()
    @Published private(set) var name = ""
    @Published private(set) var address = ""

    var model: Model? { Model.named(name) }

    private var link: Link?
    private var connectWatch: IOBluetoothUserNotification?
    private var disconnectWatch: IOBluetoothUserNotification?
    private var poll: Timer?
    private let isDemo: Bool

    init(demo: Bool = false) {
        isDemo = demo
        super.init()
        if demo { loadDemo() }
    }

    func start() {
        guard !isDemo, connectWatch == nil else { return }
        connectWatch = IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(deviceConnected(_:device:)))
        attach()
        poll = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in self?.link?.send(Read.battery.rawValue) }
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
        guard let device = paired.first(where: { $0.isConnected() && $0.getServiceRecord(for: nothingService) != nil }) else { return }
        let link = Link(device: device)
        link.onOpen = { [weak self] in
            self?.status = .connected
            Read.allCases.forEach { link.send($0.rawValue) }
        }
        link.onFrame = { [weak self] frame in self?.state.apply(frame) }
        link.onClose = { [weak self] in self?.detach(retry: device.isConnected()) }
        guard link.open() else { return }
        self.link = link
        name = device.name ?? ""
        address = (device.addressString ?? "").uppercased().replacingOccurrences(of: "-", with: ":")
        status = .connecting
        disconnectWatch = device.register(forDisconnectNotification: self, selector: #selector(deviceDisconnected(_:device:)))
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
            (0x4018, [0x04, 0x06, 0x0A, 0x07, 0x01, 0x06, 0x0A, 0x01, 0x0B, 0x06, 0x05, 0x01, 0x23, 0x06, 0x01, 0x07, 0x16]),
        ]
        for (command, payload) in replies { state.apply(Frame(command: command, payload: payload)) }
    }
}
