# OpenCode Local Server — API Reference

Complete endpoint reference for the OpenCode local server. All endpoints accept and return JSON unless otherwise noted.

## Table of Contents

- [Connection & Discovery](#connection--discovery)
- [Authentication & Middleware](#authentication--middleware)
- [Global Operations](#1-global-operations)
- [Auth Credentials](#2-auth-credentials)
- [Project Management](#3-project-management)
- [Session Management](#4-session-management)
- [Configuration](#5-configuration)
- [AI Providers](#6-ai-providers)
- [MCP Servers](#7-mcp-servers)
- [PTY / Terminal](#8-pty--terminal)
- [Permissions](#9-permissions)
- [Questions](#10-questions)
- [File Operations](#11-file-operations)
- [Root Endpoints](#12-standalone-root-endpoints)
- [TUI Control](#13-tui-control)
- [Experimental APIs](#14-experimental-apis)
- [Key Schemas](#key-schemas)

---

## Connection & Discovery

### Starting the Server

```bash
# Headless server (no TUI — ideal for mobile control)
opencode serve --port 4096 --hostname 0.0.0.0 --mdns

# With web UI alongside
opencode web --port 4096 --hostname 0.0.0.0
```

### Network CLI Options

| Flag            | Default                       | Description                                             |
| --------------- | ----------------------------- | ------------------------------------------------------- |
| `--port`        | `0` (auto-assign, tries 4096) | Port to listen on                                       |
| `--hostname`    | `127.0.0.1`                   | Bind address. Use `0.0.0.0` for LAN                     |
| `--mdns`        | `false`                       | Enable mDNS discovery (auto-sets hostname to `0.0.0.0`) |
| `--mdns-domain` | `opencode.local`              | Custom mDNS domain name                                 |
| `--cors`        | `[]`                          | Additional CORS-allowed origins                         |

All options can also be set in the global config under `server.port`, `server.hostname`, `server.mdns`, etc.

### mDNS Service Discovery

When `--mdns` is enabled:

| Property     | Value                                        |
| ------------ | -------------------------------------------- |
| Service name | `opencode-{port}`                            |
| Service type | `_http._tcp`                                 |
| Host         | `opencode.local` (or custom `--mdns-domain`) |
| TXT record   | `path=/`                                     |

Source: `packages/opencode/src/server/mdns.ts`

---

## Authentication & Middleware

### Middleware Chain (applied in order)

1. **Error Handler** — catches all errors, returns structured JSON
2. **Basic Auth** — only active if `OPENCODE_SERVER_PASSWORD` env var is set
3. **Request Logger** — logs method + path + duration
4. **CORS** — allows localhost, tauri, `*.opencode.ai`, custom origins
5. **Workspace Context** — extracts `workspace` and `directory` from query/headers
6. **Workspace Router** — routes to remote workspace instances if configured

### HTTP Basic Authentication

Only active when the env var is set:

| Env Var                    | Default             | Purpose                 |
| -------------------------- | ------------------- | ----------------------- |
| `OPENCODE_SERVER_PASSWORD` | _(unset = no auth)_ | Password for Basic Auth |
| `OPENCODE_SERVER_USERNAME` | `"opencode"`        | Username for Basic Auth |

```
Authorization: Basic base64("opencode:yourpassword")
```

`OPTIONS` requests (CORS preflight) bypass auth.

### Context Headers

Every request can include workspace/directory context:

| Method | Header                 | Query Param   | Purpose                |
| ------ | ---------------------- | ------------- | ---------------------- |
| Any    | `x-opencode-workspace` | `?workspace=` | Workspace ID           |
| Any    | `x-opencode-directory` | `?directory=` | Project directory path |

If omitted, the server uses its own `cwd` as the directory.

### CORS Allowed Origins

- `http://localhost:*`, `http://127.0.0.1:*`
- `tauri://localhost`, `http://tauri.localhost`, `https://tauri.localhost`
- `https://*.opencode.ai`
- Custom origins via `--cors` flag

### Error Response Shapes

```jsonc
// 400 Bad Request
{
  "data": null,
  "errors": [{ "message": "Invalid input" }],
  "success": false
}

// 404 Not Found
{
  "name": "NotFoundError",
  "data": { "message": "Session not found" }
}

// 500 Internal Server Error
{
  "name": "UnknownError",
  "data": { "message": "Something went wrong" }
}
```

---

## 1. Global Operations

**Base path:** `/global`

### GET /global/health

> `operationId: global.health`

Health check. Use this to verify the server is running.

**Response 200:**

```json
{ "healthy": true, "version": "0.1.79" }
```

### GET /global/event

> `operationId: global.event`

**Protocol: Server-Sent Events (SSE)**

Subscribe to events across ALL instances. See [SSE_EVENTS.md](./SSE_EVENTS.md) for the full event catalog.

**Headers sent by server:**

- `X-Accel-Buffering: no`
- `X-Content-Type-Options: nosniff`

**Response stream:**

```
data: {"directory":"/path/to/project","payload":{"type":"server.connected","properties":{}}}

data: {"directory":"/path/to/project","payload":{"type":"session.created","properties":{"info":{...}}}}

data: {"directory":"global","payload":{"type":"server.heartbeat","properties":{}}}
```

Heartbeat sent every 10 seconds.

### GET /global/config

> `operationId: global.config.get`

Get the global (user-level) configuration.

**Response 200:** `Config` schema (see [Key Schemas](#key-schemas))

### PATCH /global/config

> `operationId: global.config.update`

Update global configuration.

**Request body:** `Config` schema  
**Response 200:** Updated `Config`

### POST /global/dispose

> `operationId: global.dispose`

Clean up and dispose ALL instances. Releases all resources.

**Response 200:** `true`

---

## 2. Auth Credentials

**Base path:** `/auth`

Manages credentials for AI providers (Anthropic, OpenAI, etc.).

### PUT /auth/{providerID}

> `operationId: auth.set`

Set authentication credentials for a provider.

**Path params:** `providerID` (string) — e.g. `"anthropic"`, `"openai"`

**Request body** (discriminated by `type`):

```jsonc
// OAuth credentials
{
  "type": "oauth",
  "refresh": "refresh_token_...",
  "access": "access_token_...",
  "expires": 1700000000000,
  "accountId": "acc_...",         // optional
  "enterpriseUrl": "https://..." // optional
}

// API Key
{
  "type": "api",
  "key": "sk-ant-..."
}

// WellKnown token
{
  "type": "wellknown",
  "key": "...",
  "token": "..."
}
```

**Response 200:** `true`

### DELETE /auth/{providerID}

> `operationId: auth.remove`

Remove stored credentials for a provider.

**Response 200:** `true`

---

## 3. Project Management

**Base path:** `/project`

### GET /project

> `operationId: project.list`

List all projects that have been opened with OpenCode.

**Response 200:** `Project[]`

### GET /project/current

> `operationId: project.current`

Get the currently active project.

**Response 200:** `Project`

### POST /project/git/init

> `operationId: project.initGit`

Initialize a git repository for the current project.

**Response 200:** `Project` (refreshed)

### PATCH /project/{projectID}

> `operationId: project.update`

Update project properties.

**Path params:** `projectID` (string)

**Request body:**

```json
{
  "name": "My Project",
  "icon": {
    "url": "https://...",
    "override": "custom-icon",
    "color": "#ff0000"
  },
  "commands": {
    "start": "npm install && npm run dev"
  }
}
```

All fields optional.

**Response 200:** Updated `Project`

### Project Schema

```json
{
  "id": "string",
  "worktree": "string (absolute path)",
  "vcs": "git",
  "name": "string (optional)",
  "icon": {
    "url": "string?",
    "override": "string?",
    "color": "string?"
  },
  "commands": {
    "start": "string? (startup script for new worktrees)"
  },
  "time": {
    "created": "number (ms epoch)",
    "updated": "number (ms epoch)",
    "initialized": "number? (ms epoch)"
  },
  "sandboxes": ["string (directory paths)"]
}
```

---

## 4. Session Management

**Base path:** `/session`

This is the **primary API surface** for the mobile app. Sessions represent AI conversations.

### Session CRUD

#### GET /session

> `operationId: session.list`

List sessions for the current project.

**Query params:**

| Param       | Type    | Default | Description                                   |
| ----------- | ------- | ------- | --------------------------------------------- |
| `directory` | string  | current | Filter by project directory                   |
| `roots`     | boolean | false   | Only root sessions (no children)              |
| `start`     | number  | —       | Sessions updated on/after this timestamp (ms) |
| `search`    | string  | —       | Case-insensitive title search                 |
| `limit`     | number  | —       | Max results                                   |

**Response 200:** `Session[]`

#### GET /session/{sessionID}

> `operationId: session.get`

Get a single session.

**Response 200:** `Session`

#### POST /session

> `operationId: session.create`

Create a new session.

**Request body:**

```json
{
  "parentID": "session_...", // optional — creates child session
  "title": "My conversation", // optional — auto-generated if omitted
  "permission": {} // optional — permission ruleset
}
```

**Response 200:** `Session`

#### PATCH /session/{sessionID}

> `operationId: session.update`

Update session properties (title, archive).

**Request body:**

```json
{
  "title": "New title",
  "archived": true
}
```

**Response 200:** Updated `Session`

#### DELETE /session/{sessionID}

> `operationId: session.delete`

Delete a session.

**Response 200:** `true`

### Session Actions

#### POST /session/{sessionID}/init

> `operationId: session.init`

Initialize session with AGENTS.md context.

**Response 200:** `Session`

#### POST /session/{sessionID}/fork

> `operationId: session.fork`

Fork a session, optionally at a specific message.

**Request body:**

```json
{
  "messageID": "message_..." // optional — fork point
}
```

**Response 200:** New `Session`

#### POST /session/{sessionID}/abort

> `operationId: session.abort`

Abort an active AI processing task.

**Response 200:** `true`

#### POST /session/{sessionID}/share

> `operationId: session.share`

Create a shareable link for this session.

**Response 200:** `Session` (with `.share.url` populated)

#### DELETE /session/{sessionID}/share

> `operationId: session.unshare`

Remove the share link.

**Response 200:** `Session`

#### POST /session/{sessionID}/summarize

> `operationId: session.summarize`

Trigger AI context compaction for this session.

**Response 200:** `true`

#### POST /session/{sessionID}/revert

> `operationId: session.revert`

Revert file changes made by a specific message.

**Request body:**

```json
{
  "messageID": "message_...",
  "partID": "part_..." // optional — specific part
}
```

**Response 200:** `Session`

#### POST /session/{sessionID}/unrevert

> `operationId: session.unrevert`

Undo the last revert.

**Response 200:** `Session`

#### GET /session/{sessionID}/children

> `operationId: session.children`

Get forked child sessions.

**Response 200:** `Session[]`

#### GET /session/{sessionID}/todo

> `operationId: session.todo`

Get the AI's todo list for this session.

**Response 200:** `Todo[]`

#### GET /session/{sessionID}/diff

> `operationId: session.diff`

Get file diffs for a specific message.

**Query params:** `messageID` (string), `partID` (string, optional)

**Response 200:** `FileDiff[]`

#### GET /session/status

> `operationId: session.status`

Get busy/idle status for all sessions.

**Response 200:**

```json
{
  "session_abc": "idle",
  "session_xyz": "busy"
}
```

### Messages

#### GET /session/{sessionID}/message

> `operationId: session.messages`

List all messages in a session, with their parts.

**Response 200:** `MessageWithParts[]`

```json
[
  {
    "info": { "role": "user", "id": "message_...", ... },
    "parts": [
      { "type": "text", "text": "Hello", ... }
    ]
  },
  {
    "info": { "role": "assistant", "id": "message_...", ... },
    "parts": [
      { "type": "text", "text": "Hi! How can I help?", ... },
      { "type": "tool", "tool": "bash", "state": { "status": "completed", ... }, ... }
    ]
  }
]
```

#### GET /session/{sessionID}/message/{messageID}

> `operationId: session.message`

Get a single message with its parts.

**Response 200:** `MessageWithParts`

#### POST /session/{sessionID}/message

> `operationId: session.prompt`

**Send a message to the AI.** This is the core chat endpoint.

Returns a streaming response — the HTTP connection stays open until the AI finishes. Use this for synchronous flow, or use `prompt_async` + SSE for event-driven flow.

**Request body (`PromptInput`):**

```json
{
  "parts": [
    { "type": "text", "text": "Write a hello world in Python" },
    { "type": "file", "mime": "image/png", "url": "data:image/png;base64,..." }
  ],
  "agent": "build",
  "model": {
    "providerID": "anthropic",
    "modelID": "claude-sonnet-4-20250514"
  },
  "tools": { "bash": true, "edit": true },
  "system": "Additional system prompt instructions"
}
```

Only `parts` is required. All other fields are optional overrides.

**Response 200:** `MessageWithParts` (the assistant's response)

#### POST /session/{sessionID}/prompt_async

> `operationId: session.prompt_async`

Same as `POST /session/{id}/message` but returns immediately with **204 No Content**. The AI processes in the background and you receive updates via SSE events.

**This is the recommended approach for mobile** — fire and listen on SSE.

#### POST /session/{sessionID}/command

> `operationId: session.command`

Execute a slash command (e.g. `/init`, `/review`, custom commands).

**Request body:**

```json
{
  "command": "init"
}
```

**Response 204**

#### GET /session/{sessionID}/shell

> `operationId: session.shell`

Get the shell info for the session's project.

**Response 200:** Shell configuration object

#### DELETE /session/{sessionID}/message/{messageID}

> `operationId: session.deleteMessage`

Delete a specific message.

**Response 200:** `true`

### Message Parts

#### PATCH /session/{sessionID}/message/{messageID}/part/{partID}

> `operationId: part.update`

Update a message part (e.g. approve a tool call result).

**Request body:** Partial `Part` object  
**Response 200:** Updated `Part`

#### DELETE /session/{sessionID}/message/{messageID}/part/{partID}

> `operationId: part.delete`

Delete a message part.

**Response 200:** `true`

---

## 5. Configuration

**Base path:** `/config`

Project-level configuration (as opposed to global config at `/global/config`).

### GET /config

> `operationId: config.get`

**Response 200:** `Config`

### PATCH /config

> `operationId: config.update`

**Request body:** `Config`  
**Response 200:** Updated `Config`

### GET /config/providers

> `operationId: config.providers`

List configured providers with their default models.

**Response 200:**

```json
{
  "providers": [
    {
      "id": "anthropic",
      "name": "Anthropic",
      "models": { "claude-sonnet-4-20250514": { ... } }
    }
  ],
  "default": {
    "anthropic": "claude-sonnet-4-20250514",
    "openai": "gpt-4o"
  }
}
```

---

## 6. AI Providers

**Base path:** `/provider`

### GET /provider

> `operationId: provider.list`

List all available providers (connected + catalog).

**Response 200:**

```json
{
  "all": [
    {
      "id": "anthropic",
      "name": "Anthropic",
      "models": {
        "claude-sonnet-4-20250514": {
          "id": "claude-sonnet-4-20250514",
          "name": "Claude Sonnet 4",
          "attachments": true,
          "reasoning": true,
          "cost": { "input": 3, "output": 15 }
        }
      }
    }
  ],
  "default": { "anthropic": "claude-sonnet-4-20250514" },
  "connected": ["anthropic", "openai"]
}
```

### GET /provider/auth

> `operationId: provider.auth`

Get available authentication methods for each provider.

**Response 200:** `Record<string, AuthMethod[]>`

### POST /provider/{providerID}/oauth/authorize

> `operationId: provider.oauth.authorize`

Start OAuth authorization flow.

**Request body:**

```json
{ "method": 0 }
```

**Response 200:**

```json
{
  "url": "https://accounts.anthropic.com/oauth/...",
  "method": "browser"
}
```

### POST /provider/{providerID}/oauth/callback

> `operationId: provider.oauth.callback`

Complete OAuth flow with authorization code.

**Request body:**

```json
{
  "method": 0,
  "code": "auth_code_from_callback"
}
```

**Response 200:** `true`

---

## 7. MCP Servers

**Base path:** `/mcp`

Manage Model Context Protocol (MCP) server connections.

### GET /mcp

> `operationId: mcp.status`

Get status of all MCP servers.

**Response 200:** `Record<string, McpStatus>`

### POST /mcp

> `operationId: mcp.add`

Add a new MCP server.

**Request body:**

```json
{
  "name": "my-mcp-server",
  "config": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-filesystem"],
    "env": { "HOME": "/Users/me" }
  }
}
```

**Response 200:** `McpStatus`

### POST /mcp/{name}/auth

> `operationId: mcp.auth.start`

Start OAuth for an MCP server.

**Response 200:** `{ "authorizationUrl": "https://..." }`

### POST /mcp/{name}/auth/callback

> `operationId: mcp.auth.callback`

Complete MCP OAuth.

**Request body:** `{ "code": "..." }`  
**Response 200:** `McpStatus`

### POST /mcp/{name}/auth/authenticate

> `operationId: mcp.auth.authenticate`

Full auth flow — starts OAuth and waits for browser callback.

**Response 200:** `McpStatus`

### DELETE /mcp/{name}/auth

> `operationId: mcp.auth.remove`

Remove OAuth credentials.

**Response 200:** `{ "success": true }`

### POST /mcp/{name}/connect

> `operationId: mcp.connect`

Connect to an MCP server.

**Response 200:** `true`

### POST /mcp/{name}/disconnect

> `operationId: mcp.disconnect`

Disconnect from an MCP server.

**Response 200:** `true`

---

## 8. PTY / Terminal

**Base path:** `/pty`

Pseudo-terminal sessions for running shell commands.

### GET /pty

> `operationId: pty.list`

List all active PTY sessions.

**Response 200:** `Pty[]`

### POST /pty

> `operationId: pty.create`

Create a new PTY session.

**Request body:**

```json
{
  "command": "bash",
  "args": ["-l"],
  "size": { "cols": 80, "rows": 24 },
  "environment": { "TERM": "xterm-256color" }
}
```

All fields optional.

**Response 200:** `Pty`

### GET /pty/{ptyID}

> `operationId: pty.get`

**Response 200:** `Pty`

### PUT /pty/{ptyID}

> `operationId: pty.update`

Update PTY properties (e.g. resize).

**Response 200:** `Pty`

### DELETE /pty/{ptyID}

> `operationId: pty.remove`

Terminate and remove a PTY session.

**Response 200:** `true`

### GET /pty/{ptyID}/connect (WebSocket)

> `operationId: pty.connect`

**Protocol: WebSocket**

Upgrade to WebSocket for real-time terminal I/O.

**Query params:** `cursor` (number, optional) — resume from position

| Direction       | Format        | Description                   |
| --------------- | ------------- | ----------------------------- |
| Client → Server | string        | Raw terminal input keystrokes |
| Server → Client | string/binary | Terminal output               |
| Server → Client | `0x00` + JSON | Metadata frame                |

### Pty Schema

```json
{
  "id": "string",
  "command": "bash",
  "args": ["-l"],
  "size": { "cols": 80, "rows": 24 },
  "process": { "pid": 12345 },
  "exitCode": null
}
```

---

## 9. Permissions

**Base path:** `/permission`

When the AI needs to perform a sensitive action (file write, shell command), it requests permission.

### GET /permission

> `operationId: permission.list`

List all pending permission requests.

**Response 200:** `PermissionRequest[]`

### POST /permission/{requestID}/reply

> `operationId: permission.reply`

Approve or deny a permission request.

**Request body:**

```json
{
  "reply": "allow",
  "message": "Optional reason"
}
```

Valid `reply` values: `"allow"`, `"deny"`, `"allow_always"`, `"deny_always"`

**Response 200:** `true`

---

## 10. Questions

**Base path:** `/question`

When the AI asks the user a multiple-choice or free-form question.

### GET /question

> `operationId: question.list`

List all pending questions.

**Response 200:** `QuestionRequest[]`

### POST /question/{requestID}/reply

> `operationId: question.reply`

Answer a question.

**Request body:**

```json
{
  "answers": ["Selected option label"]
}
```

**Response 200:** `true`

### POST /question/{requestID}/reject

> `operationId: question.reject`

Reject/dismiss a question.

**Response 200:** `true`

---

## 11. File Operations

**Base path:** root (`/`)

### GET /find?pattern={pattern}

> `operationId: find.text`

Search file contents using ripgrep.

**Query params:** `pattern` (string, required)

**Response 200:** Array of match objects

### GET /find/file?query={query}

> `operationId: find.files`

Search for files by name/pattern.

**Query params:**

| Param   | Type                  | Default  | Description         |
| ------- | --------------------- | -------- | ------------------- |
| `query` | string                | required | Search query        |
| `dirs`  | `"true"\|"false"`     | `"true"` | Include directories |
| `type`  | `"file"\|"directory"` | —        | Filter by type      |
| `limit` | number                | 10       | Max results (1-200) |

**Response 200:** `string[]` (file paths)

### GET /find/symbol?query={query}

> `operationId: find.symbols`

Search workspace symbols via LSP.

**Response 200:** `Symbol[]` (currently returns `[]` — not yet implemented)

### GET /file?path={path}

> `operationId: file.list`

List files and directories at a path.

**Response 200:** `FileNode[]`

### GET /file/content?path={path}

> `operationId: file.read`

Read file contents.

**Response 200:** `FileContent`

### GET /file/status

> `operationId: file.status`

Get git status of all files.

**Response 200:** `FileInfo[]`

---

## 12. Standalone Root Endpoints

These are mounted directly on the root path.

### GET /path

> `operationId: path.get`

Get important system paths.

**Response 200:**

```json
{
  "home": "/Users/you",
  "state": "/Users/you/.local/state/opencode",
  "config": "/Users/you/.config/opencode",
  "worktree": "/path/to/project",
  "directory": "/path/to/project"
}
```

### GET /vcs

> `operationId: vcs.get`

Get version control info.

**Response 200:** Git branch info object

### GET /command

> `operationId: command.list`

List all available slash commands.

**Response 200:** `CommandInfo[]`

### GET /agent

> `operationId: app.agents`

List available AI agents.

**Response 200:**

```json
[
  { "name": "build", "description": "Default agent for development" },
  { "name": "plan", "description": "Read-only analysis agent" }
]
```

### GET /skill

> `operationId: app.skills`

List available skills.

**Response 200:** `SkillInfo[]`

### GET /lsp

> `operationId: lsp.status`

Get Language Server Protocol status.

**Response 200:** LSP status object

### GET /formatter

> `operationId: formatter.status`

Get formatter status.

**Response 200:** Formatter status object

### POST /log

> `operationId: app.log`

Write a log entry to the server log.

**Request body:**

```json
{
  "service": "mobile-app",
  "level": "info",
  "message": "Connected successfully",
  "extra": {}
}
```

**Response 200:** `true`

### POST /instance/dispose

> `operationId: instance.dispose`

Dispose the current instance.

**Response 200:** `true`

### GET /doc

Get the full OpenAPI 3.1.1 specification as JSON. No operationId — utility endpoint.

### GET /event

> `operationId: event.subscribe`

**Protocol: Server-Sent Events (SSE)**

Subscribe to events for the current workspace instance only (unlike `/global/event` which covers all instances).

**Response stream:**

```
data: {"type":"server.connected","properties":{}}
data: {"type":"session.created","properties":{"info":{...}}}
data: {"type":"server.heartbeat","properties":{}}
```

---

## 13. TUI Control

**Base path:** `/tui`

Remote control interface for the Terminal UI. A mobile app can use these to drive the TUI running on the server.

### POST /tui/append-prompt

> `operationId: tui.appendPrompt`

Append text to the prompt input field.

**Request body:** `{ "text": "some text" }`

### POST /tui/submit-prompt

> `operationId: tui.submitPrompt`

Submit the current prompt (equivalent to pressing Enter).

### POST /tui/clear-prompt

> `operationId: tui.clearPrompt`

Clear the prompt input.

### POST /tui/execute-command

> `operationId: tui.executeCommand`

Execute a TUI command.

**Request body:**

```json
{ "command": "session_new" }
```

**Available commands:**

| Command                   | Maps to                 |
| ------------------------- | ----------------------- |
| `session_new`             | Create new session      |
| `session_share`           | Share session           |
| `session_interrupt`       | Interrupt AI            |
| `session_compact`         | Compact context         |
| `messages_page_up`        | Scroll up (page)        |
| `messages_page_down`      | Scroll down (page)      |
| `messages_line_up`        | Scroll up (line)        |
| `messages_line_down`      | Scroll down (line)      |
| `messages_half_page_up`   | Scroll up (half page)   |
| `messages_half_page_down` | Scroll down (half page) |
| `messages_first`          | Scroll to top           |
| `messages_last`           | Scroll to bottom        |
| `agent_cycle`             | Cycle to next agent     |

### POST /tui/open-help

> `operationId: tui.openHelp`

### POST /tui/open-sessions

> `operationId: tui.openSessions`

### POST /tui/open-themes

> `operationId: tui.openThemes`

### POST /tui/open-models

> `operationId: tui.openModels`

### POST /tui/select-session

> `operationId: tui.selectSession`

Navigate TUI to display a specific session.

**Request body:** `{ "sessionID": "session_..." }`

### POST /tui/show-toast

> `operationId: tui.showToast`

Show a toast notification in the TUI.

### POST /tui/publish

> `operationId: tui.publish`

Publish an arbitrary TUI event.

**Request body:** `{ "type": "event.type", "properties": {...} }`

### GET /tui/control/next

> `operationId: tui.control.next`

Get the next queued TUI request (long-polling).

### POST /tui/control/response

> `operationId: tui.control.response`

Submit a response to a TUI request.

---

## 14. Experimental APIs

**Base path:** `/experimental`

These APIs may change without notice.

### GET /experimental/tool/ids

> `operationId: tool.ids`

List all available tool IDs.

**Response 200:** `string[]`

### GET /experimental/tool?provider={id}&model={id}

> `operationId: tool.list`

List tools with their JSON Schema parameters for a specific provider/model.

**Response 200:**

```json
[
  {
    "id": "bash",
    "description": "Run a shell command",
    "parameters": { "type": "object", "properties": { "command": { "type": "string" } } }
  }
]
```

### POST /experimental/worktree

> `operationId: worktree.create`

Create a git worktree.

### GET /experimental/worktree

> `operationId: worktree.list`

List worktree directories.

**Response 200:** `string[]`

### DELETE /experimental/worktree

> `operationId: worktree.remove`

Remove a worktree.

### POST /experimental/worktree/reset

> `operationId: worktree.reset`

Reset a worktree to the default branch.

### GET /experimental/session

> `operationId: experimental.session.list`

List sessions across ALL projects (global view). Supports pagination.

**Query params:**

| Param       | Type    | Description                          |
| ----------- | ------- | ------------------------------------ |
| `directory` | string  | Filter by project directory          |
| `roots`     | boolean | Only root sessions                   |
| `start`     | number  | Sessions updated on/after (ms epoch) |
| `cursor`    | number  | Pagination cursor (ms epoch)         |
| `search`    | string  | Title search                         |
| `limit`     | number  | Max results                          |
| `archived`  | boolean | Include archived (default false)     |

**Pagination:** Response header `x-next-cursor` contains the timestamp for the next page.

**Response 200:** `GlobalSession[]`

### GET /experimental/resource

> `operationId: experimental.resource.list`

List MCP resources from connected servers.

**Response 200:** `Record<string, McpResource>`

### Workspace Management

#### POST /experimental/workspace

> `operationId: experimental.workspace.create`

#### GET /experimental/workspace

> `operationId: experimental.workspace.list`

#### DELETE /experimental/workspace/{id}

> `operationId: experimental.workspace.remove`

---

## Key Schemas

### Session

```json
{
  "id": "session_abc123",
  "slug": "my-session",
  "projectID": "string",
  "workspaceID": "string (optional)",
  "directory": "/path/to/project",
  "parentID": "session_... (optional, if forked)",
  "title": "Session title",
  "version": "0.1.79",
  "summary": {
    "additions": 42,
    "deletions": 10,
    "files": 3,
    "diffs": []
  },
  "share": { "url": "https://opencode.ai/s/abc123" },
  "revert": {
    "messageID": "message_...",
    "partID": "part_...",
    "snapshot": "hash",
    "diff": "..."
  },
  "permission": {},
  "time": {
    "created": 1700000000000,
    "updated": 1700001000000,
    "compacting": null,
    "archived": null
  }
}
```

### Message (discriminated union on `role`)

**User message:**

```json
{
  "role": "user",
  "id": "message_...",
  "sessionID": "session_...",
  "time": { "created": 1700000000000 },
  "agent": "build",
  "model": { "providerID": "anthropic", "modelID": "claude-sonnet-4-20250514" },
  "format": { "type": "text" },
  "summary": { "title": "...", "body": "...", "diffs": [] },
  "system": "extra prompt",
  "tools": { "bash": true },
  "variant": "string"
}
```

**Assistant message:**

```json
{
  "role": "assistant",
  "id": "message_...",
  "sessionID": "session_...",
  "parentID": "message_... (user msg)",
  "agent": "build",
  "modelID": "claude-sonnet-4-20250514",
  "providerID": "anthropic",
  "mode": "string (deprecated)",
  "time": {
    "created": 1700000000000,
    "completed": 1700000005000
  },
  "cost": 0.0042,
  "tokens": {
    "total": 1500,
    "input": 1000,
    "output": 400,
    "reasoning": 100,
    "cache": { "read": 800, "write": 200 }
  },
  "error": null,
  "path": { "cwd": "/path", "root": "/path" },
  "summary": false,
  "structured": null,
  "finish": "stop"
}
```

### Part (discriminated union on `type`)

Every part has base fields: `id`, `sessionID`, `messageID`.

| Type          | Key Fields                             | Description        |
| ------------- | -------------------------------------- | ------------------ |
| `text`        | `text`, `time.{start,end}`, `metadata` | Text content       |
| `reasoning`   | `text`, `time.{start,end}`, `metadata` | Thinking/reasoning |
| `tool`        | `tool`, `callID`, `state`              | Tool invocation    |
| `file`        | `mime`, `url`, `filename`, `source`    | Attached file      |
| `snapshot`    | `snapshot`                             | Git snapshot hash  |
| `patch`       | `hash`, `files[]`                      | Git patch          |
| `step-start`  | `snapshot`                             | AI step started    |
| `step-finish` | `cost`, `tokens`, `reason`             | AI step completed  |
| `subtask`     | `prompt`, `description`, `agent`       | Sub-agent task     |
| `compaction`  | `auto`, `overflow`                     | Context compaction |
| `agent`       | `name`                                 | Agent marker       |
| `retry`       | `attempt`, `error`                     | Retry after error  |

### ToolState (discriminated union on `status`)

```jsonc
// Pending — tool call parsed but not started
{ "status": "pending", "input": {...}, "raw": "..." }

// Running — tool executing
{ "status": "running", "input": {...}, "title": "Reading file.ts",
  "metadata": {...}, "time": { "start": 1700000000000 } }

// Completed — success
{ "status": "completed", "input": {...}, "output": "file contents...",
  "title": "Read file.ts", "metadata": {...},
  "time": { "start": 1700000000000, "end": 1700000001000 } }

// Error — tool failed
{ "status": "error", "input": {...}, "error": "File not found",
  "metadata": {...}, "time": { "start": 1700000000000, "end": 1700000001000 } }
```

### FileDiff

```json
{
  "file": "src/main.ts",
  "before": "original content",
  "after": "modified content",
  "additions": 5,
  "deletions": 2,
  "status": "modified"
}
```

`status`: `"added"`, `"deleted"`, or `"modified"`

### Config

```json
{
  "provider": {
    "anthropic": {
      "models": {
        "claude-sonnet-4-20250514": { "temperature": 0.7 }
      }
    }
  },
  "model": {
    "providerID": "anthropic",
    "modelID": "claude-sonnet-4-20250514"
  },
  "mcp": {
    "server-name": {
      "command": "npx",
      "args": ["-y", "some-mcp-server"],
      "env": {}
    }
  },
  "instructions": "Custom system prompt additions",
  "theme": "opencode",
  "disabled_providers": ["ollama"],
  "enabled_providers": ["anthropic", "openai"]
}
```

### Error Types (in assistant message `.error`)

| Error Name                 | Data Fields                                                                               |
| -------------------------- | ----------------------------------------------------------------------------------------- |
| `ProviderAuthError`        | `providerID`, `message`                                                                   |
| `UnknownError`             | `message`                                                                                 |
| `MessageOutputLengthError` | _(none)_                                                                                  |
| `MessageAbortedError`      | `message`                                                                                 |
| `StructuredOutputError`    | `message`, `retries`                                                                      |
| `ContextOverflowError`     | `message`, `responseBody?`                                                                |
| `APIError`                 | `message`, `statusCode?`, `isRetryable`, `responseHeaders?`, `responseBody?`, `metadata?` |
