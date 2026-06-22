# @sesori/bridge

Bootstrap launcher for the [Sesori Bridge](https://github.com/sesori-ai/sesori_apps_monorepo) — a lightweight CLI that connects an AI coding assistant running on your laptop to the Sesori mobile app via an encrypted relay.

This npm package is a **bootstrap launcher**, not the runtime itself. Running `npx @sesori/bridge` installs (or refreshes) a managed native binary under your home directory and tells you how to start it — it does **not** start the bridge:

- macOS / Linux: `~/.local/share/sesori/`
- Windows: `%LOCALAPPDATA%\sesori\`

The platform-specific native binary is pulled from the matching optional dependency (`@sesori/bridge-<os>-<arch>`), with a fallback to the tagged GitHub Release asset if the npm payload is unavailable. After install, you run the managed `sesori-bridge` command yourself; the runtime keeps itself up to date from then on.

## Install

```bash
# macOS / Linux / Windows (Node.js required)
npx @sesori/bridge
```

This installs the managed runtime and prints the next step. The bootstrap only installs — it never starts the bridge, and it forwards no arguments to it. On all platforms, open a new terminal so the new PATH entry is picked up (macOS/Linux: `~/.local/bin`; Windows: `%LOCALAPPDATA%\sesori\bin`), then start the bridge and check the version:

```bash
sesori-bridge            # start the bridge
sesori-bridge --version  # check the installed version
```

On Windows, the bootstrap persists the User PATH via a child PowerShell process that cannot refresh the current terminal — a new terminal is required before `sesori-bridge` is available. Alternatively, run the binary directly: `& "$env:LOCALAPPDATA\sesori\bin\sesori-bridge.exe" --version`.

### Options

```bash
npx @sesori/bridge --force   # -f: reinstall the bundled version, overwriting
                             #     whatever is installed (even a newer or
                             #     incomplete/corrupt runtime)
npx @sesori/bridge --help    # -h: show usage
```

By default the bootstrap leaves an already-current or newer healthy runtime in place, and refuses to overwrite a newer-but-incomplete runtime with an older payload. Use `--force` to override all of that and (re)install the bundled version unconditionally — useful for repairing a wedged install.

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
