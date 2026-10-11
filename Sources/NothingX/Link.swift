import Foundation
import IOBluetooth
import NothingKit

/// Service série propre aux appareils Nothing / CMF.
let nothingService = IOBluetoothSDPUUID(bytes: [0xAE, 0xAC, 0x4A, 0x03, 0xDF, 0xF5, 0x49, 0x8F, 0x84, 0x3A, 0x34, 0x48, 0x7C, 0xF1, 0x33, 0xEB] as [UInt8], length: 16)

/// Canal RFCOMM ouvert sur un appareil. Les envois sont espacés : l'appareil répond une trame à la fois.
final class Link: NSObject, IOBluetoothRFCOMMChannelDelegate {
    let device: IOBluetoothDevice
    var onOpen: () -> Void = {}
    var onFrame: (Frame) -> Void = { _ in }
    var onClose: () -> Void = {}

    private var channel: IOBluetoothRFCOMMChannel?
    private var isOpen = false
    private var parser = FrameParser()
    private var sequence: UInt8 = 0
    private var pending: [[UInt8]] = []
    private var pacer: Timer?

    init(device: IOBluetoothDevice) { self.device = device }

    /// Le numéro du canal se lit dans les services que l'appareil déclare ; il change d'un modèle à l'autre.
    func open() -> Bool {
        guard let record = device.getServiceRecord(for: nothingService) else { return false }
        var id: BluetoothRFCOMMChannelID = 0
        guard record.getRFCOMMChannelID(&id) == kIOReturnSuccess else { return false }
        var opened: IOBluetoothRFCOMMChannel?
        guard device.openRFCOMMChannelAsync(&opened, withChannelID: id, delegate: self) == kIOReturnSuccess else { return false }
        channel = opened
        return true
    }

    func send(_ command: UInt16, _ payload: [UInt8] = []) {
        sequence &+= 1
        pending.append(Frame(command: command, sequence: sequence, payload: payload).encoded())
        pump()
    }

    func close() {
        pacer?.invalidate()
        pacer = nil
        pending.removeAll()
        isOpen = false
        channel?.setDelegate(nil)
        channel?.close()
        channel = nil
    }

    private func pump() {
        guard isOpen, pacer == nil, !pending.isEmpty else { return }
        var packet = pending.removeFirst()
        _ = channel?.writeSync(&packet, length: UInt16(packet.count))
        pacer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: false) { [weak self] _ in
            self?.pacer = nil
            self?.pump()
        }
    }

    func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, status error: IOReturn) {
        guard error == kIOReturnSuccess else { return onClose() }
        isOpen = true
        onOpen()
        pump()
    }

    func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        let bytes = [UInt8](UnsafeRawBufferPointer(start: dataPointer, count: dataLength))
        for frame in parser.feed(bytes) { onFrame(frame) }
    }

    func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        isOpen = false
        onClose()
    }
}
