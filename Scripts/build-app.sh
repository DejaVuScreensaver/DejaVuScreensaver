#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
CONFIGURATION="${CONFIGURATION:-release}"
OUTPUT_DIR="${PROJECT_DIR}/build"
APP_PATH="${OUTPUT_DIR}/DejaVuScreensaver.app"
ENTITLEMENTS_PATH="${PROJECT_DIR}/Resources/DejaVuScreensaver.entitlements"
SWIFT_BUILD_ARGS=(-c "${CONFIGURATION}" --arch arm64 --arch x86_64)

if [[ "${DISABLE_SWIFTPM_SANDBOX:-0}" == "1" ]]; then
  SWIFT_BUILD_ARGS+=(--disable-sandbox)
fi

cd "${PROJECT_DIR}"
swift build "${SWIFT_BUILD_ARGS[@]}" --product DejaVuScreensaver
BIN_DIR="$(swift build "${SWIFT_BUILD_ARGS[@]}" --show-bin-path)"
SPARKLE_FRAMEWORK="${PROJECT_DIR}/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
[[ -d "${SPARKLE_FRAMEWORK}" ]] || { echo "Sparkle framework not found; run swift package resolve." >&2; exit 1; }

# Replacing a running bundle breaks its code identity and Sparkle authorization.
if /usr/sbin/lsof -t "${APP_PATH}/Contents/MacOS/DejaVuScreensaver" >/dev/null 2>&1; then
  echo "Quit ${APP_PATH} before rebuilding it; the running app must not be replaced." >&2
  exit 1
fi
rm -rf "${APP_PATH}"
mkdir -p "${APP_PATH}/Contents/MacOS" "${APP_PATH}/Contents/Resources" "${APP_PATH}/Contents/Frameworks"
ditto "${SPARKLE_FRAMEWORK}" "${APP_PATH}/Contents/Frameworks/Sparkle.framework"
cp "${BIN_DIR}/DejaVuScreensaver" "${APP_PATH}/Contents/MacOS/DejaVuScreensaver"
# SwiftPM stamps the binary with the deployment target as its SDK version, so newer macOS draws the app in
# its old compatibility look. Stamp the real SDK; the minimum stays macOS 14 (keep in sync with Package.swift).
xcrun vtool -arch arm64 -arch x86_64 -set-build-version macos 14.0 "$(xcrun --sdk macosx --show-sdk-version)" -replace \
  -output "${APP_PATH}/Contents/MacOS/DejaVuScreensaver" "${APP_PATH}/Contents/MacOS/DejaVuScreensaver"
cp "${PROJECT_DIR}/Resources/Info.plist" "${APP_PATH}/Contents/Info.plist"
cp "${PROJECT_DIR}/Resources/AppIcon.icns" "${APP_PATH}/Contents/Resources/AppIcon.icns"
cp "${PROJECT_DIR}/Resources/WorldMap.pdf" "${APP_PATH}/Contents/Resources/WorldMap.pdf"
cp "${PROJECT_DIR}/Resources/OfflinePlaces.plist" "${APP_PATH}/Contents/Resources/OfflinePlaces.plist"
cp "${PROJECT_DIR}/Resources/Sparkle-LICENSE.txt" "${APP_PATH}/Contents/Resources/Sparkle-LICENSE.txt"

SIGN_ARGS=(--force --sign "${CODE_SIGN_IDENTITY:--}")
if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
  SIGN_ARGS+=(--options runtime --timestamp)
fi
# Sign nested executables from the inside out so notarization can validate every Sparkle helper.
SPARKLE_VERSION="${APP_PATH}/Contents/Frameworks/Sparkle.framework/Versions/B"
for component in "${SPARKLE_VERSION}/XPCServices/Downloader.xpc" \
                 "${SPARKLE_VERSION}/XPCServices/Installer.xpc" \
                 "${SPARKLE_VERSION}/Autoupdate" \
                 "${SPARKLE_VERSION}/Updater.app" \
                 "${APP_PATH}/Contents/Frameworks/Sparkle.framework"; do
  codesign "${SIGN_ARGS[@]}" "${component}"
done
codesign "${SIGN_ARGS[@]}" --entitlements "${ENTITLEMENTS_PATH}" "${APP_PATH}"
codesign --verify --deep --strict "${APP_PATH}"

echo "Built ${APP_PATH}"
