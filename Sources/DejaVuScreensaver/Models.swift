import Foundation

enum PhotoScaleMode: String, Codable, CaseIterable, Identifiable {
    case fit
    case fill

    var id: String { rawValue }
    var title: String { self == .fit ? "Fit" : "Fill" }
}

enum SlideshowStyle: String, Codable, CaseIterable, Identifiable {
    case still = "static"
    case kenBurns

    var id: String { rawValue }
    var title: String { self == .still ? "Static" : "Ken Burns" }
}

struct AppPreferences: Codable, Equatable {
    private var preferencesVersion = 3
    var selectedAlbumIDs: Set<String> = []
    var intervalSeconds: Double = 10
    var idleEnabled = false
    var idleMinutes: Double = 10
    var launchAtLogin = false
    var showCaptureDate = true
    var showLocation = true
    var showFilename = true
    var showClock = false
    var slideshowStyle: SlideshowStyle = .still
    var scaleMode: PhotoScaleMode = .fit
    var mouseMovementThreshold: Double = 18
    var lockOnDisallowedKey = true
    var stayOpenUntilEnded = false

    private enum CodingKeys: String, CodingKey {
        case preferencesVersion
        case selectedAlbumIDs
        case intervalSeconds
        case idleEnabled
        case idleMinutes
        case launchAtLogin
        case showCaptureDate
        case showLocation
        case showFilename
        case showClock
        case slideshowStyle
        case scaleMode
        case mouseMovementThreshold
        case lockOnDisallowedKey
        case stayOpenUntilEnded
    }

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let savedVersion = try values.decodeIfPresent(Int.self, forKey: .preferencesVersion) ?? 1
        preferencesVersion = 3
        selectedAlbumIDs = try values.decodeIfPresent(Set<String>.self, forKey: .selectedAlbumIDs) ?? []
        let savedInterval = try values.decodeIfPresent(Double.self, forKey: .intervalSeconds) ?? 10
        intervalSeconds = min(30, max(1, savedInterval))
        // Version 1 enabled idle launch by default. Migrate it to an explicit
        // opt-in so granting Photos access can never start a slideshow.
        idleEnabled = savedVersion >= 2
            ? (try values.decodeIfPresent(Bool.self, forKey: .idleEnabled) ?? false)
            : false
        idleMinutes = try values.decodeIfPresent(Double.self, forKey: .idleMinutes) ?? 10
        launchAtLogin = try values.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        showCaptureDate = try values.decodeIfPresent(Bool.self, forKey: .showCaptureDate) ?? true
        showLocation = try values.decodeIfPresent(Bool.self, forKey: .showLocation) ?? true
        showFilename = try values.decodeIfPresent(Bool.self, forKey: .showFilename) ?? true
        showClock = try values.decodeIfPresent(Bool.self, forKey: .showClock) ?? false
        slideshowStyle = try values.decodeIfPresent(SlideshowStyle.self, forKey: .slideshowStyle) ?? .still
        scaleMode = try values.decodeIfPresent(PhotoScaleMode.self, forKey: .scaleMode) ?? .fit
        mouseMovementThreshold = try values.decodeIfPresent(Double.self, forKey: .mouseMovementThreshold) ?? 18
        lockOnDisallowedKey = try values.decodeIfPresent(Bool.self, forKey: .lockOnDisallowedKey) ?? true
        stayOpenUntilEnded = try values.decodeIfPresent(Bool.self, forKey: .stayOpenUntilEnded) ?? false
    }
}

struct AlbumSource: Identifiable, Hashable {
    let id: String
    let title: String
    let kind: Kind

    enum Kind: String, Hashable {
        case user
        case smart
    }
}

struct PhotoMetadata: Equatable {
    let filename: String
    let captureDate: Date?
    let location: String?
}

@MainActor
final class PreferencesStore: ObservableObject {
    @Published var value: AppPreferences {
        didSet { save() }
    }

    private static let key = "DejaVuScreensaver.preferences.v1"
    private static let legacyKey = "OpenPhotoSaver.preferences.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if
            let data = defaults.data(forKey: Self.key) ?? defaults.data(forKey: Self.legacyKey),
            let decoded = try? JSONDecoder().decode(AppPreferences.self, from: data)
        {
            value = decoded
        } else {
            value = AppPreferences()
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
