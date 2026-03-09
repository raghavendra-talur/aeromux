# AeroMux

AeroMux is a lightweight macOS sidebar companion for AeroSpace. It creates a persistent left rail that shows every non-empty workspace, highlights the active one, and lists the windows inside each task container with click-to-focus and a localhost refresh hook plus polling fallback.

## What is implemented

- Persistent left sidebar window using `NSPanel` + SwiftUI
- Workspace rail that shows every non-empty workspace and keeps the active workspace highlighted
- Focused row highlighting, empty state, loading state, and error state
- AeroSpace gap verification so the app can behave like a reserved side column instead of a permanent floating overlay
- AeroSpace CLI adapter isolated behind `AeroSpaceClient`
- Hybrid refresh model:
  - polling every second by default
  - localhost bridge on `127.0.0.1:39173`
- Click-to-focus through a dedicated `FocusService`
- `UserDefaults`-backed settings store for the MVP config surface

## AeroSpace commands used

The current implementation is aligned to the installed AeroSpace CLI and uses these commands:

- `aerospace list-workspaces --focused --json`
- `aerospace list-windows --workspace <name> --json`
- `aerospace list-windows --focused --json`
- `aerospace list-monitors --focused --json`
- `aerospace focus --window-id <id>`

If your installed AeroSpace version differs later, adjust only `Sources/Services/AeroSpaceClient.swift` and `Sources/Services/FocusService.swift`.

## Run

```bash
swift run
```

## AeroSpace hook wiring

Polling mode works without hooks. For lower-latency updates, add a hook that hits the local refresh endpoint:

```bash
curl -fsS -X POST http://127.0.0.1:39173/refresh >/dev/null 2>&1 || true
```

Example helper script:

`scripts/aerospace-refresh-hook.sh`

## No-overlap integration

The clean integration is to reserve the sidebar width in AeroSpace on the main monitor:

```toml
[gaps]
    outer.left = [{ monitor.main = 260 }, 0]
```

AeroMux now checks that reservation at runtime. When the gap is wide enough, the sidebar drops to a normal window level on the main monitor. If the gap is missing or too small, the app warns in the UI and falls back to floating above other windows.
