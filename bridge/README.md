# Sesori Bridge

Dart workspace containing the headless Sesori Bridge CLI and its plugin system. One bridge can connect ordered enabled AI-assistant plugins to mobile and desktop clients over an encrypted WebSocket relay.

The bridge itself is plugin-agnostic: it knows how to authenticate, relay, encrypt, and route traffic, but all backend-specific logic (how to spawn the assistant, what its health endpoint looks like, how to parse its events) lives in plugins.

```
Clients <--(E2E encrypted)--> Relay Server <--(E2E encrypted)--> Bridge CLI -> [Plugins] -> AI assistant backends
```

## Modules

| Module | Description |
|--------|-------------|
| `sesori_plugin_interface` | Plugin contract (`BridgePluginApi`, `BridgePluginDescriptor`, lifecycle types) and shared model types |
| `sesori_bridge_foundation` | Pure-Dart primitives shared by bridge core and plugins |
| `sesori_plugin_runtime` | Managed backend-process supervision used by plugins |
| `sesori_plugin_opencode` | OpenCode backend implementation of the plugin contract |
| `sesori_plugin_codex` | Codex backend implementation |
| `sesori_plugin_acp` | Shared ACP protocol plugin base |
| `sesori_plugin_cursor` | Cursor implementation over ACP |
| `app` | CLI entry point: auth, relay, encryption, catalog, request routing, and ordered plugin composition |

## Quick Start

```bash
# Install dependencies for the whole workspace
dart pub get

# Build the host-native CLI bundle (from bridge/app/)
make build
```

The Makefiles use Dart from the Flutter SDK pinned in the repository's
`.tool-versions`; install that asdf Flutter version first. Packaged installs
remain the simplest way to run the bridge headlessly without a source checkout.

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
| `make build` | Build the host-native CLI bundle |
| `make build-host` | Build the native binary for the current OS and architecture |

The launcher artifact lands in `app/dist/` as `bridge-<os>-<arch>`, with native
libraries in `app/build/cli/bundle/`. `sqlite3` build hooks require native target
compilation, so release platforms build on matching CI runners rather than by
local cross-compilation.

## Parallel Plugins And Catalog

`--plugin` is repeatable and order-preserving. Repeated CLI values override the
ordered `enabledPlugins` array in bridge settings; if neither is set, OpenCode
is the sole enabled/default plugin. The first enabled plugin is the current
default for new clients. This default is separate from legacy missing identity:
released payloads without `pluginId` always mean OpenCode, not the first enabled
plugin.

```bash
sesori-bridge --plugin opencode --plugin codex
sesori-bridge --plugin opencode --plugin codex --import-plugin codex
```

Plugins are probed, provisioned, started, monitored, failed, and stopped
independently. A plugin failure disables controls routed to that plugin but does
not stop the relay, catalog browsing, or another plugin.

Normal project, root-session, session-detail, and child reads use the durable
database catalog only. Import is a non-destructive observation of one plugin:
`POST /plugin/import` starts, `DELETE /plugin/import` cancels, and
`GET /plugin/import` returns the latest per-plugin statuses; progress is also
published as plugin-attributed SSE. Repeated `--import-plugin <id>` flags expose
the same start operation to headless runs. Catalog readers continue to see the
last committed snapshot while import enumerates or publishes.

## Security

All traffic between phones and the bridge is end-to-end encrypted. The relay server only sees ciphertext.

| Layer | Algorithm |
|-------|-----------|
| Key exchange | X25519 (Diffie-Hellman) |
| Key derivation | HKDF-SHA256 with info `"sesori-relay-v1"` |
| Symmetric encryption | XChaCha20-Poly1305 (24-byte nonce) |

See `app/README.md` for the full security and protocol details.

## Adding a New Plugin

A plugin is a Dart package that implements the contract defined in `sesori_plugin_interface`.

1. Create a new Dart package in `bridge/`.
2. Add `sesori_plugin_interface` as a dependency.
3. Implement the contract:
   - A `BridgePluginDescriptor` that declares the plugin's CLI options, validates configuration, and starts the plugin against a `PluginHost`.
   - A `BridgePlugin` that exposes a `BridgePluginApi`, reports status via a `PluginStatus` stream, and implements ordered `shutdown()`.
4. Register the descriptor in `app/lib/src/bridge/runtime/plugin_registry.dart` (referenced from `app/bin/bridge.dart`).

For a concrete example, see `sesori_plugin_opencode`.

### Plugin lifecycle at a glance

The bridge resolves and validates the complete ordered plugin set before I/O.
It probes availability concurrently, acquires the startup mutex once, provisions
available plugins sequentially in order, and registers each start as soon as
that plugin's provisioning settles. Starts may overlap later provisioning and
other starts. Each plugin is responsible for:

- Starting (or attaching to) its backend server.
- Publishing `Ready` / `Degraded` / `Failed` / `Restarting` status transitions.
- Gracefully shutting down when the bridge exits.

The bridge lifecycle service publishes one ordered enabled/default/operational
view. A terminal plugin failure removes only that plugin API from routing. The
bridge handles relay connection, encryption, catalog routing, and sourced SSE
multiplexing; it never knows a backend's command line, health endpoint, or event
format.
