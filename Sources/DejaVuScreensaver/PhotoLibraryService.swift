import AppKit
import CoreLocation
import Photos

@MainActor
final class PhotoLibraryService: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    @Published private(set) var authorizationStatus: PHAuthorizationStatus
    @Published private(set) var albums: [AlbumSource] = []

    private let imageManager = PHCachingImageManager()
    private var collectionsByID: [String: PHAssetCollection] = [:]

    override init() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        super.init()
        PHPhotoLibrary.shared().register(self)
        if canReadLibrary {
            refreshAlbums()
        }
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    var canReadLibrary: Bool {
        authorizationStatus == .authorized || authorizationStatus == .limited
    }

    func requestAccess() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorizationStatus = status
        if canReadLibrary {
            refreshAlbums()
        }
    }

    func refreshAuthorization() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if canReadLibrary {
            refreshAlbums()
        }
    }

    func refreshAlbums() {
        guard canReadLibrary else {
            albums = []
            collectionsByID = [:]
            return
        }

        var discovered: [AlbumSource] = []
        var lookup: [String: PHAssetCollection] = [:]

        appendCollections(
            PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil),
            kind: .user,
            to: &discovered,
            lookup: &lookup
        )
        appendCollections(
            PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil),
            kind: .smart,
            to: &discovered,
            lookup: &lookup
        )

        collectionsByID = lookup
        albums = discovered.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    func fetchImages(
        from selectedAlbumIDs: Set<String>,
        matching smartFilter: SmartPhotoFilter
    ) -> [PHAsset] {
        guard canReadLibrary else { return [] }

        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "mediaType == %d",
            PHAssetMediaType.image.rawValue
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        if selectedAlbumIDs.isEmpty {
            return array(from: PHAsset.fetchAssets(with: options)).filter {
                smartFilter.matches(isFavorite: $0.isFavorite, captureDate: $0.creationDate)
            }
        }

        var seen = Set<String>()
        var result: [PHAsset] = []
        for id in selectedAlbumIDs.sorted() {
            guard let collection = collectionsByID[id] else { continue }
            let fetched = PHAsset.fetchAssets(in: collection, options: options)
            fetched.enumerateObjects { asset, _, _ in
                if seen.insert(asset.localIdentifier).inserted {
                    result.append(asset)
                }
            }
        }
        return result.filter {
            smartFilter.matches(isFavorite: $0.isFavorite, captureDate: $0.creationDate)
        }
    }

    func asset(withIdentifier identifier: String) -> PHAsset? {
        guard canReadLibrary else { return nil }
        return PHAsset.fetchAssets(
            withLocalIdentifiers: [identifier],
            options: nil
        ).firstObject
    }

    func metadata(forAssetIdentifier identifier: String) -> PhotoMetadata? {
        guard let asset = asset(withIdentifier: identifier) else { return nil }
        return metadata(for: asset)
    }

    @discardableResult
    func requestImage(
        for asset: PHAsset,
        targetSize: CGSize,
        deliveryMode: PHImageRequestOptionsDeliveryMode = .opportunistic,
        completion: @escaping (NSImage?, Bool) -> Void
    ) -> PHImageRequestID {
        let options = PHImageRequestOptions()
        options.deliveryMode = deliveryMode
        options.resizeMode = deliveryMode == .highQualityFormat ? .exact : .fast
        options.isNetworkAccessAllowed = true

        return imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { image, info in
            let cancelled = info?[PHImageCancelledKey] as? Bool ?? false
            guard !cancelled else { return }
            let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
            completion(image, !isDegraded)
        }
    }

    func cancelImageRequest(_ requestID: PHImageRequestID) {
        imageManager.cancelImageRequest(requestID)
    }

    func metadata(for asset: PHAsset) -> PhotoMetadata {
        let resources = PHAssetResource.assetResources(for: asset)
        let filename = resources.first(where: {
            $0.type == .photo || $0.type == .fullSizePhoto
        })?.originalFilename ?? resources.first?.originalFilename ?? "Untitled"

        let location: String?
        if let coordinate = asset.location?.coordinate {
            location = String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
        } else {
            location = nil
        }

        return PhotoMetadata(
            filename: filename,
            captureDate: asset.creationDate,
            location: location
        )
    }

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor [weak self] in
            self?.refreshAlbums()
        }
    }

    private func appendCollections(
        _ fetchResult: PHFetchResult<PHAssetCollection>,
        kind: AlbumSource.Kind,
        to albums: inout [AlbumSource],
        lookup: inout [String: PHAssetCollection]
    ) {
        for index in 0..<fetchResult.count {
            let collection = fetchResult.object(at: index)
            guard collection.canContainAssets else { continue }
            let id = collection.localIdentifier
            let title = collection.localizedTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
            albums.append(AlbumSource(
                id: id,
                title: title?.isEmpty == false ? title! : "Untitled Album",
                kind: kind
            ))
            lookup[id] = collection
        }
    }

    private func array(from fetchResult: PHFetchResult<PHAsset>) -> [PHAsset] {
        var result: [PHAsset] = []
        result.reserveCapacity(fetchResult.count)
        fetchResult.enumerateObjects { asset, _, _ in result.append(asset) }
        return result
    }
}
