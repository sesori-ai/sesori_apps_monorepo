# OpenCode Mobile API Documentation

Reference documentation for building a Flutter mobile client for OpenCode.

OpenCode uses a **local client/server architecture** — the server runs on the user's machine and exposes an HTTP API that any client (TUI, desktop app, web, mobile) can connect to.

## Documents

| File                                                     | Description                                            |
| -------------------------------------------------------- | ------------------------------------------------------ |
| [API_REFERENCE.md](./API_REFERENCE.md)                   | Complete REST API endpoint reference with schemas      |
| [SSE_EVENTS.md](./SSE_EVENTS.md)                         | Server-Sent Events catalog for real-time updates       |
| [ELECTRON_IPC_REFERENCE.md](./ELECTRON_IPC_REFERENCE.md) | Desktop app capabilities for feature parity planning   |
| [openapi.json](./openapi.json)                           | OpenAPI 3.1.1 spec (machine-readable, use for codegen) |

## Quick Start

```bash
# Start OpenCode in headless server mode, accessible on LAN
opencode serve --port 4096 --hostname 0.0.0.0 --mdns

# With password protection
OPENCODE_SERVER_PASSWORD=mysecret opencode serve --port 4096 --hostname 0.0.0.0 --mdns
```

Then from the Flutter app:

1. Discover via mDNS or manual `host:port` entry
2. `GET /global/health` to verify connection
3. Open SSE stream at `GET /global/event`
4. `GET /session` to list conversations
5. `POST /session/{id}/message` to chat

## Server Basics

| Property         | Value                                                       |
| ---------------- | ----------------------------------------------------------- |
| Framework        | Hono (TypeScript, Bun runtime)                              |
| Default Port     | `4096`                                                      |
| Default Hostname | `127.0.0.1` (use `0.0.0.0` for LAN)                         |
| Protocols        | REST (JSON), SSE, WebSocket                                 |
| Auth             | HTTP Basic Auth (optional, via env var)                     |
| API Spec         | Served at `GET /doc`                                        |
| mDNS             | Optional, service type `_http._tcp`, name `opencode-{port}` |
