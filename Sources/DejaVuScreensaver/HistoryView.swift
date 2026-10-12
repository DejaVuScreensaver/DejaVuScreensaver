import AppKit
import Photos
import SwiftUI

struct HistoryView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var history: ViewingHistoryStore
    @State private var selectedAssetID: String?

    init(model: AppModel) {
        self.model = model
        history = model.viewingHistory
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Recently Viewed")
                        .font(.largeTitle.bold())
                    Text("Photos that actually appeared during your slideshows")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Clear History", role: .destructive) {
                    history.clear()
                    selectedAssetID = nil
                }
                .disabled(history.entries.isEmpty)
            }

            if history.entries.isEmpty {
                ContentUnavailableView(
                    "No Recently Viewed Photos",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Start a slideshow. Photos are added here once they appear on screen.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HSplitView {
                    ScrollView {
                        LazyVStack(spacing: 7) {
                            ForEach(history.entries) { entry in
                                historyRow(entry)
                            }
                        }
                        .padding(4)
                    }
                    .frame(minWidth: 280, idealWidth: 320)

                    if let selectedEntry {
                        HistoryPhotoDetail(
                            entry: selectedEntry,
                            library: model.photoLibrary
                        )
                        .frame(minWidth: 420)
                    } else {
                        ContentUnavailableView(
                            "Select a Photo",
                            systemImage: "photo",
                            description: Text("Choose an item from your recent history.")
                        )
                        .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .padding(22)
        .frame(minWidth: 760, idealWidth: 900, minHeight: 540, idealHeight: 650)
        .onAppear {
            if selectedAssetID == nil {
                selectedAssetID = history.entries.first?.assetIdentifier
            }
        }
        .onChange(of: history.entries) { _, entries in
            if let selectedAssetID,
               !entries.contains(where: { $0.assetIdentifier == selectedAssetID })
            {
                self.selectedAssetID = entries.first?.assetIdentifier
            }
        }
    }

    private var selectedEntry: ViewingHistoryEntry? {
        guard let selectedAssetID else { return nil }
        return history.entries.first { $0.assetIdentifier == selectedAssetID }
    }

    private func historyRow(_ entry: ViewingHistoryEntry) -> some View {
        Button {
            selectedAssetID = entry.assetIdentifier
        } label: {
            HStack(spacing: 11) {
                HistoryAssetImage(
                    assetIdentifier: entry.assetIdentifier,
                    library: model.photoLibrary,
                    targetSize: CGSize(width: 180, height: 140)
                )
                .frame(width: 90, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 4) {
                    Text(model.photoLibrary.metadata(forAssetIdentifier: entry.assetIdentifier)?.filename ?? "Unavailable Photo")
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    Text(entry.viewedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(7)
            .background(
                selectedAssetID == entry.assetIdentifier
                    ? Color.accentColor.opacity(0.16)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 9)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct HistoryPhotoDetail: View {
    let entry: ViewingHistoryEntry
    let library: PhotoLibraryService

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HistoryAssetImage(
                assetIdentifier: entry.assetIdentifier,
                library: library,
                targetSize: CGSize(width: 1600, height: 1200)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 12))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if let metadata = library.metadata(forAssetIdentifier: entry.assetIdentifier) {
                Text(metadata.filename)
                    .font(.headline)
                HStack(spacing: 16) {
                    if let date = metadata.captureDate {
                        Label(date.formatted(date: .long, time: .shortened), systemImage: "calendar")
                    }
                    if let location = metadata.location {
                        Label(location, systemImage: "location.fill")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Text("This photo is no longer available in the permitted Photos library.")
                    .foregroundStyle(.secondary)
            }

            Label(
                "Viewed \(entry.viewedAt.formatted(date: .abbreviated, time: .shortened))",
                systemImage: "clock"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.leading, 14)
    }
}

private struct HistoryAssetImage: View {
    let assetIdentifier: String
    let library: PhotoLibraryService
    let targetSize: CGSize

    @State private var image: NSImage?
    @State private var requestID: PHImageRequestID?

    var body: some View {
        ZStack {
            Color.black.opacity(0.88)
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear(perform: load)
        .onChange(of: assetIdentifier) { _, _ in load() }
        .onDisappear(perform: cancel)
    }

    private func load() {
        cancel()
        image = nil
        let requestedAssetIdentifier = assetIdentifier
        guard let asset = library.asset(withIdentifier: requestedAssetIdentifier) else { return }
        requestID = library.requestImage(for: asset, targetSize: targetSize) { loadedImage, _ in
            Task { @MainActor in
                guard assetIdentifier == requestedAssetIdentifier else { return }
                image = loadedImage
            }
        }
    }

    private func cancel() {
        if let requestID {
            library.cancelImageRequest(requestID)
        }
        requestID = nil
    }
}
