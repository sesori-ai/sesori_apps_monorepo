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
