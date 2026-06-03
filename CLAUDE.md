# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AeroMux is a native macOS SwiftUI sidebar app (macOS 13+) that extends the [AeroSpace](https://github.com/nikitabobko/AeroSpace) tiling window manager with a persistent workspace/window sidebar UI. It communicates with AeroSpace via CLI process execution.

## Build & Development Commands

The build is driven by Xcode (`xcodebuild`). The Xcode project is generated from
`project.yml` by [XcodeGen](https://github.com/yonsm/XcodeGen) and is not checked
in — `make` targets regenerate it as needed (`brew install xcodegen` first).

```bash
# Regenerate AeroMux.xcodeproj from project.yml
make generate

# Build (debug, ad hoc signed)
make build

# Build (release)
make build-release

# Run the unit tests (xcodebuild test)
make test

# Build and launch the debug app
make run

# Create the Developer ID-signed .app bundle in dist/
make app

# Create the DMG (notarized if AEROMUX_NOTARY_* credentials are set)
make dmg

# Install to /Applications
make install

# Clean build, packaging, and generated-project artifacts
make clean
```

Why Xcode and not plain `swift build`: the SwiftPM CLI emits a `Bundle.module`
resource accessor that only resolves resources beside the `.app` bundle root
(which code signing forbids), so the bundled KeyboardShortcuts recorder
`fatalError`s at runtime in a packaged app. Xcode copies SwiftPM resource bundles
into `Contents/Resources/` and emits a candidate-search accessor that finds them
there. `Package.swift` is retained for dependency metadata, but the app is built
through `AeroMux.xcodeproj`.

Tests live in `Tests/AeroMuxTests/` and run via `make test`. There is no linting
configuration.

## Architecture

**Entry point:** `Sources/App/AeroMuxApp.swift` — SwiftUI `@main` App
**App lifecycle:** `Sources/App/AppDelegate.swift` — NSApplicationDelegate, initializes all services and the sidebar window

### Data Flow

1. `RefreshCoordinator` drives periodic polling (1s default) and HTTP refresh triggers
2. `AeroSpaceClient` executes `aerospace` CLI commands (`list-workspaces`, `list-windows`, `list-monitors`, `focus`, `config`) via `CommandRunner` (Foundation `Process`)
3. Parsed `WorkspaceState` is published to SwiftUI views via `@ObservableObject`
4. Clicking a window row calls `FocusService` → `aerospace focus --window-id <id>`

### Key Services (`Sources/Services/`)

| File | Purpose |
|---|---|
| `AeroSpaceClient.swift` | Core AeroSpace CLI integration and state parsing |
| `RefreshCoordinator.swift` | Polling loop + HTTP refresh bridge coordination |
| `RefreshBridgeServer.swift` | HTTP server on port 39173 for AeroSpace event hooks |
| `SettingsStore.swift` | Persists sidebar settings to `~/.config/aeromux/settings.json` |
| `WorkspaceMemoryStore.swift` | Persists workspace metadata to `~/.config/aeromux/workspaces.json` |
| `CommandRunner.swift` | Foundation `Process`-based shell command execution |
| `FocusService.swift` | Window focus operations via AeroSpace CLI |

### UI (`Sources/UI/`)

- `SidebarRootView.swift` — top-level sidebar container
- `WorkspaceSectionView.swift` — per-workspace card
- `WindowRowView.swift` — individual window entry within a workspace

### Window Management

- `Sources/Window/SidebarWindowController.swift` — positions the `NSWindow` as a left-edge sidebar
- `Sources/App/StatusItemController.swift` — menu bar icon and dropdown

## Configuration

- Config dir: `~/.config/aeromux/` (or `$XDG_CONFIG_HOME/aeromux/`)
- Settings: `settings.json` — sidebar width (100–600px), compact mode, launch-at-login, active workspace pinning
- Workspace metadata: `workspaces.json`

## CI

- **CI:** `.github/workflows/ci.yml` — generates the project and runs `xcodebuild build test` (Debug, ad hoc signed) on push/PR using macOS 15 + Xcode 16. No signing secrets.
- **Releases are built locally**, not in CI, so the Developer ID private key never leaves the maintainer's machine. There is no release workflow.

## Packaging & Release

See `docs/RELEASING.md`. Build config lives in `project.yml` (XcodeGen) and
`Packaging/ExportOptions.plist`. Release scripts are in `scripts/`:
- `build-release-app.sh` — `xcodebuild archive` + Developer ID `-exportArchive` → `dist/AeroMux.app`
- `build-release-dmg.sh` — notarizes + staples the `.app`, builds the DMG, then notarizes + staples the DMG, when `AEROMUX_NOTARY_*` credentials are set

`make release` (with `VERSION=vX.Y.Z` and `AEROMUX_NOTARY_PROFILE`) builds the
notarized DMG locally and publishes it via `gh release create`. Release builds
are Developer ID-signed with hardened runtime and notarized; Debug builds remain
ad hoc signed for local test injection.
