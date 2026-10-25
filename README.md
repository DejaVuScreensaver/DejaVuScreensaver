# DejaVuScreensaver

DejaVuScreensaver is an open-source, Mac-native, full-screen photo slideshow that
behaves like an interactive screen saver while retaining reliable keyboard
controls and direct access to Apple Photos albums.

It is Plan B from the native screen-saver feasibility work. The genuine
ScreenSaver `.appex` experiment is separate because macOS 27 does not deliver
keyboard events to either the extension or an ordinary companion event tap
while ScreenSaverEngine is active.

## Implemented feature set

- Direct read-only PhotoKit authorization
- All Photos, user albums, built-in smart albums, and multi-album selection
- Internal smart filters for favorites and capture date, with All/Any matching
- iCloud Photos image retrieval through `PHCachingImageManager`
- Random playback without repeats until the current bag is exhausted
- History-aware Previous and Next using Left and Right Arrow
- Final-quality-only automatic playback; responsive previews for arrow navigation
- Pause/resume using Space
- Exact configurable 1–30 second interval
- Capture date, GPS coordinates, and original filename overlays
- Optional large current-time overlay
- Static or Ken Burns photo presentation
- Fit or fill image presentation
- One synchronized borderless window on every connected display
- Idle-time activation based on macOS session input state
- Automatic activation is opt-in and never starts merely from granting access
- Optional Launch at Login through `SMAppService.mainApp`
- Real macOS Lock Screen handoff for every non-control input
- Mouse-movement threshold to ignore tiny activation jitter
- Photos-library change observation
- Menu-bar controls and a compact SwiftUI settings window
- Settings reopen reliably from the menu bar or by opening the app again
- Persistent Recently Viewed history with thumbnails, metadata, and large preview
- Native feedback composer addressed to `pietro.michelini@gmail.com`, with device details and screenshot attachments

## Security contract

DejaVuScreensaver is not a replacement login screen and never asks for, stores, or
draws a password field.

During a slideshow:

- Plain Left, Right, and Space control the slideshow.
- A setting chooses whether exit input requests the real macOS Lock Screen or
  simply closes the slideshow. When disabled, keyboard, mouse, app-switch, and
  display-change exits never request Lock Screen.
- Mouse clicks, scrolling, dragging, or meaningful movement request the real
  macOS Lock Screen.
- Switching away from the app or changing the display configuration requests
  the real macOS Lock Screen.
- The app keeps its black cover up until macOS independently confirms the
  session is locked. If confirmation does not arrive, playback pauses and the
  cover remains while the user is told to press Control–Command–Q.
- Idle mode refuses to arm when secure locking is unavailable.

Apple does not provide a public “lock now” API. Because this project is
distributed from a website rather than the Mac App Store, it dynamically loads
`SACLockScreenImmediate` from Apple’s private `login.framework`. The symbol is
resolved at runtime so a future macOS removal produces a visible fail-closed
state instead of a crash or an unlocked dismissal.

## Build

Requirements:

- macOS 14 or later
- Apple Silicon or Intel (the packaged app is universal)
- Xcode 15 or later

Build, package, and ad-hoc sign a local `.app`:

```sh
./Scripts/build-app.sh
open build/DejaVuScreensaver.app
```

Create the unsigned preview DMG and its SHA-256 checksum:

```sh
./Scripts/package-dmg.sh
```

Run tests:

```sh
swift test
```

To produce a website-distributed release, provide a Developer ID Application
identity and then notarize the result:

```sh
CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  ./Scripts/package-dmg.sh
```

The project intentionally has no App Sandbox entitlement. A notarized website
build still uses hardened runtime signing, but private Lock Screen integration
makes Mac App Store distribution inappropriate.

## First-run flow

1. Open the menu-bar app and grant Photos access.
2. Choose All Photos or one or more albums.
3. Pick duration, image sizing, and overlays.
4. Start a manual slideshow and verify Left, Right, and Space.
5. Press another key and confirm the genuine macOS Lock Screen appears.
6. Only after that verification, enable idle activation and Launch at Login.

## Distribution roadmap

Before publishing binaries:

1. Publish the Sparkle update feed and signed update archive (see below).
2. Sign with Developer ID and enable hardened runtime.
3. Notarize and staple the app.
4. Test Lock Screen handoff on every supported macOS release.
5. Add UI tests for multi-display changes and Photos permission transitions.
6. Publish the source, release archive, checksums, and privacy statement.

## Software updates

Sparkle 2 checks for updates automatically (users can disable this in Software
Update). A new version adds a “Software Update Available” sidebar row with a red
badge. Scheduled checks never open update windows; users open the update from
that row or “Check for Updates…” in the menu bar. Sparkle handles download,
signature verification, installation, and restart after the user confirms.
Automatic downloads/installation and system profiling are disabled.

The feed is the root `appcast.xml` on the repository's `main` branch, served over
HTTPS by GitHub. Update ZIPs are hosted on GitHub Releases; no paid update service
or custom server is required. Users on 0.7.2 and earlier need to install 0.7.3 or
later manually once before they can receive in-app updates.

The Sparkle private signing key is in the macOS login Keychain under account
`io.github.dejavuscreensaver.DejaVuScreensaver`. The public key is in
`Resources/Info.plist`. Back up the private key securely using Sparkle's
`generate_keys --account io.github.dejavuscreensaver.DejaVuScreensaver -x <secure-path>`;
never commit the export. Future releases must retain this key or follow Sparkle's
key rotation procedure.

For each release:

1. Increment both version fields in `Resources/Info.plist` (build numbers must
   increase), build with Developer ID, notarize and staple the app.
2. Download the matching [Sparkle 2.10.1 distribution](https://github.com/sparkle-project/Sparkle/releases/tag/2.10.1), then run:

   ```sh
   SPARKLE_TOOLS_DIR=/path/to/Sparkle/bin ./Scripts/prepare-update.sh
   ```

3. Upload `build/updates/DejaVuScreensaver-VERSION.zip` to GitHub release
   `vVERSION`. The script generates a signed enclosure and checks that the
   Keychain key matches the built app.
4. Copy `build/updates/appcast.xml` to the repository root and publish it on
   `main` **after** the ZIP is available. Keep existing feed entries; each item
   retains its own versioned release URL. The initial empty feed is intentional
   until a release archive is ready.
5. Test an update from a previous installed version before announcing it.

Local ad-hoc builds remain available through `build-app.sh`; they do not provide
Apple's Developer ID/notarization assurances and are not public release builds.

## Privacy

PhotoKit image data stays on the Mac. DejaVuScreensaver contains no analytics,
accounts, or photo upload path. Sparkle connects to GitHub to check for updates
and downloads updates when requested; GitHub receives standard connection data
such as the IP address. PhotoKit may access the network when macOS downloads an
iCloud photo selected by the user.

## License

MIT
