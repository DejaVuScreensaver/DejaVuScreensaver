import AppKit
import Photos
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var isPresenting = false
    @Published var statusMessage = "Choose albums, then start the slideshow."
    @Published private(set) var launchAtLoginStatus = SMAppService.mainApp.status

    let preferences = PreferencesStore()
    let photoLibrary = PhotoLibraryService()
    let lockService: any ScreenLocking
    let viewingHistory = ViewingHistoryStore()
    let slideshow: SlideshowController
    var onUnlockAfterSlideshow: (() -> Void)?

    private let presentation = SlideshowPresentation()
    private let idleMonitor = IdleMonitor()
    private var lockObserver: NSObjectProtocol?
    private var unlockObserver: NSObjectProtocol?
    private var reopenSettingsAfterUnlock = false
    private var lockConfirmationTask: Task<Void, Never>?

    init(lockService: any ScreenLocking = ScreenLockService()) {
        self.lockService = lockService
        slideshow = SlideshowController(library: photoLibrary)
        slideshow.onPhotoDisplayed = { [weak self] asset in
            self?.viewingHistory.record(assetIdentifier: asset.localIdentifier)
        }

        idleMonitor.onIdle = { [weak self] in
            self?.startSlideshow(source: "Idle timer")
        }
        idleMonitor.start(
            isEnabled: { [weak self] in self?.preferences.value.idleEnabled ?? false },
            threshold: { [weak self] in (self?.preferences.value.idleMinutes ?? 10) * 60 },
            canActivate: { [weak self] in
                guard let self else { return false }
                let secureExitReady = self.preferences.value.stayOpenUntilEnded
                    || !self.preferences.value.lockOnDisallowedKey
                    || self.lockService.isAvailable
                return !self.isPresenting && self.photoLibrary.canReadLibrary && secureExitReady
            }
        )

        lockObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleSessionLockedNotification()
            }
        }
        unlockObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.lockService.isSessionLocked else { return }
                self.idleMonitor.disarmUntilUserActivity()
                guard self.reopenSettingsAfterUnlock else { return }
                self.reopenSettingsAfterUnlock = false
                self.onUnlockAfterSlideshow?()
            }
        }

        if !lockService.isAvailable {
            statusMessage = "Secure Lock Screen integration is unavailable on this macOS version. Idle mode will not arm."
        }
    }

    deinit {
        lockConfirmationTask?.cancel()
        if let lockObserver {
            DistributedNotificationCenter.default().removeObserver(lockObserver)
        }
        if let unlockObserver {
            DistributedNotificationCenter.default().removeObserver(unlockObserver)
        }
    }

    var canStart: Bool {
        startDisabledReason == nil
    }

    var startDisabledReason: String? {
        if isPresenting {
            return "A slideshow is already running."
        }
        if !photoLibrary.canReadLibrary {
            return photoLibrary.authorizationStatus == .notDetermined
                ? "Allow Photos access above to start."
                : "Photos access is blocked. Enable it in System Settings."
        }
        let secureExitReady = preferences.value.stayOpenUntilEnded
            || !preferences.value.lockOnDisallowedKey
            || lockService.isAvailable
        if !secureExitReady {
            return "Automatic locking is unavailable. Choose Slideshow mode or turn off “Lock Mac”."
        }
        return nil
    }

    func requestPhotosAccess() {
        Task {
            await photoLibrary.requestAccess()
            idleMonitor.disarmUntilUserActivity()
            if photoLibrary.canReadLibrary {
                statusMessage = "Photos access granted. Choose one or more albums, or use All Photos."
            } else {
                statusMessage = "Photos access was not granted."
            }
        }
    }

    func startSlideshow(source: String = "Manual") {
        guard !isPresenting else { return }
        guard photoLibrary.canReadLibrary else {
            statusMessage = "Grant Photos access before starting."
            return
        }
        guard preferences.value.stayOpenUntilEnded
                || !preferences.value.lockOnDisallowedKey
                || lockService.isAvailable else {
            statusMessage = "Cannot start securely because the macOS Lock Screen function is unavailable."
            return
        }

        let assets = photoLibrary.fetchImages(
            from: preferences.value.selectedAlbumIDs,
            matching: preferences.value.smartFilter
        )
        guard !assets.isEmpty else {
            statusMessage = "No photos matched the selected source and smart filters."
            return
        }

        let targetSize = maximumDisplayPixelSize()
        slideshow.begin(
            assets: assets,
            interval: preferences.value.intervalSeconds,
            targetSize: targetSize,
            order: preferences.value.photoOrder
        )
        isPresenting = true
        statusMessage = "\(source) slideshow running with \(assets.count) photos."

        presentation.show(
            controller: slideshow,
            preferences: preferences.value,
            onControl: { [weak self] control in
                guard let self else { return }
                switch control {
                case .previous: self.slideshow.previous()
                case .next: self.slideshow.next()
                case .pause: self.slideshow.togglePause()
                }
            },
            onLock: { [weak self] in self?.lockFromSlideshow() },
            onDismiss: { [weak self] in
                self?.stopSlideshow()
                self?.statusMessage = "Slideshow dismissed without locking the Mac."
            }
        )
    }

    func stopSlideshow() {
        lockConfirmationTask?.cancel()
        lockConfirmationTask = nil
        guard isPresenting || presentation.isVisible else { return }
        presentation.stop()
        slideshow.stop()
        isPresenting = false
        idleMonitor.disarmUntilUserActivity()
    }

    @discardableResult
    func handleSessionLockedNotification() -> Bool {
        // A distributed notification is only a hint; another process can post it.
        guard lockService.isSessionLocked else { return false }
        if isPresenting {
            reopenSettingsAfterUnlock = true
        }
        stopSlideshow()
        return true
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginStatus = SMAppService.mainApp.status
            preferences.value.launchAtLogin = launchAtLoginStatus == .enabled
            statusMessage = enabled ? "Launch at login enabled." : "Launch at login disabled."
        } catch {
            launchAtLoginStatus = SMAppService.mainApp.status
            preferences.value.launchAtLogin = launchAtLoginStatus == .enabled
            statusMessage = "Could not update Launch at Login: \(error.localizedDescription)"
        }
    }

    func toggleAlbum(_ id: String) {
        if preferences.value.selectedAlbumIDs.contains(id) {
            preferences.value.selectedAlbumIDs.remove(id)
        } else {
            preferences.value.selectedAlbumIDs.insert(id)
        }
    }

    func useAllPhotos() {
        preferences.value.selectedAlbumIDs.removeAll()
    }

    private func lockFromSlideshow() {
        guard isPresenting else { return }
        slideshow.prepareForLock()
        reopenSettingsAfterUnlock = true
        if lockService.lockNow() {
            statusMessage = "Requested the macOS Lock Screen; keeping every display covered until macOS confirms it."
            lockConfirmationTask?.cancel()
            lockConfirmationTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled else { return }
                guard let self, self.isPresenting else { return }
                if self.lockService.isSessionLocked {
                    self.handleSessionLockedNotification()
                } else {
                    self.statusMessage = "macOS did not confirm that the session locked. The black security cover remains active."
                    self.slideshow.showSecurityFailure(
                        "DejaVuScreensaver kept every display covered because macOS did not confirm the lock request. Press Control–Command–Q."
                    )
                }
            }
        } else {
            reopenSettingsAfterUnlock = false
            statusMessage = "The macOS Lock Screen call failed."
            slideshow.showSecurityFailure(
                "DejaVuScreensaver kept the slideshow covered because macOS did not accept the lock request."
            )
        }
    }

    private func maximumDisplayPixelSize() -> CGSize {
        let sizes = NSScreen.screens.map { screen in
            CGSize(
                width: screen.frame.width * screen.backingScaleFactor,
                height: screen.frame.height * screen.backingScaleFactor
            )
        }
        return CGSize(
            width: max(1920, sizes.map(\.width).max() ?? 1920),
            height: max(1080, sizes.map(\.height).max() ?? 1080)
        )
    }
}
