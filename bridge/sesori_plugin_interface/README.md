# Sesori Plugin Interface

The contract between the bridge core and backend plugins. The bridge core depends only on this package, keeping it decoupled from any specific backend (OpenCode today; other harnesses later).

The package has four parts:

1. **`BridgePluginApi`** — the request surface the bridge routes traffic through (sessions, prompts, questions, permissions, projects, providers, events).
2. **The lifecycle contract** — `BridgePluginDescriptor` → `start(PluginHost)` → `BridgePlugin`: how plugins are registered, configured, started, observed, and stopped.
3. **Data models** — Freezed value types exchanged through the API (`lib/src/models/`).
4. **SSE events** — the sealed `BridgeSseEvent` family plugins emit and the bridge relays to phones.

## Lifecycle contract

```
BridgePluginDescriptor (const, inert)
        │  start(PluginHost)
        ▼
BridgePlugin { api, status, currentStatus, describe(), shutdown(budget) }
```

- **`BridgePluginDescriptor`** is the registration unit: `id`, `displayName`, CLI `options`, `validateConfig`, and `start(host)`. Descriptors are const and side-effect free — **registered is not started**. Option-level typed-parse hooks (`PluginValueOption.integer`, or a custom `validate`) and `validateConfig` both run at argument-parse time, strictly before the bridge's startup mutex and before any resident bridge could be replaced, so a config typo can never kill a healthy bridge. Reject bad configuration with `PluginConfigException`, and exercise every typed accessor in `validateConfig`.
- **`BridgePlugin`** is a live instance. Its `api` must stay the same object for the plugin's lifetime (the bridge constructor-injects it widely); a plugin whose transport can be swapped puts a stable facade there. `status` is a replay-latest stream of the sealed `PluginStatus` family; `shutdown({budget})` is idempotent ordered teardown.
- **`PluginHost`** offers opt-in services: parsed `config`, a private `stateDirectory`, `environment`, a `clock` seam, the cooperative `startAborted` signal, bridge identity facts (`BridgeHostInfo`, including the `isLiveBridgeProcess` capability that authorizes stale-runtime cleanup), process spawn/inspect/signal (`HostProcessService` — spawned children expose `stdin` for stdio protocols), port probing (`HostPortService`), and an atomic JSON store with a locked `update()` (`HostJsonStore`).

### Status state machine

`PluginStatus` is sealed: `Starting`, `Ready`, `Degraded`, `Restarting`, `Failed`, `Stopping`, `Stopped`.

| From         | May become                                      |
|--------------|-------------------------------------------------|
| `Starting`   | `Ready`, `Degraded`, `Failed`, `Stopping`       |
| `Ready`      | `Degraded`, `Restarting`, `Failed`, `Stopping`  |
| `Degraded`   | `Ready`, `Degraded`, `Restarting`, `Failed`, `Stopping` |
| `Restarting` | `Ready`, `Degraded`, `Restarting`, `Failed`, `Stopping` |
| `Failed`     | `Stopping`                                      |
| `Stopping`   | `Stopped`                                       |
| `Stopped`    | — (the stream closes)                           |

Two rules carry the weight: **no `Failed` after `Stopping`** (a clean shutdown must never be reported as a failure by a racy exit monitor), and **the stream closes after `Stopped`**. `PluginStatusController` implements the machine with a replay-latest stream: `set()` throws on illegal transitions (deliberate steps), `trySet()` drops them silently (racy sources).

`status` is the *debounced* lifecycle signal for orchestration; `BridgePluginApi.healthCheck()` stays an instantaneous, mobile-facing probe.

### `start()` contract

- Runs under the bridge's cross-instance startup mutex; the mutex is held until `start()` settles. The bridge never abandons a start with `Future.timeout` — long phases must check `host.startAborted` at every phase boundary and roll back when aborted. An aborted start settles by throwing `PluginStartAbortedException` after the rollback.
- On failure, release everything acquired (processes, records, sockets) before throwing — `PluginStartException` for expected failure modes.

### `shutdown()` / `dispose()` contract

`BridgePlugin.shutdown({budget})` owns ordered teardown and must be idempotent. `BridgePluginApi.dispose()` is kept for the migration window — the bridge core may still call it directly, before or after `shutdown()`, so both must be safe in either order. Prefer `shutdown()`; `dispose()` will be removed once the core stops calling it.

### Steady plugins in a few lines

Direct-CLI and remote-server plugins have no managed runtime; mix in `SteadyPluginLifecycle` and supply only `api`, `describe()`, and (optionally) `onShutdown`:

```dart
class RemotePlugin with SteadyPluginLifecycle implements BridgePlugin {
  @override
  BridgePluginApi get api => _api;

  @override
  PluginDiagnostics describe() => PluginDiagnostics(pluginId: api.id, endpoint: _url);

  @override
  Future<void> onShutdown({Duration? budget}) => _api.dispose();
}
```

The mixin debounces the degraded side (`markDegraded` surfaces only after the degradation persists; `markReady` recovers immediately) and enforces the state machine on every transition.

### Migration status

The bridge core still constructs the OpenCode plugin through a legacy factory; the runner adopts descriptors in a follow-up change. New code should target the descriptor contract.

## BridgePluginApi

The request surface (`lib/src/bridge_plugin.dart`), grouped:

| Area | Members |
|------|---------|
| Identity & events | `id`, `events` (buffered `Stream<BridgeSseEvent>` — use `BufferedUntilFirstListener`) |
| Projects | `getProjects`, `getProject`, `renameProject`, `deleteWorkspace` |
| Sessions | `getSessions`, `getChildSessions`, `createSession`, `renameSession`, `deleteSession`, `archiveSession`, `getSessionStatuses`, `getSessionMessages`, `getActiveSessionsSummary` |
| Prompting | `sendPrompt`, `sendCommand`, `abortSession`, `getCommands`, `getAgents`, `getProviders` |
| Questions & permissions | `getPendingQuestions`, `getProjectQuestions`, `replyToQuestion`, `rejectQuestion`, `replyToPermission` |
| Health & teardown | `healthCheck` (instantaneous probe), `dispose` (prefer `BridgePlugin.shutdown`) |

Failures are signaled with `PluginOperationException` (transport-agnostic; optional `statusCode`) or its HTTP-flavored subclass `PluginApiException`. Use `PluginOperationException.notFound` so idempotent deletes work for non-HTTP plugins.

## Data models

All models live in `lib/src/models/`, generated with [Freezed](https://pub.dev/packages/freezed), and support JSON serialization. The families:

- **Sessions** — `PluginSession` (+ time/summary), `PluginActiveSession`, `PluginSessionStatus`, `PluginSessionVariant`
- **Messages** — `PluginMessage`, `PluginMessageWithParts`, `PluginMessagePart`, tool state and timing types
- **Projects** — `PluginProject`, `PluginProjectActivitySummary`
- **Providers** — `PluginProvider` (sealed union of known providers + `custom`), `PluginModel`, `PluginProvidersResult`
- **Prompting** — `PluginPromptPart`, `PluginCommand`, `PluginAgent`
- **Questions & permissions** — `PluginPendingQuestion`, `PluginPermissionReply`

See the source files for fields — they are the authority.

## SSE events

`BridgeSseEvent` (`lib/src/bridge_sse_event.dart`) is a sealed class; plugins emit events on `events` and the bridge delivers them to connected phones. Categories: server lifecycle, session, message (including part deltas), PTY, permission/question, file/LSP/MCP, workspace/worktree, project/VCS, installation/UI. See the source file for the full family — event classes are added as upstream backends grow.

## Implementing a new plugin

1. Create a Dart package in `bridge/` and depend on `sesori_plugin_interface`.
2. Implement `BridgePluginApi` for your backend. Buffer early events with `BufferedUntilFirstListener`.
3. Implement `BridgePlugin` — mix in `SteadyPluginLifecycle` unless you manage a local runtime.
4. Write a const `BridgePluginDescriptor` declaring your CLI options and `start(host)` flow; use only `PluginHost` services for processes, ports, and state files.
5. Register the descriptor in `bridge/app/bin/bridge.dart` (descriptor registration lands with the runner migration — see Migration status above).

## Testing

```bash
dart test
```
