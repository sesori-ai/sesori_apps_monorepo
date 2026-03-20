# Sesori Bridge (for OpenCode)

CLI tool written in Dart, compiled to a native binary, that runs on your laptop to bridge a local [OpenCode](https://github.com/anomalyco/opencode) server to your phone over the internet via an encrypted relay.

It authenticates with OAuth PKCE, connects to the relay, and routes encrypted traffic between phones and the local server. Uses a plugin-based architecture to support multiple backends.

## Quick start

```bash
# Build
make build

# Run the host binary (example for Apple Silicon macOS)
./dist/bridge-macos-arm64
```

Press `Ctrl+C` to stop — this shuts down both the bridge and the opencode server it started.

Alternatively, use the npm distribution (no Dart SDK required):

```bash
npx @sesori/bridge
```

## How it works

```
Phone <--(E2E encrypted)--> Relay Server <--(E2E encrypted)--> Bridge CLI -> [OpenCode Plugin] -> opencode serve
```

1. Bridge starts `opencode serve` on `127.0.0.1:4096` with a generated password
2. Bridge authenticates with the auth backend (OAuth PKCE)
3. Bridge connects to the relay WebSocket, sends auth with role `"bridge"`
4. Phone connects to the same relay, grouped by userId
5. Key exchange: phone sends X25519 public key, bridge derives shared secret, sends encrypted ready message containing room key
6. All subsequent traffic is end-to-end encrypted — the relay cannot read any data
7. Multiple phones can connect simultaneously (up to 5)
8. Phone's HTTP requests are decrypted by the bridge and forwarded to the local opencode server
9. Responses flow back encrypted through the relay to the phone

## CLI flags

| Flag | Default | Description |
|------|---------|-------------|
| `--relay` | `wss://relay.sesori.com` | Relay server URL |
| `--port` | `4096` | Port for the localhost server (auto-start and `--no-auto-start`) |
| `--password` | *(auto-generated)* | Override the server password |
| `--opencode-bin` | `opencode` | Path to the opencode binary |
| `--no-auto-start` | `false` | Don't start opencode server (connect to existing on localhost) |
| `--auth-backend` | `https://api.sesori.com` | Auth backend URL |
| `--login` | `false` | Force re-login and clear stored tokens |
| `--debug-port` | *(disabled)* | Start a debug HTTP server on this port (for Postman/curl testing) |

## Examples

```bash
# Replace with your host artifact name as needed, e.g. `bridge-linux-x64`.
# Use a custom relay server
./dist/bridge-macos-arm64 --relay wss://my-relay.example.com

# Connect to an already-running opencode server on port 4096
./dist/bridge-macos-arm64 --no-auto-start --port 4096

# Connect to an already-running opencode server on a custom port
./dist/bridge-macos-arm64 --no-auto-start --port 8080

# Use a custom opencode binary path
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

The bridge generates a 32-byte room key on startup. This key is delivered to each phone via DH key exchange and used for all subsequent message encryption.

### Password authentication

The bridge generates a 64-character hex password (32 random bytes) and passes it to `opencode serve` via the `OPENCODE_SERVER_PASSWORD` environment variable. The bridge injects `Authorization: Basic` headers into all proxied requests. The password never leaves the local machine.

## Process management

The bridge manages the opencode server process lifecycle:

- On startup, it spawns `opencode serve` and waits for the health endpoint to respond
- On `Ctrl+C` (SIGINT) or SIGTERM, it sends SIGTERM to the child process and waits for clean exit
- On Windows, SIGTERM is not available — the bridge sends SIGKILL directly
- If the child process exits unexpectedly, the bridge shuts down as well

## Project structure

```
bin/bridge.dart              CLI entry point — flag parsing, auth, plugin loading
lib/src/bridge/              Core bridge (plugin-agnostic): routing, SSE delivery, relay, orchestrator
lib/src/auth/                OAuth PKCE login, token persistence, validation
lib/src/server/              Process management (start/stop/health)
modules/
├── sesori_plugin_interface/ Plugin contract (BridgePlugin interface)
└── opencode_plugin/         OpenCode backend implementation + models + tests
```

The crypto and protocol types live in the `sesori_shared` package, shared with the Flutter mobile app.

## Architecture

The bridge uses a plugin-based architecture. All backend-specific code lives in plugin packages under `modules/`:

- **`sesori_plugin_interface`** — defines the `BridgePlugin` contract that all plugins implement
- **`opencode_plugin`** — implements `BridgePlugin` for the OpenCode backend

The bridge core (`lib/src/bridge/`) is backend-agnostic — it only depends on the plugin interface. This enables future support for alternative backends (Codex, Claude Code, etc.) and eventual user-defined dynamic plugins.

## Building from source

Requires Dart 3.11+.

```bash
make build
```

This produces:

- one host-native binary named `dist/bridge-<os>-<arch>`
- Linux cross-compiled binaries in `dist/bridge-linux-<arch>` for the architectures supported by Dart

## Build outputs

`make build` creates the host-native binary plus the supported Linux cross-compiled binaries.

Examples on an Apple Silicon Mac:

| Artifact | How it's produced |
|--------|---------|
| `dist/bridge-macos-arm64` | native host build |
| `dist/bridge-linux-arm` | `make build` |
| `dist/bridge-linux-arm64` | `make build` |
| `dist/bridge-linux-riscv64` | `make build` |
| `dist/bridge-linux-x64` | `make build` |

`dart compile exe` outputs are architecture-specific. This project's `Makefile` names artifacts with both OS and arch to avoid ambiguity.

## Related

- [Sesori Mobile App](https://github.com/sesori-ai/sesori_mobile) — Flutter mobile client
- [Sesori Relay](https://github.com/sesori-ai/sesori_relay_server) — WebSocket relay server
- [Sesori Auth Server](https://github.com/sesori-ai/sesori_relay_server) — the remote auth server
- [sesori_shared](../sesori_shared) — Shared crypto and protocol package
- [OpenCode (not affiliated with Sesori)](https://github.com/anomalyco/opencode) — the AI coding assistant server
