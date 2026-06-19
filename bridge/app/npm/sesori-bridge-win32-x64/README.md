# @sesori/bridge-win32-x64

Platform payload for [`@sesori/bridge`](../sesori-bridge/README.md) on **Windows (x86_64)**.

This package contains the native Sesori Bridge runtime archive for `win32/x64`. It is consumed automatically by the bootstrap launcher — you do not need to install it directly. If `npx @sesori/bridge` detects `win32 x64`, this package provides the native binary payload that gets unpacked into the managed runtime under `%LOCALAPPDATA%\sesori\`.

## Install (indirect)

```bash
npx @sesori/bridge --version
```

If you somehow need the payload directly (not recommended for normal use):

```bash
npm install @sesori/bridge-win32-x64
```

## What it contains

- `lib/runtime/` — native Sesori Bridge binary archive for Windows x64, sourced from the matching GitHub Release asset (`sesori-bridge-windows-x64.zip`).

## Supported platform

| Field | Value |
| --- | --- |
| `os` | `win32` |
| `cpu` | `x64` |

## Documentation

- [Sesori Bridge install guide](https://github.com/sesori-ai/sesori_apps_monorepo/blob/main/bridge/INSTALL.md)
- [Project README](https://github.com/sesori-ai/sesori_apps_monorepo#readme)

## License

Source-available under the Functional Source License, Version 1.1, Apache 2.0 Future License (`FSL-1.1-ALv2`). See [LICENSE](./LICENSE).
