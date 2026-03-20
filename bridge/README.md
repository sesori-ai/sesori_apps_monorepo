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
