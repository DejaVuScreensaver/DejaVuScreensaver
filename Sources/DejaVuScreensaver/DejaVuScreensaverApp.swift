import AppKit
import SwiftUI

@main
struct DejaVuScreensaverApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("DejaVuScreensaver", systemImage: "photo.on.rectangle") {
            MenuContent(
                model: appDelegate.model,
                openSettings: { appDelegate.showSettings() },
                openHistory: { appDelegate.showHistory() }
            )
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var settingsWindow: NSWindow?
    private var historyWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.onUnlockAfterSlideshow = { [weak self] in self?.showSettings() }
        showSettings()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        showSettings()
        return true
    }

    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        showSettings()
        return true
    }

    func showSettings() {
        let window: NSWindow
        if let settingsWindow {
            window = settingsWindow
        } else {
            let hostingController = NSHostingController(
                rootView: SettingsView(
                    model: model,
                    onShowHistory: { [weak self] in self?.showHistory() }
                )
            )
            window = NSWindow(contentViewController: hostingController)
            window.title = "DejaVuScreensaver"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 680, height: 760))
            window.contentMinSize = NSSize(width: 620, height: 680)
            window.isReleasedWhenClosed = false
            window.center()
            self.settingsWindow = window
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showHistory() {
        let window: NSWindow
        if let historyWindow {
            window = historyWindow
        } else {
            let hostingController = NSHostingController(
                rootView: HistoryView(model: model)
            )
            window = NSWindow(contentViewController: hostingController)
            window.title = "Recently Viewed — DejaVuScreensaver"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 900, height: 650))
            window.contentMinSize = NSSize(width: 760, height: 540)
            window.isReleasedWhenClosed = false
            window.center()
            self.historyWindow = window
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct MenuContent: View {
    @ObservedObject var model: AppModel
    let openSettings: () -> Void
    let openHistory: () -> Void

    var body: some View {
        Button("Start Slideshow") {
            model.startSlideshow()
        }
        .disabled(!model.canStart)

        Button("Settings…") {
            openSettings()
        }

        Button("Recently Viewed…") {
            openHistory()
        }

        Divider()

        Text(model.photoLibrary.canReadLibrary ? "Photos ready" : "Photos access required")
        Text(model.lockService.isAvailable ? "Secure lock ready" : "Secure lock unavailable")

        Divider()

        Button("Quit DejaVuScreensaver") {
            NSApp.terminate(nil)
        }
    }
}
