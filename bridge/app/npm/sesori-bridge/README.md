# @sesori/bridge

Bootstrap launcher for the [Sesori Bridge](https://github.com/sesori-ai/sesori_apps_monorepo) — a lightweight CLI that connects an AI coding assistant running on your laptop to the Sesori mobile app via an encrypted relay.

This npm package is a **bootstrap launcher**, not the runtime itself. When you run `sesori-bridge` (or `npx @sesori/bridge`), it installs and updates a managed native binary under your home directory:

- macOS / Linux: `~/.local/share/sesori/`
- Windows: `%LOCALAPPDATA%\sesori\`

The platform-specific native binary is pulled from the matching optional dependency (`@sesori/bridge-<os>-<arch>`), with a fallback to the tagged GitHub Release asset if the npm payload is unavailable. After install, the `sesori-bridge` command runs the managed runtime, which keeps itself up to date.

## Install

```bash
# macOS / Linux / Windows (Node.js required)
npx @sesori/bridge
```

After the first run, the managed `sesori-bridge` command is installed. On all platforms, open a new terminal so the new PATH entry is picked up (macOS/Linux: `~/.local/bin`; Windows: `%LOCALAPPDATA%\sesori\bin`), then verify:

```bash
sesori-bridge --version
```

On Windows, the bootstrap persists the User PATH via a child PowerShell process that cannot refresh the current terminal — a new terminal is required before `sesori-bridge` is available. Alternatively, run the binary directly: `& "$env:LOCALAPPDATA\sesori\bin\sesori-bridge.exe" --version`.

Prefer a shell installer with no Node.js dependency?

```bash
# macOS / Linux
curl -fsSL https://raw.githubusercontent.com/sesori-ai/sesori_apps_monorepo/main/install.sh | bash

# Windows (PowerShell)
irm https://raw.githubusercontent.com/sesori-ai/sesori_apps_monorepo/main/install.ps1 | iex
```

Both paths install the same managed runtime.

## Supported platforms

| OS     | Architecture | Optional dependency            |
| ------ | ------------ | ------------------------------ |
| macOS  | arm64, x64   | `@sesori/bridge-darwin-*`       |
| Linux  | arm64, x64   | `@sesori/bridge-linux-*`        |
| Windows| arm64, x64   | `@sesori/bridge-win32-*`        |

## Uninstall

`npm uninstall @sesori/bridge` only removes this npm package. To remove the managed runtime, delete the install directory listed above (and the `~/.local/bin/sesori-bridge` symlink on macOS/Linux).

## Documentation

- [Sesori Bridge install guide](https://github.com/sesori-ai/sesori_apps_monorepo/blob/main/bridge/INSTALL.md)
- [Sesori Bridge architecture](https://github.com/sesori-ai/sesori_apps_monorepo/blob/main/bridge/ARCHITECTURE.md)
- [Project README](https://github.com/sesori-ai/sesori_apps_monorepo#readme)

## License

Source-available under the Functional Source License, Version 1.1, Apache 2.0 Future License (`FSL-1.1-ALv2`). See [LICENSE](./LICENSE).
