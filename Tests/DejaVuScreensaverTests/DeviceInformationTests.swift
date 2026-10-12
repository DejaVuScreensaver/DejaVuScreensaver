import XCTest
@testable import DejaVuScreensaver

final class DeviceInformationTests: XCTestCase {
    func testEmailBodyContainsMessageAndUsefulDeviceDetails() {
        let information = DeviceInformation(
            appVersion: "1.2.3",
            appBuild: "45",
            macModel: "MacExample1,1",
            chip: "Example Chip",
            memory: "16 GB",
            macOS: "macOS 27.0",
            displays: "2560×1440"
        )

        let body = information.emailBody(message: "  Arrow key did not work.  ")

        XCTAssertTrue(body.hasPrefix("Arrow key did not work."))
        XCTAssertTrue(body.contains("DejaVuScreensaver: v1.2.3 (45)"))
        XCTAssertTrue(body.contains("Mac: MacExample1,1"))
        XCTAssertTrue(body.contains("Displays: 2560×1440"))
    }
}
