# AGENTS.md — Sesori Apps Monorepo

## System Overview

Sesori connects AI coding assistants (like OpenCode) to mobile devices over an encrypted relay. The developer runs a **bridge CLI** on their laptop alongside the AI assistant. The bridge talks to the assistant over localhost HTTP/SSE, encrypts everything, and forwards it through a **relay server** to the **mobile app**. The relay is a dumb pipe — it routes binary frames and connection metadata (auth tokens, public keys) but cannot read application data.

Phone ↔ bridge traffic is end-to-end encrypted (X25519 key exchange + XChaCha20-Poly1305). The phone can browse projects, read sessions, respond to AI questions, and receive real-time events.

## Data Flow (condensed)

Understand these three hops when working on any module:

1. **Bridge ↔ AI Assistant (localhost HTTP + SSE)** — The bridge fetches projects/sessions via REST and subscribes to an SSE stream for real-time events. A random 256-bit password protects the local connection.

2. **Bridge ↔ Relay (WebSocket)** — Authenticated with an OAuth token. All application data is encrypted before sending — the relay only sees binary frames.

3. **Phone ↔ Bridge (E2E through relay)** — On connect, phone and bridge perform X25519 DH to derive a shared secret, then exchange a room key. All subsequent messages (HTTP requests/responses, SSE events) are encrypted with XChaCha20-Poly1305 using that room key.

**Request path:** Phone sends encrypted HTTP request → relay forwards binary frame → bridge decrypts → routes to handler → handler calls AI assistant API → encrypts response → relay forwards back → phone decrypts.

**Event path:** AI assistant emits SSE event → bridge plugin receives → orchestrator maps to shared protocol type → SSE manager encrypts per-phone → relay forwards → phone decrypts and displays.

## Key Architectural Patterns

- **Bridge plugin system:** `BridgePlugin` abstract class in `sesori_plugin_interface` defines the backend contract (projects, sessions, messages, events, health). `sesori_plugin_opencode` implements it for OpenCode. New backends implement this interface.
- **Relay protocol:** `RelayMessage` sealed class in `sesori_shared` defines all message types (auth, key_exchange, ready, request, response, sse_event, etc.). Binary wire format: `[version_byte][nonce (24B)][ciphertext + auth tag]`.
- **Request routing (bridge):** Intercept-first handler chain. `RequestRouter` tries each registered handler in order; first match wins. `ProxyHandler` is the catch-all fallback.
- **SSE pipeline (bridge):** `SseConnection` → `SseEventParser` → plugin event stream → `Orchestrator` → `SSEManager` → per-phone encrypted delivery with event buffering.
- **Mobile state management:** BLoC/Cubit pattern. Cubits live in `module_core` (pure Dart, testable). UI widgets in `app/` consume cubit state.
- **Mobile DI:** 3-phase injection: platform adapters → auth → core services.
- **Mobile relay client:** `RelayClient` handles WebSocket lifecycle, key exchange, encryption/decryption. `RelayHttpApiClient` wraps it to expose a familiar HTTP interface. `ConnectionService` manages reconnect with exponential backoff + jitter.

## Monorepo Layout

- `bridge/` — pure Dart CLI workspace (relay server + plugin system)
- `mobile/` — Flutter workspace (mobile client)
- `shared/sesori_shared/` — pure Dart, shared crypto and protocol types

Two independent Dart workspaces. `shared/sesori_shared` is consumed via path dependency by both.

## Workspace Commands

Run `dart pub get` from the workspace root, not from individual module dirs:

```sh
cd bridge && dart pub get
cd mobile && dart pub get
```

Bridge workspace also exposes:

```sh
cd bridge
make codegen   # runs build_runner across all bridge modules
make test      # runs dart test across all bridge modules
make analyze   # runs dart analyze across all bridge modules
```

## Generated Files

Never edit `*.freezed.dart`, `*.g.dart`, or `*.config.dart` by hand.

After modifying a `@freezed` class, regenerate from the module dir:

```sh
dart run build_runner build --delete-conflicting-outputs
```

## Git

Conventional commits: `fix:`, `feat:`, `ci:`, `docs:`, `chore:`.

Branch naming: `type/short-description` (e.g. `feat/relay-reconnect`).

## Testing

| Location | Command |
|---|---|
| bridge modules | `dart test` |
| mobile/app | `flutter test` |
| mobile pure Dart modules | `dart test` |

## Analysis

Strict analysis is enabled across all packages. Don't add `// ignore:` comments without a written justification in the same line.

## Forbidden

- Don't modify `shared/sesori_shared` without considering impact on both bridge and mobile consumers.
- Don't create a root-level `pubspec.yaml`. There is no root workspace.
