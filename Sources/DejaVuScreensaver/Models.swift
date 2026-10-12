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

enum ClockPosition: String, Codable, CaseIterable, Identifiable {
    case topLeading
    case topCenter
    case topTrailing
    case bottomLeading
    case bottomCenter
    case bottomTrailing

    var id: String { rawValue }
    var title: String {
        switch self {
        case .topLeading: "Top left"
        case .topCenter: "Top center"
        case .topTrailing: "Top right"
        case .bottomLeading: "Bottom left"
        case .bottomCenter: "Bottom center"
        case .bottomTrailing: "Bottom right"
        }
    }
}

enum SlideshowClockStyle: String, Codable, CaseIterable, Identifiable {
    case apple
    case appleLight
    case rounded
    // Legacy values kept only to decode preferences from older builds.
    case classic
    case digital

    var id: String { rawValue }
    static var allCases: [SlideshowClockStyle] { [.apple, .appleLight, .rounded] }

    var title: String {
        switch self {
        case .apple: "Apple (SF Pro)"
        case .appleLight: "Apple Light"
        case .rounded: "Rounded"
        case .classic, .digital: "Apple (SF Pro)"
        }
    }
}

enum SlideshowClockSize: String, Codable, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var multiplier: CGFloat {
        switch self {
        case .small: 0.75
        case .medium: 1
        case .large: 1.3
        }
    }
}

enum SmartFilterMatch: String, Codable, CaseIterable, Identifiable {
    case all
    case any

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum CaptureDateComparison: String, Codable, CaseIterable, Identifiable {
    case before
    case after

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct SmartPhotoFilter: Codable, Equatable {
    var match: SmartFilterMatch = .all
    var favoriteEnabled = false
    var captureDateEnabled = false
    var captureDateComparison: CaptureDateComparison = .before
    var captureDate = Calendar.current.startOfDay(for: Date())

    var isEnabled: Bool { favoriteEnabled || captureDateEnabled }

    func matches(isFavorite: Bool, captureDate assetDate: Date?) -> Bool {
        var results: [Bool] = []
        if favoriteEnabled {
            results.append(isFavorite)
        }
        if captureDateEnabled {
            let dateMatches = assetDate.map {
                captureDateComparison == .before ? $0 < captureDate : $0 > captureDate
            } ?? false
            results.append(dateMatches)
        }
        guard !results.isEmpty else { return true }
        return match == .all ? results.allSatisfy { $0 } : results.contains(true)
    }
}

struct AppPreferences: Codable, Equatable {
    private var preferencesVersion = 6
    var selectedAlbumIDs: Set<String> = []
    var smartFilter = SmartPhotoFilter()
    var intervalSeconds: Double = 5
    var idleEnabled = false
    var idleMinutes: Double = 10
    var launchAtLogin = false
    var showCaptureDate = true
    var showLocation = true
    var showFilename = true
    var showClock = false
    var clockPosition: ClockPosition = .topCenter
    var clockStyle: SlideshowClockStyle = .apple
    var clockSize: SlideshowClockSize = .medium
    var showClockBackground = false
    var showPhotoNumber = true
    var slideshowStyle: SlideshowStyle = .still
    var scaleMode: PhotoScaleMode = .fit
    var mouseMovementThreshold: Double = 18
    var lockOnDisallowedKey = true
    var stayOpenUntilEnded = false

    private enum CodingKeys: String, CodingKey {
        case preferencesVersion
        case selectedAlbumIDs
        case smartFilter
        case intervalSeconds
        case idleEnabled
        case idleMinutes
        case launchAtLogin
        case showCaptureDate
        case showLocation
        case showFilename
        case showClock
        case clockPosition
        case clockStyle
        case clockSize
        case showClockBackground
        case showPhotoNumber
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
        preferencesVersion = 6
        selectedAlbumIDs = try values.decodeIfPresent(Set<String>.self, forKey: .selectedAlbumIDs) ?? []
        smartFilter = try values.decodeIfPresent(SmartPhotoFilter.self, forKey: .smartFilter) ?? SmartPhotoFilter()
        let savedInterval = try values.decodeIfPresent(Double.self, forKey: .intervalSeconds) ?? 5
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
        clockPosition = try values.decodeIfPresent(ClockPosition.self, forKey: .clockPosition) ?? .topCenter
        let savedClockStyle = try values.decodeIfPresent(SlideshowClockStyle.self, forKey: .clockStyle)
        if savedClockStyle == .classic
            || savedClockStyle == .digital
            || (savedVersion < 5 && savedClockStyle == .rounded) {
            clockStyle = .apple
        } else {
            clockStyle = savedClockStyle ?? .apple
        }
        clockSize = try values.decodeIfPresent(SlideshowClockSize.self, forKey: .clockSize) ?? .medium
        showClockBackground = try values.decodeIfPresent(Bool.self, forKey: .showClockBackground) ?? false
        showPhotoNumber = try values.decodeIfPresent(Bool.self, forKey: .showPhotoNumber) ?? true
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
