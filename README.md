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

1. Add a proper app icon and Sparkle update feed.
2. Sign with Developer ID and enable hardened runtime.
3. Notarize and staple the app.
4. Test Lock Screen handoff on every supported macOS release.
5. Add UI tests for multi-display changes and Photos permission transitions.
6. Publish the source, release archive, checksums, and privacy statement.

## Privacy

PhotoKit image data stays on the Mac. DejaVuScreensaver contains no analytics,
accounts, network service, or upload path. Network access by PhotoKit may occur
when macOS downloads an iCloud photo selected by the user.

## License

MIT
