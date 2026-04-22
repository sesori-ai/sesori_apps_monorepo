# Releasing Sesori Bridge

## Current distribution

- **Enabled by default:** GitHub Releases
- **Enabled by default:** npm publish via npm trusted publishing
- **Bridge release selector:** installers and updater only consider stable GitHub releases tagged `bridge-v*`

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

## macOS code signing setup

macOS binaries are signed in CI with a Developer ID Application certificate. The following secrets must be configured in the GitHub repository:

| Secret | Description |
|--------|-------------|
| `MACOS_CERT_P12_BASE64` | Base64-encoded `.p12` containing the Developer ID Application certificate and private key |
| `MACOS_CERT_PASSWORD` | Password for the `.p12` file |
| `MACOS_KEYCHAIN_PASSWORD` | Password for the temporary keychain created during CI |

And the following repository variable:

| Variable | Description |
|----------|-------------|
| `APPLE_TEAM_ID` | 10-character Apple Team ID |

### Creating the certificate

1. Generate a Certificate Signing Request (CSR) on a Mac:
   - Open Keychain Access → Certificate Assistant → Request a Certificate From a Certificate Authority
   - Email: your Apple ID email
   - Name: your name or org name
   - Request is: Saved to disk
   - Key pair: RSA, 2048 bits

2. Download the certificate from [Apple Developer Portal](https://developer.apple.com):
   - Certificates, Identifiers & Profiles → + → Developer ID Application
   - Upload the CSR
   - Download the `.cer` file

3. Export as `.p12`:
   - Double-click the `.cer` to install it into your login keychain
   - In Keychain Access, find it under "My Certificates"
   - Select both the certificate **and** its private key
   - Right-click → Export 2 items → choose `.p12` format
   - Set a strong password

4. Base64-encode for GitHub:
   ```bash
   base64 -i DeveloperIDApplication.p12 | pbcopy
   ```
   Paste the result as the `MACOS_CERT_P12_BASE64` secret.

## Release steps

### 1. Bump version

```bash
cd bridge/app
dart run tool/bump_version.dart 0.3.1
```

That bump step is the source of truth for the release version. It must keep `bridge/app/pubspec.yaml`, `bridge/app/lib/src/version.dart`, and all six npm package manifests in `bridge/app/npm/` aligned to the same `X.Y.Z` release before you tag.

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
6. publishes the five platform npm bootstrap packages from those tagged release assets
7. publishes the `@sesori/bridge` wrapper package through npm trusted publishing

## Dry run

### GitHub CLI

```bash
gh workflow run bridge-release.yml -f dry_run=true
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

After the tagged workflow finishes, test the exact npm package version:

```bash
npx @sesori/bridge@X.Y.Z

# If PATH has not refreshed in this shell yet, open a new terminal
# or run ~/.sesori/bin/sesori-bridge directly on macOS/Linux.
sesori-bridge --version
```

The expected result is that `npx` installs or refreshes the managed runtime, then exits with a clear next-step message. The long-lived command is still `sesori-bridge`, not a binary inside `node_modules`. If npm does not materialize the platform package in the exec tree, the wrapper must fall back to the exact tagged GitHub Release asset for `bridge-vX.Y.Z` and still install the same managed runtime.

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

## npm trusted publishing prerequisites

Configure npm trusted publishing for all six packages in this repo against the exact workflow file `.github/workflows/bridge-release.yml`:

- `@sesori/bridge`
- `@sesori/bridge-darwin-arm64`
- `@sesori/bridge-darwin-x64`
- `@sesori/bridge-linux-x64`
- `@sesori/bridge-linux-arm64`
- `@sesori/bridge-win32-x64`

Those trusted publisher entries must match the GitHub owner, repository, and workflow filename exactly. The tag-triggered workflow verifies the archived GitHub Release assets against `checksums.txt`, derives each platform npm payload from those exact release artifacts, and then publishes through npm trusted publishing on `ubuntu-latest`.
