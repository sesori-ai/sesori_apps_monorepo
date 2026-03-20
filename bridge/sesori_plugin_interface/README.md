# Sesori Plugin Interface

Defines the abstract `BridgePlugin` contract and the data models that all backend plugins must implement. The bridge core depends only on this package, keeping it decoupled from any specific backend.

## BridgePlugin Interface

Every plugin must implement `BridgePlugin` from `lib/src/bridge_plugin.dart`. The interface has 8 members:

```dart
abstract class BridgePlugin {
  /// Unique plugin identifier, e.g. "opencode" or "codex".
  String get id;

  /// Stream of bridge SSE events. Buffered until the first listener subscribes.
  Stream<BridgeSseEvent> get events;

  /// Returns the list of projects from the backend.
  Future<List<PluginProject>> getProjects();

  /// Returns sessions for a worktree directory, with optional pagination.
  Future<List<PluginSession>> getSessions(String worktree, {int? start, int? limit});

  /// Returns messages for a session (last exchange only).
  Future<List<PluginMessageWithParts>> getSessionMessages(String sessionId);

  /// Returns the backend's health status as a raw JSON string.
  Future<String> healthCheck();

  /// Returns providers and their models.
  /// Pass connectedOnly: true to filter to providers with valid credentials.
  Future<PluginProvidersResult> getProviders({required bool connectedOnly});

  /// Returns a per-project count of currently active (busy) sessions.
  List<PluginProjectActivitySummary> getActiveSessionsSummary();

  /// Proxies a raw HTTP request to the backend. Temporary escape hatch.
  @Deprecated("Temporary proxy — replace with typed plugin methods")
  Future<({int status, Map<String, String> headers, String? body})> proxyRequest({
    required String method,
    required String path,
    required Map<String, String> headers,
    String? body,
  });

  /// Stops the plugin and releases resources (SSE connections, HTTP clients, etc.).
  Future<void> dispose();
}
```

## Data Models

All models are generated with [Freezed](https://pub.dev/packages/freezed) and support JSON serialization.

### Sessions

| Class | Fields |
|-------|--------|
| `PluginSession` | `id`, `projectID`, `directory`, `parentID?`, `title?`, `time?`, `summary?` |
| `PluginSessionTime` | `created`, `updated`, `archived?` |
| `PluginSessionSummary` | `additions`, `deletions`, `files` |

### Messages

| Class | Fields |
|-------|--------|
| `PluginMessage` | `role`, `id`, `sessionID`, `parentID?`, `agent?`, `modelID?`, `providerID?`, `cost?`, `time?`, `finish?` |
| `PluginMessageWithParts` | `info` (PluginMessage), `parts` (List\<PluginMessagePart\>) |
| `PluginMessagePart` | `id`, `sessionID`, `messageID`, `type`, `text?`, `tool?`, `callID?`, `state?`, `mime?`, `url?`, `filename?`, `cost?`, `reason?`, `prompt?`, `description?`, `agent?`, `snapshot?`, `time?` |
| `PluginToolState` | `status`, `title?`, `output?`, `error?` |
| `PluginMessageTime` | `created`, `completed?` |
| `PluginPartTime` | `start?`, `end?` |

### Projects

| Class | Fields |
|-------|--------|
| `PluginProject` | `id`, `worktree`, `name?`, `time?` |
| `PluginProjectTime` | `created`, `updated`, `initialized?` |
| `PluginProjectActivitySummary` | `worktree`, `activeSessions` |

### Providers

`PluginProvider` is a sealed union with named variants for known providers plus a `custom` catch-all. Each variant carries `id`, `name`, `authType`, `models`, and `defaultModelID?`.

| Variant | Factory |
|---------|---------|
| Anthropic | `PluginProvider.anthropic(...)` |
| OpenAI | `PluginProvider.openAI(...)` |
| Google | `PluginProvider.google(...)` |
| Mistral | `PluginProvider.mistral(...)` |
| Groq | `PluginProvider.groq(...)` |
| xAI | `PluginProvider.xAI(...)` |
| DeepSeek | `PluginProvider.deepseek(...)` |
| Amazon Bedrock | `PluginProvider.amazonBedrock(...)` |
| Azure | `PluginProvider.azure(...)` |
| Custom | `PluginProvider.custom(...)` |

`PluginProviderAuthType` is an enum: `apiKey`, `oauth`, `unknown`.

`PluginModel` carries `id`, `name`, and `family?`.

`PluginProvidersResult` wraps a `List<PluginProvider>` and is the return type of `getProviders`.

## SSE Events

`BridgeSseEvent` is a sealed class. Plugins emit events on their `events` stream; the bridge core delivers them to connected phones. Events are grouped by category:

### Server

| Class | Notable fields |
|-------|----------------|
| `BridgeSseServerConnected` | none |
| `BridgeSseServerHeartbeat` | none |
| `BridgeSseServerInstanceDisposed` | `directory?` |
| `BridgeSseGlobalDisposed` | none |

### Session

| Class | Notable fields |
|-------|----------------|
| `BridgeSseSessionCreated` | `info` (raw JSON map) |
| `BridgeSseSessionUpdated` | `info` |
| `BridgeSseSessionDeleted` | `info` |
| `BridgeSseSessionDiff` | `sessionID`, `diff` (list of JSON maps) |
| `BridgeSseSessionError` | `sessionID` |
| `BridgeSseSessionCompacted` | `sessionID` |
| `BridgeSseSessionStatus` | `sessionID`, `status` (raw JSON map) |
| `BridgeSseSessionIdle` | `sessionID` |

### Message

| Class | Notable fields |
|-------|----------------|
| `BridgeSseMessageUpdated` | `info` (raw JSON map) |
| `BridgeSseMessageRemoved` | `sessionID`, `messageID` |
| `BridgeSseMessagePartUpdated` | `part` (raw JSON map) |
| `BridgeSseMessagePartDelta` | `sessionID`, `messageID`, `partID`, `field`, `delta` |
| `BridgeSseMessagePartRemoved` | `sessionID`, `messageID`, `partID` |

### PTY

| Class | Notable fields |
|-------|----------------|
| `BridgeSsePtyCreated` | none |
| `BridgeSsePtyUpdated` | none |
| `BridgeSsePtyExited` | `id?`, `exitCode?` |
| `BridgeSsePtyDeleted` | `id?` |

### Permission and Question

| Class | Notable fields |
|-------|----------------|
| `BridgeSsePermissionAsked` | `requestID`, `sessionID`, `tool`, `description` |
| `BridgeSsePermissionReplied` | `requestID`, `reply` |
| `BridgeSsePermissionUpdated` | none |
| `BridgeSseQuestionAsked` | `id`, `sessionID`, `questions` (list of JSON maps) |
| `BridgeSseQuestionReplied` | `requestID`, `sessionID` |
| `BridgeSseQuestionRejected` | `requestID`, `sessionID` |

### File, LSP, and MCP

| Class | Notable fields |
|-------|----------------|
| `BridgeSseFileEdited` | `file?` |
| `BridgeSseFileWatcherUpdated` | `file?`, `event?` |
| `BridgeSseLspUpdated` | none |
| `BridgeSseLspClientDiagnostics` | `serverID?`, `path?` |
| `BridgeSseMcpToolsChanged` | none |
| `BridgeSseMcpBrowserOpenFailed` | none |

### Workspace and Worktree

| Class | Notable fields |
|-------|----------------|
| `BridgeSseWorkspaceReady` | `name?` |
| `BridgeSseWorkspaceFailed` | `message?` |
| `BridgeSseWorktreeReady` | none |
| `BridgeSseWorktreeFailed` | none |

### Project and VCS

| Class | Notable fields |
|-------|----------------|
| `BridgeSseProjectUpdated` | none |
| `BridgeSseVcsBranchUpdated` | none |
| `BridgeSseTodoUpdated` | `sessionID` |

### Installation and UI

| Class | Notable fields |
|-------|----------------|
| `BridgeSseInstallationUpdated` | `version?` |
| `BridgeSseInstallationUpdateAvailable` | `version?` |
| `BridgeSseTuiToastShow` | `title?`, `message?`, `variant?` |

## Implementing a New Plugin

1. Create a new Dart package in `bridge/`.
2. Add `sesori_plugin_interface` as a dependency.
3. Implement `BridgePlugin`. All 8 members are required.
4. Expose a `Stream<BridgeSseEvent>` on `events`. Use `BufferedUntilFirstListener` from this package to buffer events emitted before the bridge subscribes.
5. Emit events by adding to the stream as your backend produces them.
6. Register the plugin in `bridge/app/bin/bridge.dart`.

```dart
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart';

class MyPlugin implements BridgePlugin {
  @override
  String get id => 'my-backend';

  @override
  Stream<BridgeSseEvent> get events => _buffer.stream;

  // ... implement all 8 methods
}
```

## Testing

```bash
dart test
```
