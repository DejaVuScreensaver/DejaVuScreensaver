# DejaVuScreensaver technical product plan

## Decision

Ship Plan B first: a menu-bar application that presents synchronized,
screen-saver-level windows after a configurable idle period. It owns the
windows, so Left, Right, and Space can work reliably. Every other interaction
hands control to the genuine macOS Lock Screen.

Keep Plan A as a separate experiment. On the tested macOS 27 machine, the
native ScreenSaver extension did not receive keyboard events and a companion
event tap did not make navigation reliable. Plan A keyboard navigation is not
claimed as solved.

## User experience

### First run

1. DejaVuScreensaver appears in the menu bar and opens a small settings window.
2. The user grants read access to Photos.
3. The user chooses All Photos or any combination of user and smart albums.
4. The user configures interval, fit/fill, metadata, idle time, and launch at
   login.
5. A manual Start Slideshow button provides a safe way to test the experience
   before automatic activation is enabled.

### While running

- Left Arrow: previous photo from actual playback history.
- Right Arrow: next photo.
- Space: pause or resume.
- Any other key or modifier, click, drag, scroll, meaningful mouse movement,
  application switch, or display reconfiguration: either request the real
  macOS Lock Screen or close the slideshow, according to the exit-lock
  preference.
- All connected displays are covered by black, screen-saver-level windows and
  show the same photo.

### Security boundary

The app never draws a login screen or accepts credentials. Locking is provided
by `SACLockScreenImmediate`, dynamically loaded from Apple's private
`login.framework`. This is compatible with the website-distributed/open-source
goal but is an OS compatibility risk. The app checks availability before
arming idle mode. The private function has no return value, so the app retains
its black cover until macOS independently reports a locked session. If that
confirmation does not arrive, it pauses and instructs the user to press
Control-Command-Q without uncovering the desktop.

The private function is available on the development Mac running macOS 27. It
has not been invoked by automated validation, because doing so would lock the
user's active session. A human lock/unlock test remains mandatory for every
supported macOS release.

## Architecture

| Component | Responsibility |
| --- | --- |
| SwiftUI settings and menu bar | Photos permission, album selection, playback and idle preferences, Launch at Login |
| `PhotoLibraryService` | PhotoKit authorization, album discovery, image-only asset fetching, iCloud-backed image requests, metadata |
| `PlaybackSequence` | Random bag without repeats plus reversible playback history |
| `SlideshowController` | Shared photo state, timer, pause, navigation, async image loading |
| `SlideshowPresentation` | One borderless screen-saver-level window per display, cursor/menu/Dock hiding, local input monitoring |
| `SlideshowInputPolicy` | Testable allow-list for plain Left, Right, and Space |
| `IdleMonitor` | Session idle-time polling and one-shot activation/re-arming |
| `ScreenLockService` | Runtime capability check and real Lock Screen handoff |

Preferences use `UserDefaults`. Photos and metadata remain local. There is no
account, server, analytics SDK, or upload path.

## Proof-of-concept milestones

### M0 — platform validation (complete)

- Native `.appex` and helper experiment built separately.
- Keyboard navigation was not demonstrated inside the genuine native screen
  saver on the tested OS.
- Plan B chosen without representing Plan A as proven.

### M1 — functional Plan B prototype (complete)

- PhotoKit permission, All Photos, user albums, smart albums, and multi-select.
- Random no-repeat playback with previous/next history and pause.
- Capture date, coordinates, and original filename overlays.
- Configurable interval and fit/fill.
- Synchronized multi-display presentation.
- Idle activation and Launch at Login.
- Strict input-to-lock policy with fail-closed behavior.

### M2 — hands-on compatibility pass (next)

- Grant Photos permission on a clean macOS account.
- Test local-only and iCloud-only assets, empty albums, deleted albums, and
  Limited Photos access.
- Confirm Left, Right, and Space never dismiss the slideshow.
- Confirm every disallowed input reaches the genuine Lock Screen.
- Verify wake/unlock, display hot-plug, Spaces, full-screen apps, and multiple
  display arrangements.
- Repeat on each supported macOS major version and both Apple silicon and Intel
  if Intel support is retained.

### M3 — public beta

- Add app icon, onboarding, diagnostics export, and an explicit compatibility
  self-test.
- Add Sparkle with a signed update feed.
- Sign with Developer ID, enable hardened runtime, notarize, and staple.
- Publish source, tagged release ZIP, checksum, privacy statement, and known
  compatibility table.

### M4 — stable release

- Gate stable releases on the lock/unlock matrix.
- Add UI automation for settings and photo-permission transitions.
- Add crash reporting only if it is opt-in and privacy-preserving.
- Continue the Plan A experiment independently; never regress Plan B while
  investigating native screen-saver APIs.

## Known constraints

- This is not registered in System Settings as a `.saver`; automatic launch is
  provided by the running menu-bar app.
- The idle threshold should be shorter than the Mac's display-sleep threshold,
  or macOS may turn off the display before the slideshow appears.
- PhotoKit may use the network to download an iCloud asset, under the user's
  Photos/iCloud configuration.
- Apple can remove or change the private Lock Screen function. Availability is
  checked at runtime, but each OS update still requires a manual security test.
- GPS is currently displayed as coordinates. Converting it to a place name
  should be optional because reverse geocoding introduces a network/privacy
  decision.

## Release acceptance criteria

- No path displays or collects a password.
- Idle mode cannot arm unless Photos access and secure lock handoff are both
  available.
- All displays remain covered until the real Lock Screen takes over or the user
  explicitly quits during manual development testing.
- Random playback completes a bag before repeating and Previous follows actual
  history.
- Photos from selected albums are de-duplicated.
- A release is Developer ID signed and notarized; an ad-hoc build is labeled as
  local testing only.
