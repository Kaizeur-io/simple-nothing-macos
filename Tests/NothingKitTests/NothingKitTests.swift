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
