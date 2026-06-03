#!/usr/bin/env bash
set -euo pipefail

# Build the AeroMux DMG. When notarization credentials are available the app is
# notarized and the ticket is stapled to the .app *before* the DMG is built, so
# the app validates offline even after a user drags it out of the DMG. The DMG
# itself is then notarized and stapled too.
#
# Notarization credentials (optional — skipped with a warning if unset):
#   AEROMUX_NOTARY_PROFILE                    a `notarytool store-credentials` keychain profile
# or:
#   AEROMUX_NOTARY_APPLE_ID                   Apple ID email
#   AEROMUX_NOTARY_TEAM_ID                    Developer Team ID (RQ4U2AV56B)
#   AEROMUX_NOTARY_PASSWORD                   app-specific password

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/dist"
APP_NAME="AeroMux"

VERSION="${VERSION:-}"
if [[ -z "${VERSION}" ]]; then
  VERSION="$(git -C "${ROOT_DIR}" describe --tags --always --dirty)"
fi

APP_PATH="$(VERSION="${VERSION}" "${ROOT_DIR}/scripts/build-release-app.sh")"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"
STAGING_DIR="$(mktemp -d "${BUILD_DIR}/dmg-staging.XXXXXX")"

cleanup() {
  rm -rf "${STAGING_DIR}"
}
trap cleanup EXIT

have_notary_creds() {
  [[ -n "${AEROMUX_NOTARY_PROFILE:-}" ]] && return 0
  [[ -n "${AEROMUX_NOTARY_APPLE_ID:-}" && -n "${AEROMUX_NOTARY_TEAM_ID:-}" && -n "${AEROMUX_NOTARY_PASSWORD:-}" ]]
}

# Submit an artifact (zip/dmg) to the notary service and block until done.
notary_submit() {
  local artifact="$1"
  if [[ -n "${AEROMUX_NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "${artifact}" \
      --keychain-profile "${AEROMUX_NOTARY_PROFILE}" --wait >&2
  else
    xcrun notarytool submit "${artifact}" \
      --apple-id "${AEROMUX_NOTARY_APPLE_ID}" \
      --team-id "${AEROMUX_NOTARY_TEAM_ID}" \
      --password "${AEROMUX_NOTARY_PASSWORD}" --wait >&2
  fi
}

if have_notary_creds; then
  # Notarize the app (notarytool needs a container), then staple the .app itself.
  APP_ZIP="${BUILD_DIR}/${APP_NAME}.notarize.zip"
  /usr/bin/ditto -c -k --keepParent "${APP_PATH}" "${APP_ZIP}"
  notary_submit "${APP_ZIP}"
  rm -f "${APP_ZIP}"
  xcrun stapler staple "${APP_PATH}" >&2
else
  echo "warning: no notarization credentials set; shipping un-notarized app/DMG." >&2
  echo "         set AEROMUX_NOTARY_PROFILE or AEROMUX_NOTARY_{APPLE_ID,TEAM_ID,PASSWORD}." >&2
fi

rm -f "${DMG_PATH}"
cp -R "${APP_PATH}" "${STAGING_DIR}/${APP_NAME}.app"
ln -s /Applications "${STAGING_DIR}/Applications"

hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${STAGING_DIR}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}" >&2

# Also notarize + staple the DMG so the download itself carries a ticket.
if have_notary_creds; then
  notary_submit "${DMG_PATH}"
  xcrun stapler staple "${DMG_PATH}" >&2
fi

printf '%s\n' "${DMG_PATH}"
