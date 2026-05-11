# Sesori Bridge

Dart workspace containing the Sesori Bridge CLI and its plugin system. The bridge connects a local coding-agent backend (OpenCode or Codex) to mobile devices over an encrypted WebSocket relay.

## Architecture

Plugin-based design with four modules:

- **`sesori_plugin_interface`** defines the abstract `BridgePluginApi` contract. All plugins implement the same set of methods.
- **`sesori_plugin_opencode`** implements that contract for the OpenCode backend (HTTP+SSE).
- **`sesori_plugin_codex`** implements that contract for the Codex CLI backend (JSON-RPC over WebSocket).
- **`app`** orchestrates everything: auth (OAuth PKCE), relay connection, encryption, and request routing. It depends only on the plugin interface, not on any specific implementation. A `--backend opencode|codex` CLI flag (default `opencode`) selects which plugin is loaded per bridge process; both plugins ship side-by-side as compiled-in code.

```
Phone <--(E2E encrypted)--> Relay Server <--(E2E encrypted)--> Bridge CLI
                                                                    │
                                                         ┌──── --backend ────┐
                                                         ▼                   ▼
                                                  opencode serve     codex app-server
                                                   (HTTP + SSE)        (WebSocket JSON-RPC)
```

## Modules

| Module | Description |
|--------|-------------|
| `sesori_plugin_interface` | Abstract `BridgePluginApi` contract and shared model types |
| `sesori_plugin_opencode` | OpenCode backend implementation of `BridgePluginApi` |
| `sesori_plugin_codex` | Codex CLI backend implementation of `BridgePluginApi` |
| `app` | CLI entry point: auth, relay, encryption, request routing |

## Backends

The bridge can drive either OpenCode or OpenAI's Codex CLI. Pick at launch with `--backend`:

```bash
sesori-bridge --backend opencode      # default — existing behaviour
sesori-bridge --backend codex
```

### OpenCode (default)

Expects an `opencode` binary on PATH (override with `--opencode-bin`). The bridge spawns `opencode serve --port 4096` and talks to it over HTTP with a session-scoped Basic-auth password.

### Codex

Drives the [OpenAI Codex CLI](https://github.com/openai/codex) (tested against `codex-cli 0.121.0`) via its **`codex app-server`** mode — the same JSON-RPC protocol used by the official VSCode extension and the TUI's `--remote` flag. The bridge spawns:

```
codex app-server --listen ws://127.0.0.1:<port>
```

and connects over WebSocket. The `app-server` subcommand is marked `[experimental]` in codex's `--help`, so the codex plugin pins a supported version and the bridge release process should bump that pin deliberately (see "Binary resolution" below).

**Read path** is backed by codex's on-disk history (`~/.codex/session_index.jsonl` + `~/.codex/sessions/**/*.jsonl` rollouts) so `getSessions`/`getSessionMessages` work for the full history. **Write path** is live over the WS protocol: `thread/start`, `turn/start`, `turn/interrupt`, `thread/name/set`. **Approvals** (`execCommandApproval`, `applyPatchApproval`, etc.) round-trip through the bridge's permission events.

**Project model**: codex sessions only carry a CWD, not a project. The plugin synthesises a single `PluginProject` from the bridge's launch CWD and filters sessions to those whose `cwd` matches.

**Configuration flags**:

| Flag | Default | Purpose |
|------|---------|---------|
| `--backend codex` | — | Select the codex plugin |
| `--codex-bin <path>` | `codex` | Override the binary (skipped if the literal `codex` is on PATH) |
| `--codex-port <port>` | `0` | Codex listen port (`0` = ephemeral, discovered from codex's stdout) |

**Binary resolution** (`bridge/app/lib/src/server/codex_binary_resolver.dart`):
1. `--codex-bin` if it points to an existing file → use it verbatim.
2. Cached binary at `~/.local/share/sesori/codex/<pinned-version>/codex` → use it.
3. Auto-download from GitHub Releases **when** `codexSha256Manifest` carries a non-empty hash for the current platform.
4. Fall back to `codex` on PATH.

The SHA-256 manifest in `codex_binary_resolver.dart` ships **with empty hashes**. Release engineers must fill them in from a published codex release before tagging a bridge build that enables auto-download:

```dart
const Map<String, String> codexSha256Manifest = {
  "darwin-arm64": "<sha256 of codex-aarch64-apple-darwin.tar.gz>",
  // ...
};
```

Empty hashes are a safety default — the resolver refuses to download an unverified binary and falls back to PATH lookup, surfacing a clear log line.

**Known limits** in codex 0.121.0 surfaced as no-ops or empty results:
- `getProviders` / `getAgents` return empty (codex doesn't expose multi-provider/multi-agent enumeration).
- `getChildSessions` returns empty (`forked_from` isn't in the rollout header today).
- `renameProject` is a no-op (single synthetic project per launch CWD).
- `--no-auto-start` is rejected for the codex backend (no external app-server flow yet).

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
2. Add it to `bridge/pubspec.yaml`'s `workspace:` list and `bridge/Makefile`'s `MODULES`.
3. Add `sesori_plugin_interface` as a dependency.
4. Implement the `BridgePluginApi` abstract class.
5. Register a factory in `bridge/app/bin/bridge.dart` and add a new arm to `BridgeBackend` + the `--backend` allowed-values list.
6. Branch `resolveServer` in `bridge/app/lib/src/bridge/runtime/bridge_runtime_server.dart` to spawn your backend's process and return its URL/auth as `BridgeServerRuntime`.
