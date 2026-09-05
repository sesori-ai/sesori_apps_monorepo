# Sesori Bridge

Dart workspace containing the headless Sesori Bridge CLI and its plugin system. One bridge can connect independently eligible AI-assistant plugins to mobile and desktop clients over an encrypted WebSocket relay.

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
| `sesori_plugin_omp` | Oh My Pi implementation over ACP |
| `sesori_plugin_claude` | Claude Code backend implementation |
| `sesori_plugin_hermes` | Hermes implementation over ACP |
| `sesori_plugin_grok` | Grok Build implementation over ACP |
| `sesori_plugin_pi` | Pi backend implementation |
| `app` | CLI entry point: auth, relay, encryption, catalog, request routing, and plugin composition |

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

## Install and uninstall

Packaged installs are documented once, in
[INSTALL.md](INSTALL.md): the shell installers, `npx @sesori/bridge`, the managed
install locations, update behavior and the update track, and the uninstall steps.
[RELEASING.md](RELEASING.md) covers release verification and the manual
test-release flow.

Building from source, as described above, is for working on the bridge itself; a
packaged install remains the simplest way to run it headlessly.

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

Every registered plugin is eligible unless its ID appears in
`plugins.disabled` in bridge settings. Setup-ready plugins start independently,
and the first operational plugin in case-insensitive display-name order is the
current default for new clients. This default is separate from legacy missing
identity: released payloads without `pluginId` always mean OpenCode, not the
current default.

```bash
sesori-bridge config plugins
sesori-bridge config plugins disable cursor
```

Eligible plugins are inspected without installing anything. Ready plugins may
resolve a compatible PATH binary or an existing pinned managed runtime before
they are started, monitored, failed, and stopped independently. A plugin failure
disables controls routed to that plugin but does not stop the relay, catalog
browsing, or another plugin.

Normal project, root-session, session-detail, and child reads use the durable
database catalog only; external harness work enters through an explicit,
non-destructive per-plugin import. Catalog readers continue to see the last
committed snapshot while an import enumerates or publishes. The ownership model
behind this, including the import endpoints and the identity rules, is in
[docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md#catalog-ownership-and-the-plugin-boundary).

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
4. Register the descriptor in `app/lib/src/runtime/plugin_registry.dart` (referenced from `app/bin/bridge.dart`).

For a concrete example, see `sesori_plugin_opencode`.

### Plugin lifecycle at a glance

The bridge validates every registered plugin's CLI configuration before I/O,
loads the denylist, and inspects setup concurrently for eligible plugins. It
then probes ready plugins, acquires the startup mutex once, resolves existing
runtimes sequentially in display-name order, and registers each start as soon as
its resolution settles. Starts may overlap later resolutions and other starts.
Each plugin is responsible for:

- Starting (or attaching to) its backend server.
- Publishing `Ready` / `Degraded` / `Failed` / `Restarting` status transitions.
- Gracefully shutting down when the bridge exits.

The bridge lifecycle service publishes one alphabetically ordered
eligible/default/operational view. A terminal plugin failure removes only that
plugin API from routing. The
bridge handles relay connection, encryption, catalog routing, and sourced SSE
multiplexing; it never knows a backend's command line, health endpoint, or event
format.
