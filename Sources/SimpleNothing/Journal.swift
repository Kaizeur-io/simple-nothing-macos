import Foundation

/// Petit journal local des connexions, dans ~/Library/Logs. Il sert à comprendre après coup ce qui
/// s'est passé (délais, échecs, app figée) ; il ne contient ni numéro de série ni adresse, et rien
/// n'en sort. Le fichier est remis à zéro quand il dépasse 200 Ko.
enum Journal {
    private static let url = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("Logs/\(appName).log")
    private static let stamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    static func note(_ text: String) {
        guard let line = "\(stamp.string(from: Date()))  \(text)\n".data(using: .utf8) else { return }
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        if size > 200_000 { try? FileManager.default.removeItem(at: url) }
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(line)
            try? handle.close()
        } else {
            try? line.write(to: url)
        }
    }

    private static var watch: Timer?

    /// Surveille le fil principal pendant un moment : si l'app se fige, on le saura et de combien.
    static func watchMainThread(for seconds: TimeInterval) {
        watch?.invalidate()
        var last = Date()
        let end = last.addingTimeInterval(seconds)
        watch = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { timer in
            let now = Date()
            let gap = now.timeIntervalSince(last)
            if gap > 0.5 { note(String(format: "app figée pendant %.1f s", gap)) }
            last = now
            if now > end { timer.invalidate() }
        }
    }
}
