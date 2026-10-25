import AppKit
import SwiftUI

@main
struct DejaVuScreensaverApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("DejaVuScreensaver", systemImage: "photo.on.rectangle") {
            MenuContent(
                model: appDelegate.model,
                softwareUpdate: appDelegate.softwareUpdate,
                openSettings: { appDelegate.showSettings() },
                openHistory: { appDelegate.showHistory() }
            )
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    let softwareUpdate = SoftwareUpdateController()
    private var settingsWindow: NSWindow?
    private var historyWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        softwareUpdate.start()
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
                    softwareUpdate: softwareUpdate,
                    onShowHistory: { [weak self] in self?.showHistory() }
                )
            )
            hostingController.sceneBridgingOptions = [.title] // window title follows the selected pane
            window = NSWindow(contentViewController: hostingController)
            window.title = "DejaVuScreensaver"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            // An (empty) unified toolbar puts the title leading in the content area with no separate title band, like System Settings.
            window.toolbar = NSToolbar()
            window.toolbarStyle = .unifiedCompact // shorter bar
            window.setContentSize(NSSize(width: 890, height: 700))
            window.contentMinSize = NSSize(width: 870, height: 600)
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
    @ObservedObject var softwareUpdate: SoftwareUpdateController
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

        Button(softwareUpdate.availableVersion == nil ? "Check for Updates…" : "Update Available…") {
            softwareUpdate.checkForUpdates()
        }
        .disabled(!softwareUpdate.canCheckForUpdates || model.isPresenting || model.lockService.isSessionLocked)

        Divider()

        Text(model.photoLibrary.canReadLibrary ? "Photos ready" : "Photos access required")
        Text(model.lockService.isAvailable ? "Secure lock ready" : "Secure lock unavailable")

        Divider()

        Button("Quit DejaVuScreensaver") {
            NSApp.terminate(nil)
        }
    }
}
