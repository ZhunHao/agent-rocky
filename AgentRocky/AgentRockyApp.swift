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

    private var providerMenuItems: [NSMenuItem] = []

    private func setupMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "figure.walk",
            accessibilityDescription: "AgentRocky"
        )

        let menu = NSMenu()

        // Provider submenu — Claude active in M3, FoundationModels enabled in M4.
        let providerItem = NSMenuItem(title: "Provider", action: nil, keyEquivalent: "")
        let providerMenu = NSMenu()
        providerMenuItems = []
        for (i, provider) in AgentProvider.allCases.enumerated() {
            let entry = NSMenuItem(
                title: provider.displayName,
                action: #selector(switchProvider(_:)),
                keyEquivalent: ""
            )
            entry.target = self
            entry.tag = i
            entry.state = (provider == .claude) ? .on : .off
            entry.isEnabled = false                // re-enabled by async availability probe
            providerMenuItems.append(entry)
            providerMenu.addItem(entry)
        }
        providerItem.submenu = providerMenu
        menu.addItem(providerItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit AgentRocky",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        item.menu = menu

        statusItem = item

        Task { @MainActor in await self.refreshProviderMenu() }
    }

    @MainActor
    private func refreshProviderMenu() async {
        let detector = ProviderDetector()
        let availability = await detector.detectAvailable()
        for (i, provider) in AgentProvider.allCases.enumerated() {
            providerMenuItems[i].isEnabled = availability[provider, default: false]
            if availability[provider, default: false] == false {
                providerMenuItems[i].toolTip = provider.installInstructions
            }
        }
    }

    @objc private func switchProvider(_ sender: NSMenuItem) {
        let provider = AgentProvider.allCases[sender.tag]
        sender.menu?.items.forEach { $0.state = .off }
        sender.state = .on
        Task { await self.controller?.switchProvider(to: provider) }
    }
}
