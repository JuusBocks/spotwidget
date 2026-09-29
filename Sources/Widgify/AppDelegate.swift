import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        WidgifySnapshotServer.shared.start()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            handleURL(url)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            let image = NSImage(systemSymbolName: "music.note.tv", accessibilityDescription: "Widgify")
                ?? NSImage(systemSymbolName: "music.note", accessibilityDescription: "Widgify")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Widgify"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Widgify", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Add from Desktop > Edit Widgets", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    private func handleURL(_ url: URL) {
        guard url.scheme == "widgify", url.host == "command" else { return }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let command = components.queryItems?.first(where: { $0.name == "command" })?.value else {
            return
        }

        WidgifySnapshotServer.shared.performCommand(command)
    }
}
