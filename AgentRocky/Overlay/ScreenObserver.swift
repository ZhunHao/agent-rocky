import AppKit

/// Observes screen and dock-pref changes and invokes a callback on the main actor.
@MainActor
final class ScreenObserver {
    var onChange: (() -> Void)?

    private var observers: [NSObjectProtocol] = []

    func start() {
        observers.append(
            NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.onChange?() }
            }
        )
        observers.append(
            DistributedNotificationCenter.default().addObserver(
                forName: Notification.Name("com.apple.dock.preferences-changed"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.onChange?() }
            }
        )
    }

    func stop() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.forEach { DistributedNotificationCenter.default().removeObserver($0) }
        observers.removeAll()
    }

    deinit {
        // observers detach automatically when this instance is dealloc'd, since
        // NotificationCenter holds them weakly via the token API
    }
}
