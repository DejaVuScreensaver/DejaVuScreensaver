import AppKit
import Darwin
import Foundation

protocol ScreenLocking {
    var isAvailable: Bool { get }
    var isSessionLocked: Bool { get }
    func lockNow() -> Bool
}

/// Uses the same private login.framework primitive as the macOS Lock Screen
/// menu item. This app is intentionally distributed outside the Mac App Store.
final class ScreenLockService: ScreenLocking {
    private typealias LockFunction = @convention(c) () -> Void

    private let frameworkHandle: UnsafeMutableRawPointer?
    private let lockFunction: LockFunction?

    init() {
        let paths = [
            "/System/Library/PrivateFrameworks/login.framework/Versions/Current/login",
            "/System/Library/PrivateFrameworks/login.framework/login",
        ]

        var loadedHandle: UnsafeMutableRawPointer?
        for path in paths {
            if let handle = dlopen(path, RTLD_LAZY | RTLD_LOCAL) {
                loadedHandle = handle
                break
            }
        }
        frameworkHandle = loadedHandle

        if let loadedHandle, let symbol = dlsym(loadedHandle, "SACLockScreenImmediate") {
            lockFunction = unsafeBitCast(symbol, to: LockFunction.self)
        } else {
            lockFunction = nil
        }
    }

    deinit {
        if let frameworkHandle {
            dlclose(frameworkHandle)
        }
    }

    var isAvailable: Bool { lockFunction != nil }

    @discardableResult
    func lockNow() -> Bool {
        guard let lockFunction else { return false }
        lockFunction()
        return true
    }

    var isSessionLocked: Bool {
        guard let dictionary = CGSessionCopyCurrentDictionary() as? [String: Any] else {
            return false
        }
        return dictionary["CGSSessionScreenIsLocked"] as? Bool ?? false
    }
}
