# Install Sesori Bridge

## macOS / Linux

### 1. Install

Remote installer:

```bash
curl -fsSL https://raw.githubusercontent.com/sesori-ai/sesori_apps_monorepo/main/install.sh | bash
```

Local script from a checked-out repo:

```bash
bash install.sh
```

### 2. Verify

```bash
sesori-bridge --version
```

If PATH has not refreshed yet:

```bash
~/.local/share/sesori/bin/sesori-bridge --version
```

### 3. Start

```bash
sesori-bridge
```

## Windows

### 1. Install

Remote installer:

```powershell
irm https://raw.githubusercontent.com/sesori-ai/sesori_apps_monorepo/main/install.ps1 | iex
```

Local script from a checked-out repo:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

### 2. Verify

```powershell
sesori-bridge --version
```

If PATH has not refreshed yet:

```powershell
& "$env:LOCALAPPDATA\sesori\bin\sesori-bridge.exe" --version
```

### 3. Start

```powershell
sesori-bridge
```

## Notes

- Install location:
  - macOS / Linux: `~/.local/share/sesori/`
  - Windows: `%LOCALAPPDATA%\sesori\`
- On macOS/Linux, the installer creates a symlink at `~/.local/bin/sesori-bridge` pointing to the managed binary. If `~/.local/bin` is already in your PATH, `sesori-bridge` is available immediately.
- Shell installers remain supported and install the same managed runtime that `sesori-bridge` runs afterward.
- `npx @sesori/bridge` is a bootstrap option, not the long-lived runtime. Use it to install or refresh the managed runtime, then run `sesori-bridge` from the managed launcher path.
- The npm bootstrap prefers the published platform payload when npm provides it, and otherwise falls back to the exact tagged GitHub Release asset that matches the wrapper version.
- To bootstrap with npm instead of the shell installer:
  - macOS / Linux: `npx @sesori/bridge`, then `sesori-bridge`
  - Windows: `npx @sesori/bridge`, then `sesori-bridge`
- If `~/.local/bin` is not in your PATH on macOS/Linux, the installer adds it to your shell config. Open a new terminal if `sesori-bridge` is not immediately available.
- Re-running either the shell installer or `npx @sesori/bridge` is the supported manual refresh path if you want to update immediately instead of waiting for automatic updates.
- `npm uninstall @sesori/bridge` does not remove the managed install under `~/.local/share/sesori/` or `%LOCALAPPDATA%\sesori\`. Remove that directory manually if you want a full uninstall.
- Installers resolve the newest non-prerelease GitHub release tagged `bridge-v*` that contains both the platform archive and `checksums.txt`
- Release checksum manifests use archive basenames such as `sesori-bridge-macos-arm64.tar.gz`; installers match that basename instead of a temp download path
- Startup auto-update only applies to managed installs under the Sesori install root (`~/.local/share/sesori/bin` on macOS/Linux, `%LOCALAPPDATA%\sesori\bin` on Windows)
- Runtime auto-update also performs periodic polling every 4 hours while the managed bridge is running, and it is skipped in CI and when `SESORI_NO_UPDATE=1` is set
- Direct execution of package binaries from npm-owned `node_modules` locations is unsupported

## Uninstall

Delete the managed install directory for your platform:

- macOS / Linux:

```bash
rm -rf ~/.local/share/sesori
rm -f ~/.local/bin/sesori-bridge
```

- Windows:

```powershell
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\sesori"
```

If you want to clean up shell PATH changes too, remove the Sesori PATH entry from the profile file the installer or npm bootstrap updated.
