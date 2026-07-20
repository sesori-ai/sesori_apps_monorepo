# Sesori Bridge (Dart)

Dart CLI compiled to a native bundle. Runs headlessly on a laptop or VM, authenticates via OAuth PKCE, connects to the relay, and routes E2E-encrypted traffic between clients and ordered enabled backend plugins. OpenCode, Codex, and Cursor can run concurrently in one bridge.

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
│   │   ├── request_router.dart   Iterates handlers, delegates to first match; returns 404 when none match
│   │   ├── health_check_handler.dart        GET /global/health
│   │   ├── get_projects_handler.dart        GET /project
│   │   ├── get_sessions_handler.dart        GET /session
│   │   └── get_session_messages_handler.dart GET /session/:id/message
│   ├── sse/                   SSE stream management (backend-agnostic)
│   │   ├── sse_manager.dart   SSE stream multiplexing to connected phones
│   │   └── event_queue.dart   Per-subscriber event buffer with replay
│   └── debug_server.dart      Debug HTTP server for local testing
├── listeners/                 Layer 4 reactive/scheduled trigger consumers
├── server/                    Bridge instance / host services (single-live-bridge enforcement, startup mutex, plugin host abstractions)

bridge/ workspace modules (siblings of app/):
├── sesori_plugin_interface/   Plugin contract — BridgePlugin, BridgePluginDescriptor, PluginHost
├── sesori_bridge_foundation/  Bridge/plugin shared pure-Dart primitives
├── sesori_plugin_runtime/     Managed backend-process supervision for plugins
├── sesori_plugin_opencode/    OpenCode implementation
├── sesori_plugin_codex/       Codex implementation
├── sesori_plugin_acp/         ACP protocol plugin base
└── sesori_plugin_cursor/      Cursor implementation over ACP
```

## WHERE TO LOOK

| Task             | Location                           | Notes                                                   |
| ---------------- | ---------------------------------- | ------------------------------------------------------- |
| CLI flags        | `bin/bridge.dart`                  | Bridge core flags (`--relay`, repeatable `--plugin`/`--import-plugin`, etc.); every enabled plugin contributes namespaced options |
| Auth flow        | `lib/src/auth/`                    | OAuth PKCE with token persistence to disk               |
| Relay connection | `lib/src/bridge/relay_client.dart` | WebSocket + auth handshake + reconnection               |
| Key exchange     | `lib/src/bridge/key_exchange.dart` | X25519 → HKDF → room key delivery                       |
| Request routing  | `lib/src/bridge/routing/`          | Explicit handlers; unmatched routes return 404          |
| Trigger listeners | `lib/src/listeners/`               | One trigger lifecycle per class; typed output only      |
| Plugin interface | `../sesori_plugin_interface/`       | BridgePlugin contract for all backends                  |
| OpenCode plugin  | `../sesori_plugin_opencode/`        | OpenCode backend implementation + models + tests        |
| Bridge instances | `lib/src/server/`                  | Single-live-bridge enforcement, startup mutex, plugin host abstractions |

## CONVENTIONS

- **Plugin architecture** — all backend-specific code lives in sibling plugin packages under `bridge/`. Core repositories, services, handlers, and shared contracts remain backend-neutral. `plugin_registry.dart` is the supported composition point that imports the OpenCode, Codex, and Cursor descriptors; do not import concrete plugins elsewhere in bridge core.
- **Ordered plugin selection** — repeated `--plugin <id>` flags override persisted `enabledPlugins`; otherwise settings win, otherwise OpenCode is the sole fallback. Preserve order and reject duplicates/unknown/explicitly empty selection. The first enabled plugin is the current default. Missing legacy `pluginId` still means OpenCode, not the first enabled plugin.
- **Plugin CLI options are namespaced** — plugins declare **bare** option names in their descriptor (`port`, `host`, `bin`, …). `PluginCliOptionsMapper` namespaces each to `--<pluginId>-<name>` (e.g. `--opencode-host`) at registration so options can't collide once multiple plugins run in parallel. Never bake the plugin prefix into the declared name. When renaming/migrating a previously un-prefixed flag, keep the old spelling working via `PluginOption.deprecatedAliases` (registered hidden, emits a `Log.w` deprecation when used) rather than breaking existing invocations. Plugin code reads values by the **bare** name through `PluginConfig`, unaware of namespacing.
- **Catalog and import semantics** — project/root/detail/child reads use only the durable database catalog. `POST`, `DELETE`, and `GET /plugin/import` start, cancel, and report independent per-plugin imports; progress SSE is plugin-attributed. Imports are atomic/non-destructive, and concurrent catalog reads observe the last committed snapshot.
- **Independent lifecycle** — `PluginLifecycleService` owns ordered enabled/default metadata and the operational API map. A terminal plugin failure disables only that plugin's routes and new-session choice; it does not stop catalog browsing, the relay, or another plugin.
- **Explicit routing** — every supported route has a dedicated handler; `RequestRouter` returns 404 for unmatched routes (no catch-all proxy).
- **Layer 4 trigger listeners** — new reactive/scheduled consumers live in
  `lib/src/listeners/`. Each owns one trigger's subscription/timer lifecycle,
  delegates decisions to repositories/services, does not depend on listener
  peers, and exposes typed output for the Orchestrator instead of emitting SSE
  directly.
- **User-facing output vs logging** — use `Console` (from `sesori_plugin_interface`) for anything the user must see to operate the bridge: prompts, requests, the login URL/code, essential startup status, and deprecation nudges. `Console.message` writes to stdout; `Console.warning` (yellow) and `Console.error` (red) write to stderr; none are gated by `--log-level`. Coloring is applied only when stderr is an interactive terminal, so redirected/piped output stays clean. Use `Log` only for diagnostics that can be safely ignored; all `Log` levels write to stderr and are suppressible via `--log-level`. `Log` warning/error lines are colorized (yellow/red) on a terminal, and the `[CallerClass]` tag is shown only at `debug`/`verbose` levels to keep normal output clean. The bridge must stay fully operable with logging silenced (`--log-level error` or `2>/dev/null`), so never put an essential prompt or actionable status behind `Log`.
- **Crypto from `sesori_shared`** — all crypto primitives imported from shared package, not duplicated
- **Linting**: `package:lints/recommended.yaml` (lighter than mobile's `all_lint_rules`)
- **Binary distribution**: npm wrapper package with platform-specific optional deps (darwin/linux/windows × arm64/x64)
- **Proper architecture** — network calls go in dedicated API classes (e.g. `OpenCodeApi`), not inlined in business logic. Classes receive dependencies via constructor injection.
- **BridgePlugin is API-layer in app/** — request handlers must not access `BridgePlugin` directly for session lifecycle flows. Put thin plugin-backed session operations in `SessionRepository`, and put multi-step session workflows like create/archive/unarchive in services.
- **Always use typed models** — deserialize JSON responses into Freezed objects immediately. Never pass raw `Map<String, dynamic>` or `List<dynamic>` through business logic.
- **API classes return Freezed types** — e.g. `Future<List<Project>>` not `Future<http.Response>`. Parsing lives in the API layer.
- **Constructor injection for testability** — business logic classes (e.g. `ActiveSessionTracker`) receive their API dependency via constructor, enabling fake/mock injection in tests.
- **Prefer typed version value objects** — when bridge code needs version parsing/comparison, parse once into a small typed value object that implements `Comparable`. Keep raw version strings in API/transport DTOs and map them into typed versions in repository code rather than exposing loose `String` comparison helpers.
- **Prefer `CompositeSubscription` for multiple owned stream subscriptions** — when a class owns more than one long-lived `StreamSubscription`, store them in a single `CompositeSubscription` and cancel that composite in one place during teardown instead of manually tracking multiple nullable subscription fields.
- **Request bodies use shared Freezed models** — every handler that accepts a JSON body must have a corresponding Freezed request class in `sesori_shared` (e.g. `HideProjectRequest`, `CreateProjectRequest`). Parse with `FooRequest.fromJson(map)` inside a try/catch:
  ```dart
  final FooRequest fooRequest;
  try {
    fooRequest = FooRequest.fromJson(
      jsonDecodeMap(request.body),
    );
  } catch (error) {
    Log.d("Rejecting request with an invalid JSON body: $error");
    return buildErrorResponse(request, 400, "invalid JSON body");
  }
  ```

## ANTI-PATTERNS

- **Never silently swallow** — a `catch` that swallows and continues (no-op/best-effort cleanup) must log; a catch-all (`on Object catch`/`catch (e)`) should generally log since the cause is unknown. But do NOT add a redundant log when the catch already surfaces the failure (rethrows, throws a typed exception, or returns/yields an explicit failure like `ExplicitUpdateFailed`/`ProvisionFailed`) — that double-logs. When you do log a caught error, pass it as the logger argument (`Log.w("msg", error, stackTrace)`), don't string-interpolate it.
- **Never duplicate crypto** — use `sesori_shared` package for all encryption/protocol types
- **Never hardcode URLs** — relay and auth backend are CLI-configurable. The OpenCode server defaults to loopback (`127.0.0.1`) but its host and port are CLI-configurable too (`--opencode-host`, `--opencode-port`)
- **Never inline HTTP calls in business logic** — extract to a dedicated API class with typed return values
- **Never pass raw JSON maps through layers** — always deserialize at the boundary (API class) and use Freezed objects downstream
- **Never construct classes with server URLs/passwords directly** — inject an API client instance instead
- **Never use inline JSON maps for request bodies** — always create a Freezed class in `sesori_shared` and use `toJson()`/`fromJson()`. Never write `body: {"key": value}` in service or handler code.
- **Never split a service into fake helpers that still depend on that same service** — if logic is being extracted into a focused collaborator, it must stand on its own injected dependencies. Do not use `part` files, extensions, or pseudo-helper classes that call back into the owning service, because that keeps same-level coupling and hides circular design.
- **Do not use top-level/global functions for non-trivial bridge logic** — extracting 20-100 lines of decision-making into free functions is not an acceptable file-splitting strategy. If logic is substantial enough to deserve its own file, make it a named collaborator class with explicit constructor-injected dependencies and test it directly.
- **Never extract a class only for file-length pressure** — the extracted collaborator must own lifecycle, state or invariants, a stable domain responsibility, or a multi-caller decision boundary. If it owns none of those, keep the logic as private methods in the original class.
- **Keep command primitives in standalone dependencies** — shell-facing git or worktree operations belong in a dedicated API/helper dependency that the service composes. `WorktreeService` should orchestrate those collaborators, not attach command execution as service-owned helper methods in another file.
- **Don't couple the in-place updater with the npm bootstrap/install script** — they are intentionally independent. The npm bootstrap atomically replaces the managed install (full-dir rename under its own `.sesori-bootstrap.lock`) and the Dart updater swaps `bin/`/`lib/` under `.update.lock`. Do NOT add cross-process/cross-language lock coordination between them (e.g. having the updater observe the bootstrap lock or unifying the two locks). The bootstrap's job is simply to replace the binaries; a rare collision from running `npx @sesori/bridge` during the updater's apply window is an accepted edge, not a bug to "fix" by coupling the two locking schemes.

For push code specifically, `PushDispatcher` owns only outbound push sends (immediate sends, completion sends, rate limiting, payload construction, and client disposal). `CompletionPushListener` owns SSE-driven tracker/notifier bookkeeping plus abort suppression, and `MaintenancePushListener` owns the timer lifecycle, maintenance-step sequencing, and maintenance telemetry/logging.

## TESTING

```bash
# Run analysis/tests from the bridge/ workspace root.
make analyze                                   # Analyze all bridge modules
make test                                      # Test all bridge modules
(cd app && make build)                         # Build the host-native CLI bundle

# Target a single module (the subshell keeps your shell at bridge/):
(cd app && dart test)                          # Bridge app tests only
(cd sesori_plugin_opencode && dart test)       # OpenCode plugin tests only
(cd sesori_plugin_interface && dart analyze)   # Interface analysis only
(cd sesori_plugin_opencode && dart analyze)    # Plugin analysis only
```

Test helpers in `test/helpers/test_helpers.dart`: `makeRoomKey()`, `startTestRelayServer()`, `connectTestRelayClient()`

## RELEASE

Makefiles use the Flutter SDK pinned in the root `.tool-versions`. `make build`
builds only the host-native CLI bundle because sqlite build hooks require native
target compilation. GitHub Actions builds release artifacts on the matching
platform runners, creates the GitHub Release, and publishes the npm bootstrap
packages via trusted publishing.
