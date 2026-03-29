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

Never edit `*.freezed.dart`, `*.g.dart`, `*.config.dart`, or `*.steps.dart` by hand.

After modifying a `@freezed` class, regenerate from the module dir:

```sh
dart run build_runner build --delete-conflicting-outputs
```

## Database Migrations (Bridge)

The bridge uses Drift (SQLite) for local persistence. Schema changes require a strict migration workflow.

### Migration Workflow

1. **Before modifying tables**: Run `dart run drift_dev make-migrations` from `bridge/app/` to export the current schema version.
2. **Make schema changes**: Modify table definitions in `bridge/app/lib/src/bridge/persistence/tables/`, add new tables, register in `database.dart`.
3. **Bump `schemaVersion`**: Increment the version number in `database.dart`.
4. **Generate migration code**: Run `dart run drift_dev make-migrations` again. This generates:
   - Schema export in `bridge/app/drift_schemas/`
   - Step-by-step migration helper in `database.steps.dart`
   - Test scaffolding in `bridge/app/test/drift/`
5. **Write migration logic**: Implement the `fromNToN+1` callback in `database.steps.dart`.
6. **Run `make codegen`**: Regenerate Drift + Freezed files from `bridge/`.
7. **Write migration tests**: Every schema migration MUST have tests using `SchemaVerifier`:
   - Structural test: `verifier.migrateAndValidate(db, targetVersion)`
   - Data integrity test: insert data at old version, migrate, verify data at new version
8. **Verify**: `make test && make analyze` from `bridge/`.

### Important Rules

- Never edit `*.steps.dart` beyond the migration callback bodies.
- Never edit `drift_schemas/*.json` files — these are generated snapshots.
- Every schema migration MUST have corresponding migration tests. No exceptions.
- The `databases:` key in `bridge/app/build.yaml` must point to the database class.

## Git

Conventional commits: `fix:`, `feat:`, `ci:`, `docs:`, `chore:`.

Branch naming: `type/short-description` (e.g. `feat/relay-reconnect`).

Worktrees: Always create new worktrees inside the `.worktrees/` directory at the repo root (e.g. `.worktrees/feat-relay-reconnect`). Unless explicitly told otherwise, the worktree should start from the `main` branch.

## Testing

| Location | Command |
|---|---|
| bridge modules | `dart test` |
| mobile/app | `flutter test` |
| mobile pure Dart modules | `dart test` |

## Dart Coding Conventions

- Always use **named arguments with the `required` keyword**, including for nullable parameters. Never use positional arguments.

```dart
// CORRECT
int computeNotificationId({required String sessionId, required NotificationCategory category}) { ... }
void show({required String title, required String? sessionId}) { ... }
MyClass({required FlutterLocalNotificationsPlugin plugin}) : _plugin = plugin;

// WRONG — positional arguments
int computeNotificationId(String sessionId, NotificationCategory category) { ... }
MyClass([FlutterLocalNotificationsPlugin? plugin]) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();
```

## Analysis

Strict analysis is enabled across all packages. Don't add `// ignore:` comments without a written justification in the same line.

## Forbidden

- Don't modify `shared/sesori_shared` without considering impact on both bridge and mobile consumers.
- Don't create a root-level `pubspec.yaml`. There is no root workspace.
