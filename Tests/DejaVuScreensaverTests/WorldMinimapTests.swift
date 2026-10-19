import XCTest
@testable import DejaVuScreensaver

final class WorldMinimapTests: XCTestCase {
    func testEquirectangularProjectionPlacesCenterAndCorners() {
        let size = CGSize(width: 360, height: 180)

        XCTAssertEqual(
            WorldMapProjection.point(for: PhotoCoordinate(latitude: 0, longitude: 0), in: size),
            CGPoint(x: 180, y: 90)
        )
        XCTAssertEqual(
            WorldMapProjection.point(for: PhotoCoordinate(latitude: 90, longitude: -180), in: size),
            CGPoint(x: 0, y: 0)
        )
        XCTAssertEqual(
            WorldMapProjection.point(for: PhotoCoordinate(latitude: -90, longitude: 180), in: size),
            CGPoint(x: 360, y: 180)
        )
    }
}
