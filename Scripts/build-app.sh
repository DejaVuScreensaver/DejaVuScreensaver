#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
CONFIGURATION="${CONFIGURATION:-release}"
OUTPUT_DIR="${PROJECT_DIR}/build"
APP_PATH="${OUTPUT_DIR}/DejaVuScreensaver.app"
SWIFT_BUILD_ARGS=(-c "${CONFIGURATION}")

if [[ "${DISABLE_SWIFTPM_SANDBOX:-0}" == "1" ]]; then
  SWIFT_BUILD_ARGS+=(--disable-sandbox)
fi

cd "${PROJECT_DIR}"
swift build "${SWIFT_BUILD_ARGS[@]}" --product DejaVuScreensaver
BIN_DIR="$(swift build "${SWIFT_BUILD_ARGS[@]}" --show-bin-path)"

rm -rf "${APP_PATH}"
mkdir -p "${APP_PATH}/Contents/MacOS" "${APP_PATH}/Contents/Resources"
cp "${BIN_DIR}/DejaVuScreensaver" "${APP_PATH}/Contents/MacOS/DejaVuScreensaver"
# SwiftPM stamps the binary with the deployment target as its SDK version, so newer macOS draws the app in
# its old compatibility look. Stamp the real SDK; the minimum stays macOS 14 (keep in sync with Package.swift).
xcrun vtool -set-build-version macos 14.0 "$(xcrun --sdk macosx --show-sdk-version)" -replace \
  -output "${APP_PATH}/Contents/MacOS/DejaVuScreensaver" "${APP_PATH}/Contents/MacOS/DejaVuScreensaver"
cp "${PROJECT_DIR}/Resources/Info.plist" "${APP_PATH}/Contents/Info.plist"
cp "${PROJECT_DIR}/Resources/AppIcon.icns" "${APP_PATH}/Contents/Resources/AppIcon.icns"
cp "${PROJECT_DIR}/Resources/WorldMap.pdf" "${APP_PATH}/Contents/Resources/WorldMap.pdf"
cp "${PROJECT_DIR}/Resources/OfflinePlaces.plist" "${APP_PATH}/Contents/Resources/OfflinePlaces.plist"

if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
  codesign --force --deep --options runtime --sign "${CODE_SIGN_IDENTITY}" "${APP_PATH}"
else
  codesign --force --deep --sign - "${APP_PATH}"
fi

echo "Built ${APP_PATH}"
