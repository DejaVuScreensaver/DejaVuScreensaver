import XCTest
@testable import DejaVuScreensaver

final class OfflinePlaceResolverTests: XCTestCase {
    func testUsesNearbyCityBeforeAdministrativeAreas() {
        let resolver = OfflinePlaceResolver(database: OfflinePlaceDatabase(
            cities: [OfflineCity(name: "Rome", longitude: 124_813, latitude: 418_979)],
            regions: [area(name: "Lazio", country: "Italy", minimum: 0, maximum: 20)],
            countries: [area(name: "Italy", minimum: 0, maximum: 20)]
        ))

        XCTAssertEqual(
            resolver.name(for: PhotoCoordinate(latitude: 41.89332, longitude: 12.482932)),
            "Rome"
        )
    }

    func testFallsBackFromRegionAndCountryToCoordinatesOnly() {
        let resolver = OfflinePlaceResolver(database: OfflinePlaceDatabase(
            cities: [],
            regions: [area(name: "Tuscany", country: "Italy", minimum: 0, maximum: 10)],
            countries: [area(name: "Italy", minimum: 0, maximum: 20)]
        ))

        XCTAssertEqual(
            resolver.name(for: PhotoCoordinate(latitude: 5, longitude: 5)),
            "Tuscany, Italy"
        )
        XCTAssertEqual(
            resolver.name(for: PhotoCoordinate(latitude: 15, longitude: 15)),
            "Italy"
        )
        XCTAssertNil(resolver.name(for: PhotoCoordinate(latitude: -20, longitude: -20)))
    }

    func testSearchesCitiesAndAddsTheirCountry() {
        let resolver = OfflinePlaceResolver(database: OfflinePlaceDatabase(
            cities: [OfflineCity(name: "Rome", longitude: 50_000, latitude: 50_000)],
            regions: [],
            countries: [area(name: "Italy", minimum: 0, maximum: 10)]
        ))

        XCTAssertEqual(
            resolver.cities(matching: "rom"),
            [OfflineCitySearchResult(
                name: "Rome",
                country: "Italy",
                coordinate: PhotoCoordinate(latitude: 5, longitude: 5)
            )]
        )
        XCTAssertTrue(resolver.isInCountry(
            named: "Italy",
            coordinate: PhotoCoordinate(latitude: 5, longitude: 5)
        ))
    }

    private func area(
        name: String,
        country: String? = nil,
        minimum: Int,
        maximum: Int
    ) -> OfflineArea {
        let minimum = minimum * 10_000
        let maximum = maximum * 10_000
        return OfflineArea(
            name: name,
            country: country,
            bounds: [minimum, minimum, maximum, maximum],
            polygons: [[[
                minimum, minimum,
                maximum - minimum, 0,
                0, maximum - minimum,
                minimum - maximum, 0,
            ]]]
        )
    }
}
