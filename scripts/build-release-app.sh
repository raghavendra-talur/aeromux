#!/usr/bin/env bash
set -euo pipefail

# Build a Developer ID-signed, hardened-runtime AeroMux.app via Xcode.
#
# This replaces the old hand-assembled .app. The Xcode archive/export flow
# embeds the KeyboardShortcuts resource bundle in Contents/Resources/ (where the
# Xcode-generated Bundle.module accessor looks for it) and signs everything with
# the Developer ID Application certificate, ready for notarization.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
ARCHIVE_PATH="${ROOT_DIR}/build/AeroMux.xcarchive"
EXPORT_OPTIONS="${ROOT_DIR}/Packaging/ExportOptions.plist"

# Raw version (e.g. "v0.1.8" or "v0.1.8-3-gabc1234-dirty" for dev builds).
VERSION="${VERSION:-}"
if [[ -z "${VERSION}" ]]; then
  VERSION="$(git -C "${ROOT_DIR}" describe --tags --always --dirty)"
fi

# MARKETING_VERSION must be a dotted numeric string; derive it from the tag.
MARKETING_VERSION="${VERSION#v}"
MARKETING_VERSION="${MARKETING_VERSION%%-*}"
if [[ ! "${MARKETING_VERSION}" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
  MARKETING_VERSION="0.0.0"
fi
# CFBundleVersion must be a monotonically increasing integer.
BUILD_NUMBER="$(git -C "${ROOT_DIR}" rev-list --count HEAD 2>/dev/null || echo 1)"

cd "${ROOT_DIR}"
xcodegen generate >&2
rm -rf "${ARCHIVE_PATH}" "${DIST_DIR}/AeroMux.app"
mkdir -p "${DIST_DIR}"

xcodebuild archive \
  -project AeroMux.xcodeproj \
  -scheme AeroMux \
  -configuration Release \
  -archivePath "${ARCHIVE_PATH}" \
  MARKETING_VERSION="${MARKETING_VERSION}" \
  CURRENT_PROJECT_VERSION="${BUILD_NUMBER}" >&2

xcodebuild -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportPath "${DIST_DIR}" \
  -exportOptionsPlist "${EXPORT_OPTIONS}" >&2

printf '%s\n' "${DIST_DIR}/AeroMux.app"
