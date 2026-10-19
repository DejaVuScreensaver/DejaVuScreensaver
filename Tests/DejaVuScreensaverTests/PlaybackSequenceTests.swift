import CoreGraphics
import XCTest
@testable import DejaVuScreensaver

final class PlaybackSequenceTests: XCTestCase {
    func testVisitsEveryItemBeforeRepeating() {
        var sequence = PlaybackSequence()
        sequence.reset(itemCount: 8)

        let firstCycle = (0..<8).compactMap { _ in sequence.next() }
        XCTAssertEqual(Set(firstCycle), Set(0..<8))
    }

    func testPreviousAndForwardFollowHistory() {
        var sequence = PlaybackSequence()
        sequence.reset(itemCount: 5)

        let first = sequence.next()
        let second = sequence.next()
        let third = sequence.next()

        XCTAssertEqual(sequence.previous(), second)
        XCTAssertEqual(sequence.previous(), first)
        XCTAssertEqual(sequence.next(), second)
        XCTAssertEqual(sequence.next(), third)
    }

    func testEmptyAndSingleItemCollections() {
        var sequence = PlaybackSequence()
        sequence.reset(itemCount: 0)
        XCTAssertNil(sequence.next())

        sequence.reset(itemCount: 1)
        XCTAssertEqual(sequence.next(), 0)
        XCTAssertEqual(sequence.next(), 0)
        XCTAssertEqual(sequence.previous(), 0)
    }

    func testChronologicalOrderRepeatsOldestToNewest() {
        var sequence = PlaybackSequence()
        sequence.reset(itemCount: 3, order: .chronological)

        XCTAssertEqual((0..<5).compactMap { _ in sequence.next() }, [0, 1, 2, 0, 1])
    }

    func testReverseChronologicalOrderRepeatsNewestToOldest() {
        var sequence = PlaybackSequence()
        sequence.reset(itemCount: 3, order: .reverseChronological)

        XCTAssertEqual((0..<5).compactMap { _ in sequence.next() }, [2, 1, 0, 2, 1])
    }
}

@MainActor
final class IdleMonitorTests: XCTestCase {
    func testIdleTimeUsesTheMostRecentRealInputEvent() {
        var sampled = Set<CGEventType>()

        let idle = IdleMonitor.secondsSinceLastInput { eventType in
            sampled.insert(eventType)
            return eventType == .mouseMoved ? 1 : 99
        }

        XCTAssertEqual(idle, 1)
        XCTAssertTrue(sampled.contains(.keyDown))
        XCTAssertTrue(sampled.contains(.scrollWheel))
    }
}

final class SlideshowInputPolicyTests: XCTestCase {
    func testOnlyPlainArrowsAndSpaceControlSlideshow() {
        XCTAssertEqual(
            SlideshowInputPolicy.keyDown(keyCode: 123, modifierFlags: [], isRepeat: false),
            .control(.previous)
        )
        XCTAssertEqual(
            SlideshowInputPolicy.keyDown(keyCode: 124, modifierFlags: [], isRepeat: false),
            .control(.next)
        )
        XCTAssertEqual(
            SlideshowInputPolicy.keyDown(keyCode: 49, modifierFlags: [], isRepeat: false),
            .control(.pause)
        )
    }

    func testMacOSAutomaticFunctionFlagOnArrowKeysIsAllowed() {
        XCTAssertEqual(
            SlideshowInputPolicy.keyDown(keyCode: 123, modifierFlags: [.function], isRepeat: false),
            .control(.previous)
        )
        XCTAssertEqual(
            SlideshowInputPolicy.keyDown(keyCode: 124, modifierFlags: [.function], isRepeat: false),
            .control(.next)
        )
    }

    func testOtherKeysAndModifiedControlsLock() {
        XCTAssertEqual(
            SlideshowInputPolicy.keyDown(keyCode: 0, modifierFlags: [], isRepeat: false),
            .lock
        )
        XCTAssertEqual(
            SlideshowInputPolicy.keyDown(keyCode: 123, modifierFlags: [.shift], isRepeat: false),
            .lock
        )
        XCTAssertEqual(
            SlideshowInputPolicy.keyDown(keyCode: 49, modifierFlags: [.function], isRepeat: false),
            .lock
        )
        XCTAssertEqual(SlideshowInputPolicy.keyUp(keyCode: 0), .lock)
    }

    func testArrowRepeatsNavigateAndSpaceRepeatIsConsumed() {
        XCTAssertEqual(
            SlideshowInputPolicy.keyDown(keyCode: 124, modifierFlags: [.function], isRepeat: true),
            .control(.next)
        )
        XCTAssertEqual(
            SlideshowInputPolicy.keyDown(keyCode: 123, modifierFlags: [.function], isRepeat: true),
            .control(.previous)
        )
        XCTAssertEqual(
            SlideshowInputPolicy.keyDown(keyCode: 49, modifierFlags: [], isRepeat: true),
            .consume
        )
        XCTAssertEqual(SlideshowInputPolicy.keyUp(keyCode: 123), .consume)
        XCTAssertEqual(SlideshowInputPolicy.keyUp(keyCode: 124), .consume)
        XCTAssertEqual(SlideshowInputPolicy.keyUp(keyCode: 49), .consume)
    }

    func testFunctionOnlyFlagsEventAroundArrowIsConsumed() {
        XCTAssertEqual(SlideshowInputPolicy.flagsChanged([.function]), .consume)
        XCTAssertEqual(SlideshowInputPolicy.flagsChanged([]), .consume)
        XCTAssertEqual(SlideshowInputPolicy.flagsChanged([.shift]), .lock)
        XCTAssertEqual(SlideshowInputPolicy.flagsChanged([.command, .function]), .lock)
    }

    func testSlideshowModeOnlyDismissesForEscape() {
        XCTAssertEqual(
            SlideshowInputPolicy.keyDown(
                keyCode: 53,
                modifierFlags: [],
                isRepeat: false,
                stayOpenUntilEnded: true
            ),
            .dismiss
        )
        XCTAssertEqual(
            SlideshowInputPolicy.keyDown(
                keyCode: 0,
                modifierFlags: [],
                isRepeat: false,
                stayOpenUntilEnded: true
            ),
            .consume
        )
        XCTAssertEqual(
            SlideshowInputPolicy.keyDown(
                keyCode: 124,
                modifierFlags: [.function],
                isRepeat: false,
                stayOpenUntilEnded: true
            ),
            .control(.next)
        )
        XCTAssertEqual(
            SlideshowInputPolicy.flagsChanged([.command], stayOpenUntilEnded: true),
            .consume
        )
    }
}

final class AppPreferencesTests: XCTestCase {
    func testOlderSavedPreferencesEnableKeyboardLockByDefault() throws {
        let oldPreferences = Data(#"{"intervalSeconds":7,"showFilename":false}"#.utf8)
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: oldPreferences)

        XCTAssertEqual(decoded.intervalSeconds, 7)
        XCTAssertFalse(decoded.showFilename)
        XCTAssertTrue(decoded.lockOnDisallowedKey)
        XCTAssertFalse(decoded.idleEnabled)
        XCTAssertEqual(decoded.photoOrder, .random)
        XCTAssertFalse(decoded.showMinimap)
        XCTAssertTrue(decoded.animateMinimapZoom)
        XCTAssertEqual(decoded.clockTimeFormat, .system)
    }

    func testKeyboardLockPreferenceRoundTrips() throws {
        var preferences = AppPreferences()
        preferences.lockOnDisallowedKey = false
        preferences.intervalSeconds = 24
        preferences.idleEnabled = true
        preferences.showMinimap = true
        preferences.animateMinimapZoom = false
        preferences.clockTimeFormat = .twentyFourHour

        let data = try JSONEncoder().encode(preferences)
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: data)

        XCTAssertEqual(decoded, preferences)
    }

    func testAutomaticStartIsOffByDefault() {
        XCTAssertFalse(AppPreferences().idleEnabled)
    }

    func testPhotoDurationDefaultsToFiveSeconds() {
        XCTAssertEqual(AppPreferences().intervalSeconds, 5)
    }

    func testNewPresentationOptionsHaveConservativeDefaults() {
        let preferences = AppPreferences()

        XCTAssertFalse(preferences.showClock)
        XCTAssertEqual(preferences.clockPosition, .topCenter)
        XCTAssertEqual(preferences.clockStyle, .apple)
        XCTAssertEqual(preferences.clockSize, .medium)
        XCTAssertEqual(preferences.clockTimeFormat, .system)
        XCTAssertFalse(preferences.showClockBackground)
        XCTAssertFalse(preferences.showMinimap)
        XCTAssertTrue(preferences.animateMinimapZoom)
        XCTAssertTrue(preferences.showPhotoNumber)
        XCTAssertEqual(preferences.slideshowStyle, .still)
        XCTAssertEqual(preferences.photoOrder, .random)
    }

    func testSavedPhotoDurationIsClampedToThirtySeconds() throws {
        let savedPreferences = Data(#"{"intervalSeconds":600}"#.utf8)
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: savedPreferences)

        XCTAssertEqual(decoded.intervalSeconds, 30)
    }

    func testClockTimeFormatsCanForceTwelveOrTwentyFourHours() {
        let date = Date(timeIntervalSince1970: 13 * 3600 + 5 * 60)
        let locale = Locale(identifier: "en_US_POSIX")
        let timeZone = TimeZone(secondsFromGMT: 0)!

        XCTAssertEqual(
            ClockTimeFormat.twelveHour.string(from: date, locale: locale, timeZone: timeZone),
            "1:05 PM"
        )
        XCTAssertEqual(
            ClockTimeFormat.twentyFourHour.string(from: date, locale: locale, timeZone: timeZone),
            "13:05"
        )
    }

    func testPreviousRoundedDefaultMigratesToAppleFont() throws {
        let savedPreferences = Data(#"{"preferencesVersion":4,"clockStyle":"rounded"}"#.utf8)
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: savedPreferences)

        XCTAssertEqual(decoded.clockStyle, .apple)
    }

    func testPreviousClassicClockStyleMigratesToAppleFont() throws {
        let savedPreferences = Data(#"{"preferencesVersion":4,"clockStyle":"classic"}"#.utf8)
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: savedPreferences)

        XCTAssertEqual(decoded.clockStyle, .apple)
        XCTAssertFalse(SlideshowClockStyle.allCases.contains(.classic))
    }

    func testPreviousDigitalClockStyleMigratesToAppleFont() throws {
        let savedPreferences = Data(#"{"preferencesVersion":5,"clockStyle":"digital"}"#.utf8)
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: savedPreferences)

        XCTAssertEqual(decoded.clockStyle, .apple)
        XCTAssertFalse(SlideshowClockStyle.allCases.contains(.digital))
    }

    func testSmartFilterMatchesAllEnabledConditions() {
        let cutoff = Date(timeIntervalSince1970: 1_000)
        let filter = SmartPhotoFilter(
            favoriteEnabled: true,
            captureDateEnabled: true,
            captureDateComparison: .before,
            captureDate: cutoff
        )

        XCTAssertTrue(filter.matches(isFavorite: true, captureDate: Date(timeIntervalSince1970: 500)))
        XCTAssertFalse(filter.matches(isFavorite: false, captureDate: Date(timeIntervalSince1970: 500)))
        XCTAssertFalse(filter.matches(isFavorite: true, captureDate: nil))
    }

    func testSavedAnyFilterMigratesToAllMatching() throws {
        let savedFilter = Data(#"{"match":"any","favoriteEnabled":true,"captureDateEnabled":true,"captureDateComparison":"before","captureDate":1000}"#.utf8)
        let filter = try JSONDecoder().decode(SmartPhotoFilter.self, from: savedFilter)

        XCTAssertFalse(filter.matches(
            isFavorite: false,
            captureDate: Date(timeIntervalSinceReferenceDate: 500)
        ))
    }

    func testSmartFilterBetweenIncludesWholeEndDay() {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: 2020, month: 6, day: 1))!
        let end = calendar.date(from: DateComponents(year: 2020, month: 6, day: 30))!
        let filter = SmartPhotoFilter(
            captureDateEnabled: true,
            captureDateComparison: .between,
            captureDate: start,
            captureEndDate: end
        )

        XCTAssertTrue(filter.matches(isFavorite: false, captureDate: start))
        XCTAssertTrue(filter.matches(isFavorite: false, captureDate: end.addingTimeInterval(23 * 3600)))
        XCTAssertFalse(filter.matches(isFavorite: false, captureDate: start.addingTimeInterval(-1)))
        XCTAssertFalse(filter.matches(isFavorite: false, captureDate: end.addingTimeInterval(24 * 3600)))
    }

    func testLocationFilterOnlyAcceptsPhotosWithValidCoordinates() {
        let filter = SmartPhotoFilter(locationEnabled: true)

        XCTAssertTrue(filter.matches(isFavorite: false, captureDate: nil, hasLocation: true))
        XCTAssertFalse(filter.matches(isFavorite: false, captureDate: nil, hasLocation: false))
    }

    func testDisabledSmartFilterAcceptsEveryPhoto() {
        XCTAssertTrue(SmartPhotoFilter().matches(isFavorite: false, captureDate: nil))
    }
}

@MainActor
final class ViewingHistoryStoreTests: XCTestCase {
    func testHistoryIsRecentUniqueLimitedAndPersistent() {
        let suiteName = "DejaVuScreensaverTests.history.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ViewingHistoryStore(defaults: defaults, key: "history", limit: 3)
        store.record(assetIdentifier: "a", viewedAt: Date(timeIntervalSince1970: 1))
        store.record(assetIdentifier: "b", viewedAt: Date(timeIntervalSince1970: 2))
        store.record(assetIdentifier: "c", viewedAt: Date(timeIntervalSince1970: 3))
        store.record(assetIdentifier: "d", viewedAt: Date(timeIntervalSince1970: 4))
        store.record(assetIdentifier: "c", viewedAt: Date(timeIntervalSince1970: 5))

        XCTAssertEqual(store.entries.map(\.assetIdentifier), ["c", "d", "b"])
        XCTAssertEqual(store.entries.first?.viewedAt, Date(timeIntervalSince1970: 5))

        let reloaded = ViewingHistoryStore(defaults: defaults, key: "history", limit: 3)
        XCTAssertEqual(reloaded.entries, store.entries)

        reloaded.clear()
        XCTAssertTrue(reloaded.entries.isEmpty)
        XCTAssertNil(defaults.data(forKey: "history"))
    }
}
