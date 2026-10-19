import Foundation

struct OfflinePlaceDatabase: Decodable {
    let cities: [OfflineCity]
    let regions: [OfflineArea]
    let countries: [OfflineArea]

    private enum CodingKeys: String, CodingKey {
        case cities = "c"
        case regions = "r"
        case countries = "n"
    }
}

struct OfflineCity: Decodable {
    let name: String
    let longitude: Int
    let latitude: Int

    private enum CodingKeys: String, CodingKey {
        case name = "n"
        case longitude = "x"
        case latitude = "y"
    }
}

struct OfflineArea: Decodable {
    let name: String
    let country: String?
    let bounds: [Int]
    let polygons: [[[Int]]]

    private enum CodingKeys: String, CodingKey {
        case name = "n"
        case country = "c"
        case bounds = "b"
        case polygons = "p"
    }
}

struct OfflinePlaceResolver {
    private static let coordinateScale = 10_000.0
    private static let maximumCityDistance = 30.0

    static let shared: OfflinePlaceResolver = {
        guard
            let url = Bundle.main.url(forResource: "OfflinePlaces", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let database = try? PropertyListDecoder().decode(OfflinePlaceDatabase.self, from: data)
        else {
            return OfflinePlaceResolver(database: OfflinePlaceDatabase(cities: [], regions: [], countries: []))
        }
        return OfflinePlaceResolver(database: database)
    }()

    let database: OfflinePlaceDatabase

    func name(for coordinate: PhotoCoordinate) -> String? {
        guard (-90...90).contains(coordinate.latitude),
              (-180...180).contains(coordinate.longitude) else { return nil }

        if let city = nearestCity(to: coordinate), city.distance <= Self.maximumCityDistance {
            return city.name
        }
        if let region = containingArea(in: database.regions, coordinate: coordinate) {
            return [region.name, region.country]
                .compactMap { $0 }
                .joined(separator: ", ")
        }
        return containingArea(in: database.countries, coordinate: coordinate)?.name
    }

    private func nearestCity(to coordinate: PhotoCoordinate) -> (name: String, distance: Double)? {
        var nearest: (name: String, distance: Double)?
        for city in database.cities {
            let distance = distance(
                from: coordinate,
                to: PhotoCoordinate(
                    latitude: Double(city.latitude) / Self.coordinateScale,
                    longitude: Double(city.longitude) / Self.coordinateScale
                )
            )
            if distance < (nearest?.distance ?? .infinity) {
                nearest = (city.name, distance)
            }
        }
        return nearest
    }

    private func containingArea(in areas: [OfflineArea], coordinate: PhotoCoordinate) -> OfflineArea? {
        let x = coordinate.longitude * Self.coordinateScale
        let y = coordinate.latitude * Self.coordinateScale
        return areas.first { area in
            guard area.bounds.count == 4,
                  x >= Double(area.bounds[0]), y >= Double(area.bounds[1]),
                  x <= Double(area.bounds[2]), y <= Double(area.bounds[3]) else { return false }
            return area.polygons.contains { polygon in
                polygon.reduce(false) { inside, ring in
                    ringContains(ring, x: x, y: y) ? !inside : inside
                }
            }
        }
    }

    private func ringContains(_ ring: [Int], x: Double, y: Double) -> Bool {
        guard ring.count >= 6 else { return false }
        let firstX = Double(ring[0])
        let firstY = Double(ring[1])
        var previousX = firstX
        var previousY = firstY
        var inside = false

        for index in stride(from: 2, to: ring.count, by: 2) {
            let currentX = previousX + Double(ring[index])
            let currentY = previousY + Double(ring[index + 1])
            if edgeCrossesRay(
                x: x, y: y,
                startX: previousX, startY: previousY,
                endX: currentX, endY: currentY
            ) {
                inside.toggle()
            }
            previousX = currentX
            previousY = currentY
        }
        if edgeCrossesRay(
            x: x, y: y,
            startX: previousX, startY: previousY,
            endX: firstX, endY: firstY
        ) {
            inside.toggle()
        }
        return inside
    }

    private func edgeCrossesRay(
        x: Double,
        y: Double,
        startX: Double,
        startY: Double,
        endX: Double,
        endY: Double
    ) -> Bool {
        guard (startY > y) != (endY > y) else { return false }
        return x < (endX - startX) * (y - startY) / (endY - startY) + startX
    }

    private func distance(from start: PhotoCoordinate, to end: PhotoCoordinate) -> Double {
        let radius = 6_371.0
        let startLatitude = start.latitude * .pi / 180
        let endLatitude = end.latitude * .pi / 180
        let latitudeDelta = endLatitude - startLatitude
        let longitudeDelta = (end.longitude - start.longitude) * .pi / 180
        let a = sin(latitudeDelta / 2) * sin(latitudeDelta / 2)
            + cos(startLatitude) * cos(endLatitude)
            * sin(longitudeDelta / 2) * sin(longitudeDelta / 2)
        let normalized = min(1, max(0, a))
        return radius * 2 * atan2(sqrt(normalized), sqrt(1 - normalized))
    }
}
