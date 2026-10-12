import AppKit
import Carbon.HIToolbox
import ServiceManagement
import SwiftUI

/// Options de lancement, pour les captures d'écran et les essais sans casque :
///   --demo                     état factice, aucun accès Bluetooth
///   --demo-custom              avec --demo : égaliseur sur « Personnalisé »
///   --demo-name <nom>          avec --demo : nom Bluetooth de l'appareil factice, pour voir un autre modèle
///   --section <nom>            listen, controls, link ou device
///   --dark | --light           force l'apparence
///   --snapshot <fichier.png>   enregistre la fenêtre puis quitte
///   --snapshot-menu <fichier>  enregistre le panneau de la barre des menus puis quitte
///   --snapshot-hud <fichier>   enregistre la carte de connexion puis quitte
///   --snapshot-toast <fichier> enregistre la confirmation du raccourci clavier puis quitte
///   --verify <fichier.txt>     essaie chaque réglage sur l'appareil, le remet en place, écrit un rapport
///   -AppleLanguages "(en)"     force la langue
enum Launch {
    static let arguments = CommandLine.arguments
    static let isDemo = arguments.contains("--demo")
    static func value(_ name: String) -> String? {
        arguments.firstIndex(of: name).flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
    }

    /// Fichier de sortie. Un chemin relatif part du dossier d'où tools/app.sh a été lancé.
    static func path(_ name: String) -> String? {
        value(name).map { path in
            let base = ProcessInfo.processInfo.environment["NOTHING_PWD"] ?? NSHomeDirectory()
            return path.hasPrefix("/") ? path : URL(fileURLWithPath: base).appendingPathComponent(path).path
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let headset = Headset(demo: Launch.isDemo)
    /// Ouvre la fenêtre principale ; fourni par SwiftUI dès que la barre des menus est en place.
    static var openMain: (() -> Void)?
    private static var hotKey: HotKey?

    static var mainWindow: NSWindow? { NSApp.windows.first { $0.frame.width > 600 && $0.contentView != nil && !($0 is NSPanel) } }

    /// L'app vit dans la barre des menus : elle n'occupe le Dock que tant que sa fenêtre est ouverte.
    static func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        openMain?()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) { Self.headset.stop() }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { Self.showMainWindow() }
        return true
    }

    @objc private func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === Self.mainWindow else { return }
        NSApp.setActivationPolicy(.accessory)
    }

    /// Ouverture au démarrage du Mac. Renvoie faux si macOS refuse, par exemple hors de /Applications.
    static var opensAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    @discardableResult
    static func setOpensAtLogin(_ on: Bool) -> Bool {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            return true
        } catch {
            return false
        }
    }

    /// Met le raccourci global en accord avec le réglage : ⌃⌥A passe au mode de bruit suivant.
    static func applyShortcut() {
        hotKey = nil
        guard UserDefaults.standard.bool(forKey: "shortcutEnabled"), !Launch.arguments.contains(where: { $0.hasPrefix("--snapshot") || $0 == "--verify" }) else { return }
        hotKey = HotKey(character: "a", modifiers: HotKey.controlOption) {
            if let mode = headset.cycleNoise() { HUD.shared.show(ModeToast(mode: mode), seconds: 1.8) }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if Launch.arguments.contains("--dark") { NSApp.appearance = NSAppearance(named: .darkAqua) }
        if Launch.arguments.contains("--light") { NSApp.appearance = NSAppearance(named: .aqua) }
        UserDefaults.standard.register(defaults: ["shortcutEnabled": true, "arrivalCard": true])
        Self.headset.onArrival = {
            // Fenêtre déjà sous les yeux : elle montre la même chose, la carte ferait doublon.
            let windowInFront = NSApp.isActive && Self.mainWindow?.isVisible == true
            if UserDefaults.standard.bool(forKey: "arrivalCard"), !windowInFront { HUD.shared.show(ArrivalCard(headset: Self.headset), seconds: 4.5) }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose(_:)), name: NSWindow.willCloseNotification, object: nil)
        // Lancée par macOS à l'ouverture de session : pas de fenêtre, seulement la barre des menus.
        let event = NSAppleEventManager.shared().currentAppleEvent
        let atLogin = event?.eventID == AEEventID(kAEOpenApplication) && event?.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue == AEKeyword(keyAELaunchedAsLogInItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if atLogin {
                Self.mainWindow?.close()
            } else if Self.mainWindow == nil {
                // macOS se souvient d'une fenêtre fermée lors de la session précédente et ne la rouvre pas.
                // Quelqu'un qui lance l'app veut pourtant la voir.
                Self.showMainWindow()
            }
        }
        Self.applyShortcut()
        Self.headset.start()
        let extras: [(String, AnyView)] = [("--snapshot-menu", AnyView(MenuBarPanel(headset: Self.headset).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous)))),
                                           ("--snapshot-hud", AnyView(ArrivalCard(headset: Self.headset).padding(HUD.margin))),
                                           ("--snapshot-toast", AnyView(ModeToast(mode: Self.headset.state.noise ?? .transparency).padding(HUD.margin)))]
        for (option, view) in extras {
            if let path = Launch.path(option) {
                DispatchQueue.main.asyncAfter(deadline: .now() + (Launch.isDemo ? 1.5 : 5)) { self.snapshot(view, to: path) }
            }
        }
        if let path = Launch.path("--verify") { Verification(headset: Self.headset, report: path).run() }
        if let path = Launch.path("--snapshot") {
            DispatchQueue.main.asyncAfter(deadline: .now() + (Launch.isDemo ? 1.5 : 5)) { self.snapshot(to: path) }
        }
    }

    private func snapshot(to path: String) {
        guard let window = NSApp.windows.first(where: { $0.frame.width > 600 && $0.contentView != nil }),
              let view = window.contentView?.superview ?? window.contentView else { exit(1) }
        save(view, to: path)
    }

    /// Panneau et cartes n'existent qu'un instant à l'écran : on les monte dans une fenêtre à part.
    private func snapshot(_ view: AnyView, to path: String) {
        let host = NSHostingView(rootView: view)
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: host.fittingSize), styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = host
        window.orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.save(host, to: path) }
    }

    private func save(_ view: NSView, to path: String) {
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { exit(1) }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try? bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        exit(0)
    }
}

@main
struct SimpleNothingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @ObservedObject private var headset = AppDelegate.headset
    @AppStorage("section") private var section = Pane.listen
    @Environment(\.openWindow) private var openWindow

    init() {
        // L'état des fenêtres n'est pas repris d'une session à l'autre : l'app décide elle-même quoi montrer.
        UserDefaults.standard.register(defaults: ["NSQuitAlwaysKeepsWindows": false])
        Typeface.register()
        if let name = Launch.value("--section"), Pane(rawValue: name) != nil { UserDefaults.standard.set(name, forKey: "section") }
    }

    var body: some Scene {
        Window(appName, id: "main") {
            ContentView(headset: headset)
        }
        .windowStyle(.hiddenTitleBar).windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu(tr("Présentation")) {
                ForEach(Array(Pane.allCases.enumerated()), id: \.element) { index, item in
                    Button(tr(item.label)) { section = item }.keyboardShortcut(KeyEquivalent(Character("\(index + 1)")))
                }
            }
        }

        MenuBarExtra {
            MenuBarPanel(headset: headset)
        } label: {
            Image(systemName: "headphones").onAppear { AppDelegate.openMain = { openWindow(id: "main") } }
            if headset.status == .connected, let level = headset.state.mainBattery { Text(tr("%d %%", level.percent)) }
        }
        .menuBarExtraStyle(.window)
    }
}
