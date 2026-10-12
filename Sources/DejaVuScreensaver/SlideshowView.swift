import SwiftUI

struct SlideshowView: View {
    @ObservedObject var controller: SlideshowController
    let preferences: AppPreferences
    let onEnd: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                if let image = controller.image {
                    SlideshowPhoto(
                        image: image,
                        size: geometry.size,
                        preferences: preferences
                    )
                        .id(controller.currentAssetID)
                        .transition(.opacity)
                } else if controller.isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                }

                if preferences.showClock {
                    clockOverlay(for: geometry.size)
                }

                if let metadata = controller.metadata {
                    VStack {
                        Spacer()
                        HStack(alignment: .bottom) {
                            metadataOverlay(metadata)
                            Spacer()
                            playbackStatus
                        }
                        .padding(28)
                    }
                }


                if preferences.stayOpenUntilEnded, controller.isExitControlVisible {
                    VStack {
                        HStack {
                            Spacer()
                            Button("End Slideshow", action: onEnd)
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                        }
                        Spacer()
                    }
                    .padding(28)
                }

                if let message = controller.securityMessage {
                    Color.black.opacity(0.94).ignoresSafeArea()
                    VStack(spacing: 14) {
                        Image(systemName: "lock.trianglebadge.exclamationmark")
                            .font(.system(size: 44))
                        Text("Couldn’t open the macOS Lock Screen")
                            .font(.title2.bold())
                        Text(message)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Text("Press Control–Command–Q to lock this Mac.")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .padding(36)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
                    .padding(40)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .animation(.easeInOut(duration: 0.45), value: controller.currentAssetID)
    }

    private func clockOverlay(for size: CGSize) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(context.date.formatted(date: .omitted, time: .shortened))
                .font(preferences.clockStyle.font(size: min(140, max(64, size.width * 0.1))))
                .monospacedDigit()
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.9), radius: 12)
                .padding(.horizontal, preferences.clockStyle == .rounded ? 24 : 0)
                .padding(.vertical, preferences.clockStyle == .rounded ? 10 : 0)
                .background {
                    if preferences.clockStyle == .rounded {
                        Capsule().fill(.black.opacity(0.42))
                    }
                }
                .accessibilityLabel("Current time")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: clockAlignment)
        .padding(.horizontal, 54)
        .padding(.vertical, preferences.clockPosition.isBottom ? 100 : 54)
    }

    private var clockAlignment: Alignment {
        switch preferences.clockPosition {
        case .topLeading: .topLeading
        case .topCenter: .top
        case .topTrailing: .topTrailing
        case .bottomLeading: .bottomLeading
        case .bottomCenter: .bottom
        case .bottomTrailing: .bottomTrailing
        }
    }

    @ViewBuilder
    private func metadataOverlay(_ metadata: PhotoMetadata) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if preferences.showCaptureDate, let date = metadata.captureDate {
                Label(date.formatted(date: .long, time: .shortened), systemImage: "calendar")
            }
            if preferences.showLocation, let location = metadata.location {
                Label(location, systemImage: "location.fill")
            }
            if preferences.showFilename {
                Label(metadata.filename, systemImage: "photo")
            }
        }
        .font(.system(size: 15, weight: .medium, design: .rounded))
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.black.opacity(0.52), in: RoundedRectangle(cornerRadius: 13))
    }

    private var playbackStatus: some View {
        HStack(spacing: 10) {
            Image(systemName: controller.isPaused ? "pause.fill" : "play.fill")
            if preferences.showPhotoNumber {
                Text("\(controller.currentPosition) / \(controller.assetCount)")
            }
        }
        .font(.system(size: 14, weight: .semibold, design: .rounded))
        .foregroundStyle(.white)
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(.black.opacity(0.52), in: Capsule())
    }
}

extension SlideshowClockStyle {
    func font(size: CGFloat) -> Font {
        switch self {
        case .apple:
            return .system(size: size, weight: .semibold)
        case .appleLight:
            return .system(size: size, weight: .light)
        case .rounded:
            return .system(size: size, weight: .semibold, design: .rounded)
        case .classic, .digital:
            return .system(size: size, weight: .semibold)
        }
    }
}

private extension ClockPosition {
    var isBottom: Bool {
        switch self {
        case .topLeading, .topCenter, .topTrailing: false
        case .bottomLeading, .bottomCenter, .bottomTrailing: true
        }
    }
}

private struct SlideshowPhoto: View {
    let image: NSImage
    let size: CGSize
    let preferences: AppPreferences

    @State private var scale = 1.0
    @State private var drift = CGSize.zero

    var body: some View {
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: preferences.scaleMode == .fill ? .fill : .fit)
            .frame(width: size.width, height: size.height)
            .scaleEffect(scale)
            .offset(drift)
            .frame(width: size.width, height: size.height)
            .clipped()
            .onAppear {
                guard preferences.slideshowStyle == .kenBurns else { return }
                withAnimation(.linear(duration: max(2, preferences.intervalSeconds))) {
                    scale = 1.08
                    drift = CGSize(width: size.width * 0.012, height: -size.height * 0.012)
                }
            }
    }
}
