import AppKit
import SwiftUI

@MainActor
final class SlideshowPresentation {
    private var windows: [NSWindow] = []
    private var localEventMonitor: Any?
    private var resignObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?
    private var previousPresentationOptions: NSApplication.PresentationOptions = []
    private var cursorHidden = false
    private var ignoreMouseUntil = Date.distantPast
    private var accumulatedMouseMovement: Double = 0
    private var movementThreshold: Double = 18
    private var isRequestingLock = false
    private var onControl: ((SlideshowControl) -> Void)?
    private var onLock: (() -> Void)?
    private var onDismiss: (() -> Void)?
    private var lockOnExitInput = true
    private var stayOpenUntilEnded = false
    private weak var controller: SlideshowController?

    var isVisible: Bool { !windows.isEmpty }

    func show(
        controller: SlideshowController,
        preferences: AppPreferences,
        onControl: @escaping (SlideshowControl) -> Void,
        onLock: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        stop()
        self.onControl = onControl
        self.onLock = onLock
        self.onDismiss = onDismiss
        lockOnExitInput = preferences.lockOnDisallowedKey
        stayOpenUntilEnded = preferences.stayOpenUntilEnded
        self.controller = controller
        movementThreshold = max(4, preferences.mouseMovementThreshold)
        ignoreMouseUntil = Date().addingTimeInterval(1.2)
        accumulatedMouseMovement = 0
        isRequestingLock = false

        previousPresentationOptions = NSApp.presentationOptions
        NSApp.presentationOptions = [.hideDock, .hideMenuBar]

        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.backgroundColor = .black
            window.isOpaque = true
            window.hasShadow = false
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            window.acceptsMouseMovedEvents = true
            window.isMovable = false
            window.contentView = NSHostingView(
                rootView: SlideshowView(
                    controller: controller,
                    preferences: preferences,
                    onEnd: { [weak self] in self?.requestDismiss() }
                )
            )
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
            windows.append(window)
        }

        windows.first?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSCursor.hide()
        cursorHidden = true
        installMonitors()
    }

    func stop() {
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
        }
        localEventMonitor = nil

        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
        }
        resignObserver = nil

        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        screenObserver = nil

        windows.forEach { $0.orderOut(nil) }
        windows = []
        NSApp.presentationOptions = previousPresentationOptions
        if cursorHidden {
            NSCursor.unhide()
            cursorHidden = false
        }
        onControl = nil
        onLock = nil
        onDismiss = nil
        controller = nil
        isRequestingLock = false
    }

    private func installMonitors() {
        let mask: NSEvent.EventTypeMask = [
            .keyDown, .keyUp, .flagsChanged,
            .mouseMoved, .leftMouseDown, .rightMouseDown, .otherMouseDown,
            .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
            .scrollWheel,
        ]

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            guard let self else { return event }
            return self.handle(event)
        }

        if !stayOpenUntilEnded {
            resignObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.requestExit() }
            }
        }

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.stayOpenUntilEnded {
                    self.requestDismiss()
                } else {
                    self.requestExit()
                }
            }
        }
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        switch event.type {
        case .keyDown:
            applyInputDecision(SlideshowInputPolicy.keyDown(
                keyCode: event.keyCode,
                modifierFlags: event.modifierFlags,
                isRepeat: event.isARepeat,
                stayOpenUntilEnded: stayOpenUntilEnded
            ))
            return nil

        case .keyUp:
            applyInputDecision(SlideshowInputPolicy.keyUp(
                keyCode: event.keyCode,
                stayOpenUntilEnded: stayOpenUntilEnded
            ))
            return nil

        case .flagsChanged:
            applyInputDecision(SlideshowInputPolicy.flagsChanged(
                event.modifierFlags,
                stayOpenUntilEnded: stayOpenUntilEnded
            ))
            return nil

        case .leftMouseDown, .rightMouseDown, .otherMouseDown,
             .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .scrollWheel:
            if stayOpenUntilEnded { return event }
            requestExit()
            return nil

        case .mouseMoved:
            if stayOpenUntilEnded {
                controller?.showExitControl()
                if cursorHidden {
                    NSCursor.unhide()
                    cursorHidden = false
                }
                return event
            }
            guard Date() >= ignoreMouseUntil else { return nil }
            accumulatedMouseMovement += hypot(event.deltaX, event.deltaY)
            if accumulatedMouseMovement >= movementThreshold {
                requestExit()
            }
            return nil

        default:
            return event
        }
    }

    private func applyInputDecision(_ decision: SlideshowInputDecision) {
        switch decision {
        case let .control(control): onControl?(control)
        case .consume: break
        case .dismiss: requestDismiss()
        case .lock: requestExit()
        }
    }

    private func requestDismiss() {
        guard !isRequestingLock else { return }
        isRequestingLock = true
        onDismiss?()
    }

    private func requestExit() {
        guard !isRequestingLock else { return }
        isRequestingLock = true
        if lockOnExitInput {
            onLock?()
        } else {
            onDismiss?()
        }
    }
}
