# Sesori Bridge (Dart)

Dart CLI compiled to native binary. Runs on laptop, authenticates via OAuth PKCE, connects to relay, routes E2E-encrypted traffic between phones and local server. Plugin-based architecture supports multiple backends (OpenCode, Codex, etc.). Manages process lifecycle (SIGTERM on shutdown).

## STRUCTURE

```
bin/bridge.dart                CLI entry point — flag parsing, auth flow, plugin loading
lib/src/
├── auth/                      OAuth PKCE login, token storage, profile fetch, validation
├── bridge/                    Core bridge logic (plugin-agnostic)
│   ├── relay_client.dart      WebSocket connection to relay, message routing
│   ├── orchestrator.dart      Coordinates relay + plugin lifecycle + key exchange
│   ├── key_exchange.dart      X25519 DH key exchange with phones, room key delivery
│   ├── routing/               Request handler chain (one class per API route)
│   │   ├── request_handler.dart  Abstract base — declares method + path pattern, implements canHandle/extractParams
│   │   ├── request_router.dart   Iterates handler list, extracts params, delegates to first match
│   │   ├── health_check_handler.dart        GET /global/health
│   │   ├── get_projects_handler.dart        GET /project
│   │   ├── get_sessions_handler.dart        GET /session
│   │   ├── get_session_messages_handler.dart GET /session/:id/message
│   │   └── proxy_handler.dart               Catch-all fallback — proxies unmatched routes to plugin backend
│   ├── sse/                   SSE stream management (backend-agnostic)
│   │   ├── sse_manager.dart   SSE stream multiplexing to connected phones
│   │   └── event_queue.dart   Per-subscriber event buffer with replay
│   └── debug_server.dart      Debug HTTP server for local testing
├── server/                    OpenCode process management (start/stop/health check)
modules/
├── sesori_plugin_interface/   Plugin contract — BridgePlugin, RequestHandler, SseConfig
└── opencode_plugin/           OpenCode implementation
    ├── handlers/              Request handlers (project list, session list, messages)
    ├── models/                Freezed models (project, session, message, SSE events, etc.)
    ├── opencode_plugin_impl.dart  BridgePlugin implementation
    ├── opencode_service.dart      Business logic coordinator
    ├── opencode_repository.dart   Data access (project/session merging, virtual projects)
    ├── opencode_api.dart          Raw HTTP client for OpenCode REST API
    ├── active_session_tracker.dart  Tracks active sessions via SSE events
    └── sse_event_parser.dart      Parses raw SSE JSON into typed events
```

## WHERE TO LOOK

| Task             | Location                           | Notes                                                   |
| ---------------- | ---------------------------------- | ------------------------------------------------------- |
| CLI flags        | `bin/bridge.dart`                  | `--relay`, `--port`, `--no-auto-start`, `--login`, etc. |
| Auth flow        | `lib/src/auth/`                    | OAuth PKCE with token persistence to disk               |
| Relay connection | `lib/src/bridge/relay_client.dart` | WebSocket + auth handshake + reconnection               |
| Key exchange     | `lib/src/bridge/key_exchange.dart` | X25519 → HKDF → room key delivery                       |
| Request routing  | `lib/src/bridge/routing/`          | Intercept-first handlers with proxy fallback            |
| Plugin interface | `modules/sesori_plugin_interface/` | BridgePlugin contract for all backends                  |
| OpenCode plugin  | `modules/opencode_plugin/`         | OpenCode backend implementation + models + tests        |
| Process mgmt     | `lib/src/server/`                  | Spawns OpenCode, health poll, SIGTERM cleanup         |

## FILE SIZE
- Maximum file length: 250 lines per production code file
- If a file exceeds 250 lines, split it into smaller focused files (by use-case, component, or concern)
- Prefer many small files over few large files
- Test files are explicitly excluded from this limit

## CONVENTIONS

- **Plugin architecture** — all backend-specific code lives in plugin modules under `modules/`. The bridge `lib/src/` is plugin-agnostic — it only imports from `sesori_plugin_interface`, never from concrete plugins.
- **Intercept-first routing** — requests are intercepted by handlers by default. Proxy is the fallback for unhandled routes, not the default path.
- **Crypto from `sesori_shared`** — all crypto primitives imported from shared package, not duplicated
- **Linting**: `package:lints/recommended.yaml` (lighter than mobile's `all_lint_rules`)
- **Binary distribution**: npm wrapper package with platform-specific optional deps (darwin/linux/windows × arm64/x64)
- **Proper architecture** — network calls go in dedicated API classes (e.g. `OpenCodeApi`), not inlined in business logic. Classes receive dependencies via constructor injection.
- **Always use typed models** — deserialize JSON responses into Freezed objects immediately. Never pass raw `Map<String, dynamic>` or `List<dynamic>` through business logic.
- **API classes return Freezed types** — e.g. `Future<List<Project>>` not `Future<http.Response>`. Parsing lives in the API layer.
- **Constructor injection for testability** — business logic classes (e.g. `ActiveSessionTracker`) receive their API dependency via constructor, enabling fake/mock injection in tests.
- **Request bodies use shared Freezed models** — every handler that accepts a JSON body must have a corresponding Freezed request class in `sesori_shared` (e.g. `HideProjectRequest`, `CreateProjectRequest`). Parse with `FooRequest.fromJson(map)` inside a try/catch:
  ```dart
  final FooRequest fooRequest;
  try {
    fooRequest = FooRequest.fromJson(
      jsonDecodeMap(request.body),
    );
  } catch {
    return buildErrorResponse(request, 400, "invalid JSON body");
  }
  ```

## ANTI-PATTERNS

- **Never duplicate crypto** — use `sesori_shared` package for all encryption/protocol types
- **Never hardcode URLs** — relay and auth backend are CLI-configurable. Server is always localhost (only port is configurable)
- **Never inline HTTP calls in business logic** — extract to a dedicated API class with typed return values
- **Never pass raw JSON maps through layers** — always deserialize at the boundary (API class) and use Freezed objects downstream
- **Never construct classes with server URLs/passwords directly** — inject an API client instance instead
- **Never use inline JSON maps for request bodies** — always create a Freezed class in `sesori_shared` and use `toJson()`/`fromJson()`. Never write `body: {"key": value}` in service or handler code.

## TESTING

```bash
dart test                                    # Bridge tests
dart test modules/opencode_plugin/           # Plugin tests
dart analyze                                 # Bridge analysis
dart analyze modules/sesori_plugin_interface/ # Interface analysis
dart analyze modules/opencode_plugin/        # Plugin analysis
make build                                   # Compile native binary
```

Test helpers in `test/helpers/test_helpers.dart`: `makeRoomKey()`, `startTestRelayServer()`, `connectTestRelayClient()`

## RELEASE

`make build` produces host binary + Linux cross-compiled binaries. GitHub Actions release workflow (on tag `v*`) builds for 5 platforms, creates GitHub release, publishes 5 npm platform packages + wrapper.
