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
| `sesori_plugin_antigravity` | Google Antigravity implementation over ACP |
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
and OpenCode is the default when selectable; otherwise the first selectable
plugin in case-insensitive display-name order is the default for new clients. This default is separate from legacy missing
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

### Antigravity official runtime

Antigravity support uses Google's proprietary official ACP runtime pair. Review
[Google's terms](https://antigravity.google/terms) and
[Antigravity documentation](https://antigravity.google/docs/) before using it.
The pin is ACP registry package `1.0.0`, with exact runtime identity
`agy_acp_server_20260818_01_RC01`. Sesori can install the official pair from
harness detail after showing download guidance, then update existing managed
installations on bridge start. Linux requires Info-ZIP `unzip` with ZipInfo;
installation checks it before downloading. See [INSTALL.md](INSTALL.md).

For manual setup, place `agy_acp_server.par` and `localharness_external`
together on macOS arm64 or Linux x64/arm64; on Windows x64/arm64 use
`agy_acp_server.exe` and `localharness_external.exe`. Both POSIX files must be
executable. macOS x64 is unsupported, including an explicit binary path.
Either make the server discoverable on PATH or pass
`--antigravity-bin <path-to-server>`. The sibling harness is mandatory; an
explicit server path is authoritative and disables managed Install/upgrade.
Otherwise resolution prefers a validated PATH pair, then an installed managed
pair. Setup inspection itself remains inert and does not validate the runtime.

Authentication supports personal Google OAuth only and must be started from a
current Sesori mobile or desktop app; there is no bridge-CLI fallback. For a
remote browser, submit its final loopback return URL through the active Sesori
challenge. Sesori uses an isolated Antigravity profile below bridge plugin
state and never imports ambient Google credentials.

Prompts stay in supervised `default` mode; persistent and warning-bearing
approvals are excluded. One primary agent is available; until a real
new/load/resume discovers models in a fresh process, new sessions use the
account default.
Later model selection, replay and image content use the existing shared ACP
boundaries. Provider-local image paths are never fetched. Local session deletion
removes Sesori's record but not Google's retained conversation/profile files.

The [Antigravity operator guide](../docs/ANTIGRAVITY.md) covers complete setup,
remote login, retained history and limits. Native macOS arm64 managed installation
has been checked; native Linux/Windows and authenticated end-to-end behavior
remain unverified. Do not confuse implemented capabilities with completed L5 QA.

### Catalog reads

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
