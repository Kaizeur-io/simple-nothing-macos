import Testing
@testable import NothingKit

// Les octets viennent des relevés de tools/probe.sh sur un CMF Headphone Pro.

@Test func encodesReadsLikeTheProbe() {
    #expect(Frame(command: Read.battery.rawValue, sequence: 1).encoded() == [0x55, 0x60, 0x01, 0x07, 0xC0, 0x00, 0x00, 0x01, 0xAC, 0xDF])
    #expect(Frame(command: Read.spatial.rawValue, sequence: 8).encoded() == [0x55, 0x60, 0x01, 0x4F, 0xC0, 0x00, 0x00, 0x08, 0x8C, 0xD7])
}

@Test func parsesFramesSplitAcrossChunks() {
    var parser = FrameParser()
    let reply: [UInt8] = [0x55, 0x00, 0x01, 0x07, 0x40, 0x03, 0x00, 0x01, 0x01, 0x06, 0x28]
    #expect(parser.feed(Array(reply[..<5])).isEmpty)
    #expect(parser.feed(Array(reply[5...]) + reply) == [Frame(command: 0x4007, sequence: 1, payload: [0x01, 0x06, 0x28]),
                                                         Frame(command: 0x4007, sequence: 1, payload: [0x01, 0x06, 0x28])])
}

@Test func checksTheCRCWhenPresent() {
    var parser = FrameParser()
    var sent = Frame(command: Write.noise.rawValue, sequence: 3, payload: [0x01, 0x07, 0x00]).encoded()
    #expect(parser.feed(sent) == [Frame(command: 0xF00F, sequence: 3, payload: [0x01, 0x07, 0x00])])
    sent[9] ^= 0xFF
    #expect(parser.feed(sent).isEmpty)
}

@Test func readsTheHeadsetState() {
    var state = DeviceState()
    let replies: [(UInt16, [UInt8])] = [
        (0x4007, [0x01, 0x06, 0x28]), (0x4042, Array("1.0.1.49".utf8)), (0x401E, [0x01, 0x01, 0x00, 0x02, 0x01, 0x00]),
        (0x4050, [0x03]), (0x404F, [0x02, 0x00]), (0x4041, [0x00]), (0x4027, [0x01]), (0x4029, [0x00]), (0x405A, [0x00]),
        (0x4018, [0x04, 0x06, 0x0A, 0x07, 0x01, 0x06, 0x0A, 0x01, 0x0B, 0x06, 0x05, 0x01, 0x23, 0x06, 0x01, 0x07, 0x16]),
        (0x4006, [0x04] + Array("6,1,AAA\n6,2,1.0.1.49\n6,4,SERIE123\n6,6,00:11".utf8)),
    ]
    for (command, payload) in replies {
        let understood = state.apply(Frame(command: command, payload: payload))
        #expect(understood, "réponse \(command)")
    }

    #expect(state.mainBattery == Battery(slot: 0x06, percent: 40, charging: false))
    #expect(state.firmware == "1.0.1.49")
    #expect(state.serial == "SERIE123")
    #expect(state.noise == .high)
    #expect(state.preset == .pop)
    #expect(state.spatial == .concert)
    #expect(state.lowLatency == false)
    #expect(state.dualConnection == true)
    #expect(state.codec == .aac)
    #expect(state.gesture(.buttonPress)?.action == ButtonMapping.Action.voiceAssistant)
    #expect(state.gesture(.buttonHold)?.action == ButtonMapping.Action.none)
    #expect(state.gesture(.slider)?.action == ButtonMapping.Action.bass)
    #expect(state.gesture(.rollerHold).map { ButtonMapping.Action.noiseControlAll.contains($0.action) } == true)
}

@Test func readsChargingAndPushedUpdates() {
    var state = DeviceState()
    state.apply(Frame(command: Push.battery, payload: [0x03, 0x02, 0xD0, 0x03, 0x4B, 0x04, 0x10]))
    #expect(state.battery.map(\.percent) == [80, 75, 16])
    #expect(state.battery.map(\.charging) == [true, false, false])
    #expect(state.mainBattery?.percent == 75)
    state.apply(Frame(command: Push.noise, payload: [0x01, 0x07, 0x00]))
    #expect(state.noise == .transparency)
    let understood = state.apply(Frame(command: 0x7C09, payload: [0x00, 0x04, 0x00]))
    #expect(!understood)
}

@Test func spatialModesRoundTrip() {
    for mode in [SpatialMode.off, .fixed, .headTracked, .concert, .theatre, .game] {
        #expect(SpatialMode(bytes: mode.bytes) == mode)
    }
}

@Test func findsModelsByBluetoothName() {
    #expect(Model.named("CMF Headphone Pro") == .headphonePro)
    #expect(Model.named("Nothing Headphone (1) Pro")?.id == "B192")
    #expect(Model.named("Nothing Ear (a)")?.id == "B162")
    #expect(Model.named("AirPods Pro") == nil)
}

@Test func customEQRoundTrips() {
    let curve = CustomEQ(mid: 2, bass: -1, treble: 3)
    let payload = curve.payload
    #expect(payload.count == 1 + 4 + 3 * 13 + 9)
    #expect(Array(payload[0..<5]) == [0x03, 0x00, 0x00, 0x40, 0xC0])  // trois filtres, gain d'ensemble de -3 dB
    #expect(Array(payload[5..<10]) == [0x01, 0x00, 0x00, 0x00, 0x40])  // filtre en cloche, +2 dB
    #expect(CustomEQ(payload: payload) == curve)
    #expect(CustomEQ(payload: [UInt8](repeating: 0, count: 109)) == nil)  // ce que renvoie un casque sans courbe
}

@Test func readsDualConnectionPages() {
    var state = DeviceState()
    let mac: [UInt8] = [0x11, 0x22, 0x33, 0x44, 0x55, 0x66]
    var page: [UInt8] = [0x00, 0x00, 0x02, 0x11]
    page += mac
    page += [0x03]
    page += Array("Mac".utf8)
    page += [0x00, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0x05]
    page += Array("Phone".utf8)
    let fresh = state.apply(Frame(command: 0x4028, payload: page))
    #expect(fresh)
    #expect(state.dualDevices == [DualDevice(address: "11:22:33:44:55:66", name: "Mac", isConnected: true, isSelf: true),
                                  DualDevice(address: "AA:BB:CC:DD:EE:FF", name: "Phone", isConnected: false, isSelf: false)])
    let again = state.apply(Frame(command: 0x4028, payload: page))
    #expect(!again)  // rien de nouveau : inutile de demander la page suivante
}

@Test func recoversFromACorruptLength() {
    var parser = FrameParser()
    let reply: [UInt8] = [0x55, 0x00, 0x01, 0x07, 0x40, 0x03, 0x00, 0x01, 0x01, 0x06, 0x28]
    let frames = parser.feed([0x55, 0x00, 0x01, 0x07, 0x40, 0xFF, 0xFF, 0x01] + reply)
    #expect(frames == [Frame(command: 0x4007, sequence: 1, payload: [0x01, 0x06, 0x28])])
}

@Test func knowsWhatEachModelCanDo() {
    let headphonePro = Model.headphonePro.capabilities
    #expect(headphonePro.spatial == [.concert, .theatre])
    #expect(headphonePro.bassSteps.isEmpty && !headphonePro.wearDetection && headphonePro.ring == [.headset])
    let earA = Model.named("Nothing Ear (a)")?.capabilities
    #expect(earA?.bassSteps == [2, 4, 6, 8, 10] && earA?.ring == [.left, .right] && earA?.wearDetection == true)
    #expect(Model.named("Nothing Ear (open)")?.capabilities.noiseControl == false)
}

@Test func offersTheActionsEachGestureAccepts() {
    typealias A = ButtonMapping.Action
    let earA = Model.named("Nothing Ear (a)")!
    #expect(earA.actions(for: ButtonMapping(device: 0x02, button: 0x01, type: 0x02, action: 0x09)) == [A.previous, A.next, A.voiceAssistant])
    #expect(earA.actions(for: ButtonMapping(device: 0x03, button: 0x01, type: 0x09, action: 0x01)) == [A.noiseControl, A.volumeUp, A.volumeDown, A.voiceAssistant, A.none])
    let open = Model.named("Nothing Ear (open)")!
    #expect(!open.actions(for: ButtonMapping(device: 0x02, button: 0x01, type: 0x07, action: 0x12)).contains(A.noiseControl))
    let buds = Model.named("CMF Buds Pro 2")!
    #expect(buds.actions(for: ButtonMapping(device: 0x02, button: 0x01, type: 0x02, action: 0x02)).first == A.playPause)
    #expect(buds.actions(for: ButtonMapping(device: 0x04, button: 0x01, type: 0x0A, action: 0x17)).isEmpty)
}

@Test func buildsRingAndDualDevicePayloads() {
    #expect(RingTarget.headset.payload(on: true) == [0x06, 0x01])
    #expect(RingTarget.left.payload(on: false) == [0x02, 0x00])
    #expect(RingTarget.legacy.payload(on: true) == [0x01])
    let phone = DualDevice(address: "0A:1B:2C:3D:4E:5F", name: "Phone", isConnected: false, isSelf: false)
    #expect(phone.writePayload(connect: true) == [0x01, 0x0A, 0x1B, 0x2C, 0x3D, 0x4E, 0x5F])
}

@Test func readsBassAndWearDetection() {
    var state = DeviceState()
    state.apply(Frame(command: Read.bass.reply, payload: [0x01, 0x06]))
    state.apply(Frame(command: Read.wearDetection.reply, payload: [0x00, 0x00, 0x01]))
    #expect(state.bassEnabled == true && state.bassLevel == 6 && state.wearDetection == true)
}
