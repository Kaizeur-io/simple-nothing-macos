// Interroge un appareil Nothing / CMF en lecture seule, directement sur son canal Bluetooth.
//
//   tools/build-probe.sh && .build/probe            (appareil déjà connecté au Mac)
//
// N'envoie que des requêtes de lecture (commandes 0xC0xx) : rien n'est modifié sur l'appareil.
// Sert à vérifier que le protocole répond avant d'écrire l'application.
//
// Format des trames, d'après la documentation communautaire du protocole (projets Ear (web) et BudsLink) :
//   55 60 01 | commande (2 octets, petit-boutiste) | longueur (2 octets) | n° de séquence | données | CRC16

import Foundation
import IOBluetooth

/// Service série propre aux appareils Nothing / CMF.
let serviceUUID: [UInt8] = [0xAE, 0xAC, 0x4A, 0x03, 0xDF, 0xF5, 0x49, 0x8F, 0x84, 0x3A, 0x34, 0x48, 0x7C, 0xF1, 0x33, 0xEB]

let reads: [(UInt16, String)] = [
    (0xC007, "batterie"), (0xC042, "firmware"), (0xC006, "numéro de série"), (0xC01E, "réduction du bruit"),
    (0xC01F, "égaliseur"), (0xC04F, "audio spatial"), (0xC041, "faible latence"), (0xC04E, "renfort des basses"),
    (0xC018, "commandes"),
]
let batterySlots: [UInt8: String] = [0x02: "gauche", 0x03: "droite", 0x04: "boîtier", 0x06: "casque"]
let noiseModes: [UInt8: String] = [0x01: "réduction · haut", 0x02: "réduction · moyen", 0x03: "réduction · bas",
                                   0x04: "réduction · adaptatif", 0x05: "désactivée", 0x07: "transparence"]

func hex(_ bytes: [UInt8]) -> String { bytes.isEmpty ? "(vide)" : bytes.map { String(format: "%02x", $0) }.joined(separator: " ") }

func crc16(_ data: [UInt8]) -> UInt16 {
    var crc: UInt16 = 0xFFFF
    for byte in data {
        crc ^= UInt16(byte)
        for _ in 0..<8 { crc = crc & 1 == 1 ? (crc >> 1) ^ 0xA001 : crc >> 1 }
    }
    return crc
}

func frame(_ command: UInt16, seq: UInt8) -> [UInt8] {
    precondition(command >> 8 == 0xC0, "cet outil n'envoie que des lectures (0xC0xx)")
    let head: [UInt8] = [0x55, 0x60, 0x01, UInt8(command & 0xFF), UInt8(command >> 8), 0x00, 0x00, seq]
    let crc = crc16(head)
    return head + [UInt8(crc & 0xFF), UInt8(crc >> 8)]
}

func describe(_ command: UInt16, _ data: [UInt8]) -> String {
    switch command {
    case 0x4007, 0xE001:
        guard let count = data.first, data.count >= 1 + Int(count) * 2 else { return "" }
        return "batterie : " + (0..<Int(count)).map { i in
            let slot = data[1 + i * 2], level = data[2 + i * 2]
            return "\(batterySlots[slot] ?? String(format: "0x%02x", slot)) \(level & 0x7F) %\(level & 0x80 != 0 ? " (en charge)" : "")"
        }.joined(separator: ", ")
    case 0x4042: return "firmware : " + (String(bytes: data, encoding: .ascii) ?? "")
    case 0x401E, 0xE003: return data.count > 1 ? "réduction du bruit : " + (noiseModes[data[1]] ?? String(format: "0x%02x", data[1])) : ""
    case 0x401F: return data.isEmpty ? "" : "égaliseur : préréglage n° \(data[0])"
    case 0x4041: return data.isEmpty ? "" : "faible latence : " + (data[0] == 1 ? "activée" : "désactivée")
    default: return ""
    }
}

final class Listener: NSObject, IOBluetoothRFCOMMChannelDelegate {
    var buffer: [UInt8] = []
    var answers = 0

    func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        buffer += [UInt8](UnsafeRawBufferPointer(start: dataPointer, count: dataLength))
        while let start = buffer.firstIndex(of: 0x55) {
            buffer.removeFirst(start)
            guard buffer.count >= 8 else { return }
            let control = UInt16(buffer[1]) | UInt16(buffer[2]) << 8
            let length = Int(buffer[5]) | Int(buffer[6]) << 8
            let total = 8 + length + (control & 0x20 != 0 ? 2 : 0)
            guard buffer.count >= total else { return }
            let command = UInt16(buffer[3]) | UInt16(buffer[4]) << 8
            let data = Array(buffer[8..<(8 + length)])
            answers += 1
            print(String(format: "← 0x%04X  ", command) + hex(data) + "  " + describe(command, data))
            buffer.removeFirst(total)
        }
        buffer.removeAll()
    }
}

func wait(_ seconds: TimeInterval) { RunLoop.current.run(until: Date().addingTimeInterval(seconds)) }

// ---------- Recherche de l'appareil ----------
let paired = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
let wanted = CommandLine.arguments.dropFirst().first
let candidates = paired.filter { $0.isConnected() && (wanted == nil ? $0.getServiceRecord(for: IOBluetoothSDPUUID(bytes: serviceUUID, length: 16)) != nil
                                                                   : ($0.name ?? "").localizedCaseInsensitiveContains(wanted!)) }
guard let device = candidates.first else {
    print("Aucun appareil Nothing / CMF connecté. Appareils jumelés : " + paired.map { "\($0.name ?? "?")\($0.isConnected() ? " (connecté)" : "")" }.joined(separator: ", "))
    exit(1)
}
print("Appareil : \(device.name ?? "?")  \(device.addressString ?? "")")

print("Services déclarés :")
for record in (device.services as? [IOBluetoothSDPServiceRecord]) ?? [] {
    var channel: BluetoothRFCOMMChannelID = 0
    let hasChannel = record.getRFCOMMChannelID(&channel) == kIOReturnSuccess
    let classes = (record.getAttributeDataElement(0x0001)?.getArrayValue() as? [IOBluetoothSDPDataElement])?
        .compactMap { $0.getUUIDValue() }.map { hex([UInt8]($0 as Data)).replacingOccurrences(of: " ", with: "") } ?? []
    print("  canal \(hasChannel ? String(channel) : "–")  \(record.getServiceName() ?? "(sans nom)")  \(classes.joined(separator: ", "))")
}

guard let record = device.getServiceRecord(for: IOBluetoothSDPUUID(bytes: serviceUUID, length: 16)) else {
    print("Le service Nothing n'est pas déclaré par cet appareil.")
    exit(2)
}
var channelID: BluetoothRFCOMMChannelID = 0
guard record.getRFCOMMChannelID(&channelID) == kIOReturnSuccess else { print("Service Nothing sans canal RFCOMM."); exit(2) }
print("Service Nothing sur le canal \(channelID)")

// ---------- Échange ----------
let listener = Listener()
var channel: IOBluetoothRFCOMMChannel?
let opened = device.openRFCOMMChannelSync(&channel, withChannelID: channelID, delegate: listener)
guard opened == kIOReturnSuccess, let channel else { print(String(format: "Ouverture du canal refusée (0x%08x).", opened)); exit(3) }
wait(0.5)
for (index, (command, label)) in reads.enumerated() {
    var packet = frame(command, seq: UInt8(index + 1))
    print("→ \(label.padding(toLength: 20, withPad: " ", startingAt: 0)) \(hex(packet))")
    let sent = channel.writeSync(&packet, length: UInt16(packet.count))
    if sent != kIOReturnSuccess { print(String(format: "  envoi refusé (0x%08x)", sent)) }
    wait(0.8)
}
wait(0.5)
channel.close()
print(listener.answers > 0 ? "\n\(listener.answers) réponse(s) reçue(s)." : "\nAucune réponse.")
exit(listener.answers > 0 ? 0 : 4)
