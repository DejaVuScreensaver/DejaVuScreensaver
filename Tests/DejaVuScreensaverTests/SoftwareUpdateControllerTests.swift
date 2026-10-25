import Sparkle
import XCTest
@testable import DejaVuScreensaver

final class SoftwareUpdateControllerTests: XCTestCase {
    func testAvailableUpdateAndSessionDismissal() async throws {
        try await MainActor.run {
            let subject = SoftwareUpdateController()
            let updater = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil).updater
            // Sparkle's dictionary initializer is sufficient for this display-only fixture.
            let item = try XCTUnwrap(SUAppcastItem(dictionary: [
                "title": "DejaVuScreensaver 0.8.0",
                "enclosure": [
                    "url": "https://example.com/DejaVuScreensaver.zip",
                    "sparkle:version": "31",
                    "sparkle:shortVersionString": "0.8.0",
                ],
            ]))

            XCTAssertNil(subject.availableVersion)
            subject.updater(updater, didFindValidUpdate: item)
            XCTAssertEqual(subject.availableVersion, "0.8.0")
            XCTAssertTrue(subject.supportsGentleScheduledUpdateReminders)
            XCTAssertFalse(subject.standardUserDriverShouldHandleShowingScheduledUpdate(item, andInImmediateFocus: true))
            XCTAssertFalse(subject.standardUserDriverShouldHandleShowingScheduledUpdate(item, andInImmediateFocus: false))

            subject.standardUserDriverWillFinishUpdateSession()
            XCTAssertNil(subject.availableVersion)
        }
    }

    func testFailedCheckDoesNotClaimAppIsUpToDate() async {
        await MainActor.run {
            let subject = SoftwareUpdateController()
            let updater = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil).updater
            subject.updater(updater, didAbortWithError: NSError(
                domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet,
                userInfo: [NSLocalizedDescriptionKey: "The Internet connection appears to be offline."]
            ))
            XCTAssertEqual(subject.lastError, "The Internet connection appears to be offline.")
            subject.updaterDidNotFindUpdate(updater)
            XCTAssertNil(subject.lastError)
            XCTAssertNil(subject.availableVersion)
        }
    }
}
