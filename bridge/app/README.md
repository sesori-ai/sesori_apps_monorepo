# Sesori Bridge CLI

Native CLI tool written in Dart, compiled to a platform bundle, that runs headlessly and bridges local AI assistant backends to mobile and desktop clients over an encrypted WebSocket relay.

The bridge authenticates with OAuth PKCE, loads the ordered enabled plugins,
connects to the relay, performs an X25519 key exchange with each connecting
client, and routes encrypted requests and responses. All traffic is end-to-end
encrypted; the relay server only ever sees ciphertext. Each plugin owns its
backend-specific spawning, health checks, event parsing, and graceful shutdown.

## Quick Start

```bash
# Build a native binary
make build

# Run (example for Apple Silicon macOS)
./dist/bridge-macos-arm64
```

Press `Ctrl+C` to stop. This shuts down the bridge, independently drains plugin
sessions/imports/listeners, and triggers ordered shutdown for every returned
plugin instance and any backend process it started.

No Dart SDK? You can bootstrap the managed install with npm:

```bash
npx @sesori/bridge

# If PATH has not refreshed in this shell yet, open a new terminal
# or run ~/.local/share/sesori/bin/sesori-bridge directly on macOS/Linux.
sesori-bridge
```

`npx @sesori/bridge` only installs or refreshes the managed runtime under `~/.local/share/sesori/` on macOS/Linux or `%LOCALAPPDATA%\sesori\` on Windows. It prefers the published platform payload when npm provides it, and otherwise falls back to the exact tagged GitHub Release asset for the wrapper version. `sesori-bridge` is the long-lived command you keep running after that bootstrap step. Shell installers are still supported if you prefer them. `npm uninstall @sesori/bridge` does not remove the managed install, so delete that Sesori directory manually if you want a full uninstall.

## Install

Choose one supported packaged install path:

### npm bootstrap

```bash
npx @sesori/bridge

# If PATH has not refreshed in this shell yet, open a new terminal
# or run ~/.local/share/sesori/bin/sesori-bridge directly on macOS/Linux.
sesori-bridge
```

Use `npx @sesori/bridge` when you want npm to bootstrap or refresh the managed runtime, then keep running `sesori-bridge` from your PATH. The bootstrap path installs the same managed runtime that the GitHub release assets and shell installers publish, but it does not launch the service for you. On macOS/Linux, a symlink is created at `~/.local/bin/sesori-bridge`. If `~/.local/bin` is already in your PATH, the command is available immediately.

### Shell installer

macOS / Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/sesori-ai/sesori_apps_monorepo/main/install.sh | bash

# If PATH has not refreshed in this shell yet, open a new terminal
# or run ~/.local/share/sesori/bin/sesori-bridge directly.
sesori-bridge --version
```

Windows:

```powershell
irm https://raw.githubusercontent.com/sesori-ai/sesori_apps_monorepo/main/install.ps1 | iex

# If PATH has not refreshed in this shell yet, open a new terminal
# or run the managed binary directly.
sesori-bridge --version
```

Both paths install the same managed runtime under `~/.local/share/sesori/` on macOS/Linux or `%LOCALAPPDATA%\sesori\` on Windows.

## Update

- Managed installs check for updates at startup.
- Managed installs poll again every 4 hours while the bridge keeps running.
- Auto-update is skipped in CI.
- Auto-update is skipped when `SESORI_NO_UPDATE=1` is set.
- If you want to refresh immediately, rerun either the shell installer or `npx @sesori/bridge`.
- The **update track** selects which releases the auto-updater follows. `stable` (the default) follows stable `vX.Y.Z` releases; `internal` additionally follows the `vX.Y.Z-internal.N` pre-releases. Set it with `sesori-bridge config track internal` and restart the bridge to apply. The shell/npm installers always install the latest stable release regardless of track.

Direct execution from npm-owned package payloads inside `node_modules` is unsupported. The supported steady-state command is always the managed `sesori-bridge` launcher.

## Uninstall

Delete the managed install directory to fully remove the packaged bridge runtime:

- macOS / Linux: `rm -rf ~/.local/share/sesori`
- Windows: `Remove-Item -Recurse -Force "$env:LOCALAPPDATA\sesori"`

Also remove the symlink on macOS/Linux:

```bash
rm -f ~/.local/bin/sesori-bridge
```

If you used the npm bootstrap path, `npm uninstall @sesori/bridge` does not remove that managed install directory.

## How It Works

```
Clients <--(E2E encrypted)--> Relay Server <--(E2E encrypted)--> Bridge CLI -> [Plugins] -> AI assistant backends
```

1. The bridge resolves repeated `--plugin` values, otherwise persisted `enabledPlugins`, otherwise the OpenCode fallback.
2. The bridge authenticates with the auth backend (OAuth PKCE).
3. It probes descriptors concurrently, provisions available plugins in configured order under one startup mutex, and starts each plugin as its provisioning settles.
4. The bridge connects to the relay WebSocket with role `"bridge"`.
5. The client connects to the same relay, grouped by user ID.
6. Key exchange: the client sends its X25519 public key; the bridge derives a shared secret via HKDF-SHA256 and sends an encrypted ready message containing the room key.
7. All subsequent traffic is end-to-end encrypted. The relay cannot read any data.
8. Up to 5 clients can connect simultaneously.
9. Client HTTP requests are decrypted by the bridge. Catalog reads use the local database; targeted controls route through the session's stored plugin binding.
10. Responses flow back encrypted through the relay to the client.

## CLI Flags (for `run` command)

These flags apply when running the bridge. The `run` command is the default, so you can use these flags directly without specifying `run`.

Bridge core flags:

| Flag | Default | Description |
|------|---------|-------------|
| `--relay` | `wss://relay.sesori.com` | Relay server URL |
| `--plugin` | `enabledPlugins`, then `opencode` | Plugin backend to run. Repeat in the desired order; CLI selection overrides settings. |
| `--import-plugin` | *(none)* | Start an import for this enabled plugin after startup. Repeatable. |
| `--auth-backend` | `https://api.sesori.com` | Auth backend URL (also reads `AUTH_BACKEND_URL` env var) |
| `--debug-port` | *(disabled)* | Start a debug HTTP server on this port for Postman/curl testing |
| `--log-level` | `info` | Minimum **diagnostic log** level (written to stderr): `verbose`, `debug`, `info`, `warning`, `error` |
| `--version` | — | Print the bridge version and exit |

> `--log-level` controls **diagnostic logging only**. Logs are written to stderr and can be silenced freely. User-facing messages — login prompts, the authorization URL and code, startup status, "Authenticated as…" — are written to stdout and are **always shown regardless of `--log-level`**, so the bridge stays operable even with logging disabled (`--log-level error`, or redirecting stderr with `2>/dev/null`).

Every enabled plugin contributes its namespaced options after selection is
resolved. Run `--help` with the desired repeated `--plugin` values to see their
combined options. The OpenCode plugin adds:

| Flag | Default | Description |
|------|---------|-------------|
| `--opencode-port` | *(auto)* | Port for the OpenCode server. Required with `--opencode-no-auto-start`; otherwise a free port is chosen automatically. |
| `--opencode-host` | `127.0.0.1` | Host the OpenCode server binds to (managed mode) or is reached at (`--opencode-no-auto-start`). Use `0.0.0.0` to expose it on all interfaces, e.g. inside a Docker container. **Warning:** a non-loopback host exposes the server to your network. |
| `--opencode-no-auto-start` | `false` | Skip spawning OpenCode; attach to an existing server on `--opencode-port` |
| `--opencode-password` | *(auto-generated)* | Override the OpenCode server password |
| `--opencode-no-password` | `false` | Disable OpenCode server authentication. Rejected when combined with a non-loopback `--opencode-host` in managed mode (it would expose an unauthenticated server). |
| `--opencode-bin` | `opencode` | Path to the OpenCode binary |

## Commands

In addition to flags, the bridge supports subcommands:

| Command | Description |
|---------|-------------|
| `help` | Show the help message (also available via `--help` or `-h`) |
| `config track [stable\|internal]` | Show or set the update track. With no argument, prints the current track. |
| `config yolo [on\|off]` | Show or set automatic permission approval. With no argument, prints the current mode. |
| `config edit` | Open the bridge configuration file in your default editor |
| `logout` | Clear stored authentication tokens. You will be asked to log in again on next start. |

`config edit` opens `~/.config/sesori/config.json`. A generated config includes:

```json
{
  "sleepPrevention": "always",
  "yolo": false,
  "releaseTrack": "stable"
}
```

Setting `"yolo": true` makes the bridge approve every permission request
without sending the request to connected clients. The bridge prints a warning
at startup whenever this mode is active. Use `sesori-bridge config yolo on` or
`sesori-bridge config yolo off` to change it without editing the file directly.

To persist ordered plugin selection, add `enabledPlugins` to the same file:

```json
{
  "enabledPlugins": ["opencode", "codex"]
}
```

The first entry is the current default plugin. It is not the fallback for old
payloads: missing legacy `pluginId` always means OpenCode. Duplicate, unknown,
or explicitly empty selections are rejected.

## Examples

```bash
# Use a custom relay server
./dist/bridge-macos-arm64 --relay wss://my-relay.example.com

# Use a custom auth backend
./dist/bridge-macos-arm64 --auth-backend https://my-auth.example.com

# Run OpenCode and Codex in order
./dist/bridge-macos-arm64 --plugin opencode --plugin codex

# Run both and import Codex after startup
./dist/bridge-macos-arm64 --plugin opencode --plugin codex --import-plugin codex

# Log out (clear stored tokens)
./dist/bridge-macos-arm64 logout
```

Plugin-specific examples (OpenCode):

```bash
# Connect to an already-running OpenCode server on port 4096
./dist/bridge-macos-arm64 --opencode-no-auto-start --opencode-port 4096

# Expose the managed OpenCode server on all interfaces (e.g. inside Docker)
./dist/bridge-macos-arm64 --opencode-host 0.0.0.0

# Use a custom OpenCode binary path
./dist/bridge-macos-arm64 --opencode-bin /usr/local/bin/opencode
```

## Security

All traffic between phones and the bridge is end-to-end encrypted. The relay server only sees ciphertext.

| Layer | Algorithm |
|-------|-----------|
| Key exchange | X25519 (Diffie-Hellman) |
| Key derivation | HKDF-SHA256 with info `"sesori-relay-v1"` |
| Symmetric encryption | XChaCha20-Poly1305 (24-byte nonce) |

The bridge generates a 32-byte room key on startup. Each phone receives this key via the DH key exchange, and all subsequent messages use it for symmetric encryption. Because the bridge generates a fresh ephemeral key pair per session, forward secrecy holds: compromising a long-term key does not expose past session traffic.

### Password authentication

The bridge generates a 64-character hex password (32 random bytes) and passes it to the backend server via the plugin. All proxied requests include an `Authorization: Basic` header injected by the bridge. The password never leaves the local machine; the exact mechanism is plugin-defined.

## Plugin Process Management

Backend process lifecycle is owned independently by each plugin, not the bridge core:

- On startup, each available plugin starts (or attaches to) its backend server.
- On `Ctrl+C` (SIGINT) or SIGTERM, the bridge disposes and drains all returned plugin APIs, then calls each plugin's idempotent ordered `shutdown()`.
- On Windows, SIGTERM is unavailable; the plugin typically sends SIGKILL directly.
- If a backend process exits unexpectedly, its plugin may attempt a bounded restart. A terminal `Failed` removes only that API from operational routing. The relay, durable catalog, and other plugins continue; transient problems surface as recoverable `Degraded`.
- A 10-second safety timer forces process exit if graceful shutdown stalls.

See the plugin package (e.g. `sesori_plugin_opencode`) for backend-specific details.

## Build

Requires Dart `^3.12.2`. The Makefile uses Dart from the Flutter SDK pinned in
the repository's `.tool-versions`; install that asdf Flutter version first. Run
from `bridge/app/`.

| Command | Description |
|---------|-------------|
| `make build` | Build the host-native CLI bundle |
| `make build-host` | Build the native binary for the current OS and architecture only |

The launcher artifact lands in `dist/` as `bridge-<os>-<arch>`, while required
native libraries remain in `build/cli/bundle/`. `sqlite3` build hooks require
native target compilation, so other release platforms build on matching CI
runners. Example output on Apple Silicon macOS:

| Artifact | How it's produced |
|----------|-------------------|
| `dist/bridge-macos-arm64` | `make build-host` |

## Catalog And Import

The bridge owns a durable project/session/child catalog. Normal project,
root-session, session-detail, and child reads are database-only and remain
available when a plugin is degraded or failed.

Import is a non-destructive observation of one plugin. Use
`POST /plugin/import` with `{"pluginId":"codex"}` to start,
`DELETE /plugin/import` with the same body to request cooperative cancellation,
and `GET /plugin/import` to retrieve the latest ordered per-plugin statuses.
Progress is also emitted as plugin-attributed SSE. Duplicate starts join the
same plugin operation; another plugin imports independently. Enumeration occurs
before an atomic publication transaction, and readers see the last committed
catalog while enumeration or publication is in progress. Missing imported rows
are retained.

## Run

```bash
# From source (requires Dart SDK)
dart run bin/bridge.dart

# Compiled binary
./dist/bridge-macos-arm64
./dist/bridge-linux-x64

# npm bootstrap, then run the managed launcher
npx @sesori/bridge
sesori-bridge
```

## Project Structure

```
bin/bridge.dart       CLI entry point: flag parsing, auth, plugin loading, signal handling
lib/src/
├── api/              Dumb data-access classes (HTTP, DB, shell, plugins)
├── auth/             OAuth PKCE login, token persistence, validation
├── bridge/           Core bridge (plugin-agnostic)
│   ├── relay_client.dart      WebSocket connection to relay, message routing
│   ├── orchestrator.dart      Coordinates relay + plugin lifecycle + key exchange
│   ├── key_exchange.dart      X25519 DH key exchange with phones, room key delivery
│   ├── routing/               Explicit request handler chain (one class per API route); unmatched routes return 404
│   ├── sse/                   SSE stream multiplexing and per-subscriber event buffers
│   └── debug_server.dart      Debug HTTP server for local testing
├── push/             Outgoing push notification subsystem
├── repositories/     Aggregators + mappers over APIs
├── server/           Bridge instance / host services: single-live-bridge enforcement, startup mutex, plugin host abstractions
├── services/         Business logic and coordination
└── updater/          Packaged-install auto-update logic
```

The crypto and protocol types live in `sesori_shared`, shared with the Flutter mobile app. Backend-specific logic lives in plugin packages (e.g. `bridge/sesori_plugin_opencode`).

## Testing

```bash
dart test
```

## License

This package is source-available under the Functional Source License, Version 1.1, Apache 2.0 Future License (`FSL-1.1-ALv2`).

You may use it for permitted purposes, but you may not use it to launch a competing product or service.

On the second anniversary of the date this version is made available, it automatically becomes available under Apache License 2.0.

See the repo root [LICENSE](../../LICENSE) for the full terms.
