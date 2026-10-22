#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
OUTPUT_DIR="${PROJECT_DIR}/build"
DMG_NAME="DejaVuScreensaver.dmg"
DMG_PATH="${OUTPUT_DIR}/${DMG_NAME}"
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

if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
  codesign --force --timestamp --sign "${CODE_SIGN_IDENTITY}" "${DMG_PATH}"
fi

(cd "${OUTPUT_DIR}" && shasum -a 256 "${DMG_NAME}" > "${DMG_NAME}.sha256")
echo "Packaged ${DMG_PATH}"
