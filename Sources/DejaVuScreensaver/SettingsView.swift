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
    @State private var selectedPane: SettingsPane? = .photos
    @State private var selectedPhotoCount: Int?
    let onShowHistory: () -> Void

    init(model: AppModel, onShowHistory: @escaping () -> Void) {
        self.model = model
        preferences = model.preferences
        photoLibrary = model.photoLibrary
        viewingHistory = model.viewingHistory
        self.onShowHistory = onShowHistory
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedPane) {
                header
                    .padding(.leading, 4)
                    .padding(.top, 6)
                    .padding(.bottom, 20)
                // Metrics measured from System Settings: 20pt icon, 7pt gap, 32pt row pitch, icon 9pt inside the highlight.
                ForEach(SettingsPane.allCases) { pane in
                    HStack(spacing: 7) {
                        Image(systemName: pane.systemImage)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(pane.color.gradient, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        Text(pane.title)
                            .lineLimit(1)
                    }
                    .padding(.leading, 4)
                    .frame(height: 24)
                    .tag(pane)
                }
            }
            // The column width modifier alone is ignored in our AppKit-hosted window; min/max frame pins it.
            .frame(minWidth: 250, maxWidth: 250)
            .navigationSplitViewColumnWidth(250) // fixed, like System Settings
            .toolbar(removing: .sidebarToggle)
            .safeAreaInset(edge: .bottom) { sidebarFooter }
        } detail: {
            // Real toolbar title over a scrolling Form: macOS draws the scroll edge effect, like System Settings.
            Form {
                detail
                // Inside the scroll content so the scroll bar runs full height; a footer-only Section has no panel.
                Section {} footer: {
                    aboutFooter
                        .padding(.top, 16)
                }
            }
            .formStyle(.grouped)
            .toggleStyle(.switch)
            // macOS places the toolbar title ~12pt from the column; the grouped panels start at 20pt. Pull them in to line up.
            .padding(.leading, -8)
            .navigationTitle((selectedPane ?? .photos).title)
        }
        .frame(minWidth: 870, idealWidth: 890, minHeight: 600, idealHeight: 700)
        .sheet(isPresented: $isShowingFeedback) {
            FeedbackView()
        }
        .sheet(isPresented: $isShowingAlbumPicker) {
            AlbumPickerView(model: model)
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selectedPane ?? .photos {
        case .photos:
            photosSection
            smartFiltersSection
        case .playback: playbackSection
        case .automaticStart: behaviorSection
        case .security: securitySection
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .padding(-5) // app icon artwork has a transparent margin; keep its edge aligned with the pane icons
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("DejaVuScreensaver")
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text("Find it in the menu bar as")
                        .lineLimit(1)
                    Image(systemName: "photo.on.rectangle")
                        .accessibilityLabel("the DejaVuScreensaver menu bar icon")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var photosSection: some View {
        Section("Source") {
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
            }
        }
    }

    private var smartFiltersSection: some View {
        Section {
            Toggle("Favorites only", isOn: smartFilterFavoriteBinding)

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
                    if preferences.value.smartFilter.captureDateComparison == .between {
                        Text("and")
                        DatePicker(
                            "",
                            selection: smartFilterEndDateBinding,
                            in: preferences.value.smartFilter.captureDate...,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                    }
                }
            }

            // All/Any only means something once two filters are on.
            if preferences.value.smartFilter.favoriteEnabled && preferences.value.smartFilter.captureDateEnabled {
                Picker("Photos must match", selection: smartFilterMatchBinding) {
                    ForEach(SmartFilterMatch.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
        } header: {
            Text("Filters")
        } footer: {
            if let selectedPhotoCount {
                Text("\(selectedPhotoCount) photo\(selectedPhotoCount == 1 ? "" : "s") selected")
            }
        }
        // shortcut: counts on the main actor, like Start does; move off-main if huge libraries stutter.
        .task(id: preferences.value) {
            selectedPhotoCount = photoLibrary.canReadLibrary
                ? photoLibrary.fetchImages(
                    from: preferences.value.selectedAlbumIDs,
                    matching: preferences.value.smartFilter
                ).count
                : nil
        }
    }

    private var playbackSection: some View {
        Section {
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

            Toggle("Show current time", isOn: preferenceBinding(\.showClock))
            if preferences.value.showClock {
                LabeledContent("Position") {
                    Picker("Current time position", selection: clockPositionBinding) {
                        ForEach(ClockPosition.allCases) { position in
                            Text(position.title).tag(position)
                        }
                    }
                    .labelsHidden()
                }
                LabeledContent("Font") {
                    Picker("Current time font", selection: clockStyleBinding) {
                        ForEach(SlideshowClockStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .labelsHidden()
                }
                LabeledContent("Size") {
                    Picker("Current time size", selection: preferenceBinding(\.clockSize)) {
                        ForEach(SlideshowClockSize.allCases) { size in
                            Text(size.title).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Toggle(
                    "Add background behind time",
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
    }

    private var behaviorSection: some View {
        Section {
            Toggle("Start after this Mac is idle", isOn: preferenceBinding(\.idleEnabled))
            LabeledContent("Idle time") {
                HStack {
                    Slider(value: idleBinding, in: 1...120) // no step: macOS 27 draws a tick per step
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
            Text("DejaVuScreensaver uses its own idle timer. The macOS screen saver will appear over DejaVuScreensaver. To avoid switching to another screen saver, disable the macOS screen saver or set it to start later.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var securitySection: some View {
        Section {
            Picker("When someone touches the Mac", selection: exitBehaviorBinding) {
                exitOption("Lock the Mac", "Opens the macOS Lock Screen.").tag(ExitBehavior.lock)
                exitOption("Close the slideshow", "Back to the desktop, no password.").tag(ExitBehavior.close)
                exitOption("Keep playing", "Press Esc to stop.").tag(ExitBehavior.keepPlaying)
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
        } header: {
            Text("When someone touches the Mac")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                // Apple only speaks up when something doesn't work.
                if !model.lockService.isAvailable {
                    Label("Locking isn’t available on this Mac.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                Text("← → and Space always browse photos. Your password is handled only by macOS.")
            }
        }
    }

    private func exitOption(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }

    /// The three behaviors map onto the two stored preferences.
    private var exitBehaviorBinding: Binding<ExitBehavior> {
        Binding(
            get: {
                if preferences.value.stayOpenUntilEnded { return .keepPlaying }
                return preferences.value.lockOnDisallowedKey ? .lock : .close
            },
            set: {
                preferences.value.stayOpenUntilEnded = $0 == .keepPlaying
                if $0 != .keepPlaying {
                    preferences.value.lockOnDisallowedKey = $0 == .lock
                }
            }
        )
    }

    private var sidebarFooter: some View {
        VStack(spacing: 8) {
            if let reason = model.startDisabledReason {
                Label(reason, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }

            Button {
                model.startSlideshow()
            } label: {
                Label("Start", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!model.canStart)

            Button {
                onShowHistory()
            } label: {
                Label(
                    "Recently Viewed (\(viewingHistory.entries.count))",
                    systemImage: "clock.arrow.circlepath"
                )
                .frame(maxWidth: .infinity)
            }
        }
        .padding(12)
    }

    private var aboutFooter: some View {
        VStack(spacing: 8) {
            Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                isShowingFeedback = true
            } label: {
                Label("Feedback — report a bug or request a feature", systemImage: "bubble.left")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityHint("Opens the feedback form")

            if let repositoryURL = URL(string: "https://github.com/DejaVuScreensaver/DejaVuScreensaver") {
                Link(destination: repositoryURL) {
                    Label(
                        "Open source — view or contribute on GitHub",
                        systemImage: "chevron.left.forwardslash.chevron.right"
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            if let supportURL = URL(string: "https://ko-fi.com/feedpippopizza") {
                Link(destination: supportURL) {
                    Text("Enjoying the app? Please feed me 🍕")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .font(.callout)
        .frame(maxWidth: .infinity)
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
                .font(preferences.value.clockStyle.font(
                    size: 34 * preferences.value.clockSize.multiplier
                ))
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
        .accessibilityLabel("Current time preview")
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
            set: { preferences.value.idleMinutes = $0.rounded() }
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

    private var smartFilterEndDateBinding: Binding<Date> {
        Binding(
            get: { preferences.value.smartFilter.periodEndDate },
            set: { preferences.value.smartFilter.captureEndDate = Calendar.current.startOfDay(for: $0) }
        )
    }

    private func preferenceBinding<Value>(
        _ keyPath: WritableKeyPath<AppPreferences, Value>
    ) -> Binding<Value> {
        Binding(
            get: { preferences.value[keyPath: keyPath] },
            set: { preferences.value[keyPath: keyPath] = $0 }
        )
    }
}

private enum ExitBehavior: Hashable {
    case lock, close, keepPlaying
}

private enum SettingsPane: CaseIterable, Identifiable {
    case photos, playback, automaticStart, security

    var id: Self { self }

    var title: String {
        switch self {
        case .photos: "Photos"
        case .playback: "Playback"
        case .automaticStart: "Automatic Start"
        case .security: "Lock & Exit"
        }
    }

    var systemImage: String {
        switch self {
        case .photos: "photo.fill"
        case .playback: "play.fill"
        case .automaticStart: "clock.fill"
        case .security: "lock.fill"
        }
    }

    var color: Color {
        switch self {
        case .photos: .orange
        case .playback: .green
        case .automaticStart: .indigo
        case .security: .blue
        }
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
            Text("Choose Albums")
                .font(.title2.bold())
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
