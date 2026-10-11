import AppKit
import SwiftUI

/// Options de lancement, pour les captures d'écran et les essais sans casque :
///   --demo                     état factice, aucun accès Bluetooth
///   --section <nom>            listen, controls, link ou device
///   --dark | --light           force l'apparence
///   --snapshot <fichier.png>   enregistre la fenêtre puis quitte
///   --snapshot-menu <fichier>  enregistre le panneau de la barre des menus puis quitte
///   --verify <fichier.txt>     essaie chaque réglage sur l'appareil, le remet en place, écrit un rapport
///   -AppleLanguages "(en)"     force la langue
enum Launch {
    static let arguments = CommandLine.arguments
    static let isDemo = arguments.contains("--demo")
    static func value(_ name: String) -> String? {
        arguments.firstIndex(of: name).flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let headset = Headset(demo: Launch.isDemo)

    func applicationDidFinishLaunching(_ notification: Notification) {
        if Launch.arguments.contains("--dark") { NSApp.appearance = NSAppearance(named: .darkAqua) }
        if Launch.arguments.contains("--light") { NSApp.appearance = NSAppearance(named: .aqua) }
        Self.headset.start()
        if let path = Launch.value("--verify") { Verification(headset: Self.headset, report: path).run() }
        if let path = Launch.value("--snapshot-menu") {
            DispatchQueue.main.asyncAfter(deadline: .now() + (Launch.isDemo ? 1.5 : 5)) { self.snapshotMenu(to: path) }
        }
        if let path = Launch.value("--snapshot") {
            DispatchQueue.main.asyncAfter(deadline: .now() + (Launch.isDemo ? 1.5 : 5)) { self.snapshot(to: path) }
        }
    }

    private func snapshot(to path: String) {
        guard let window = NSApp.windows.first(where: { $0.frame.width > 600 && $0.contentView != nil }),
              let view = window.contentView?.superview ?? window.contentView else { exit(1) }
        save(view, to: path)
    }

    /// Le panneau n'existe qu'une fois la barre des menus cliquée : on le monte dans une fenêtre à part.
    private func snapshotMenu(to path: String) {
        let host = NSHostingView(rootView: MenuBarPanel(headset: Self.headset).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous)))
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
struct NothingXApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @ObservedObject private var headset = AppDelegate.headset
    @AppStorage("section") private var section = Pane.listen

    init() {
        Typeface.register()
        if let name = Launch.value("--section"), Pane(rawValue: name) != nil { UserDefaults.standard.set(name, forKey: "section") }
    }

    var body: some Scene {
        Window("Nothing X", id: "main") {
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
            Image(systemName: "headphones")
            if headset.status == .connected, let level = headset.state.mainBattery { Text(tr("%d %%", level.percent)) }
        }
        .menuBarExtraStyle(.window)
    }
}
