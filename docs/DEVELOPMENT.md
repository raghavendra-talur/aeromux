# Development

This document is for contributors working on AeroMux locally.

## Common Commands

The repository includes a [Makefile](../Makefile) that wraps the usual local workflow.

The app is built with Xcode. The `AeroMux.xcodeproj` is generated from
`project.yml` by [XcodeGen](https://github.com/yonsm/XcodeGen), so install it
first (`brew install xcodegen`); the Makefile regenerates the project as needed.

Show available targets:

```bash
make help
```

Build the debug binary:

```bash
make build
```

Run the app from source:

```bash
make run
```

Run the unit tests:

```bash
make test
```

Build the release `.app` bundle:

```bash
make app
```

Build the release DMG:

```bash
make dmg
```

Install the built app into `/Applications`:

```bash
make install
```

Remove the installed app:

```bash
make uninstall
```

You can override the packaging version:

```bash
make dmg VERSION=v0.1.4
```

You can also override the install directory:

```bash
make install APP_INSTALL_DIR="$HOME/Applications"
```

## Release Scripts

The Makefile delegates packaging to:

- `scripts/build-release-app.sh`
- `scripts/build-release-dmg.sh`

If you need the raw scripts directly:

```bash
./scripts/build-release-app.sh
VERSION=v0.1.4 ./scripts/build-release-dmg.sh
```

## Continuous Integration

GitHub Actions provides a single `CI` workflow. For every push and pull request
it installs XcodeGen, generates the project, and runs `xcodebuild build test`
(Debug, ad hoc signed) on macOS 15 with Xcode 16. It needs no signing secrets.

There is no release workflow. Releases are built locally so the Developer ID
signing key never leaves the maintainer's machine; see [RELEASING.md](RELEASING.md).

## Notes

- Release builds are Developer ID-signed with hardened runtime and notarized; Debug builds are ad hoc signed so the unit-test bundle can inject into the app host
- The menu bar icon and app icon are packaged from repository assets, not the KeyboardShortcuts SwiftPM resource bundle
- `docs/FORUM_ANNOUNCEMENT.md` is intentionally kept out of commits for now
