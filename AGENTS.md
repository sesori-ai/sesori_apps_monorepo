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

## Mandatory Internal Layer Architecture

All packages in this monorepo follow a strict layered architecture. **Much of the existing code was written before these rules and does NOT follow them.** This is expected — legacy code will be migrated over time. However, **all new code must fully comply with the layering described below. It is not acceptable to follow old patterns just because existing code does.**

The full specification — including all cross-dependency rules, acceptable patterns, and cohesion checks — lives in `.opencode/agents/aristotle-plan-review.md` (plan review) and `.opencode/agents/aristotle-impl-review.md` (code review). Use those as the source of truth when in doubt.

### Layer Definitions

Each layer has a specific responsibility and a dedicated directory. Dependencies flow upward only — a lower layer must NEVER know about a higher layer. NO layer skipping.

| Layer | Responsibility | Directory |
|-------|---------------|-----------|
| **Layer 0 — Foundation** | Transport primitives and base abstractions. HOW we communicate, not WHAT. No business logic, no decisions. | `foundation/` |
| **Layer 1 — API** | Dumb data-access classes that execute operations (HTTP calls, DB queries, shell commands). Parse responses into models. No decision-making logic. | `api/` |
| **Layer 2 — Repository** | Aggregates data from one or more Layer 1 sources. Maps API/DB DTOs to internal models. **MANDATORY** even when only one data source exists — it just delegates. All mapping logic lives here and nowhere else. | `repositories/` |
| **Layer 3 — Service** | Business logic and coordination. Decision-making lives here. MUST use Repositories, NEVER call APIs directly. | `services/` |
| **Layer 4+ — Consumer** | Consumes services/repositories. Cubits (mobile), request handlers (bridge), orchestrators. | `cubits/`, `routing/`, `sse/` |

**Core rules:**
- A Service MUST NOT call an API directly — it goes through a Repository
- A Consumer (cubit, handler) MUST NOT import from `api/` — it goes through repositories/services
- Within a layer: NO cross-dependency between same-level classes (unless base classes/abstractions designed for reuse within that layer)
- Helper, use-case, and supporting classes around a Service MUST NOT depend back on that owning Service. If you split service logic into a collaborator, make it a standalone dependency with its own injected inputs, not a `part` file, extension, or pseudo-helper that calls back into the service.
- Do NOT extract non-trivial business logic into top-level/global functions just to satisfy file-size limits. If the extracted logic is more than a tiny pure helper, split it into a named collaborator class with explicit dependencies and a clear ownership boundary so it can be tested in isolation.
- Directory structure MUST mirror layers — when you see `import '../api/...'` in a `services/` file, that is a violation

### Naming Conventions

Pick a class suffix that accurately reflects the class's role. Vague names (`Manager`, `Helper`, `Utils`, `Wrapper`) invite kitchen-sink growth and are forbidden. If a class's role doesn't match any suffix below, the class's responsibilities probably need rethinking, not a vague label.

**Orchestration & business logic:**
- **`Service`** — orchestrates two or more collaborators, coordinates a non-trivial state machine, or uses a Repository. This is the Layer 3 default.
- **`Dispatcher`** — single choke point through which a class of requests flows; owns the pipeline for those requests.
- **`Orchestrator`** — top-level composer that wires multiple layers or subsystems.

**Data access:**
- **`Api`** / **`Dao`** — Layer 1 data access.
- **`Client`** — transport-level; HTTP/WebSocket to an external system.
- **`Repository`** — Layer 2 aggregator + mapper.

**Reactive / event wiring:**
- **`Listener`** — subscribes to a stream/event source and delegates downstream; owns its subscription lifecycle.
- **`Notifier`** — detects a condition and emits events.
- **`Tracker`** — maintains state derived from events; exposes stream or snapshot access.

**Pure transformations (no decisions, no orchestration):**
- **`Builder`** — constructs an output artifact from inputs.
- **`Formatter`** — converts data to presentation form.
- **`Mapper`** — translates between data models.
- **`Parser`** — deserializes raw input into typed data.
- **`Validator`** — checks input against rules.
- **`Calculator`** — computes derived values.

**State management:**
- **`Cubit`** — mobile only, Layer 4.

**Forbidden suffixes:** `Manager`, `Helper`, `Utils`, `Wrapper`, `Handler` (except for routing handlers in the bridge `routing/` layer).

### Class Cohesion Rules

These four rules catch the common structural failures that layer rules alone miss. Apply them at author time, not just at review time.

- **No pass-through parameters.** If a constructor parameter is used only to construct another object inside the class — never stored on `this`, never read by any method, never part of the class's own logic — it's a pass-through. Inject the already-constructed subcomponent instead, or move its configuration inside the class as defaults.

- **No peer-as-child dependency overlap.** If class X constructs class Y internally and Y's constructor takes 2+ dependencies that X also takes, Y is a peer being miscast as a subcomponent. Extract Y to the same composition level as X; wire both from the subsystem entrypoint.

- **Symmetric handling of equivalent triggers.** When multiple triggers (streams, timers, external calls) feed the same downstream pipeline, handle them symmetrically. One trigger as a method and another as a separate class is a violation. Extract a Dispatcher that owns the pipeline; each trigger becomes a Listener (or method, but consistent across all triggers).

- **Service suffix discipline.** A class ending in `Service` must orchestrate 2+ collaborators, coordinate a non-trivial state machine, OR depend on a Repository. If it only transforms/builds/formats/validates/parses, it needs a role-specific suffix from the list above. `NotificationContentService` that just builds payloads is wrong; `NotificationContentBuilder` is right.

### Bridge workspace (`bridge/`)

**`bridge/app` — target directory structure:**
```
app/lib/src/
├── foundation/              # Layer 0
│   ├── relay_client.dart    #   WebSocket transport (connect, send, receive, E2E encrypt/decrypt)
│   ├── key_exchange.dart    #   X25519 DH key exchange primitives
│   └── ...                  #   ProcessRunner, BridgeConfig, base abstractions
│
├── api/                     # Layer 1
│   ├── database/            #   Drift SQLite (transport abstracted by Drift)
│   │   ├── database.dart    #     AppDatabase
│   │   ├── tables/          #     ProjectsTable, SessionTable
│   │   └── daos/            #     ProjectsDao, SessionDao
│   ├── gh_cli_api.dart      #   git operations via shell (create worktree, query branches, compute diffs)
│   └── sesori_server_api.dart  # auth server HTTP (generate session metadata, etc.)
│
├── repositories/            # Layer 2
│   ├── project_repository.dart   # combines BridgePlugin.getProjects() + ProjectsDao
│   ├── session_repository.dart   # combines BridgePlugin.getSessions() + SessionDao
│   ├── worktree_repository.dart  # wraps GhCliApi + SessionDao
│   └── mappers/                  # ALL mappers live here (PluginProject → Project, etc.)
│
├── services/                # Layer 3
│   ├── metadata_service.dart     # session metadata generation logic
│   └── worktree_service.dart     # worktree lifecycle decisions
│
├── routing/                 # Layer 4 — request handling
│   ├── request_router.dart       # ordered handler chain (first match wins)
│   ├── request_handler.dart      # base handler classes (Get/Body variants)
│   └── handlers/                 # ~30 concrete handlers
│
├── sse/                     # Layer 4 — event delivery
│   ├── sse_service.dart          # subscriber queues, orphan replay
│   └── bridge_event_mapper.dart  # BridgeSseEvent → SesoriSseEvent
│
├── orchestrator.dart        # Layer 5 — composes everything (ONLY class that wires layers)
│
├── auth/                    # Subsystem (self-contained, no deps on core layers)
│   ├── token_service.dart        # token lifecycle (implements TokenRefresher)
│   └── login_service.dart        # login flow orchestration
│
├── push/                    # Subsystem (self-contained, no deps on core layers)
│   ├── push_dispatcher.dart           # single choke point for outgoing pushes
│   ├── completion_push_listener.dart  # reactive trigger → dispatcher
│   ├── maintenance_push_listener.dart # scheduled trigger → dispatcher
│   ├── push_notification_client.dart  # HTTP to FCM/APNs
│   ├── push_notification_content_builder.dart  # builds payloads
│   ├── push_rate_limiter.dart
│   ├── push_session_state_tracker.dart
│   └── completion_notifier.dart
│
└── server/                  # Subsystem (minimal — process lifecycle)
```

- BridgePlugin is semantically a Layer 1 data source (it exposes a public API for projects/sessions/messages)
- Routing handlers use Repositories/Services — they MUST NOT call APIs (Layer 1) directly
- For bridge session lifecycle flows, routing handlers MUST NOT depend on `BridgePlugin` directly. Treat `BridgePlugin` as Layer 1/API. Thin plugin-backed session commands and lookups belong in `SessionRepository`; multi-step session orchestration (create, archive, unarchive) belongs in services.
- All mappers belong in `repositories/mappers/`, NOT in `routing/`
- `auth/`, `push/`, `server/` are self-contained subsystems outside the layer hierarchy
- **New push triggers** (another stream, another timer) MUST be added as a new Listener class delegating to the existing `PushDispatcher`. Do not grow a single class to own multiple triggers.

**`sesori_plugin_opencode` — internal layers:**
```
lib/src/
├── models/                  # Layer 0 — OpenCode-specific Freezed data classes
├── opencode_api.dart        # Layer 1 — HTTP client for OpenCode REST endpoints
├── opencode_repository.dart # Layer 2 — merges API data, maps to plugin interface models
├── active_session_tracker.dart  # Layer 2 — tracks session state from SSE
├── opencode_service.dart    # Layer 3 — coordinates Repository + Tracker
├── opencode_plugin_impl.dart    # Layer 4 — BridgePlugin implementation (top-level composition)
└── sse/                     # SSE pipeline components (SseConnection, SseEventParser, SseEventMapper)
```

### Mobile workspace (`mobile/`)

**Module dependency direction (never reverse, never skip):**
```
app → module_core → module_auth → sesori_shared
```
`app` has `module_auth` in pubspec only for DI wiring — it MUST NOT import `module_auth` types in source code.

**`module_core` — target directory structure:**
```
module_core/lib/src/
├── foundation/              # Layer 0
│   ├── platform/            #   abstract interfaces: UrlLauncher, DeepLinkSource, LifecycleSource, etc.
│   ├── transport/           #   relay stack: RelayClient → ConnectionService → RelayHttpApiClient
│   ├── logging/             #   logd/logw/loge
│   ├── concurrency/         #   isolate pool, message queue
│   └── extensions/          #   Dart utility extensions
│
├── api/                     # Layer 1
│   ├── session_api.dart     #   session CRUD endpoints (→ RelayHttpApiClient)
│   ├── project_api.dart     #   project CRUD endpoints (→ RelayHttpApiClient)
│   ├── voice_api.dart       #   audio upload (→ AuthenticatedHttpApiClient)
│   └── notification_api.dart    # FCM token registration (→ AuthenticatedHttpApiClient)
│
├── repositories/            # Layer 2
│   ├── session_repository.dart
│   ├── project_repository.dart
│   └── ...
│
├── services/                # Layer 3
│   └── sse_event_service.dart   # processes real-time events from ConnectionService streams
│
├── cubits/                  # Layer 4 — state management (one cubit per feature)
│   ├── login/
│   ├── project_list/
│   ├── session_list/
│   ├── session_detail/
│   └── ...
│
└── routing/                 # Layer 4 — navigation
    ├── app_routes.dart          # AppRoute enum
    └── auth_redirect_service.dart
```

- APIs talking to bridge use `RelayHttpApiClient`; APIs talking to auth server use `AuthenticatedHttpApiClient`
- Cubits may depend on services (Layer 3), repositories (Layer 2 for simple CRUD), and ConnectionService streams (Layer 0, push-based only)
- Cubits MUST NOT import from `api/` or depend on other cubits
- No cross-dependency between repositories, between services, or between cubits

**`app` (Flutter shell) — target directory structure:**
```
app/lib/
├── core/platform/           # Layer 0 — concrete Flutter implementations of module_core interfaces
│   ├── flutter_secure_storage_adapter.dart   # implements SecureStorage
│   ├── flutter_url_launcher.dart             # implements UrlLauncher
│   ├── app_lifecycle_observer.dart           # implements LifecycleSource
│   └── ...
├── core/di/                 # Infrastructure — DI wiring (3-phase: platform → auth → core)
├── core/routing/            # Infrastructure — GoRouter config
├── core/widgets/            # Shared UI — ConnectionOverlay, bottom sheets, etc.
└── features/                # Screens — one dir per feature, BlocProvider creates cubits, getIt resolves services
    ├── login/
    ├── project_list/
    ├── session_list/
    └── ...
```

- Features NEVER instantiate services or call APIs directly — only through cubits
- `module_core` MUST NOT import `package:flutter`
- `module_auth` MUST NOT import `module_core`

**`module_auth` — internal structure:**
```
module_auth/lib/src/
├── interfaces/              # exported API: AuthTokenProvider, OAuthFlowProvider, AuthSession
├── models/                  # AuthState sealed class
├── platform/                # SecureStorage abstract interface
├── storage/                 # Layer 1 — TokenStorageService, OAuthStorageService (→ SecureStorage)
├── client/                  # Layer 1 — HttpApiClient (base), AuthenticatedHttpApiClient (decorator)
├── auth_manager.dart        # Layer 2 — single owner of auth lifecycle (implements all 3 interfaces)
└── di/                      # DI registration
```

- AuthService (currently named AuthManager) is the SINGLE writer of tokens
- Only the 3 interfaces + AuthenticatedHttpApiClient are exported; everything else is internal

## Key Architectural Patterns

- **Bridge plugin system:** `BridgePlugin` abstract class in `sesori_plugin_interface` defines the backend contract (projects, sessions, messages, events, health). `sesori_plugin_opencode` implements it for OpenCode. New backends implement this interface.
- **Relay protocol:** `RelayMessage` sealed class in `sesori_shared` defines all message types (auth, key_exchange, ready, request, response, sse_event, etc.). Binary wire format: `[version_byte][nonce (24B)][ciphertext + auth tag]`.
- **Request routing (bridge):** Intercept-first handler chain. `RequestRouter` tries each registered handler in order; first match wins. `ProxyHandler` is the catch-all fallback.
- **SSE pipeline (bridge):** `SseConnection` → `SseEventParser` → plugin event stream → `Orchestrator` → `SSEManager` → per-phone encrypted delivery with event buffering.
- **Mobile state management:** BLoC/Cubit pattern. Cubits live in `module_core` (pure Dart, testable). UI widgets in `app/` consume cubit state.
- **Mobile DI:** 3-phase injection: platform adapters → auth → core services.
- **Mobile relay client:** `RelayClient` handles WebSocket lifecycle, key exchange, encryption/decryption. `RelayHttpApiClient` wraps it to expose a familiar HTTP interface. `ConnectionService` manages reconnect with exponential backoff + jitter.

## Reactive vs. Polling

Data flows downstream via streams and events — this is push-based. Polling is a violation unless the data source genuinely can't expose a stream.

- **Polling** (flag): `Timer.periodic`, `Stream.periodic`, manual re-fetch loops, or repeatedly-triggered invalidation to re-fetch data you already had from a stream-capable source.
- **Not polling** (fine): one-shot fetches on user action (pull-to-refresh, initial load); retry-with-backoff on failed network calls (that's reconnection); periodic timers used for genuine scheduling like heartbeats or stuck-session sweeps.

When adding a feature that consumes real-time data, subscribe to the existing stream. Don't add a timer that re-fetches.

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
- **Never replace a `switch` statement with a cascade of `if` statements** to satisfy the `prefer_exhaustive_switch` lint. Instead, keep the `switch` and add all missing cases explicitly (return `null` or handle appropriately for unrecognized values).

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

## Architectural Review Workflow

Two review agents enforce the rules above. Both reject on any violation — no warnings or partial approvals.

- **Before implementation**: send the plan to `aristotle-plan-review` (agent file at `.opencode/agents/aristotle-plan-review.md`). A plan needs a clear goal, specific classes/files/layers, and stated data flow. Vague plans are rejected on the gate without further review.
- **Before opening a PR**: send the branch/PR to `aristotle-impl-review` (agent file at `.opencode/agents/aristotle-impl-review.md`). It reviews only new and changed code — preexisting legacy patterns are not flagged unless the change extends them.

Do not skip either step. The reviewers exist because violations compound — one bypass in a handler becomes three bypasses in the handlers that copy it.

## Learning From Feedback

- Treat user feedback in **PR comments** and in the **live chat** as guidance for future code, not just the current patch.
- When the user pushes back on a coding practice, architecture choice, testing shape, utility placement, or workflow decision, proactively update the closest relevant `AGENTS.md` file so the same mistake is less likely to recur.
- Prefer updating both the **repo-root `AGENTS.md`** for general guidance and the **workspace/module `AGENTS.md`** for domain-specific guidance when the feedback is scoped.
- Do this proactively after the lesson is clear; do not wait for the user to ask a second time.
- Assume the user reviews **committed and pushed code**, not your uncommitted local workspace. If you are expecting PR feedback to reflect your latest work, proactively commit and push first.
- Never rely on users reviewing uncommitted changes. Remote PR state is the review source of truth unless the user explicitly says otherwise.
- Never use `git commit --amend` anywhere in this repo workflow. There are no exceptions; if follow-up changes are needed, create a new commit instead.

## Forbidden

- Don't modify `shared/sesori_shared` without considering impact on both bridge and mobile consumers.
- Don't create a root-level `pubspec.yaml`. There is no root workspace.