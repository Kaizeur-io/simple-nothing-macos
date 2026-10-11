import AppKit
import SwiftUI

/// Options de lancement, pour les captures d'écran et les essais sans casque :
///   --demo                     état factice, aucun accès Bluetooth
///   --section <nom>            listen, controls, link ou device
///   --dark | --light           force l'apparence
///   --snapshot <fichier.png>   enregistre la fenêtre puis quitte
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
        if let path = Launch.value("--snapshot") {
            DispatchQueue.main.asyncAfter(deadline: .now() + (Launch.isDemo ? 1.5 : 5)) { self.snapshot(to: path) }
        }
    }

    private func snapshot(to path: String) {
        guard let window = NSApp.windows.first(where: { $0.frame.width > 600 && $0.contentView != nil }),
              let view = window.contentView?.superview ?? window.contentView,
              let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { exit(1) }
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
        if let name = Launch.value("--section"), Pane(rawValue: name) != nil { UserDefaults.standard.set(name, forKey: "section") }
    }

    var body: some Scene {
        Window("Nothing X", id: "main") {
            ContentView(headset: headset)
        }
        .windowStyle(.hiddenTitleBar).windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Présentation") {
                ForEach(Array(Pane.allCases.enumerated()), id: \.element) { index, item in
                    Button(item.label) { section = item }.keyboardShortcut(KeyEquivalent(Character("\(index + 1)")))
                }
            }
        }

        MenuBarExtra {
            MenuBarPanel(headset: headset)
        } label: {
            Image(systemName: "headphones")
            if let level = headset.state.mainBattery { Text("\(level.percent) %") }
        }
        .menuBarExtraStyle(.window)
    }
}
