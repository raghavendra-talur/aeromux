#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/dist"
APP_NAME="AeroMux"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
INFO_TEMPLATE="${ROOT_DIR}/Packaging/Info.plist"
BIN_DIR="$(swift build -c release --package-path "${ROOT_DIR}" --show-bin-path)"

VERSION="${VERSION:-}"
if [[ -z "${VERSION}" ]]; then
  VERSION="$(git -C "${ROOT_DIR}" describe --tags --always --dirty)"
fi

rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

swift build -c release --package-path "${ROOT_DIR}" >&2

cp "${BIN_DIR}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"
chmod 755 "${MACOS_DIR}/${APP_NAME}"

find "${BIN_DIR}" -maxdepth 1 -name '*.bundle' -exec cp -R {} "${RESOURCES_DIR}" \;

if [[ -f "${ROOT_DIR}/Packaging/AeroMux.icns" ]]; then
  cp "${ROOT_DIR}/Packaging/AeroMux.icns" "${RESOURCES_DIR}/AeroMux.icns"
fi

sed "s/__VERSION__/${VERSION}/g" "${INFO_TEMPLATE}" > "${CONTENTS_DIR}/Info.plist"
printf 'APPL????' > "${CONTENTS_DIR}/PkgInfo"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "${APP_DIR}" >&2
fi

printf '%s\n' "${APP_DIR}"
