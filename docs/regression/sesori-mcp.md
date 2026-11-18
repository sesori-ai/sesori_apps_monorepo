# Sesori MCP For Agents

## Capability

The bridge serves its own MCP server, `sesori_bridge`, to agents in the harness sessions it launches, so an agent can
work with the computer's scheduled tasks through the same bridge services the app uses. It serves the protocol
handshake and no tools yet. The server is streamable HTTP on `127.0.0.1` with an ephemeral port, JSON responses only, and a per-launch bearer token
that names the calling session. `sesori-bridge config agent-tools on|off` (default on) decides whether launches get a
token at all.

No plugin injects the server yet, so no harness can reach it; until a plugin does, every check below runs headlessly
against the endpoint. The read tools, proposing tools with user approval and the per-harness injection are later steps
of the plan.

## Required Behavior

- The endpoint binds only the loopback interface before any plugin starts and closes at shutdown after in-flight
  answers finish.
- It refuses before reading the body: any `Origin` header (403), a `Host` other than `127.0.0.1` or `localhost` with its
  own port (403), another path (404), another method (405 with `Allow: POST`), a non-JSON content type (415), a
  declared body over 1 MiB (413), and a missing or non-Bearer `Authorization` (401). A streamed body over 1 MiB is read
  without being kept and refused with 413.
- Tokens are 256 random bits, held in memory only, one per launch. A token the bridge never minted, including one from
  before a restart, gets HTTP 401 for every method. A minted token that is not yet bound to a backend session may
  `initialize`, `ping` and list tools.
- A bound token resolves to the Sesori session that holds its plugin and backend session id, read from the session row
  at each call. A token never resolves to another plugin's session with the same backend id.
- With `agent-tools` off, `SesoriMcpAccess.mint()` returns null, so no launch gets a token. The setting is read at each
  launch; a CLI change needs a bridge restart.
- `initialize` echoes a supported protocol version (`2024-11-05` through `2025-11-25`) and otherwise offers the newest.
  Notifications get 202 with no body. Malformed JSON is -32700, an unknown method -32601, an unknown tool -32602.
- `tools/list` is empty until the read tools land.
- Request bodies are never logged.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included: no harness reaches the server yet. |
| L2 Routine | Automated: `sesori_mcp_access_test.dart` (mint, bind, unknown and post-restart tokens, the setting, caller resolution from session rows), `sesori_mcp_server_test.dart` (loopback bind, Origin, Host, path, method, content type, bearer and size refusals), and `sesori_mcp_endpoint_test.dart` (protocol handshake, unbound and unknown tokens). |
| L3 Release | No additional coverage: no plugin injects the server yet. Each injection step adds its live harness check here (the server listed, a call resolving to the right session, no token in argv, URLs or harness session files). |
| L4 Extended | No additional coverage. |
| L5 Full | No additional coverage. |

## Exploration Guidance

Vary the token (missing, wrong scheme, unknown, minted but unbound, bound to a deleted session), the Host header
(`localhost`, another port, a public name) and the body size around 1 MiB. Use fixture data only.

## Material Failure Signals

- The endpoint answers on a non-loopback address, or accepts a request carrying `Origin` or a foreign `Host`.
- A token appears in argv, a URL, a log line or a harness config file.
- An unknown or pre-restart token gets anything but 401.
- A token resolves to the wrong session or another plugin's session.
- A request body shows up in bridge logs.

## Known Limitations

- No harness injects the server yet; per-harness support lands with the injection steps and is recorded in
  [harness capabilities](../HARNESS_CAPABILITIES.md).
- Tokens are not revoked when a harness process exits; they live until the bridge stops.

## Harness Scope

Harness-neutral: the endpoint and tools live in `bridge/app`. Each injection step adds its harness here.

## Related Coverage and Sources

- [Scheduled tasks](scheduled-tasks.md), [MCP management](mcp-management.md),
  [Session history and recovery](session-history-and-recovery.md).
- Bridge: `SesoriMcpServer` (`foundation/`), `SesoriMcpRequestDispatcher` (`routing/sesori_mcp/`),
  `SesoriMcpAccessService`, `SesoriMcpGrantRepository` and `BridgeSesoriMcpAccessImpl` under `bridge/app/lib/src/`,
  with tests under `bridge/app/test/bridge/sesori_mcp/`.
- Plugin contract: `SesoriMcpAccess` and `SesoriMcpLaunch` in `bridge/sesori_plugin_interface`.
- Plan: [.plan/active/sesori-mcp/PLAN.md](../../.plan/active/sesori-mcp/PLAN.md).
