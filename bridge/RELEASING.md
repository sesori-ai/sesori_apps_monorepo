# Releasing Sesori Bridge

## Current distribution

- **Enabled by default:** GitHub Releases
- **Enabled by default:** npm publish via npm trusted publishing
- **Release selector:** installers always use the newest stable GitHub release tagged `v*`. The runtime auto-updater follows the configured update track — `stable` (default) uses stable `v*` releases, while `internal` also picks up `v*-internal.*` pre-releases (see `config track` in [INSTALL.md](INSTALL.md)).

## Release tag

Use shared `vX.Y.Z` tags:

```bash
vX.Y.Z
```

Example:

```bash
v0.3.1
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
   - Name: must match the CI signing identity (e.g., `DigitalBlock Labs LTD`)
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

4. Base64-encode for GitHub (use `-b 0` to produce a single-line string):
   ```bash
   base64 -b 0 -i DeveloperIDApplication.p12 | pbcopy
   ```
   Paste the result as the `MACOS_CERT_P12_BASE64` secret.

## Release steps

The bridge releases together with the mobile apps under the shared `vX.Y.Z`
version. There is no manual tagging — tags and GitHub releases are created by
the workflows.

### 1. Bump version

```bash
make bump-version TYPE=patch
```

That bump step is the source of truth for the release version. It must keep `bridge/app/pubspec.yaml`, `bridge/app/lib/src/version.dart`, all six npm package manifests in `bridge/app/npm/`, and `mobile/app/pubspec.yaml` aligned to the same `X.Y.Z` semantic release. For an explicit version, run `make bump-version VERSION=X.Y.Z`. The bump is REQUIRED after every production release: `release-all-platforms.yml` fails its preflight guard for any main push whose version already has a `v<version>` tag.

### 2. Merge to main

Every main merge runs `release-all-platforms.yml`: it uploads the mobile apps to TestFlight / Play internal, builds all five bridge platform archives with `X.Y.Z-internal.<N>` baked in, and — only when everything succeeded — pushes a `v<X.Y.Z>-internal.<N>` tag and rolls the single internal GitHub pre-release onto it (binaries + `checksums.txt` + regenerated notes). The auto-updater ignores pre-releases on the default `stable` track; bridges switched to the `internal` track (`sesori-bridge config track internal`) pick up these `-internal.<N>` pre-releases.

### 3. Submit to production

Run the `Submit Release` workflow (`submit-release.yml`) with the build number to promote. For production it rebuilds the bridge from the resolved commit with the clean version, tags `v<X.Y.Z>`, and creates the GitHub release with the five archives plus `checksums.txt`. Use `platforms: bridge-only` for a bridge hotfix that skips the app stores.

- `publish_bridge` ticked (default): the release is published immediately — bridge auto-update goes live for all users right away.
- `publish_bridge` unticked: the release is created as a pre-release, invisible to the auto-updater until you promote it in the GitHub UI.

### 4. npm publish (automatic)

When the stable `v<X.Y.Z>` release goes live, `bridge-npm-publish.yml` publishes the npm packages: dispatched directly by `submit-release.yml` when publishing immediately, or fired by the `release: released` event when you promote a pre-release manually in the GitHub UI.

## What the release pipeline does

1. builds binaries for macOS arm64/x64, Linux x64/arm64, Windows x64 (`_reusable-bridge-build.yml`)
2. renames `bridge` to `sesori-bridge` and signs the macOS binaries
3. creates release archives
4. generates basename-based `checksums.txt`
5. creates the `v<X.Y.Z>` GitHub Release and uploads all assets (`submit-release.yml`)
6. publishes the five platform npm bootstrap packages from those tagged release assets
7. publishes the `@sesori/bridge` wrapper package through npm trusted publishing

## Manual test release and install

Use this sequence when you want to test the real packaged distribution flow end to end.

### A. Test a GitHub Release for the shell installers

1. Bump the shared App + Bridge version with `make bump-version TYPE=<type>` or `make bump-version VERSION=X.Y.Z`.
2. Merge to main and wait for `release-all-platforms.yml` to roll the internal pre-release.
3. Run `Submit Release` for production (use `platforms: bridge-only` to skip the app stores).
4. Wait for the `v<X.Y.Z>` GitHub Release to be published with its assets and `checksums.txt`.
5. Verify the release contains all five platform archives plus `checksums.txt`.
6. Test the shell installer against that release:

```bash
# from a clone of this repo
bash install.sh
sesori-bridge --version
```

Or with the hosted installer from that exact tag:

```bash
curl -fsSL https://raw.githubusercontent.com/sesori-ai/sesori_apps_monorepo/vX.Y.Z/install.sh | bash
sesori-bridge --version
```

Windows:

```powershell
irm https://raw.githubusercontent.com/sesori-ai/sesori_apps_monorepo/vX.Y.Z/install.ps1 | iex
sesori-bridge --version
```

The expected result is that `sesori-bridge --version` prints `X.Y.Z` from the managed install root. If PATH has not refreshed in the current shell yet, open a new terminal or use the managed binary path directly.

### B. Test the npm bootstrap path with `npx`

After the tagged workflow finishes, test the exact npm package version:

```bash
npx @sesori/bridge@X.Y.Z

# If PATH has not refreshed in this shell yet, open a new terminal
# or run ~/.local/share/sesori/bin/sesori-bridge directly on macOS/Linux.
sesori-bridge --version
```

The expected result is that `npx` installs or refreshes the managed runtime, then exits with a clear next-step message. The long-lived command is still `sesori-bridge`, not a binary inside `node_modules`. If npm does not materialize the platform package in the exec tree, the wrapper must fall back to the exact tagged GitHub Release asset for `vX.Y.Z` and still install the same managed runtime.

### C. Manual uninstall verification

After either install path, confirm uninstall behavior matches the contract:

- `npm uninstall @sesori/bridge` removes only the npm package, not the managed install.
- Full uninstall is manual directory deletion:
  - macOS / Linux: `rm -rf ~/.local/share/sesori`
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

Managed installs from these installers are the supported long-lived runtime and the only binaries eligible for startup or periodic auto-update. The npm package stays bootstrap-only: users run `npx @sesori/bridge` to install or refresh the managed runtime, then run `sesori-bridge` from the managed launcher path. Direct execution of platform package binaries inside npm-owned locations is unsupported. `npm uninstall` does not remove the managed install, so release docs and support copy must keep pointing users to manual removal of `~/.local/share/sesori/` (and `~/.local/bin/sesori-bridge`) or `%LOCALAPPDATA%\sesori\` when they want a full uninstall.

## npm trusted publishing prerequisites

Configure npm trusted publishing for all six packages in this repo against the exact workflow file `.github/workflows/bridge-npm-publish.yml`:

- `@sesori/bridge`
- `@sesori/bridge-darwin-arm64`
- `@sesori/bridge-darwin-x64`
- `@sesori/bridge-linux-x64`
- `@sesori/bridge-linux-arm64`
- `@sesori/bridge-win32-x64`

Those trusted publisher entries must match the GitHub owner, repository, and workflow filename exactly. The workflow verifies the archived GitHub Release assets against `checksums.txt`, derives each platform npm payload from those exact release artifacts, and then publishes through npm trusted publishing on `ubuntu-latest`.
