# Releasing Sesori Bridge

## Current distribution

- **Enabled by default:** GitHub Releases
- **Disabled by default:** npm publish
- **Bridge release selector:** installers and updater only consider stable GitHub releases tagged `bridge-v*`

npm publishing only runs from **manual workflow dispatch** with:

- `dry_run=false`
- `publish_npm=true`
- `release_tag=bridge-vX.Y.Z` for an already-published bridge GitHub Release

## Release tag

Use tags in this format:

```bash
bridge-vX.Y.Z
```

Example:

```bash
bridge-v0.3.1
```

## Before release

From repo root:

```bash
cd bridge
dart pub get
make test
make analyze

cd ../
shellcheck --severity=error install.sh
bash -n install.sh
```

## Release steps

### 1. Bump version

```bash
cd bridge/app
dart run tool/bump_version.dart 0.3.1
```

### 2. Commit and push

```bash
git add .
git commit -m "feat(bridge): release 0.3.1"
git push
```

### 3. Tag and push

```bash
git tag bridge-v0.3.1
git push origin bridge-v0.3.1
```

## What the workflow does on tag push

1. builds binaries for macOS arm64/x64, Linux x64/arm64, Windows x64
2. renames `bridge` to `sesori-bridge`
3. creates release archives
4. generates basename-based `checksums.txt`
5. creates a GitHub Release and uploads all assets

The automatic tag flow stops there. It does **not** publish npm packages.

## Dry run

### GitHub CLI

```bash
gh workflow run bridge-release.yml -f dry_run=true -f publish_npm=false
```

Expected: build jobs run, release/publish jobs do not.

## Manual test release and install

Use this sequence when you want to test the real packaged distribution flow end to end.

### A. Test a GitHub Release for the shell installers

1. Bump the bridge version.
2. Commit and push the branch.
3. Create and push a stable release tag:

```bash
git tag bridge-vX.Y.Z
git push origin bridge-vX.Y.Z
```

4. Wait for `bridge-release.yml` to publish the GitHub Release assets and `checksums.txt`.
5. Verify the release contains all five platform archives plus `checksums.txt`.
6. Test the shell installer against that release:

```bash
# from a clone of this repo
bash install.sh
sesori-bridge --version
```

Or with the hosted installer from that exact tag:

```bash
curl -fsSL https://raw.githubusercontent.com/sesori-ai/sesori_apps_monorepo/bridge-vX.Y.Z/install.sh | bash
sesori-bridge --version
```

Windows:

```powershell
irm https://raw.githubusercontent.com/sesori-ai/sesori_apps_monorepo/bridge-vX.Y.Z/install.ps1 | iex
sesori-bridge --version
```

The expected result is that `sesori-bridge --version` prints `X.Y.Z` from the managed install root. If PATH has not refreshed in the current shell yet, open a new terminal or use the managed binary path directly.

### B. Test the npm bootstrap path with `npx`

After the GitHub Release exists, publish the npm bootstrap packages from that exact release:

```bash
gh workflow run bridge-release.yml \
  -f dry_run=false \
  -f publish_npm=true \
  -f release_tag=bridge-vX.Y.Z
```

Wait for the manual publish workflow to finish, then test the exact npm package version:

```bash
npx @sesori/bridge@X.Y.Z --version

# If PATH has not refreshed in this shell yet, open a new terminal
# or run ~/.sesori/bin/sesori-bridge directly on macOS/Linux.
sesori-bridge --version
```

The expected result is that `npx` bootstraps or refreshes the managed runtime, and the long-lived command is still `sesori-bridge`, not a binary inside `node_modules`.

### C. Manual uninstall verification

After either install path, confirm uninstall behavior matches the contract:

- `npm uninstall @sesori/bridge` removes only the npm package, not the managed install.
- Full uninstall is manual directory deletion:
  - macOS / Linux: `rm -rf ~/.sesori`
  - Windows: `Remove-Item -Recurse -Force "$env:LOCALAPPDATA\sesori"`

### D. Automatic update verification

Auto-update only applies when the bridge is launched from the managed install path.

- Managed installs check at startup.
- Managed installs poll again every 4 hours while running.
- Auto-update is skipped in CI.
- Auto-update is skipped when `SESORI_NO_UPDATE=1` is set.
- Direct execution from npm-owned `node_modules` payloads is unsupported and not an auto-update path.

## Verify release

Check the GitHub Release contains:

- `sesori-bridge-macos-arm64.tar.gz`
- `sesori-bridge-macos-x64.tar.gz`
- `sesori-bridge-linux-x64.tar.gz`
- `sesori-bridge-linux-arm64.tar.gz`
- `sesori-bridge-windows-x64.zip`
- `checksums.txt`

`checksums.txt` must use archive basenames as keys, for example:

```text
<sha256>  sesori-bridge-macos-arm64.tar.gz
```

Then verify install:

```bash
bash install.sh
sesori-bridge --version
```

Managed installs from these installers are the supported long-lived runtime and the only binaries eligible for startup or periodic auto-update. The npm package stays bootstrap-only: users run `npx @sesori/bridge` to install or refresh the managed runtime, then run `sesori-bridge` from the managed launcher path. Direct execution of platform package binaries inside npm-owned locations is unsupported. `npm uninstall` does not remove the managed install, so release docs and support copy must keep pointing users to manual removal of `~/.sesori/` or `%LOCALAPPDATA%\sesori\` when they want a full uninstall.

## Optional npm publish later

Run the workflow manually with:

- `dry_run=false`
- `publish_npm=true`
- `release_tag=bridge-vX.Y.Z`

The manual npm publish path checks out the tagged bridge release, verifies its archived asset checksums against `checksums.txt`, and then derives each platform npm package payload directly from those existing GitHub Release assets before publishing.

That manual path is the final release step when npm packages are needed: first create and verify the GitHub Release, then run the manual workflow dispatch against that exact `bridge-vX.Y.Z` tag. Those npm packages remain bootstrap payloads for the managed runtime, and CI now fails if the package metadata, copied runtime payload, or recorded release provenance drifts from the tagged GitHub Release contract.
