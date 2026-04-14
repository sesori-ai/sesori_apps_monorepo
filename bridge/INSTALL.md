# Install Sesori Bridge

## macOS / Linux

### 1. Install

```bash
bash install.sh
```

### 2. Verify

```bash
sesori-bridge --version
```

If PATH has not refreshed yet:

```bash
~/.sesori/bin/sesori-bridge --version
```

### 3. Start

```bash
sesori-bridge
```

## Windows

### 1. Install

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
  - macOS / Linux: `~/.sesori/`
  - Windows: `%LOCALAPPDATA%\sesori\`
- Shell installers remain supported and install the same managed runtime that `sesori-bridge` runs afterward.
- `npx @sesori/bridge` is a bootstrap option, not the long-lived runtime. Use it to install or refresh the managed runtime, then run `sesori-bridge` from the managed launcher path.
- To bootstrap with npm instead of the shell installer:
  - macOS / Linux: `npx @sesori/bridge --version`, then `sesori-bridge`
  - Windows: `npx @sesori/bridge --version`, then `sesori-bridge`
- `npm uninstall @sesori/bridge` does not remove the managed install under `~/.sesori/` or `%LOCALAPPDATA%\sesori\`. Remove that directory manually if you want a full uninstall.
- Installers resolve the newest non-prerelease GitHub release tagged `bridge-v*` that contains both the platform archive and `checksums.txt`
- Release checksum manifests use archive basenames such as `sesori-bridge-macos-arm64.tar.gz`; installers match that basename instead of a temp download path
- Startup auto-update only applies to managed installs under the Sesori install root (`~/.sesori/bin` on macOS/Linux, `%LOCALAPPDATA%\sesori\bin` on Windows)
- Runtime auto-update is skipped in CI and when `SESORI_NO_UPDATE=1` is set
- Direct execution of package binaries from npm-owned `node_modules` locations is unsupported
