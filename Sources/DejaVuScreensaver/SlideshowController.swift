import AppKit
import Photos

@MainActor
final class SlideshowController: ObservableObject {
    @Published private(set) var image: NSImage?
    @Published private(set) var metadata: PhotoMetadata?
    @Published private(set) var currentAssetID = ""
    /// True when the current photo came from the timer, not from the arrow keys.
    @Published private(set) var isAutomaticAdvance = false
    @Published private(set) var isPaused = false
    @Published private(set) var assetCount = 0
    @Published private(set) var currentPosition = 0
    @Published private(set) var isLoading = false
    @Published private(set) var securityMessage: String?
    @Published private(set) var isSecurityCoverVisible = false
    @Published private(set) var isExitControlVisible = false

    var onPhotoDisplayed: ((PHAsset) -> Void)?

    private let library: PhotoLibraryService
    private var assets: [PHAsset] = []
    private var sequence = PlaybackSequence()
    private var interval: TimeInterval = 10
    private var timerTask: Task<Void, Never>?
    private var imageRequestID: PHImageRequestID?
    private var targetSize = CGSize(width: 3840, height: 2160)
    private var displayGeneration = 0
    private var recordedGeneration: Int?
    private var isDisplayAsleep = false

    init(library: PhotoLibraryService) {
        self.library = library
        // Like the macOS screen saver: no photo changes while the displays are off.
        let center = NSWorkspace.shared.notificationCenter
        _ = center.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.isDisplayAsleep = true
                self?.timerTask?.cancel()
            }
        }
        _ = center.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.isDisplayAsleep = false
                self?.scheduleAdvance()
            }
        }
    }

    func begin(assets: [PHAsset], interval: TimeInterval, targetSize: CGSize, order: PhotoOrder) {
        stop()
        self.assets = assets
        self.interval = max(1, interval)
        self.targetSize = targetSize
        assetCount = assets.count
        isPaused = false
        securityMessage = nil
        isSecurityCoverVisible = false
        isExitControlVisible = false
        sequence.reset(itemCount: assets.count, order: order)
        if let first = sequence.next() {
            show(index: first, deliveryMode: .highQualityFormat)
        }
    }

    func stop() {
        displayGeneration += 1
        timerTask?.cancel()
        timerTask = nil
        if let imageRequestID {
            library.cancelImageRequest(imageRequestID)
        }
        imageRequestID = nil
        assets = []
        sequence.reset(itemCount: 0)
        image = nil
        metadata = nil
        currentAssetID = ""
        assetCount = 0
        currentPosition = 0
        isLoading = false
        isPaused = false
        securityMessage = nil
        isSecurityCoverVisible = false
        isExitControlVisible = false
    }

    func next() {
        guard !isSecurityCoverVisible else { return }
        guard let index = sequence.next() else { return }
        show(index: index, deliveryMode: .opportunistic)
    }

    func previous() {
        guard !isSecurityCoverVisible else { return }
        guard let index = sequence.previous() else { return }
        show(index: index, deliveryMode: .opportunistic)
    }

    func togglePause() {
        guard !isSecurityCoverVisible else { return }
        isPaused.toggle()
        scheduleAdvance()
    }

    func updateInterval(_ seconds: TimeInterval) {
        interval = max(1, seconds)
        scheduleAdvance()
    }

    func prepareForLock() {
        guard !isSecurityCoverVisible else { return }
        isSecurityCoverVisible = true
        displayGeneration += 1
        isPaused = true
        timerTask?.cancel()
        timerTask = nil
        if let imageRequestID {
            library.cancelImageRequest(imageRequestID)
        }
        imageRequestID = nil
        image = nil
        metadata = nil
        currentAssetID = ""
        isLoading = false
        isExitControlVisible = false
    }

    func showSecurityFailure(_ message: String) {
        prepareForLock()
        securityMessage = message
    }

    func showExitControl() {
        guard !isSecurityCoverVisible else { return }
        isExitControlVisible = true
    }

    func hideExitControl() {
        isExitControlVisible = false
    }

    private func advanceAutomatically() {
        guard let index = sequence.next() else { return }
        show(index: index, deliveryMode: .highQualityFormat, automatic: true)
    }

    private func show(index: Int, deliveryMode: PHImageRequestOptionsDeliveryMode, automatic: Bool = false) {
        guard !isSecurityCoverVisible, assets.indices.contains(index) else { return }
        displayGeneration += 1
        let generation = displayGeneration
        timerTask?.cancel()
        if let imageRequestID {
            library.cancelImageRequest(imageRequestID)
        }

        let asset = assets[index]
        isLoading = true

        imageRequestID = library.requestImage(
            for: asset,
            targetSize: targetSize,
            deliveryMode: deliveryMode
        ) { [weak self] image, isFinal in
            Task { @MainActor in
                guard let self, self.displayGeneration == generation else { return }

                if let image {
                    self.image = image
                    self.isAutomaticAdvance = automatic
                    self.currentAssetID = asset.localIdentifier
                    self.currentPosition = min(self.sequence.cursor + 1, self.assetCount)
                    self.metadata = self.library.metadata(for: asset)
                    if self.recordedGeneration != generation {
                        self.recordedGeneration = generation
                        self.onPhotoDisplayed?(asset)
                    }
                }

                // Manual navigation may show a preview, but its timer starts
                // only after Photos has supplied the final image.
                guard isFinal else { return }
                self.imageRequestID = nil
                self.isLoading = false

                guard image != nil else {
                    self.scheduleAdvance()
                    return
                }
                self.scheduleAdvance()
            }
        }
    }

    private func scheduleAdvance() {
        timerTask?.cancel()
        timerTask = nil
        guard !isSecurityCoverVisible, !isPaused, !isDisplayAsleep, !assets.isEmpty else { return }

        let nanoseconds = UInt64(interval * 1_000_000_000)
        timerTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            self?.advanceAutomatically()
        }
    }
}
