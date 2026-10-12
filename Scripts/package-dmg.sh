#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
OUTPUT_DIR="${PROJECT_DIR}/build"
DMG_PATH="${OUTPUT_DIR}/DejaVuScreensaver.dmg"
STAGING_DIR="$(mktemp -d "${TMPDIR%/}/DejaVuScreensaver.XXXXXX")"

trap 'rm -rf "${STAGING_DIR}"' EXIT

"${SCRIPT_DIR}/build-app.sh"
cp -R "${OUTPUT_DIR}/DejaVuScreensaver.app" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

hdiutil create \
  -volname "DejaVuScreensaver" \
  -srcfolder "${STAGING_DIR}" \
  -format UDZO \
  -ov \
  "${DMG_PATH}"

shasum -a 256 "${DMG_PATH}" > "${DMG_PATH}.sha256"
echo "Packaged ${DMG_PATH}"
