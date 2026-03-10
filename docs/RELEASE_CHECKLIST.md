# Release Checklist

Use this before posting AeroMux publicly outside your own network.

## Must Have

- Verify the README from a clean shell on macOS
- Confirm `swift build` and `swift run` work without local hacks
- Replace SSH clone URLs with HTTPS in any public-facing post if you want friction-free copy/paste
- Add at least one screenshot to the repository or release post
- State clearly that this is an early DMG release and not notarized yet
- State clearly that the current layout is main-monitor-only and left-sidebar-only
- State clearly that a reserved AeroSpace left gap is recommended

## Strongly Recommended

- Create a GitHub release for `v0.1`
- Add a short changelog section or release notes
- Test against at least one more AeroSpace version
- Test on a second machine or user account
- Verify behavior when `aerospace` is missing from `PATH`
- Verify behavior when `outer.left` is absent
- Verify behavior when `focus --window-id` is unsupported

## Nice To Have

- A menu bar item with Quit and Relaunch
- A compatibility matrix in the README
- A short demo GIF in the repo
- CI that at least runs `swift build`

## Suggested Public Positioning

Use language like:

`AeroMux is an early DMG release for AeroSpace users on macOS.`

Avoid language like:

`This is a polished Mac app`

until you add notarization and a more complete app lifecycle.
