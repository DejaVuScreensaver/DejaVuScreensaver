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

    func testProjectionCanConvertAPointBackToCoordinates() {
        let size = CGSize(width: 360, height: 180)

        let rome = WorldMapProjection.coordinate(for: CGPoint(x: 192.4964, y: 48.0972), in: size)
        XCTAssertEqual(rome.latitude, 41.9028, accuracy: 0.000_001)
        XCTAssertEqual(rome.longitude, 12.4964, accuracy: 0.000_001)
        XCTAssertEqual(
            WorldMapProjection.coordinate(for: CGPoint(x: -20, y: 300), in: size),
            PhotoCoordinate(latitude: -90, longitude: -180)
        )
    }

    func testZoomedProjectionKeepsCenterAndSelectionInSync() {
        let size = CGSize(width: 360, height: 180)
        let rome = PhotoCoordinate(latitude: 41.9028, longitude: 12.4964)
        let paris = PhotoCoordinate(latitude: 48.8581, longitude: 2.3530)

        XCTAssertEqual(
            WorldMapProjection.displayedPoint(for: rome, centeredAt: rome, zoom: 4, in: size),
            CGPoint(x: 180, y: 90)
        )

        let displayedParis = WorldMapProjection.displayedPoint(
            for: paris,
            centeredAt: rome,
            zoom: 4,
            in: size
        )
        let selectedParis = WorldMapProjection.coordinate(
            forDisplayedPoint: displayedParis,
            centeredAt: rome,
            zoom: 4,
            in: size
        )
        XCTAssertEqual(selectedParis.latitude, paris.latitude, accuracy: 0.000_001)
        XCTAssertEqual(selectedParis.longitude, paris.longitude, accuracy: 0.000_001)
    }

    func testRadiusSizeUsesMapScaleLatitudeAndZoom() {
        let size = CGSize(width: 360, height: 180)

        let equator = WorldMapProjection.radiusSize(
            kilometers: 111.32,
            at: PhotoCoordinate(latitude: 0, longitude: 0),
            zoom: 1,
            in: size
        )
        XCTAssertEqual(equator.width, 2, accuracy: 0.000_001)
        XCTAssertEqual(equator.height, 2, accuracy: 0.000_001)

        let latitudeSixty = WorldMapProjection.radiusSize(
            kilometers: 111.32,
            at: PhotoCoordinate(latitude: 60, longitude: 0),
            zoom: 4,
            in: size
        )
        XCTAssertEqual(latitudeSixty.width, 16, accuracy: 0.000_001)
        XCTAssertEqual(latitudeSixty.height, 8, accuracy: 0.000_001)
    }
}
