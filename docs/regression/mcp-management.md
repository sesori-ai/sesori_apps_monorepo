# MCP Management

## Capability

Backend-neutral inventory contracts describe configured servers and offered
connectors. The optional plugin read interface and shared wire models are
implemented. `POST /mcp/inventory` reads Claude Code inventory from an existing
resident session. Client views and management actions are not yet exposed.
Existing permission flows remain separate.

## Required Behavior

- Harness, project, and session scopes are explicit variants. Plugin scope IDs
  are native bindings; shared scope IDs belong to the bridge catalog.
- A configured server and an offered connector have distinct target types,
  including when their opaque keys happen to match.
- Server connection, authorization, configuration origin, and tool discovery
  are separate values. Authentication alone grants no tool permission.
- Server and connector sections report availability independently; failure of
  one section never turns into a successful empty catalog or hides the other.
- Unknown response states degrade to unknown/unavailable variants. Request scope
  and target variants remain closed and invalid requests are rejected.
- Unavailable or failed discovery is distinct from a successfully discovered
  empty tool catalog. Connector-catalog unavailability leaves server inventory
  readable; an offer has no invented server status or tool list.
- Wire metadata contains no native commands, arguments, environment, headers,
  credentials, or full endpoint URL. An endpoint origin is presentation metadata.
- An inventory read does not launch or resume an agent, authenticate a server,
  execute a tool, or write configuration. The optional API declares this contract;
  Claude reads only the named resident process and reports live-session-required
  when none exists. The bridge uses active lifecycle access without starting a plugin.
- Session requests must name the owning integration; the bridge resolves the
  native session ID from its durable binding. Project reads resolve the current
  catalog path; missing IDs never become native paths. Claude supports session
  inventory only, with explicit unsupported states for project/harness reads.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Read a live Claude session through the headless route; compare with native status. |
| L2 Routine | Automated codec and adapter/route coverage described below. |
| L3 Release | No additional coverage. |
| L4 Extended | No additional coverage. |
| L5 Full | No additional coverage. |

Automated codec checks preserve distinct targets, empty/unavailable/failed tool
states, authorization without grants, independent section availability, and
unknown response states. These require no plugin or native process. Adapter and
route tests prove safe metadata, resident-only reads, owner validation, scope
rebinding, and inactive/unsupported states.

## Exploration Guidance

Vary scopes, equal server/offer keys, missing nullable metadata, and discovery
states. Verify the decoded type as well as the serialized discriminator. Read
an inactive session without spawning a process, reject a mismatched plugin, and
compare a project ID with its moved catalog path. Live route smoke remains a
manual qualification; unit tests do not prove a real relay or native runtime.

## Failure Signals

- A connector offer becomes a server target or gains server-only state.
- Discovery failure becomes an empty catalog, or an unavailable connector
  catalog hides otherwise readable servers.
- Authorization implies a permission grant or native configuration enters a
  shared inventory payload.

## Evidence

The owning automated coverage is `shared/sesori_shared/test/models/mcp_test.dart`.
Pinned native protocol evidence is recorded in
[HARNESS_CAPABILITIES.md](../HARNESS_CAPABILITIES.md); it does not qualify a
Sesori management flow before an adapter and route are implemented.

Automated adapter/route coverage:

- `bridge/sesori_plugin_claude/test/claude_mcp_mapper_test.dart`
- `bridge/sesori_plugin_claude/test/claude_session_process_repository_test.dart`
- `bridge/app/test/bridge/routing/post_mcp_inventory_handler_test.dart`
