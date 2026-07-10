# Bridge Workspace — Agent Rules

This file covers bridge-specific guidance. For general architecture, layering, class suffixes, cohesion rules, commit discipline, and review workflow, see the repo-root `AGENTS.md`.

## Commands

From `bridge/`:
- `dart pub get` — install dependencies for the workspace
- `make codegen` — regenerate Freezed/JSON files across all modules
- `make test` — run tests in all modules that have a `test/` directory
- `make analyze` — static analysis across all modules

Bridge CI runs `dart analyze --fatal-infos`, which is stricter than `make analyze` — info-level lints (e.g. `directives_ordering` import sorting) fail CI. Before pushing, run `dart analyze --fatal-infos` from each changed module dir (e.g. `bridge/app/`).

From `bridge/app/`:
- `make build` — build all targets (host-native + Linux cross-compiled)
- `make build-host` — native binary only
- `make build-linux` — Linux cross-compiled binaries only

## Module Order

Dependencies flow in one direction:

1. `sesori_plugin_interface` — no internal deps; defines the contract (also the home of foundational primitives like `Log`, `Console`, `HostProcessService`)
2. `sesori_bridge_foundation` — depends on interface; **bridge-wide** Layer-0 primitives shared by the main app AND plugins (`SemanticVersion`, `PlatformTarget`, `ChecksumValidator`, `BinaryDownloadClient`, format-keyed `ArchiveExtractor`, `CommandExecutor`/`HostProcessCommandExecutor`). NOT plugin-only.
3. `sesori_plugin_runtime` — depends on interface; **plugin-only** managed-runtime supervision (`ManagedProcessService`, `ManagedRuntimeMonitor`, ownership/restart/intent). Used by plugins to supervise their backend process; the main app does not depend on it.
4. `sesori_plugin_opencode` — depends on interface + foundation + runtime + `sesori_shared`
5. `app` — depends on interface + foundation + `opencode_plugin` + `sesori_shared` (NOT runtime)

When changing shared types, update in this order.

Decide placement by audience: a primitive used by **both** the app and plugins (download, extract, checksum, version, platform target, command execution) belongs in `sesori_bridge_foundation`, not `sesori_plugin_runtime` (which is plugin-only supervision). Do not duplicate these per consumer; map their neutral results into a consumer's own vocabulary at that consumer's boundary (e.g. `UpdateArtifactRepository` maps `DownloadException` → `UpdateResult`).

## Plugin Runtime Provisioning (`ensureRuntime`)

`BridgePluginDescriptor` has an `ensureRuntime({host})` phase that runs **after** `checkAvailability` and **immediately before** `start()`, under the cross-instance startup mutex (so two bridges never install the same managed runtime at once). It returns a `Stream<RuntimeProvisionProgress>` whose terminal event is `ProvisionReady(binaryPath)` or `ProvisionFailed(message)`. The default is a no-op (remote/attach plugins need no runtime).

- The runner consumes the stream, renders progress (`RuntimeProvisionFormatter`), and records `ProvisionReady.binaryPath` on the host (`PluginHost.provisionedRuntimePath`) for `start()` to launch.
- **`ProvisionFailed` is non-fatal**: the bridge proceeds to `start()`, which returns a **degraded** plugin (`PluginDegraded`, never `PluginFailed` — a `PluginFailed` status exits the bridge). The relay/phone stay connected; a restart re-attempts provisioning.
- A cooperative abort during provisioning surfaces as `PluginStartAbortedException` (a stream error), handled by the runner as "aborted as requested".
- When mapping a long-running primitive stream into provisioning progress, prefer `await for (...) { yield ... }` over `yield*` if you need to **catch** errors from the inner stream: `yield*` forwards the inner stream's error straight to the consumer and bypasses your surrounding `try/catch`.

### Bumping the managed OpenCode runtime

The managed runtime is pinned in `sesori_plugin_opencode/lib/src/runtime/open_code_runtime_manifest.dart`:

1. Pick the new `vX.Y.Z` release of `anomalyco/opencode`.
2. Update `bundledVersion`.
3. Replace all six per-platform `sha256` values from that release's asset digests — GitHub's release API exposes each asset's `digest: "sha256:…"` (`opencode-darwin-{arm64,x64}.zip`, `opencode-linux-{arm64,x64}.tar.gz`, `opencode-windows-{arm64,x64}.zip`).
4. Raise `minSupportedVersion` only when new bridge code needs a newer OpenCode API than older PATH installs provide (keep it conservative — prefer the user's own install, and never force a download that would migrate a newer OpenCode's local DB).

## Testing

- `dart test` from `app/`, `sesori_plugin_opencode/`, and `sesori_plugin_interface/`

## Conventions

- Freezed models use `build.yaml` options: `format: false`, `map: false`, `when: false`
- Plugin implementations must implement the full `BridgePluginApi` surface — no partial implementations
- SSE events use sealed classes (see `bridge_sse_event.dart`)
- Pure Dart only — no Flutter dependencies anywhere in this workspace

## Class Suffix Guidance

Root `AGENTS.md` has the full suffix vocabulary. Concrete bridge examples:

- **Tool wrappers** use `Api`: `GhCliApi` (gh), `GitCliApi` (git), `SesoriServerApi` (HTTP)
- **Transport wrappers** use `Client`: `RelayClient`, `PushNotificationClient`
- **Layer 3 orchestration** uses `Service`: `WorktreeService`, `MetadataService`, `TokenService`
- **Pipeline choke points** use `Dispatcher`: `PushDispatcher` (owns only outbound push sends: immediate sends, completion sends, rate limiting, payload building, and client disposal)
- **Stream-driven triggers** use `Listener`: `CompletionPushListener`, `MaintenancePushListener`
- **State derived from events** uses `Tracker`: `ActiveSessionTracker`, `PushSessionStateTracker`
- **Pure transformations** use `Builder`/`Mapper`/`Parser`: `PushNotificationContentBuilder`, `BridgeEventMapper`, `SseEventParser`

If a new class doesn't fit one of these, reconsider its responsibilities before labeling it `Manager`, `Helper`, or `Wrapper`.

Ask this before extracting any new bridge class: **Would this class still deserve to exist if the original file were under the line limit?** If the answer is no, keep the logic as cohesive private methods. File length alone never justifies a new class.

## Bridge-Specific Patterns

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

### API Classes Are Per-Tool, Not Per-Use-Case

One API class wraps one external binary/tool. Use separate classes for separate tools (for example, `GhCliApi` for `gh`, `GitCliApi` for `git`). Do not merge tool wrappers just because features are related. Within one tool wrapper, keep all operations together instead of splitting by use-case. This also applies to external providers — e.g., a `GithubApi` wrapping GitHub's web API is separate from `GhCliApi`.

### DAOs Are Dumb

DAOs execute raw queries and return raw data. No decision-making logic, no selection algorithms, no business rules. All mapping and selection logic belongs in the Repository layer.

When a durable entity has separate identity and location fields, do not infer
the location from an unknown identifier. Non-null persisted fields are
authoritative; a missing row remains missing (`null`) and the repository or
service decides whether to return 404, rather than manufacturing a path from
the id.

### No Default-Constructed Dependencies

Constructor parameters for injected dependencies (services, runners, checkers) must be `required` with no default values. Never do `ProcessRunner? processRunner` with `?? ProcessRunner()` — if a test forgets to pass the dependency, it silently uses a real implementation instead of failing fast. This ties into the class-cohesion rules in root: if defaults tempt you to avoid threading a dependency, you likely have pass-through parameters or a peer-as-child problem higher up.

### DebugServer Shares Instances

`DebugServer` must receive the same service/repository instances as the main `Orchestrator`. Never create new instances inside `DebugServer` — it must be wired with injected dependencies.

### Streams Over Callbacks

Use push-based communication (`StreamController`, `PublishSubject`) between services. Never pass `Function` callbacks for event notification. Services that produce events expose a `Stream`; consumers subscribe to it. This also unlocks symmetric trigger handling — two consumers of the same stream are structurally symmetric by construction.

### Prefer CompositeSubscription For Multiple Owned Streams

When a class owns more than one long-lived `StreamSubscription`, prefer a single `CompositeSubscription` and add each owned subscription to it. Cancel the composite in one place during teardown instead of manually tracking several nullable subscription fields.

### Honest Ownership Boundaries

Do not extract a bridge collaborator only to make a file shorter. The extracted class must own lifecycle, state or invariants, a stable domain responsibility, or a multi-caller decision boundary. If it owns none of those, keep the logic as private methods on the cohesive owner.

In the push subsystem, `PushDispatcher` owns only outbound push sends. `CompletionPushListener` owns SSE-driven tracker/notifier bookkeeping plus abort suppression, and `MaintenancePushListener` owns the timer lifecycle, maintenance-step sequencing, and maintenance telemetry/logging.

### Backend Quirks Live In The Plugin

Backend-specific endpoint semantics and the workarounds they require (synchronous vs async endpoints, dispatch timeouts compensating for upstream API shape, retry quirks) belong inside the plugin that implements `BridgePluginApi` — never in bridge `app/` services or handlers. Bridge `app/` code must stay plugin-agnostic: it programs against the `BridgePluginApi` contract, and the contract's doc comments define the semantics (e.g., `sendCommand` completes on acceptance, not on run completion). If a fix requires knowing how a specific backend behaves, it goes in that backend's plugin.

### Orchestrator Owns SSE Decisions

No component below the Orchestrator may emit SSE events directly. The Orchestrator subscribes to streams (`plugin.events`, `prSyncService.prChanges`) and decides what to emit to phones. No `emitBridgeEvent()` or similar public methods on the Orchestrator.

### No Magic Strings for Known Enumerations

If a concept has a fixed set of values (PR state, mergeable status, review decision, check status), **use an enum**. Never compare strings like `state.toUpperCase() == "OPEN"` in business logic. Map the raw string to an enum at the deserialization boundary (API/mapper layer), then use the enum everywhere else.

### No Swallowing Errors with Empty Defaults

API methods must **throw** on unexpected errors. Never return empty lists, `null`, or `false` to hide failures — the caller should decide how to handle the error. A single `catch` block is fine if all errors are handled identically; don't split into multiple catches that do the same thing.

### Never Silently Swallow Exceptions

The target is a `catch` that **discards an error and continues as if nothing happened, with no trace** (`catch (e) { /* no-op */ }`) — if it fails for everyone, you'd never know.

- **Swallow-and-continue must log.** A handler that recovers/degrades and keeps going (no-op and best-effort cleanup included) emits at least a `debug`/`warning` with enough context to know what failed and why continuing is safe.
- **Catch-all (`on Object catch (error)` / `catch (e)`) should generally log** — reaching it means the cause is unknown.
- **Don't double-log a surfaced failure.** When the catch already makes the failure observable — rethrow, throw a typed exception, or return/yield an explicit failure the caller renders (`ExplicitUpdateFailed`, `ProvisionFailed`, a `PluginUnavailable`, etc.) — do NOT add a redundant upfront `Log`. The returned/thrown failure is the signal.
- **Pass the error as the logger argument, not inlined.** `Log.w("what failed", error, stackTrace)`, never `Log.w("what failed: $error")`. `Log.d`/`Log.i` take only a message, so use `Log.w`/`Log.e` when attaching the caught error/stack.

### No Redundant Model Layers

If a DTO and a "Record" model have the same fields and no meaningful transformation between them, **use the DTO directly**. Don't create parallel data classes just to rename things.

### No Manual JSON Parsing

Always create Freezed models with auto-generated `fromJson` when parsing JSON. Never use inline `jsonDecode` + manual field extraction. Use `jsonDecodeListMap`/`jsonDecodeMap` from `sesori_shared` as the decode step, then `Model.fromJson(map)`.

### Prefer jsonDecodeMap Helpers

When decoding JSON objects, prefer `jsonDecodeMap` / `jsonDecodeListMap` over raw `jsonDecode` plus manual type checks. Use the helper first, then `fromJson` or typed field access.

### Prefer Callback-Scoped Locks

If a lock protects a single operation, prefer a callback-scoped API like `locked<T>(...)` that acquires, runs the callback, and auto-releases in one place. Avoid manual lock bookkeeping at call sites when a scoped API can express the same flow more clearly.

### Prefer Typed Version Value Objects

If code needs to parse or compare versions, do not expose loose helpers that accept arbitrary `String` inputs like `compareVersions(String, String)`. Parse once into a small typed value object that implements `Comparable`, keep transport-layer DTO fields as raw strings, and do the string-to-type mapping in the repository layer.

### Shared Utility Placement Follows Explicit Product Choice

If a utility is intentionally meant to live in `sesori_shared`, keep it there even if the current number of consumers is temporarily one. Do not move it out solely because present-day usage is narrow when product direction or explicit reviewer feedback says it should remain shared.

### Be Conservative With Makefile Entries

Do not add maintenance scripts to a Makefile by default. Only add them when they are part of the normal repeated workspace workflow, not one-off or occasional release chores.

## Forbidden

- Don't edit `*.freezed.dart`, `*.g.dart`, or `*.steps.dart` — these are generated; run `make codegen` instead.
- Don't modify `sesori_plugin_interface` without checking all implementors (`sesori_plugin_opencode` and any others).
- Don't add Flutter dependencies — this is a pure Dart workspace.
- Don't modify `sesori_shared` from here; it lives in the monorepo root and is shared with the mobile app.

## Definition of Done

- `dart pub get` exits 0
- `make analyze` exits 0
- `make test` all pass
