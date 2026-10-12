import AppKit
import Photos
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var preferences: PreferencesStore
    @ObservedObject private var photoLibrary: PhotoLibraryService
    @ObservedObject private var viewingHistory: ViewingHistoryStore
    @State private var albumSearch = ""
    @State private var isShowingFeedback = false
    let onShowHistory: () -> Void

    init(model: AppModel, onShowHistory: @escaping () -> Void) {
        self.model = model
        preferences = model.preferences
        photoLibrary = model.photoLibrary
        viewingHistory = model.viewingHistory
        self.onShowHistory = onShowHistory
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                photosSection
                playbackSection
                behaviorSection
                securitySection
                footer
            }
            .padding(28)
        }
        .frame(minWidth: 620, idealWidth: 680, minHeight: 680, idealHeight: 760)
        .sheet(isPresented: $isShowingFeedback) {
            FeedbackView()
        }
    }

    private var header: some View {
        HStack(spacing: 15) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text("DejaVuScreensaver")
                    .font(.largeTitle.bold())
                HStack(spacing: 5) {
                    Text("Find it in the menu bar as")
                    Image(systemName: "photo.on.rectangle")
                        .accessibilityLabel("the DejaVuScreensaver menu bar icon")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var photosSection: some View {
        GroupBox("Photos Library") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(authorizationText, systemImage: photoLibrary.canReadLibrary ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(photoLibrary.canReadLibrary ? .green : .orange)
                    Spacer()
                    if !photoLibrary.canReadLibrary {
                        Button("Grant Access") { model.requestPhotosAccess() }
                            .buttonStyle(.borderedProminent)
                    } else {
                        Button("Refresh Albums") { photoLibrary.refreshAlbums() }
                    }
                }

                if photoLibrary.canReadLibrary {
                    TextField("Filter albums", text: $albumSearch)
                        .textFieldStyle(.roundedBorder)

                    ScrollView {
                        LazyVStack(spacing: 2) {
                            albumRow(
                                title: "All Photos",
                                subtitle: "Entire Photos library",
                                selected: preferences.value.selectedAlbumIDs.isEmpty
                            ) { model.useAllPhotos() }

                            ForEach(filteredAlbums) { album in
                                albumRow(
                                    title: album.title,
                                    subtitle: album.kind == .user ? "Album" : "Smart Album",
                                    selected: preferences.value.selectedAlbumIDs.contains(album.id)
                                ) { model.toggleAlbum(album.id) }
                            }
                        }
                    }
                    .frame(height: 190)
                    .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))

                    Text(preferences.value.selectedAlbumIDs.isEmpty ? "Using All Photos" : "\(preferences.value.selectedAlbumIDs.count) album(s) selected; duplicates are removed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
        }
    }

    private var playbackSection: some View {
        GroupBox("Playback") {
            VStack(alignment: .leading, spacing: 13) {
                LabeledContent("Photo duration") {
                    HStack {
                        Stepper(
                            value: intervalBinding,
                            in: 1...30,
                            step: 1
                        ) {
                            Text("\(Int(preferences.value.intervalSeconds)) sec")
                            .monospacedDigit()
                            .frame(width: 70, alignment: .trailing)
                        }
                    }
                }
                Picker("Slideshow style", selection: slideshowStyleBinding) {
                    ForEach(SlideshowStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Image sizing", selection: scaleModeBinding) {
                    ForEach(PhotoScaleMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Show large clock", isOn: preferenceBinding(\.showClock))
                if preferences.value.showClock {
                    LabeledContent("Clock position") {
                        Picker("Clock position", selection: clockPositionBinding) {
                            ForEach(ClockPosition.allCases) { position in
                                Text(position.title).tag(position)
                            }
                        }
                        .labelsHidden()
                    }
                    LabeledContent("Clock style") {
                        Picker("Clock style", selection: clockStyleBinding) {
                            ForEach(SlideshowClockStyle.allCases) { style in
                                Text(style.title).tag(style)
                            }
                        }
                        .labelsHidden()
                    }
                }
                Toggle("Show capture date", isOn: preferenceBinding(\.showCaptureDate))
                Toggle("Show location", isOn: preferenceBinding(\.showLocation))
                Toggle("Show filename", isOn: preferenceBinding(\.showFilename))
                Toggle("Show photo number", isOn: preferenceBinding(\.showPhotoNumber))
                Text("Photos are shuffled without immediate repeats. ← goes back through actual history; → advances; Space pauses or resumes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
        }
    }

    private var behaviorSection: some View {
        GroupBox("Automatic Start") {
            VStack(alignment: .leading, spacing: 13) {
                Toggle("Start after this Mac is idle", isOn: preferenceBinding(\.idleEnabled))
                LabeledContent("Idle time") {
                    HStack {
                        Slider(value: idleBinding, in: 1...120, step: 1)
                            .frame(width: 230)
                        Text("\(Int(preferences.value.idleMinutes)) min")
                            .monospacedDigit()
                            .frame(width: 55, alignment: .trailing)
                    }
                }
                Toggle("Launch DejaVuScreensaver at login", isOn: Binding(
                    get: { model.launchAtLoginStatus == .enabled },
                    set: { model.setLaunchAtLogin($0) }
                ))
                Text("DejaVuScreensaver uses its own idle timer. To avoid switching to another screen saver, disable the macOS screen saver or set it to start later.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
        }
    }

    private var securitySection: some View {
        GroupBox("Security Behavior") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Mode", selection: preferenceBinding(\.stayOpenUntilEnded)) {
                    Text("Screensaver").tag(false)
                    Text("Slideshow").tag(true)
                }
                .pickerStyle(.segmented)

                Text(preferences.value.stayOpenUntilEnded
                     ? "Stays open during interaction. Move the pointer for End Slideshow, or press Esc to exit."
                     : "Closes or locks when you interact with the Mac, like a screen saver.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !preferences.value.stayOpenUntilEnded {
                    Label(
                        model.lockService.isAvailable ? "Can open the macOS Lock Screen" : "Cannot open the macOS Lock Screen on this Mac",
                        systemImage: model.lockService.isAvailable ? "lock.shield.fill" : "lock.trianglebadge.exclamationmark"
                    )
                    .foregroundStyle(model.lockService.isAvailable ? .green : .red)
                    Toggle(
                        "Lock Mac when leaving the slideshow",
                        isOn: preferenceBinding(\.lockOnDisallowedKey)
                    )
                    Text(preferences.value.lockOnDisallowedKey
                         ? "Any input except ←, →, and Space invokes the real macOS Lock Screen."
                         : "Other keys, mouse input, switching apps, or changing displays close the slideshow without locking the Mac.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Your Mac password is handled only by macOS. DejaVuScreensaver never sees or stores it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    onShowHistory()
                } label: {
                    Label(
                        "Recently Viewed (\(viewingHistory.entries.count))",
                        systemImage: "clock.arrow.circlepath"
                    )
                }

                Button {
                    model.startSlideshow()
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .frame(minWidth: 160)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canStart)
            }
            .controlSize(.large)

            Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"))")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Button {
                isShowingFeedback = true
            } label: {
                Label("Feedback, feature request or bug report", systemImage: "bubble.left")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityHint("Opens the feedback form")

            if let supportURL = URL(string: "https://ko-fi.com/feedpippopizza") {
                Link(destination: supportURL) {
                    Text("Enjoy the app? Feed me 🍕")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var authorizationText: String {
        switch photoLibrary.authorizationStatus {
        case .authorized: "Full Photos access granted"
        case .limited: "Limited Photos access granted"
        case .denied: "Photos access denied"
        case .restricted: "Photos access restricted"
        case .notDetermined: "Photos access required"
        @unknown default: "Unknown Photos access state"
        }
    }

    private var filteredAlbums: [AlbumSource] {
        guard !albumSearch.isEmpty else { return photoLibrary.albums }
        return photoLibrary.albums.filter {
            $0.title.localizedCaseInsensitiveContains(albumSearch)
        }
    }

    private func albumRow(
        title: String,
        subtitle: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).foregroundStyle(.primary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var intervalBinding: Binding<Double> {
        Binding(
            get: { preferences.value.intervalSeconds },
            set: {
                let clamped = min(30, max(1, $0.rounded()))
                preferences.value.intervalSeconds = clamped
                model.slideshow.updateInterval(clamped)
            }
        )
    }

    private var idleBinding: Binding<Double> {
        Binding(
            get: { preferences.value.idleMinutes },
            set: { preferences.value.idleMinutes = $0 }
        )
    }

    private var scaleModeBinding: Binding<PhotoScaleMode> {
        Binding(
            get: { preferences.value.scaleMode },
            set: { preferences.value.scaleMode = $0 }
        )
    }

    private var slideshowStyleBinding: Binding<SlideshowStyle> {
        Binding(
            get: { preferences.value.slideshowStyle },
            set: { preferences.value.slideshowStyle = $0 }
        )
    }

    private var clockPositionBinding: Binding<ClockPosition> {
        Binding(
            get: { preferences.value.clockPosition },
            set: { preferences.value.clockPosition = $0 }
        )
    }

    private var clockStyleBinding: Binding<SlideshowClockStyle> {
        Binding(
            get: { preferences.value.clockStyle },
            set: { preferences.value.clockStyle = $0 }
        )
    }

    private func preferenceBinding(_ keyPath: WritableKeyPath<AppPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { preferences.value[keyPath: keyPath] },
            set: { preferences.value[keyPath: keyPath] = $0 }
        )
    }
}
