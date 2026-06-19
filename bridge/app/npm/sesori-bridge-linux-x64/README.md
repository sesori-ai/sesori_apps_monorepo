# @sesori/bridge-linux-x64

Platform payload for [`@sesori/bridge`](https://www.npmjs.com/package/@sesori/bridge) on **Linux (x86_64)**.

This package contains the native Sesori Bridge runtime archive for `linux/x64`. It is consumed automatically by the bootstrap launcher — you do not need to install it directly. If `npx @sesori/bridge` detects `linux x64`, this package provides the native binary payload that gets unpacked into the managed runtime under `~/.local/share/sesori/`.

## Install (indirect)

```bash
npx @sesori/bridge
```

If you somehow need the payload directly (not recommended for normal use):

```bash
npm install @sesori/bridge-linux-x64
```

## What it contains

- `lib/runtime/` — native Sesori Bridge binary archive for Linux x64, sourced from the matching GitHub Release asset (`sesori-bridge-linux-x64.tar.gz`).

## Supported platform

| Field | Value |
| --- | --- |
| `os` | `linux` |
| `cpu` | `x64` |

## Documentation

- [Sesori Bridge install guide](https://github.com/sesori-ai/sesori_apps_monorepo/blob/main/bridge/INSTALL.md)
- [Project README](https://github.com/sesori-ai/sesori_apps_monorepo#readme)

## License

Source-available under the Functional Source License, Version 1.1, Apache 2.0 Future License (`FSL-1.1-ALv2`). See [LICENSE](./LICENSE).
