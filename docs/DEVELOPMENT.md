# Development

This document is for contributors working on AeroMux locally.

## Common Commands

The repository includes a [Makefile](../Makefile) that wraps the usual local workflow.

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

## Release Workflow

GitHub Actions currently provides:

- `CI`: runs `swift build` for every push and pull request
- `Release`: builds a DMG and publishes it for tags matching `v*`

The release workflow currently selects Xcode 16 explicitly because the package requires a Swift 6 toolchain.

## Notes

- Release builds are ad hoc signed, not notarized
- The menu bar icon and app icon are packaged from repository assets, not a SwiftPM resource bundle
- `docs/FORUM_ANNOUNCEMENT.md` is intentionally kept out of commits for now
