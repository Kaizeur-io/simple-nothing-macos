import Carbon.HIToolbox

/// Raccourci clavier actif dans toutes les apps. Passe par l'API Carbon, la seule qui ne demande
/// pas l'autorisation « Accessibilité ».
final class HotKey {
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void

    static let controlOption = controlKey | optionKey

    /// `character` est la lettre gravée sur la touche, quelle que soit la disposition du clavier.
    init?(character: String, modifiers: Int, action: @escaping () -> Void) {
        self.action = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            Unmanaged<HotKey>.fromOpaque(context!).takeUnretainedValue().action()
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
        let id = EventHotKeyID(signature: OSType(0x4E58_4D43), id: 1)
        let code = Self.keyCode(for: character) ?? UInt32(kVK_ANSI_A)
        guard RegisterEventHotKey(code, UInt32(modifiers), id, GetApplicationEventTarget(), 0, &reference) == noErr else { return nil }
    }

    deinit {
        if let reference { UnregisterEventHotKey(reference) }
        if let handler { RemoveEventHandler(handler) }
    }

    /// Sur un clavier AZERTY la touche « A » n'a pas le même code que sur un QWERTY : on le cherche.
    private static func keyCode(for character: String) -> UInt32? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue() as Data
        return data.withUnsafeBytes { buffer -> UInt32? in
            guard let layout = buffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return nil }
            for code in UInt16(0)..<50 {
                var deadKeys: UInt32 = 0
                var length = 0
                var characters = [UniChar](repeating: 0, count: 4)
                let status = UCKeyTranslate(layout, code, UInt16(kUCKeyActionDown), 0, UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                            &deadKeys, characters.count, &length, &characters)
                if status == noErr, length > 0, String(utf16CodeUnits: characters, count: length).lowercased() == character { return UInt32(code) }
            }
            return nil
        }
    }
}
