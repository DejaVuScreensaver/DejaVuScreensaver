import AppKit
import Photos
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var preferences: PreferencesStore
    @ObservedObject private var photoLibrary: PhotoLibraryService
    @ObservedObject private var viewingHistory: ViewingHistoryStore
    @State private var isShowingAlbumPicker = false
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
                smartFiltersSection
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
        .sheet(isPresented: $isShowingAlbumPicker) {
            AlbumPickerView(model: model)
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
                    HStack(spacing: 14) {
                        Image(systemName: preferences.value.selectedAlbumIDs.isEmpty ? "photo.stack.fill" : "rectangle.stack.fill")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 34)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(photoSourceTitle)
                                .font(.headline)
                            Text(photoSourceSubtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Button("Choose Albums…") {
                            isShowingAlbumPicker = true
                        }
                    }
                    .padding(12)
                    .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(10)
        }
    }

    private var smartFiltersSection: some View {
        GroupBox("Smart Filters") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Match", selection: smartFilterMatchBinding) {
                    ForEach(SmartFilterMatch.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Photo is favorite", isOn: smartFilterFavoriteBinding)

                Toggle("Filter by date captured", isOn: smartFilterDateEnabledBinding)
                if preferences.value.smartFilter.captureDateEnabled {
                    HStack {
                        Picker("Date Captured", selection: smartFilterDateComparisonBinding) {
                            ForEach(CaptureDateComparison.allCases) { comparison in
                                Text(comparison.title).tag(comparison)
                            }
                        }
                        DatePicker(
                            "",
                            selection: smartFilterDateBinding,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                    }
                }

                Text(preferences.value.smartFilter.isEnabled
                     ? "Applied to All Photos or the albums selected above."
                     : "No smart filter is active.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    Toggle(
                        "Add background behind clock",
                        isOn: preferenceBinding(\.showClockBackground)
                    )
                    LabeledContent("Preview") {
                        clockPreview
                    }
                }
                Toggle("Show capture date", isOn: preferenceBinding(\.showCaptureDate))
                Toggle("Show location", isOn: preferenceBinding(\.showLocation))
                Toggle("Show filename", isOn: preferenceBinding(\.showFilename))
                Toggle("Show photo number and total", isOn: preferenceBinding(\.showPhotoNumber))
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
                        model.lockService.isAvailable ? "Automatic Mac locking is available" : "Automatic Mac locking is unavailable",
                        systemImage: model.lockService.isAvailable ? "lock.shield.fill" : "lock.trianglebadge.exclamationmark"
                    )
                    .foregroundStyle(model.lockService.isAvailable ? .green : .red)
                    Text(model.lockService.isAvailable
                         ? "When enabled below, leaving the screensaver opens the real macOS Lock Screen."
                         : "DejaVuScreensaver can close, but it cannot automatically lock this Mac.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

            if let reason = model.startDisabledReason {
                Text("⚠️ \(reason)")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

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

    private var clockPreview: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(context.date.formatted(date: .omitted, time: .shortened))
                .font(preferences.value.clockStyle.font(size: 34))
                .monospacedDigit()
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.9), radius: 6)
                .padding(.horizontal, preferences.value.showClockBackground ? 15 : 0)
                .padding(.vertical, preferences.value.showClockBackground ? 7 : 0)
                .background {
                    if preferences.value.showClockBackground {
                        Capsule().fill(.black.opacity(0.42))
                    }
                }
        }
        .frame(width: 190, height: 76)
        .background(
            Color(white: 0.16),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .accessibilityLabel("Clock style preview")
    }

    private var photoSourceTitle: String {
        let count = preferences.value.selectedAlbumIDs.count
        return count == 0 ? "All Photos" : "\(count) album\(count == 1 ? "" : "s") selected"
    }

    private var photoSourceSubtitle: String {
        guard !preferences.value.selectedAlbumIDs.isEmpty else {
            return "Entire Photos library"
        }
        let names = photoLibrary.albums
            .filter { preferences.value.selectedAlbumIDs.contains($0.id) }
            .map(\.title)
        return names.isEmpty ? "Duplicates are removed automatically" : names.joined(separator: ", ")
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

    private var smartFilterMatchBinding: Binding<SmartFilterMatch> {
        Binding(
            get: { preferences.value.smartFilter.match },
            set: { preferences.value.smartFilter.match = $0 }
        )
    }

    private var smartFilterFavoriteBinding: Binding<Bool> {
        Binding(
            get: { preferences.value.smartFilter.favoriteEnabled },
            set: { preferences.value.smartFilter.favoriteEnabled = $0 }
        )
    }

    private var smartFilterDateEnabledBinding: Binding<Bool> {
        Binding(
            get: { preferences.value.smartFilter.captureDateEnabled },
            set: { preferences.value.smartFilter.captureDateEnabled = $0 }
        )
    }

    private var smartFilterDateComparisonBinding: Binding<CaptureDateComparison> {
        Binding(
            get: { preferences.value.smartFilter.captureDateComparison },
            set: { preferences.value.smartFilter.captureDateComparison = $0 }
        )
    }

    private var smartFilterDateBinding: Binding<Date> {
        Binding(
            get: { preferences.value.smartFilter.captureDate },
            set: { preferences.value.smartFilter.captureDate = Calendar.current.startOfDay(for: $0) }
        )
    }

    private func preferenceBinding(_ keyPath: WritableKeyPath<AppPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { preferences.value[keyPath: keyPath] },
            set: { preferences.value[keyPath: keyPath] = $0 }
        )
    }
}

private struct AlbumPickerView: View {
    @ObservedObject private var preferences: PreferencesStore
    @ObservedObject private var photoLibrary: PhotoLibraryService
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    let model: AppModel

    init(model: AppModel) {
        self.model = model
        preferences = model.preferences
        photoLibrary = model.photoLibrary
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Choose Photo Sources")
                    .font(.title2.bold())
                Text(selectionSummary)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)

            Divider()

            VStack(spacing: 16) {
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search albums", text: $search)
                        .textFieldStyle(.plain)
                    if !search.isEmpty {
                        Button {
                            search = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 9))

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        albumRow(
                            title: "All Photos",
                            subtitle: "Entire Photos library",
                            systemImage: "photo.stack",
                            selected: preferences.value.selectedAlbumIDs.isEmpty,
                            action: model.useAllPhotos
                        )

                        if !userAlbums.isEmpty {
                            albumSection("Albums", albums: userAlbums)
                        }
                        if !smartAlbums.isEmpty {
                            albumSection("Built-in Smart Albums", albums: smartAlbums)
                        }
                        if filteredAlbums.isEmpty {
                            ContentUnavailableView.search(text: search)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        }
                    }
                    .padding(2)
                }
                .frame(maxHeight: .infinity)
            }
            .padding(20)

            Divider()

            HStack {
                Button {
                    photoLibrary.refreshAlbums()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                Spacer()
                Text("Changes are saved automatically")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(minWidth: 600, idealWidth: 660, minHeight: 620, idealHeight: 720)
    }

    private var filteredAlbums: [AlbumSource] {
        guard !search.isEmpty else { return photoLibrary.albums }
        return photoLibrary.albums.filter {
            $0.title.localizedCaseInsensitiveContains(search)
        }
    }

    private var userAlbums: [AlbumSource] {
        filteredAlbums.filter { $0.kind == .user }
    }

    private var smartAlbums: [AlbumSource] {
        filteredAlbums.filter { $0.kind == .smart }
    }

    private var selectionSummary: String {
        let count = preferences.value.selectedAlbumIDs.count
        return count == 0
            ? "Using every photo in your library"
            : "\(count) album\(count == 1 ? "" : "s") selected · duplicates are removed"
    }

    private func albumSection(_ title: String, albums: [AlbumSource]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            ForEach(albums) { album in
                albumRow(
                    title: album.title,
                    subtitle: album.kind == .user ? "Album" : "Provided by Photos",
                    systemImage: album.kind == .user ? "rectangle.stack" : "gearshape",
                    selected: preferences.value.selectedAlbumIDs.contains(album.id)
                ) { model.toggleAlbum(album.id) }
            }
        }
    }

    private func albumRow(
        title: String,
        subtitle: String,
        systemImage: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                Image(systemName: systemImage)
                    .frame(width: 24)
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(12)
            .contentShape(Rectangle())
            .background(
                selected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.035),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? Color.accentColor.opacity(0.35) : .clear)
            }
        }
        .buttonStyle(.plain)
    }
}
