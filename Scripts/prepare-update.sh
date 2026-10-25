#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
APP_PATH="${PROJECT_DIR}/build/DejaVuScreensaver.app"
UPDATE_DIR="${PROJECT_DIR}/build/updates"
: "${SPARKLE_TOOLS_DIR:?Set SPARKLE_TOOLS_DIR to the bin directory of the Sparkle 2.10.1 distribution}"

[[ -d "${APP_PATH}" ]] || { echo "Build and notarize the app before preparing an update." >&2; exit 1; }
codesign --verify --deep --strict "${APP_PATH}"
PUBLIC_KEY="$("${SPARKLE_TOOLS_DIR}/generate_keys" --account io.github.dejavuscreensaver.DejaVuScreensaver -p)"
APP_KEY="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "${APP_PATH}/Contents/Info.plist")"
[[ "${PUBLIC_KEY}" == "${APP_KEY}" ]] || { echo "The Sparkle signing key does not match this app." >&2; exit 1; }

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${APP_PATH}/Contents/Info.plist")"
mkdir -p "${UPDATE_DIR}"
cp "${PROJECT_DIR}/appcast.xml" "${UPDATE_DIR}/appcast.xml"
ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${UPDATE_DIR}/DejaVuScreensaver-${VERSION}.zip"
"${SPARKLE_TOOLS_DIR}/generate_appcast" \
  --account io.github.dejavuscreensaver.DejaVuScreensaver \
  --download-url-prefix "https://github.com/DejaVuScreensaver/DejaVuScreensaver/releases/download/v${VERSION}/" \
  --link "https://github.com/DejaVuScreensaver/DejaVuScreensaver/releases" \
  --maximum-deltas 0 \
  "${UPDATE_DIR}"

echo "Upload ${UPDATE_DIR}/DejaVuScreensaver-${VERSION}.zip to GitHub release v${VERSION}."
echo "Then copy ${UPDATE_DIR}/appcast.xml to the repository root and publish it on main."
