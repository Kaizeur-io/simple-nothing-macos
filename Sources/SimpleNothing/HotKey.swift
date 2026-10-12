import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Le raccourci choisi dans les réglages ; ⌃⌥A tant que rien n'a été changé.
struct Shortcut {
    /// Code de la touche. Sans lui, c'est la touche « A » de la disposition du clavier.
    var keyCode: UInt32?
    /// Touches mortes, au format Carbon.
    var modifiers = controlKey | optionKey
    var label = "⌃⌥A"

    static var saved: Shortcut {
        let defaults = UserDefaults.standard
        guard let label = defaults.string(forKey: "shortcutLabel"), defaults.object(forKey: "shortcutKey") != nil else { return Shortcut() }
        return Shortcut(keyCode: UInt32(defaults.integer(forKey: "shortcutKey")), modifiers: defaults.integer(forKey: "shortcutModifiers"), label: label)
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(Int(keyCode ?? 0), forKey: "shortcutKey")
        defaults.set(modifiers, forKey: "shortcutModifiers")
        defaults.set(label, forKey: "shortcutLabel")
    }

    private static let named: [Int: String] = [
        kVK_Space: "␣", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
        kVK_F11: "F11", kVK_F12: "F12",
    ]
}

extension Shortcut {
    /// La combinaison tapée. Il faut au moins ⌃, ⌥ ou ⌘ : une lettre seule ou avec ⇧ gênerait la frappe partout.
    init?(event: NSEvent) {
        let flags = event.modifierFlags
        guard !flags.isDisjoint(with: [.control, .option, .command]) else { return nil }
        let code = Int(event.keyCode)
        guard let key = Self.named[code] ?? event.charactersIgnoringModifiers?.uppercased(), !key.isEmpty else { return nil }
        let pairs: [(NSEvent.ModifierFlags, Int, String)] = [(.control, controlKey, "⌃"), (.option, optionKey, "⌥"), (.shift, shiftKey, "⇧"), (.command, cmdKey, "⌘")]
        let held = pairs.filter { flags.contains($0.0) }
        self.init(keyCode: UInt32(code), modifiers: held.reduce(0) { $0 | $1.1 }, label: held.map(\.2).joined() + key)
    }
}

/// Pastille qui montre le raccourci ; un clic, puis la combinaison voulue, le remplace. Échap annule.
struct ShortcutRecorder: View {
    @State private var recording = false
    @State private var monitor: Any?
    @State private var label = Shortcut.saved.label

    var body: some View {
        Button { recording ? stop() : start() } label: {
            Text(recording ? tr("Tapez le raccourci…") : label).font(.system(size: 12, weight: .medium)).foregroundStyle(recording ? Color.nRed : Color.nText)
                .padding(.horizontal, 12).frame(height: 26).background(Color.nWell, in: Capsule()).contentShape(Capsule())
        }
        .buttonStyle(.plain).onDisappear(perform: stop)
    }

    private func start() {
        recording = true
        AppDelegate.suspendShortcut()  // sinon le raccourci en place se déclencherait pendant la saisie
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if Int(event.keyCode) == kVK_Escape {
                stop()
            } else if let shortcut = Shortcut(event: event) {
                shortcut.save()
                label = shortcut.label
                stop()
            } else {
                NSSound.beep()
            }
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        guard recording else { return }
        recording = false
        AppDelegate.applyShortcut()
    }
}

/// Raccourci clavier actif dans toutes les apps. Passe par l'API Carbon, la seule qui ne demande
/// pas l'autorisation « Accessibilité ».
final class HotKey {
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void

    /// Sans code de touche, on prend la touche gravée « A », quelle que soit la disposition du clavier.
    init?(_ shortcut: Shortcut, action: @escaping () -> Void) {
        let modifiers = shortcut.modifiers
        self.action = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            Unmanaged<HotKey>.fromOpaque(context!).takeUnretainedValue().action()
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
        let id = EventHotKeyID(signature: OSType(0x4E58_4D43), id: 1)
        let code = shortcut.keyCode ?? Self.keyCode(for: "a") ?? UInt32(kVK_ANSI_A)
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
