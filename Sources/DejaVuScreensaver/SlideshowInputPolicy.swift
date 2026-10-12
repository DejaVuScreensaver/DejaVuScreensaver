import AppKit

enum SlideshowControl: Equatable {
    case previous
    case next
    case pause
}

enum SlideshowInputDecision: Equatable {
    case control(SlideshowControl)
    case consume
    case dismiss
    case lock
}

/// Pure, testable keyboard policy for the full-screen presentation.
/// Only unmodified Left, Right, and Space are permitted to avoid weakening
/// the normal expectation that other interaction takes the user to Lock Screen.
struct SlideshowInputPolicy {
    static func keyDown(
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags,
        isRepeat: Bool,
        stayOpenUntilEnded: Bool = false
    ) -> SlideshowInputDecision {
        if stayOpenUntilEnded, keyCode == 53 {
            return isRepeat ? .consume : .dismiss
        }

        let exitDecision: SlideshowInputDecision = stayOpenUntilEnded ? .consume : .lock
        let disallowedModifiers = modifierFlags.intersection([
            .command, .control, .option, .shift, .capsLock,
        ])
        guard disallowedModifiers.isEmpty else { return exitDecision }

        // macOS sets `.function` automatically on arrow-key NSEvents even when
        // the user did not hold Fn. Accept it only for Left and Right; an Fn
        // modifier on other permitted keys still follows the lock path.
        if modifierFlags.contains(.function), keyCode != 123, keyCode != 124 {
            return exitDecision
        }

        let control: SlideshowControl?
        switch keyCode {
        case 123: control = .previous
        case 124: control = .next
        case 49: control = .pause
        default: control = nil
        }

        guard let control else { return exitDecision }

        // Holding or rapidly tapping an arrow should continue navigating.
        // Space repeat is suppressed so pause cannot toggle back and forth.
        if isRepeat, control == .pause {
            return .consume
        }
        return .control(control)
    }

    static func keyUp(keyCode: UInt16, stayOpenUntilEnded: Bool = false) -> SlideshowInputDecision {
        if stayOpenUntilEnded { return .consume }
        return switch keyCode {
        case 123, 124, 49: .consume
        default: .lock
        }
    }

    static func flagsChanged(
        _ modifierFlags: NSEvent.ModifierFlags,
        stayOpenUntilEnded: Bool = false
    ) -> SlideshowInputDecision {
        if stayOpenUntilEnded { return .consume }
        let meaningfulModifiers = modifierFlags.intersection([
            .command, .control, .option, .shift, .capsLock,
        ])

        // Some keyboards emit a function-only flagsChanged event around an
        // arrow event. It is transport noise, not a separate exit command.
        return meaningfulModifiers.isEmpty ? .consume : .lock
    }
}
