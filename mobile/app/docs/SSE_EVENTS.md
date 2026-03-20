# OpenCode SSE Events — Complete Catalog

Reference for all Server-Sent Events emitted by the OpenCode local server.

## Endpoints

| Path                | Scope                 | Event Wrapper                                  |
| ------------------- | --------------------- | ---------------------------------------------- |
| `GET /event`        | Current instance only | `{ type, properties }`                         |
| `GET /global/event` | All instances         | `{ directory, payload: { type, properties } }` |

## Connection Lifecycle

```
GET /global/event HTTP/1.1
Accept: text/event-stream
Authorization: Basic base64("opencode:password")

# Server immediately sends:
data: {"directory":"global","payload":{"type":"server.connected","properties":{}}}

# Then streams events as they occur:
data: {"directory":"/path/to/project","payload":{"type":"session.created","properties":{"info":{...}}}}

# Heartbeat every 10 seconds:
data: {"directory":"global","payload":{"type":"server.heartbeat","properties":{}}}
```

### Reconnection

If the connection drops, reconnect with exponential backoff (start 3s, max 30s). On reconnect you'll receive `server.connected` again. Refetch any state you need (sessions, messages) since you may have missed events.

---

## Event Format

All events follow this shape:

```json
{
  "type": "event.type.name",
  "properties": { ... }
}
```

For `/global/event`, wrapped as:

```json
{
  "directory": "/path/to/project",
  "payload": {
    "type": "event.type.name",
    "properties": { ... }
  }
}
```

---

## System Events

### server.connected

Sent immediately on SSE connection.

```json
{ "type": "server.connected", "properties": {} }
```

### server.heartbeat

Sent every 10 seconds as keep-alive. Use to detect stale connections.

```json
{ "type": "server.heartbeat", "properties": {} }
```

### server.instance.disposed

An instance (project context) was disposed.

```json
{ "type": "server.instance.disposed", "properties": { "directory": "/path/to/project" } }
```

### global.disposed

All instances disposed (server shutting down).

```json
{ "type": "global.disposed", "properties": {} }
```

---

## Session Events

### session.created

New session created.

```json
{
  "type": "session.created",
  "properties": {
    "info": {
      /* full Session object */
    }
  }
}
```

### session.updated

Session metadata changed (title, summary, share, timestamps).

```json
{
  "type": "session.updated",
  "properties": {
    "info": {
      /* full Session object */
    }
  }
}
```

### session.deleted

Session was deleted.

```json
{
  "type": "session.deleted",
  "properties": {
    "info": {
      /* full Session object */
    }
  }
}
```

### session.diff

File diffs generated for a session.

```json
{
  "type": "session.diff",
  "properties": {
    "sessionID": "session_...",
    "diff": [
      {
        "file": "src/main.ts",
        "before": "...",
        "after": "...",
        "additions": 5,
        "deletions": 2,
        "status": "modified"
      }
    ]
  }
}
```

### session.error

An error occurred in a session.

```json
{
  "type": "session.error",
  "properties": {
    "sessionID": "session_...",
    "error": {
      "name": "ProviderAuthError",
      "data": { "providerID": "anthropic", "message": "Invalid API key" }
    }
  }
}
```

### session.compacted

Session context was compacted/summarized.

```json
{
  "type": "session.compacted",
  "properties": {
    "sessionID": "session_..."
  }
}
```

### session.status

Session busy/idle status changed.

```json
{
  "type": "session.status",
  "properties": {
    "sessionID": "session_...",
    "status": "busy"
  }
}
```

---

## Message Events

These are the **most important events for a mobile chat UI**.

### message.updated

A message was created or its metadata changed.

```json
{
  "type": "message.updated",
  "properties": {
    "info": {
      "role": "assistant",
      "id": "message_...",
      "sessionID": "session_...",
      "parentID": "message_...",
      "agent": "build",
      "modelID": "claude-sonnet-4-20250514",
      "providerID": "anthropic",
      "time": { "created": 1700000000000, "completed": null },
      "cost": 0,
      "tokens": { "input": 0, "output": 0, "reasoning": 0, "cache": { "read": 0, "write": 0 } }
    }
  }
}
```

### message.removed

A message was deleted.

```json
{
  "type": "message.removed",
  "properties": {
    "sessionID": "session_...",
    "messageID": "message_..."
  }
}
```

### message.part.updated

A part was created or finalized. You'll receive this when:

- A new text/tool/reasoning part starts
- A tool call completes (state transitions)
- A step finishes

```json
{
  "type": "message.part.updated",
  "properties": {
    "part": {
      "id": "part_...",
      "sessionID": "session_...",
      "messageID": "message_...",
      "type": "text",
      "text": "Here's the complete response...",
      "time": { "start": 1700000000000, "end": 1700000003000 }
    }
  }
}
```

### message.part.delta ⭐

**Streaming text delta.** This is how you display real-time AI output.

Append `delta` to the corresponding part's `field` (usually `"text"`).

```json
{
  "type": "message.part.delta",
  "properties": {
    "sessionID": "session_...",
    "messageID": "message_...",
    "partID": "part_...",
    "field": "text",
    "delta": "Here's a"
  }
}
```

Followed by:

```json
{
  "type": "message.part.delta",
  "properties": { "sessionID": "...", "messageID": "...", "partID": "...", "field": "text", "delta": " hello world" }
}
```

**Flutter implementation pattern:**

```dart
// Accumulate deltas per partID
final partText = <String, StringBuffer>{};

void onDelta(String partID, String field, String delta) {
  partText.putIfAbsent(partID, () => StringBuffer());
  partText[partID]!.write(delta);
  // Trigger UI rebuild
}
```

### message.part.removed

A part was deleted.

```json
{
  "type": "message.part.removed",
  "properties": {
    "sessionID": "session_...",
    "messageID": "message_...",
    "partID": "part_..."
  }
}
```

---

## PTY Events

### pty.created

```json
{
  "type": "pty.created",
  "properties": {
    "info": { "id": "pty_...", "command": "bash", ... }
  }
}
```

### pty.updated

```json
{
  "type": "pty.updated",
  "properties": {
    "info": { "id": "pty_...", ... }
  }
}
```

### pty.exited

```json
{
  "type": "pty.exited",
  "properties": {
    "id": "pty_...",
    "exitCode": 0
  }
}
```

### pty.deleted

```json
{
  "type": "pty.deleted",
  "properties": {
    "id": "pty_..."
  }
}
```

---

## Permission Events

### permission.asked

The AI is requesting permission to perform an action.

**Mobile app should display an approval dialog when this fires.**

```json
{
  "type": "permission.asked",
  "properties": {
    "requestID": "perm_...",
    "sessionID": "session_...",
    "tool": "bash",
    "input": { "command": "rm -rf node_modules" },
    "description": "Run shell command"
  }
}
```

### permission.replied

A permission request was answered.

```json
{
  "type": "permission.replied",
  "properties": {
    "requestID": "perm_...",
    "reply": "allow"
  }
}
```

### permission.updated

Permission rules changed.

---

## Question Events

### question.asked

The AI is asking the user a question.

**Mobile app should display a picker/dialog when this fires.**

```json
{
  "type": "question.asked",
  "properties": {
    "requestID": "q_...",
    "sessionID": "session_...",
    "question": "Which database should I use?",
    "options": [
      { "label": "PostgreSQL", "description": "Relational database" },
      { "label": "SQLite", "description": "Embedded database" }
    ],
    "multiple": false
  }
}
```

### question.replied

```json
{
  "type": "question.replied",
  "properties": {
    "requestID": "q_...",
    "answers": ["PostgreSQL"]
  }
}
```

### question.rejected

```json
{
  "type": "question.rejected",
  "properties": {
    "requestID": "q_..."
  }
}
```

---

## Todo Events

### todo.updated

The AI's task list changed.

```json
{
  "type": "todo.updated",
  "properties": {
    "sessionID": "session_...",
    "todos": [
      { "id": "t1", "content": "Create database schema", "status": "completed", "priority": "high" },
      { "id": "t2", "content": "Add API routes", "status": "in_progress", "priority": "high" },
      { "id": "t3", "content": "Write tests", "status": "pending", "priority": "medium" }
    ]
  }
}
```

---

## Project & VCS Events

### project.updated

Project metadata changed.

```json
{
  "type": "project.updated",
  "properties": {
    "id": "...",
    "worktree": "/path",
    "name": "My Project",
    "time": { "created": ..., "updated": ... },
    "sandboxes": []
  }
}
```

### vcs.branch.updated

Git branch changed.

---

## File Events

### file.edited

A file was modified (by the AI or user).

```json
{
  "type": "file.edited",
  "properties": {
    "file": "src/main.ts"
  }
}
```

---

## LSP Events

### lsp.updated

LSP server status changed.

```json
{ "type": "lsp.updated", "properties": {} }
```

### lsp.client.diagnostics

New diagnostics received for a file.

```json
{
  "type": "lsp.client.diagnostics",
  "properties": {
    "serverID": "typescript",
    "path": "src/main.ts"
  }
}
```

---

## MCP Events

### mcp.tools.changed

MCP tools list was updated (server connected/disconnected, tools added/removed).

```json
{ "type": "mcp.tools.changed", "properties": {} }
```

### mcp.browser.open.failed

Browser failed to open for MCP OAuth.

---

## Installation Events

### installation.updated

```json
{
  "type": "installation.updated",
  "properties": { "version": "0.1.80" }
}
```

### installation.update-available

```json
{
  "type": "installation.update-available",
  "properties": { "version": "0.1.81" }
}
```

---

## Workspace Events

### workspace.ready

```json
{
  "type": "workspace.ready",
  "properties": { "name": "default" }
}
```

### workspace.failed

```json
{
  "type": "workspace.failed",
  "properties": { "message": "Failed to initialize workspace" }
}
```

---

## Worktree Events

### worktree.ready / worktree.failed

Same shape as workspace events.

---

## Event Priority for Mobile

When building a mobile client, handle events in this priority order:

### Must-Have (Core Chat)

1. `message.part.delta` — streaming AI text
2. `message.part.updated` — part state transitions
3. `message.updated` — message lifecycle
4. `session.updated` — session metadata
5. `permission.asked` — approval dialogs
6. `question.asked` — question dialogs
7. `session.status` — busy/idle indicator
8. `session.error` — error display

### Should-Have (Good UX)

9. `todo.updated` — show AI's task progress
10. `session.created` / `session.deleted` — session list updates
11. `file.edited` — show which files changed
12. `session.diff` — show code changes
13. `server.heartbeat` — connection health

### Nice-to-Have (Advanced)

14. `pty.*` — terminal integration
15. `mcp.tools.changed` — tools list refresh
16. `lsp.*` — diagnostics
17. `installation.*` — version updates
18. `project.updated` — project metadata
