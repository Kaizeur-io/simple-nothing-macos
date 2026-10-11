// Trames du protocole Nothing / CMF. Voir docs/protocole.md.
//
//   55 60 01 | commande (2 octets, petit-boutiste) | longueur (2 octets) | séquence | données | CRC16

public struct Frame: Equatable, Sendable {
    public var command: UInt16
    public var sequence: UInt8
    public var payload: [UInt8]

    public init(command: UInt16, sequence: UInt8 = 0, payload: [UInt8] = []) {
        self.command = command
        self.sequence = sequence
        self.payload = payload
    }

    /// Octets à envoyer à l'appareil, CRC compris.
    public func encoded() -> [UInt8] {
        let head: [UInt8] = [0x55, 0x60, 0x01, UInt8(command & 0xFF), UInt8(command >> 8),
                             UInt8(payload.count & 0xFF), UInt8(payload.count >> 8), sequence]
        let body = head + payload
        let crc = crc16(body)
        return body + [UInt8(crc & 0xFF), UInt8(crc >> 8)]
    }
}

/// CRC16 de type Modbus : valeur initiale 0xFFFF, polynôme réfléchi 0xA001.
public func crc16(_ bytes: [UInt8]) -> UInt16 {
    var crc: UInt16 = 0xFFFF
    for byte in bytes {
        crc ^= UInt16(byte)
        for _ in 0..<8 { crc = crc & 1 == 1 ? (crc >> 1) ^ 0xA001 : crc >> 1 }
    }
    return crc
}

/// Reconstitue les trames à partir des morceaux reçus, qui ne tombent pas forcément sur leurs limites.
public struct FrameParser: Sendable {
    private var buffer: [UInt8] = []
    /// Aucune trame connue ne dépasse quelques centaines d'octets. Au-delà, c'est un faux départ :
    /// sans cette limite, un octet corrompu ferait attendre des données qui n'arriveront jamais.
    private static let longest = 2048

    public init() {}

    public mutating func feed(_ bytes: [UInt8]) -> [Frame] {
        buffer += bytes
        var frames: [Frame] = []
        while let start = buffer.firstIndex(of: 0x55) {
            buffer.removeFirst(start)
            guard buffer.count >= 8 else { return frames }
            let hasCRC = buffer[1] & 0x20 != 0
            let length = Int(buffer[5]) | Int(buffer[6]) << 8
            let total = 8 + length + (hasCRC ? 2 : 0)
            guard length <= Self.longest else {
                buffer.removeFirst()
                continue
            }
            guard buffer.count >= total else { return frames }
            if hasCRC {
                let crc = crc16(Array(buffer[..<(8 + length)]))
                guard buffer[total - 2] == UInt8(crc & 0xFF), buffer[total - 1] == UInt8(crc >> 8) else {
                    buffer.removeFirst()  // faux départ : on cherche le 0x55 suivant
                    continue
                }
            }
            frames.append(Frame(command: UInt16(buffer[3]) | UInt16(buffer[4]) << 8, sequence: buffer[7],
                                payload: Array(buffer[8..<(8 + length)])))
            buffer.removeFirst(total)
        }
        buffer.removeAll()
        return frames
    }
}
