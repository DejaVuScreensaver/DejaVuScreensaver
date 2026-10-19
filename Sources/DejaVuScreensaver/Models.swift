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
    case fade

    var id: String { rawValue }
    var title: String {
        switch self {
        case .still: "Static"
        case .kenBurns: "Ken Burns"
        case .fade: "Fade"
        }
    }
}

enum PhotoOrder: String, Codable, CaseIterable, Identifiable {
    case random
    case chronological
    case reverseChronological

    var id: String { rawValue }
    var title: String {
        switch self {
        case .random: "Random"
        case .chronological: "Oldest first"
        case .reverseChronological: "Newest first"
        }
    }
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

enum ClockTimeFormat: String, Codable, CaseIterable, Identifiable {
    case system
    case twelveHour
    case twentyFourHour

    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: "System"
        case .twelveHour: "12-hour"
        case .twentyFourHour: "24-hour"
        }
    }

    func string(
        from date: Date,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        switch self {
        case .system:
            formatter.timeStyle = .short
        case .twelveHour:
            formatter.dateFormat = "h:mm a"
        case .twentyFourHour:
            formatter.dateFormat = "HH:mm"
        }
        return formatter.string(from: date)
    }
}

enum CaptureDateComparison: String, Codable, CaseIterable, Identifiable {
    case before
    case after
    case between

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct SmartPhotoFilter: Codable, Equatable {
    var favoriteEnabled = false
    var locationEnabled = false
    var captureDateEnabled = false
    var captureDateComparison: CaptureDateComparison = .before
    var captureDate = Calendar.current.startOfDay(for: Date())
    // Optional so filters saved before the period option existed still decode.
    var captureEndDate: Date?

    private enum CodingKeys: String, CodingKey {
        case favoriteEnabled
        case locationEnabled
        case captureDateEnabled
        case captureDateComparison
        case captureDate
        case captureEndDate
    }

    init(
        favoriteEnabled: Bool = false,
        locationEnabled: Bool = false,
        captureDateEnabled: Bool = false,
        captureDateComparison: CaptureDateComparison = .before,
        captureDate: Date = Calendar.current.startOfDay(for: Date()),
        captureEndDate: Date? = nil
    ) {
        self.favoriteEnabled = favoriteEnabled
        self.locationEnabled = locationEnabled
        self.captureDateEnabled = captureDateEnabled
        self.captureDateComparison = captureDateComparison
        self.captureDate = captureDate
        self.captureEndDate = captureEndDate
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        favoriteEnabled = try values.decodeIfPresent(Bool.self, forKey: .favoriteEnabled) ?? false
        locationEnabled = try values.decodeIfPresent(Bool.self, forKey: .locationEnabled) ?? false
        captureDateEnabled = try values.decodeIfPresent(Bool.self, forKey: .captureDateEnabled) ?? false
        captureDateComparison = try values.decodeIfPresent(CaptureDateComparison.self, forKey: .captureDateComparison) ?? .before
        captureDate = try values.decodeIfPresent(Date.self, forKey: .captureDate) ?? Calendar.current.startOfDay(for: Date())
        captureEndDate = try values.decodeIfPresent(Date.self, forKey: .captureEndDate)
    }

    /// Last day of a "between" period; never before the start day.
    var periodEndDate: Date {
        max(captureEndDate ?? Calendar.current.startOfDay(for: Date()), captureDate)
    }

    var isEnabled: Bool { favoriteEnabled || locationEnabled || captureDateEnabled }

    func matches(isFavorite: Bool, captureDate assetDate: Date?, hasLocation: Bool = false) -> Bool {
        var results: [Bool] = []
        if favoriteEnabled {
            results.append(isFavorite)
        }
        if locationEnabled {
            results.append(hasLocation)
        }
        if captureDateEnabled {
            let dateMatches = assetDate.map { date -> Bool in
                switch captureDateComparison {
                case .before: return date < captureDate
                case .after: return date > captureDate
                case .between:
                    // Inclusive of the whole end day.
                    let end = Calendar.current.date(byAdding: .day, value: 1, to: periodEndDate) ?? .distantFuture
                    return date >= captureDate && date < end
                }
            } ?? false
            results.append(dateMatches)
        }
        guard !results.isEmpty else { return true }
        return results.allSatisfy { $0 }
    }
}

struct AppPreferences: Codable, Equatable {
    private var preferencesVersion = 8
    var selectedAlbumIDs: Set<String> = []
    var smartFilter = SmartPhotoFilter()
    var intervalSeconds: Double = 5
    var idleEnabled = false
    var idleMinutes: Double = 10
    var launchAtLogin = false
    var showCaptureDate = true
    var showLocation = true
    var showMinimap = false
    var animateMinimapZoom = true
    var showFilename = true
    var showClock = false
    var clockPosition: ClockPosition = .topCenter
    var clockStyle: SlideshowClockStyle = .apple
    var clockSize: SlideshowClockSize = .medium
    var clockTimeFormat: ClockTimeFormat = .system
    var showClockBackground = false
    var showPhotoNumber = true
    var slideshowStyle: SlideshowStyle = .still
    var photoOrder: PhotoOrder = .random
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
        case showMinimap
        case animateMinimapZoom
        case showFilename
        case showClock
        case clockPosition
        case clockStyle
        case clockSize
        case clockTimeFormat
        case showClockBackground
        case showPhotoNumber
        case slideshowStyle
        case photoOrder
        case scaleMode
        case mouseMovementThreshold
        case lockOnDisallowedKey
        case stayOpenUntilEnded
    }

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let savedVersion = try values.decodeIfPresent(Int.self, forKey: .preferencesVersion) ?? 1
        preferencesVersion = 8
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
        showMinimap = try values.decodeIfPresent(Bool.self, forKey: .showMinimap) ?? false
        animateMinimapZoom = try values.decodeIfPresent(Bool.self, forKey: .animateMinimapZoom) ?? true
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
        clockTimeFormat = try values.decodeIfPresent(ClockTimeFormat.self, forKey: .clockTimeFormat) ?? .system
        showClockBackground = try values.decodeIfPresent(Bool.self, forKey: .showClockBackground) ?? false
        showPhotoNumber = try values.decodeIfPresent(Bool.self, forKey: .showPhotoNumber) ?? true
        slideshowStyle = try values.decodeIfPresent(SlideshowStyle.self, forKey: .slideshowStyle) ?? .still
        photoOrder = try values.decodeIfPresent(PhotoOrder.self, forKey: .photoOrder) ?? .random
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

struct PhotoCoordinate: Equatable {
    let latitude: Double
    let longitude: Double
}

struct PhotoMetadata: Equatable {
    let filename: String
    let captureDate: Date?
    let location: String?
    let coordinate: PhotoCoordinate?
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
