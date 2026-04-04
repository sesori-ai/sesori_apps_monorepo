# Bridge Workspace — Agent Rules

## Commands

From `bridge/`:
- `dart pub get` — install dependencies for the workspace
- `make codegen` — regenerate Freezed/JSON files across all modules
- `make test` — run tests in all modules that have a `test/` directory
- `make analyze` — static analysis across all modules

From `bridge/app/`:
- `make build` — build all targets (host-native + Linux cross-compiled)
- `make build-host` — native binary only
- `make build-linux` — Linux cross-compiled binaries only

## Module Order

Dependencies flow in one direction:

1. `sesori_plugin_interface` — no internal deps; defines the contract
2. `sesori_plugin_opencode` — depends on interface + `sesori_shared`
3. `app` — depends on both plugin packages + `sesori_shared`

When changing shared types, update in this order.

## Forbidden

- Don't edit `*.freezed.dart` or `*.g.dart` — these are generated; run `make codegen` instead.
- Don't modify `sesori_plugin_interface` without checking all implementors (`sesori_plugin_opencode` and any others).
- Don't add Flutter dependencies — this is a pure Dart workspace.
- Don't modify `sesori_shared` from here; it lives in the monorepo root and is shared with the mobile app.

## Testing

- `dart test` from `app/` and `sesori_plugin_opencode/`
- `sesori_plugin_interface` has no tests (it's a contract package)

## File Size
- Maximum file length: 250 lines per production code file
- If a file exceeds 250 lines, split it into smaller focused files (by use-case, component, or concern)
- Prefer many small files over few large files
- Test files are explicitly excluded from this limit

## Conventions

- Freezed models use `build.yaml` options: `format: false`, `map: false`, `when: false`
- Plugin implementations must implement all 8 `BridgePlugin` methods — no partial implementations
- SSE events use sealed classes (see `bridge_sse_event.dart`)

## Forbidden Patterns

### No Pointless Interfaces
Only create an interface if **at least one** of these is true:
1. It has **multiple production implementations** (e.g., platform-specific variants, different backend adapters)
2. It splits a class into **semantic single-purpose use-cases** (e.g., `AccessTokenReader` vs `AccessTokenWriter` to limit write surface)
3. It is **defined in a shared layer** and implemented in another (e.g., `ErrorReporter` in shared, implemented by app)

**Never** create a 1:1 interface for a concrete class just for testability. In Dart 3, `implements` works on **any class**, so `class FakeFoo implements Foo` is the correct approach for test fakes.

**Exception:** If `implements` genuinely cannot be used (e.g., the class is `final` or has sealed members that make faking impractical), an interface is acceptable as a last resort.

**Forbidden:**
- Creating an interface just so tests can fake it (when `implements` would work)
- `PullRequestDaoLike` wrapping `PullRequestDao`
- `PullRequestRepositoryLike` / `SessionRepositoryLike` / `PrSourceRepositoryLike`

### No Magic Strings for Known Enumerations
If a concept has a fixed set of values (PR state, mergeable status, review decision, check status), **use an enum**. Never compare strings like `state.toUpperCase() == "OPEN"` in business logic. Map the raw string to an enum at the deserialization boundary (API/mapper layer), then use the enum everywhere else.

### No Swallowing Errors with Empty Defaults
API methods must **throw** on unexpected errors. Never return empty lists, `null`, or `false` to hide failures — the caller should decide how to handle the error. A single `catch` block is fine if all errors are handled identically; don't split into multiple catches that do the same thing.

### No Redundant Model Layers
If a DTO and a "Record" model have the same fields and no meaningful transformation between them, **use the DTO directly**. Don't create parallel data classes just to rename things.

### API Classes Are Per-Tool, Not Per-Use-Case
An API class wraps a single external tool/binary. Different tools get separate API classes even if they serve related purposes. For example:
- `GhCliApi` — wraps the `gh` CLI (GitHub-specific: PRs, auth, etc.)
- `GitCliApi` — wraps the `git` CLI (generic git operations: remotes, config, etc.)

These are separate tools with different binaries, different capabilities, and different scopes. `git` works with any git host; `gh` is GitHub-specific. Don't merge them into one class.

Within a single tool, don't split by use-case — keep all operations for that tool in one class.

### DebugServer Shares Instances
`DebugServer` must receive the same service/repository instances as the main `Orchestrator`. Never create new instances inside `DebugServer` — it must be wired with injected dependencies.

### DAOs Are Dumb
DAOs execute raw queries and return raw data. No decision-making logic, no selection algorithms, no business rules. All mapping and selection logic belongs in the Repository layer.

## Architectural Rules

### No Manual JSON Parsing
Always create Freezed models with auto-generated `fromJson` when parsing JSON. Never use inline `jsonDecode` + manual field extraction. Use `jsonDecodeListMap`/`jsonDecodeMap` from `sesori_shared` as the decode step, then `Model.fromJson(map)`.

### Streams Over Callbacks
Use push-based communication (`StreamController`, `PublishSubject`) between services. Never pass `Function` callbacks for event notification. Services that produce events expose a `Stream`; consumers subscribe to it.

### Orchestrator Owns SSE Decisions
No component below the Orchestrator may emit SSE events directly. The Orchestrator subscribes to streams (`plugin.events`, `prSyncService.prChanges`) and decides what to emit to phones. No `emitBridgeEvent()` or similar public methods on the Orchestrator.

## Definition of Done

- `dart pub get` exits 0
- `make analyze` exits 0
- `make test` all pass
