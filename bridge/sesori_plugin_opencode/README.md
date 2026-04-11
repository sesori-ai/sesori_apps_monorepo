# Sesori OpenCode Plugin

Implements the `BridgePlugin` interface for the [OpenCode](https://github.com/anomalyco/opencode) backend. Handles HTTP API communication, SSE event parsing, session tracking, and translation of OpenCode-specific types into the shared plugin interface models.

## Architecture

The plugin is layered. Each layer has a single responsibility:

```
OpenCodePlugin          BridgePlugin implementation — coordinates all layers, maps types
    |
OpenCodeService         Coordination — pagination, last-exchange extraction, SSE dispatch
    |
OpenCodeRepository      Data access — merges standard and global sessions, builds virtual projects
    |
OpenCodeApi             HTTP client — raw requests to the OpenCode REST API
```

`SseConnection` runs alongside this stack, maintaining a persistent SSE connection to `GET /global/event` and feeding raw event strings to `OpenCodePlugin`. `SseEventParser` translates those strings into typed `SseEventData` objects. `ActiveSessionTracker` watches session status events to maintain a live count of busy sessions per project.

Compatibility note: the plugin keeps bridge-facing SSE behavior intentionally narrow. `session.diff` is normalized into the shared event model for invalidation tracking, parser failures are reported as categorized outcomes instead of exceptions, and dropped SSE frames are logged with stable category tags plus `directory` context when available. Cold-start hydration of pending questions/permissions is best-effort only. Shell routes such as `GET /session/{id}/shell` remain outside the bridge router and are expected to 404.

## Key Components

### `OpenCodePlugin`

The main entry point. Implements all 8 `BridgePlugin` methods and wires together the other components.

```dart
OpenCodePlugin({
  required String serverUrl,
  String? password,
})
```

On construction it creates the full service stack, starts an `SseConnection`, and performs a cold start to populate the `ActiveSessionTracker`. Its `events` stream is backed by a `BufferedUntilFirstListener` so events emitted before the bridge subscribes are not lost.

Plugin ID: `"opencode"`.

### `SseConnection`

Manages a persistent SSE connection to `GET /global/event` on the OpenCode server. Reconnects automatically with exponential backoff (1s initial, 30s cap). On reconnect, it calls an optional `onReconnect` callback so the plugin can reset and re-sync state.

```dart
SseConnection({
  required String targetUrl,
  required String? password,
  required void Function(String rawData) onEvent,
  Future<void> Function()? onReconnect,
})
```

Call `start()` to begin streaming and `stop()` to disconnect.

### `SseEventParser`

Translates raw OpenCode SSE data strings into typed `SseEventData` objects. Never throws; callers can distinguish malformed envelopes, malformed known payloads, and unknown event types while malformed or unknown frames are logged and dropped.

```dart
SseParseResult parse(String rawData)
```

The parser follows OpenCode's event envelope format: it JSON-decodes the string, extracts `payload.type` and `payload.properties`, merges them into `{"type": type, ...properties}`, then deserializes via `SseEventData.fromJson`. The top-level `directory` field, when present, is preserved in the result for use by `ActiveSessionTracker` and drop logging. `session.diff` is normalized specially so OpenCode 1.4 invalidation-only payloads and older legacy diff arrays both map to the same shared model.

### `ActiveSessionTracker`

Tracks which sessions are currently active (busy or retrying) and maps them back to their project worktrees. Used to power `getActiveSessionsSummary`.

On cold start it fetches all projects and current session statuses from the API. It then best-effort hydrates pending questions and permissions, and updates incrementally as `SseSessionStatus`, `SseSessionCreated`, `SseSessionUpdated`, `SseSessionDeleted`, and `SseSessionIdle` events arrive. `handleEvent` returns `true` when the active session counts change, signaling the plugin to emit a `BridgeSseProjectUpdated` event.

### `OpenCodeApi`

Raw HTTP client for the OpenCode REST API. All methods add `Authorization: Basic` headers when a password is configured.

| Method | Endpoint |
|--------|----------|
| `listProjects()` | `GET /project` |
| `listSessions({directory?})` | `GET /session` |
| `listRootSessions()` | `GET /session?roots=true` |
| `listGlobalSessions({directory?, roots?})` | `GET /experimental/session` |
| `getMessages(sessionId)` | `GET /session/:id/message` |
| `listProviders()` | `GET /provider` |
| `getSessionStatuses()` | `GET /session/status` |

### `OpenCodeRepository`

Data access layer that merges OpenCode's standard and global session APIs into a unified view. Key behaviors:

- `getProjects()` fetches both `/project` and `/experimental/session` (roots), merges timestamps, and synthesizes virtual projects for directories that have global sessions but no real project entry.
- `getSessions(worktree:)` merges standard and global sessions, deduplicates by ID, filters to root sessions under the given worktree, and sorts by `updated` descending.

### `OpenCodeService`

Thin coordination layer sitting between `OpenCodePlugin` and `OpenCodeRepository`. Applies `start` and `limit` pagination to session lists, extracts the last exchange from a message list (from the last user message to the end), and delegates SSE event handling and summary building to `ActiveSessionTracker`.

## Testing

```bash
dart test
```
