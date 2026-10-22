import AppKit
import SwiftUI
import XCTest
@testable import DejaVuScreensaver

@MainActor
final class SecurityHandlingTests: XCTestCase {
    func testLockNotificationRequiresIndependentLockConfirmation() {
        let service = TestLockService()
        let model = AppModel(lockService: service)

        XCTAssertFalse(model.handleSessionLockedNotification())
        service.isSessionLocked = true
        XCTAssertTrue(model.handleSessionLockedNotification())
        service.isSessionLocked = false
        XCTAssertFalse(model.handleSessionLockedNotification())
        XCTAssertEqual(service.lockRequests, 0)
    }

    func testLockCoverStaysPausedAndBlocksPlaybackControls() {
        let controller = SlideshowController(library: PhotoLibraryService())
        controller.prepareForLock()
        controller.togglePause()
        controller.next()
        controller.previous()
        controller.showExitControl()

        XCTAssertTrue(controller.isSecurityCoverVisible)
        XCTAssertTrue(controller.isPaused)
        XCTAssertFalse(controller.isExitControlVisible)
        XCTAssertFalse(controller.isLoading)
        XCTAssertNil(controller.image)
        XCTAssertNil(controller.metadata)

        controller.showSecurityFailure("Test lock failure")
        controller.prepareForLock() // Display changes must not erase the warning.
        XCTAssertEqual(controller.securityMessage, "Test lock failure")
        XCTAssertTrue(controller.isSecurityCoverVisible)

        controller.stop()
        XCTAssertFalse(controller.isSecurityCoverVisible)
        XCTAssertNil(controller.securityMessage)
    }

    func testSecurityCoverIsOpaqueOverSensitiveContent() throws {
        let controller = SlideshowController(library: PhotoLibraryService())
        controller.prepareForLock()
        for failure in [false, true] {
            if failure { controller.showSecurityFailure("Test lock failure") }
            let renderer = ImageRenderer(content:
                ZStack {
                    Color.red
                    SlideshowSecurityCover(controller: controller)
                }
                .frame(width: 512, height: 384)
            )
            let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(renderer.cgImage))
            let color = try XCTUnwrap(bitmap.colorAt(x: 2, y: 2)?.usingColorSpace(.deviceRGB))
            XCTAssertEqual(color.alphaComponent, 1, accuracy: 0.001)
            XCTAssertEqual(color.redComponent, 0, accuracy: 0.001)
            XCTAssertEqual(color.greenComponent, 0, accuracy: 0.001)
            XCTAssertEqual(color.blueComponent, 0, accuracy: 0.001)
        }
    }
}

private final class TestLockService: ScreenLocking {
    let isAvailable = true
    var isSessionLocked = false
    var lockRequests = 0

    func lockNow() -> Bool {
        lockRequests += 1
        return false
    }
}
