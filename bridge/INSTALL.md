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
- Installers resolve the newest non-prerelease GitHub release tagged `bridge-v*` that contains both the platform archive and `checksums.txt`
- Release checksum manifests use archive basenames such as `sesori-bridge-macos-arm64.tar.gz`; installers match that basename instead of a temp download path
- Startup auto-update only applies to managed installs under the Sesori install root (`~/.sesori/bin` on macOS/Linux, `%LOCALAPPDATA%\sesori\bin` on Windows)
- Runtime auto-update is skipped in CI, when `SESORI_NO_UPDATE=1` is set, and when the bridge is launched from an npm-managed `node_modules` path
- `npx @sesori/bridge` and other npm-managed installs stay on the package manager’s version; use npm to upgrade them instead of expecting the binary to self-replace
