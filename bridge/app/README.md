# Sesori Bridge CLI

Native CLI tool written in Dart, compiled to a platform binary, that bridges a local OpenCode server to mobile devices over the internet via an encrypted WebSocket relay.

It authenticates with OAuth PKCE, spawns `opencode serve`, connects to the relay, performs an X25519 key exchange with each connecting phone, and routes encrypted requests and responses between them. All traffic is end-to-end encrypted; the relay server only ever sees ciphertext.

## Quick Start

```bash
# Build a native binary
make build

# Run (example for Apple Silicon macOS)
./dist/bridge-macos-arm64
```

Press `Ctrl+C` to stop. This shuts down both the bridge and the OpenCode server it started.

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
Phone <--(E2E encrypted)--> Relay Server <--(E2E encrypted)--> Bridge CLI -> [OpenCode Plugin] -> opencode serve
```

1. Bridge starts `opencode serve` on `127.0.0.1:4096` with a generated password.
2. Bridge authenticates with the auth backend (OAuth PKCE).
3. Bridge connects to the relay WebSocket with role `"bridge"`.
4. Phone connects to the same relay, grouped by user ID.
5. Key exchange: phone sends its X25519 public key; bridge derives a shared secret via HKDF-SHA256 and sends an encrypted ready message containing the room key.
6. All subsequent traffic is end-to-end encrypted. The relay cannot read any data.
7. Up to 5 phones can connect simultaneously.
8. Phone HTTP requests are decrypted by the bridge and forwarded to the local OpenCode server.
9. Responses flow back encrypted through the relay to the phone.

## CLI Flags

| Flag | Default | Description |
|------|---------|-------------|
| `--relay` | `wss://relay.sesori.com` | Relay server URL |
| `--port` | `4096` | Port for the OpenCode server (applies to both auto-start and `--no-auto-start`) |
| `--password` | *(auto-generated)* | Override the server password |
| `--opencode-bin` | `opencode` | Path to the OpenCode binary |
| `--no-auto-start` | `false` | Skip spawning OpenCode; connect to an existing server on localhost instead |
| `--auth-backend` | `https://api.sesori.com` | Auth backend URL (also reads `AUTH_BACKEND_URL` env var) |
| `--login` | `false` | Force re-login and clear stored tokens |
| `--debug-port` | *(disabled)* | Start a debug HTTP server on this port for Postman/curl testing |
| `--log-level` | `info` | Minimum log level: `verbose`, `debug`, `info`, `warning`, `error` |

## Examples

```bash
# Use a custom relay server
./dist/bridge-macos-arm64 --relay wss://my-relay.example.com

# Connect to an already-running OpenCode server on port 4096
./dist/bridge-macos-arm64 --no-auto-start --port 4096

# Connect to an already-running OpenCode server on a custom port
./dist/bridge-macos-arm64 --no-auto-start --port 8080

# Use a custom OpenCode binary path
./dist/bridge-macos-arm64 --opencode-bin /usr/local/bin/opencode

# Force re-login (clears stored tokens)
./dist/bridge-macos-arm64 --login

# Use a custom auth backend
./dist/bridge-macos-arm64 --auth-backend https://my-auth.example.com --login
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

The bridge generates a 64-character hex password (32 random bytes) and passes it to `opencode serve` via the `OPENCODE_SERVER_PASSWORD` environment variable. All proxied requests include an `Authorization: Basic` header injected by the bridge. The password never leaves the local machine.

## Process Management

The bridge manages the OpenCode server process lifecycle:

- On startup, it spawns `opencode serve` and polls the health endpoint until it responds.
- On `Ctrl+C` (SIGINT) or SIGTERM, it sends SIGTERM to the child process and waits for a clean exit.
- On Windows, SIGTERM is unavailable; the bridge sends SIGKILL directly.
- If the child process exits unexpectedly, the bridge shuts down as well.
- A 10-second safety timer forces process exit if graceful shutdown stalls.

## Build

Requires Dart 3.11+. Run from `bridge/app/`.

| Command | Description |
|---------|-------------|
| `make build` | Build all targets: host-native binary plus Linux cross-compiled binaries |
| `make build-host` | Build the native binary for the current OS and architecture only |
| `make build-linux` | Cross-compile Linux binaries for arm, arm64, riscv64, and x64 |

Artifacts land in `dist/` named `bridge-<os>-<arch>`. Example outputs on Apple Silicon macOS:

| Artifact | How it's produced |
|----------|-------------------|
| `dist/bridge-macos-arm64` | `make build-host` |
| `dist/bridge-linux-arm` | `make build` |
| `dist/bridge-linux-arm64` | `make build` |
| `dist/bridge-linux-riscv64` | `make build` |
| `dist/bridge-linux-x64` | `make build` |

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
lib/src/auth/         OAuth PKCE login, token persistence, validation
lib/src/bridge/       Core bridge (plugin-agnostic): relay client, orchestrator, SSE delivery, debug server
lib/src/server/       OpenCode process management: start, stop, health polling
```

The crypto and protocol types live in `sesori_shared`, shared with the Flutter mobile app.

## Testing

```bash
dart test
```

## License

This package is source-available under the Functional Source License, Version 1.1, Apache 2.0 Future License (`FSL-1.1-ALv2`).

You may use it for permitted purposes, but you may not use it to launch a competing product or service.

On the second anniversary of the date this version is made available, it automatically becomes available under Apache License 2.0.

See the repo root [LICENSE](../../LICENSE) for the full terms.
