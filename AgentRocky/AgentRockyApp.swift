import SwiftUI
import AppKit

@main
struct AgentRockyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: AppController?
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let controller = AppController()
        controller.start()
        self.controller = controller
        setupMenuBar()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.shutdown()
    }

    private func setupMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "figure.walk",
            accessibilityDescription: "AgentRocky"
        )

        let menu = NSMenu()
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit AgentRocky",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        item.menu = menu

        statusItem = item
    }
}
