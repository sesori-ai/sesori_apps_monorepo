# Sesori Bridge

Dart workspace containing the Sesori Bridge CLI and its plugin system. The bridge connects a local OpenCode server to mobile devices over an encrypted WebSocket relay.

## Architecture

Plugin-based design with three modules:

- **`sesori_plugin_interface`** defines the abstract `BridgePlugin` contract. All plugins implement its 8 methods: `getProjects`, `getSessions`, `getSessionMessages`, `healthCheck`, `getProviders`, `getActiveSessionsSummary`, `proxyRequest`, `dispose`.
- **`sesori_plugin_opencode`** implements that contract for the OpenCode backend.
- **`app`** orchestrates everything: auth (OAuth PKCE), relay connection, encryption, and request routing. It depends only on the plugin interface, not on any specific implementation.

```
Phone <--(E2E encrypted)--> Relay Server <--(E2E encrypted)--> Bridge CLI -> [Plugin] -> opencode serve
```

## Modules

| Module | Description |
|--------|-------------|
| `sesori_plugin_interface` | Abstract `BridgePlugin` contract and shared model types |
| `sesori_plugin_opencode` | OpenCode backend implementation of `BridgePlugin` |
| `app` | CLI entry point: auth, relay, encryption, request routing |

## Quick Start

```bash
# Install dependencies for the whole workspace
dart pub get

# Build a native binary (from bridge/app/)
make build
```

## Install

For packaged installs, use the bridge distribution docs instead of building from source:

- [INSTALL.md](INSTALL.md) — shell installer, `npx @sesori/bridge`, update behavior, and uninstall steps
- [RELEASING.md](RELEASING.md) — release verification and manual test-release flow

Quick packaged install options:

```bash
# npm bootstrap
npx @sesori/bridge

# If PATH has not refreshed in this shell yet, open a new terminal
# or run ~/.local/share/sesori/bin/sesori-bridge directly on macOS/Linux.
sesori-bridge

# macOS / Linux shell installer
curl -fsSL https://raw.githubusercontent.com/sesori-ai/sesori_apps_monorepo/main/install.sh | bash
```

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/sesori-ai/sesori_apps_monorepo/main/install.ps1 | iex
```

Both install paths create a managed runtime under `~/.local/share/sesori/` on macOS/Linux or `%LOCALAPPDATA%\sesori\` on Windows. On macOS/Linux, a symlink is placed at `~/.local/bin/sesori-bridge`. If `~/.local/bin` is already in your PATH, the command is available immediately.

The npm bootstrap path uses `npx @sesori/bridge` only as a launcher: it installs or refreshes the managed native runtime under the Sesori install root and then gets out of the way. The steady-state command remains `sesori-bridge`, not a binary inside `node_modules`.

## Uninstall

Delete the managed install directory to fully remove the packaged bridge runtime:

- macOS / Linux: `~/.local/share/sesori/`
- Windows: `%LOCALAPPDATA%\sesori\`

Also remove the symlink on macOS/Linux:

```bash
rm -f ~/.local/bin/sesori-bridge
```

If you used the npm bootstrap path, `npm uninstall @sesori/bridge` does not remove that managed install directory.

## Development Commands

Run these from `bridge/`:

| Command | Description |
|---------|-------------|
| `make pub-get` | Run `dart pub get` across all modules |
| `make codegen` | Run `build_runner` in all modules (generates Freezed/JSON code) |
| `make test` | Run `dart test` in every module that has a `test/` directory |
| `make analyze` | Run `dart analyze` across all modules |

## Build Commands

Run these from `bridge/app/`:

| Command | Description |
|---------|-------------|
| `make build` | Build all targets: host-native binary + Linux cross-compiled binaries |
| `make build-host` | Build the native binary for the current OS and architecture |
| `make build-linux` | Cross-compile Linux binaries for arm, arm64, riscv64, x64 |

Artifacts land in `app/dist/` named `bridge-<os>-<arch>`.

## Security

All traffic between phones and the bridge is end-to-end encrypted. The relay server only sees ciphertext.

| Layer | Algorithm |
|-------|-----------|
| Key exchange | X25519 (Diffie-Hellman) |
| Key derivation | HKDF-SHA256 with info `"sesori-relay-v1"` |
| Symmetric encryption | XChaCha20-Poly1305 (24-byte nonce) |

See `app/README.md` for the full security and protocol details.

## Adding a New Plugin

1. Create a new Dart package in `bridge/`.
2. Add `sesori_plugin_interface` as a dependency.
3. Implement the `BridgePlugin` abstract class — all 8 methods are required.
4. Register the plugin in the `app` orchestrator (`bin/bridge.dart`).
