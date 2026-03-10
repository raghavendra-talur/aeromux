# Releasing AeroMux

This repository can now build a macOS `.app` bundle and a DMG from the SwiftPM executable, then publish the DMG on GitHub Releases from a version tag.

## Local Packaging

Build the app bundle:

```bash
./scripts/build-release-app.sh
```

Build the DMG:

```bash
VERSION=v0.1.0 ./scripts/build-release-dmg.sh
```

Artifacts are written to `dist/`.

## GitHub Release Flow

The repository includes [release.yml](../.github/workflows/release.yml), which runs on tags matching `v*`.

Release steps:

```bash
git tag v0.1.0
git push origin v0.1.0
```

That workflow will:

- build a release `.app`
- package `AeroMux-v0.1.0.dmg`
- generate `AeroMux-v0.1.0.dmg.sha256`
- create a GitHub Release for the tag
- upload both files to the release

## Current Signing Status

Release builds are currently ad hoc signed only.

That means:

- the app bundle has an embedded ad hoc signature for packaging consistency
- the release is not notarized
- macOS may show the usual warning for apps downloaded from the internet

If you want smoother end-user installation later, the next step is adding Developer ID signing and notarization to the release workflow.
