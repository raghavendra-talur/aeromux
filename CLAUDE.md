# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AeroMux is a native macOS SwiftUI sidebar app (macOS 13+) that extends the [AeroSpace](https://github.com/nikitabobko/AeroSpace) tiling window manager with a persistent workspace/window sidebar UI. It communicates with AeroSpace via CLI process execution.

## Build & Development Commands

```bash
# Build (debug)
make build          # or: swift build

# Build (release)
make build-release  # or: swift build -c release

# Run from source
make run            # or: swift run

# Create .app bundle
make app

# Create DMG installer
make dmg

# Install to /Applications
make install

# Clean build artifacts
make clean
```

There is no test suite. There is no linting configuration.

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

- **CI:** `.github/workflows/ci.yml` — runs `swift build` on push/PR using macOS 14 + Xcode 16
- **Release:** `.github/workflows/release.yml` — triggers on `v*` tags, builds DMG, publishes to GitHub Releases

## Packaging & Release

See `docs/RELEASING.md`. Release scripts are in `scripts/`:
- `build-release-app.sh` — creates `.app` bundle
- `build-release-dmg.sh` — packages DMG with ad hoc signing

App is ad hoc signed only (not notarized); macOS will show a warning on first launch.
