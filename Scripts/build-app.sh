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
cp "${PROJECT_DIR}/Resources/Info.plist" "${APP_PATH}/Contents/Info.plist"
cp "${PROJECT_DIR}/Resources/AppIcon.icns" "${APP_PATH}/Contents/Resources/AppIcon.icns"

if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
  codesign --force --deep --options runtime --sign "${CODE_SIGN_IDENTITY}" "${APP_PATH}"
else
  codesign --force --deep --sign - "${APP_PATH}"
fi

echo "Built ${APP_PATH}"
