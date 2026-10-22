import Foundation

struct ViewingHistoryEntry: Codable, Equatable, Identifiable {
    let assetIdentifier: String
    let viewedAt: Date

    var id: String { assetIdentifier }
}

@MainActor
final class ViewingHistoryStore: ObservableObject {
    @Published private(set) var entries: [ViewingHistoryEntry]

    private static let defaultKey = "DejaVuScreensaver.viewingHistory.v1"
    private static let legacyKey = "OpenPhotoSaver.viewingHistory.v1"
    private let defaults: UserDefaults
    private let key: String
    private let limit: Int

    init(
        defaults: UserDefaults = .standard,
        key: String = "DejaVuScreensaver.viewingHistory.v1",
        limit: Int = 100
    ) {
        self.defaults = defaults
        self.key = key
        self.limit = max(1, limit)

        let storedData = defaults.data(forKey: key)
            ?? (key == Self.defaultKey ? defaults.data(forKey: Self.legacyKey) : nil)
        if
            let data = storedData,
            let decoded = try? JSONDecoder().decode([ViewingHistoryEntry].self, from: data)
        {
            entries = Array(decoded.prefix(self.limit))
        } else {
            entries = []
        }
        if key == Self.defaultKey, defaults.data(forKey: Self.legacyKey) != nil {
            save()
            defaults.removeObject(forKey: Self.legacyKey)
        }
    }

    func record(assetIdentifier: String, viewedAt: Date = Date()) {
        guard !assetIdentifier.isEmpty else { return }
        entries.removeAll { $0.assetIdentifier == assetIdentifier }
        entries.insert(
            ViewingHistoryEntry(assetIdentifier: assetIdentifier, viewedAt: viewedAt),
            at: 0
        )
        if entries.count > limit {
            entries.removeLast(entries.count - limit)
        }
        save()
    }

    func clear() {
        entries = []
        defaults.removeObject(forKey: key)
        if key == Self.defaultKey {
            defaults.removeObject(forKey: Self.legacyKey)
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: key)
    }
}
