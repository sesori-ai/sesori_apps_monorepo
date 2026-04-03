# Bridge Architecture

## Overview

The bridge is a Dart CLI that sits between a local AI assistant (OpenCode) and connected mobile phones. It authenticates with OAuth PKCE, maintains a WebSocket to the relay server, performs X25519 key exchange with each phone, and routes encrypted HTTP requests and SSE events end-to-end. The relay is a dumb pipe — it never sees plaintext.

## Module Structure

Three modules, one dependency direction:

```
sesori_plugin_interface   (no bridge deps — abstract contract only)
       ↑
sesori_plugin_opencode    (implements interface; depends on sesori_shared)
       ↑
app                       (bridge core; depends on interface + shared; never imports concrete plugins)
```

| Module | Responsibility |
|--------|---------------|
| `sesori_plugin_interface` | `BridgePlugin` abstract class + `BridgeSseEvent` sealed types |
| `sesori_plugin_opencode` | OpenCode HTTP client, SSE parsing, session/project models |
| `app` | Orchestration, relay connection, routing, SSE delivery, persistence |

The `app` module is plugin-agnostic. It depends only on `sesori_plugin_interface`, never on `sesori_plugin_opencode` directly. The concrete plugin is wired at startup in `bin/bridge.dart`.

## Architectural Layers

Top to bottom — each layer depends only on the layers below it.

### Bootstrap — `bin/bridge.dart`
Parses CLI flags, runs the OAuth PKCE flow, constructs all components (plugin, DAOs, services, orchestrator), installs SIGINT/SIGTERM handlers, and calls `orchestrator.run()`. This is the only place where concrete dependencies are wired together.

### Orchestration — `lib/src/bridge/orchestrator.dart`
The central coordinator. `Orchestrator` is a factory that creates `OrchestratorSession` instances with a fresh room key and `SSEManager`. `OrchestratorSession.run()` drives the relay loop:
- Handles `phone_connected` / `phone_disconnected` control messages
- Delegates key exchange to `KeyExchangeManager`
- Decrypts incoming frames, routes requests via `RequestRouter`, encrypts responses
- Subscribes to `plugin.events` and `prSyncService.prChanges` — the only two event sources that feed the `SSEManager`
- Manages reconnect with exponential backoff

Nothing below the orchestrator emits SSE events. It owns all SSE decisions.

### Request Handling — `lib/src/bridge/routing/`
`RequestRouter` holds an ordered list of `RequestHandlerBase` instances. `route()` iterates them and returns the first match's response. First match wins; `ProxyHandler` is the catch-all fallback.

Each handler is one class per API route (`GetProjectsHandler`, `CreateSessionHandler`, etc.). Handlers are pure request-to-response — they don't touch the SSE layer. All exceptions are caught in `RequestRouter.route()` and converted to `502` responses.

26 named handlers + 1 proxy fallback. See `request_router.dart` for the full list.

### SSE Delivery — `lib/src/bridge/sse/`
`SSEManager` multiplexes events to all connected phones. Each subscriber gets an `EventQueue` that buffers events and replays orphaned ones on reconnect.

Events enter via `sseManager.enqueueEvent(event)` (called only from `OrchestratorSession`). Each event is encrypted with the room key and sent over the relay WebSocket to every active subscriber.

### Services — `lib/src/bridge/pr/`, `worktree_service.dart`, `metadata_service.dart`
Business logic helpers. Services that produce async state expose a `Stream` — consumers subscribe rather than polling. `PrSyncService.prChanges` is the canonical example: it emits a project ID whenever PR data changes, and the orchestrator translates that into a `sessionsUpdated` SSE event.

### Persistence — `lib/src/bridge/persistence/`
Drift (SQLite) database with three DAOs: `ProjectsDao`, `SessionDao`, `PullRequestDao`. Schema migrations follow the workflow in the root `AGENTS.md`. DAOs are injected into handlers and services — never accessed statically.

### Shared — `shared/sesori_shared/`
Crypto primitives (`RelayCryptoService`, `SessionEncryptor`), relay protocol types (`RelayMessage` sealed class, `frame`/`unframe`), and shared Freezed models (`SesoriSseEvent`, `Project`, `Session`, etc.). Consumed by both bridge and mobile — changes here affect both.

## Data Flows

### Request to Response

```
Phone (encrypted frame)
  → RelayClient.read()
  → OrchestratorSession: decrypt with room key
  → RequestRouter.route(RelayRequest)
  → matching RequestHandler → plugin or DAO → RelayResponse
  → OrchestratorSession: encrypt + frame
  → RelayClient.send() → Phone
```

### SSE Event to Phone

```
AI assistant SSE stream or PrSyncService.prChanges
  → OrchestratorSession event subscription
  → BridgeEventMapper.map() → SesoriSseEvent
  → SSEManager.enqueueEvent()
  → EventQueue per subscriber → encrypt per phone → RelayClient.send()
```

## Architectural Rules

### Orchestrator owns SSE decisions
Nothing below `OrchestratorSession` may emit SSE events. The orchestrator subscribes to `plugin.events` and `prSyncService.prChanges` and decides what reaches phones. No `emitEvent()` or equivalent method should exist on services or handlers.

### Streams over callbacks
Services that produce async state expose a `Stream` (via `StreamController` or `PublishSubject`). Never pass `Function` callbacks for event notification. Consumers subscribe; producers just add to the stream.

### No manual JSON parsing
Always deserialize JSON into Freezed models at the boundary (API class or handler). Use `jsonDecodeMap` / `jsonDecodeListMap` from `sesori_shared` as the decode step, then `Model.fromJson(map)`. Never pass raw `Map<String, dynamic>` or `List<dynamic>` through business logic.

### Constructor injection
All dependencies flow through constructors. No service locators, no static access to DAOs or services. This makes components independently testable.

### Plugin-agnostic core
`lib/src/` never imports from `sesori_plugin_opencode` or any other concrete plugin. Depend only on `sesori_plugin_interface`. Concrete plugins are wired exclusively in `bin/bridge.dart`.
