import CoreGraphics
import Foundation

@MainActor
final class IdleMonitor {
    var onIdle: (() -> Void)?

    private var timer: Timer?
    private var isArmed = false
    private var isEnabled: () -> Bool = { false }
    private var threshold: () -> TimeInterval = { 600 }
    private var canActivate: () -> Bool = { false }

    private static let activityEventTypes: [CGEventType] = [
        .keyDown, .keyUp, .flagsChanged,
        .mouseMoved, .leftMouseDown, .rightMouseDown, .otherMouseDown,
        .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
        .scrollWheel,
    ]

    static func secondsSinceLastInput(
        sample: (CGEventType) -> TimeInterval = {
            CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0)
        }
    ) -> TimeInterval {
        activityEventTypes.map(sample).min() ?? .infinity
    }

    func start(
        isEnabled: @escaping () -> Bool,
        threshold: @escaping () -> TimeInterval,
        canActivate: @escaping () -> Bool
    ) {
        self.isEnabled = isEnabled
        self.threshold = threshold
        self.canActivate = canActivate
        isArmed = isEnabled()

        timer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func disarmUntilUserActivity() {
        isArmed = false
    }

    private func tick() {
        guard !sessionIsLocked else { return }

        let idle = Self.secondsSinceLastInput()

        if idle < 2 {
            isArmed = true
        }

        guard isEnabled(), isArmed, canActivate(), idle >= threshold() else { return }
        isArmed = false
        onIdle?()
    }

    private var sessionIsLocked: Bool {
        guard let dictionary = CGSessionCopyCurrentDictionary() as? [String: Any] else {
            return false
        }
        return dictionary["CGSSessionScreenIsLocked"] as? Bool ?? false
    }
}
