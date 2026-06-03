# Releasing AeroMux

Releases are built **locally** with Xcode, signed with a Developer ID
certificate, notarized by Apple, and published to GitHub Releases from your
machine. Signing material never leaves your Mac, so there is no CI release
workflow and no signing secrets in the repository.

## One-time setup

1. **Developer ID Application certificate** installed in your login keychain
   (`security find-identity -v -p codesigning` should list it). Make sure it has
   no manual trust overrides, or codesign will reject it — set its Trust to
   "Use System Defaults" in Keychain Access.
2. **Notary credential profile** (uses an app-specific password from
   appleid.apple.com → Sign-In and Security → App-Specific Passwords):

   ```bash
   xcrun notarytool store-credentials aeromux-notary \
     --apple-id "raghavendra.talur@gmail.com" \
     --team-id RQ4U2AV56B
   ```

3. **XcodeGen** (`brew install xcodegen`) and the GitHub CLI (`gh auth login`).

## Build a notarized DMG

```bash
AEROMUX_NOTARY_PROFILE=aeromux-notary VERSION=v0.1.0 make dmg
```

This generates the Xcode project, archives a Release build, exports a Developer
ID-signed `.app` with hardened runtime, notarizes and staples the `.app`, then
builds, notarizes, and staples `dist/AeroMux-v0.1.0.dmg`. Without
`AEROMUX_NOTARY_*` set, the same command still builds a signed (but
un-notarized) DMG and prints a warning.

Verify the result:

```bash
xcrun stapler validate dist/AeroMux-v0.1.0.dmg
# mount it and confirm the app inside:
spctl -a -vvv "/Volumes/AeroMux/AeroMux.app"   # => accepted, source=Notarized Developer ID
```

## Publish the GitHub release

Tag, then publish the locally built artifacts:

```bash
git tag v0.1.0
git push origin v0.1.0
AEROMUX_NOTARY_PROFILE=aeromux-notary VERSION=v0.1.0 make release
```

`make release` builds the notarized DMG, writes a `.sha256` checksum, and runs
`gh release create` to create the release and upload both files.

## Signing status

Release builds are Developer ID-signed with hardened runtime and notarized, so
Gatekeeper accepts them without a warning. Debug builds (`make build`,
`make run`, `make test`) remain ad hoc signed so the unit-test bundle can be
injected into the app host.
