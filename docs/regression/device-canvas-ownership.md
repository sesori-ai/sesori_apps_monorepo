# Device Canvas Ownership

## Capability

Bridge-authoritative ownership of locally discovered Device Canvas simulators,
including client presentation, exact-session deep links, and OpenCode-native
list, claim, and release tools.

## Required Behavior

- The bridge database is the only claim authority. Claims are scoped to the
  current bridge identity and canonical `Session.id`; presence and Device Canvas
  connectivity are independent ephemeral state.
- A first claim succeeds, a repeat by the same session is idempotent, and a
  different session conflicts without stealing. Release is owner-scoped and
  idempotent. Only an authenticated human reassignment path can replace an
  owner; agent tools never accept force, bridge identity, or canonical session
  identity as model input.
- Device Canvas publishes bounded inventory through authenticated loopback IPC.
  Disconnect and device stop change availability without releasing ownership.
  Explicit release, session archive or deletion, and bridge-identity replacement
  remove the applicable claims.
- Client status keeps online presence separate from ownership and degrades when
  used with an older unsupported bridge. A Device Canvas deep link carries the
  exact bridge and session identity, resolves the canonical project before
  opening session detail, and loads no session content before verification.
- Managed OpenCode exposes exactly `list_simulators`, `claim_simulator`, and
  `release_simulator`. Its adapter binds trusted invocation `context.sessionID`
  to the stored `(pluginId, backendSessionId)` session before calling the neutral
  claim service. Results expose bounded device metadata and only ownership
  relative to the caller, never another session's identity, project, path,
  prompt, or transcript.
- The OpenCode adapter uses a loopback-only server, an owner-readable
  rendezvous, and a bridge-generated bootstrap credential exchanged for an
  in-memory bearer token. Each OpenCode spawn receives only the path to an
  owner-only one-time credential file; registration consumes that file. The
  credential itself never enters the child environment, capability paths are
  removed from process and shell environments by the loaded adapter, and
  nothing is forwarded when injection fails.
- OpenCode startup writes only bridge-managed plugin/config files. It warms the
  native tool registry and requires an authenticated readiness marker before a
  configured managed runtime is healthy. Device Canvas disconnection
  hard-disables operations with a typed unavailable result; bridge shutdown
  stops intake, drains accepted work, and removes the rendezvous file.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Automated bridge coverage proves canonical binding, idempotent claim/release, conflict without reassignment, privacy-safe bounded listing, disconnected behavior, bridge-rotation cleanup, loopback authentication, request bounds, and rendezvous cleanup. OpenCode package coverage proves the exact native tool surface, trusted context use, config isolation, capability stripping, and readiness gating. |
| L2 Routine | Headless bridge with a Device Canvas fixture and two stored OpenCode sessions exercises list, claim, repeat, conflict, wrong-owner release, owner release, archive cleanup, Device Canvas disconnect/reconnect, and bridge restart. A live managed OpenCode runtime must advertise exactly the three native tools through its real tool registry. |
| L3 Release | Live OpenCode agent plus Device Canvas and Sesori client: two real sessions demonstrate relative listing, claim, repeat, conflict, release, inability to act as another canonical session, ownership badges/accessibility, and exact deep-link navigation. Client end to end and live plugin on the release-target bridge host. |
| L4 Extended | Device Canvas and bridge takeover/restart in both orders; device stop/restart; OpenCode crash/restart; malformed, oversized, unauthorized, and stalled local requests; archive/deletion during activity; alternate client platform; older client/new bridge and new client/older bridge degradation. |
| L5 Full | Packaged Sesori and Device Canvas builds across supported bridge hosts with large bounded inventories, multiple concurrent sessions and devices, repeated lifecycle recovery, and every documented compatible version pairing. |

## Exploration Guidance

Vary which session claims first, whether devices are iOS or Android, whether a
device or Device Canvas disconnects before or after a mutation, and whether the
bridge or OpenCode restarts while claims exist. Use unrelated canonical and
backend session IDs so an accidental identity shortcut is visible. Restore
claims, sessions, plugin eligibility, and local processes after the run.

## Failure Signals

- A model can provide `sessionId`, `bridgeId`, or force; one session can mutate
  another session's claim; a conflict reveals owner identity or content.
- Device or IPC loss releases ownership, stale bridge identity leaves a durable
  late claim, or archive/deletion leaves an owned device behind.
- Inventory or tool output is unbounded or includes project paths, prompts,
  transcripts, account data, or another session's identity.
- The local server binds beyond loopback, accepts bootstrap/bearer mismatches,
  leaves a rendezvous after shutdown, or exposes credentials to another bridge
  backend or an OpenCode shell when injection is absent or failed.
- A managed OpenCode runtime reports healthy before its configured native
  adapter registers, modifies user/project configuration, advertises extra
  simulator tools, or accepts claims while Device Canvas is unavailable.
- A deep link opens the wrong bridge/session, guesses project identity, or loads
  session content before exact resolution.

## Known Limitations

- Autonomous simulator tools are currently OpenCode-only and require a
  bridge-managed OpenCode process. Attach mode is unchanged because the bridge
  cannot safely inject a trusted invocation adapter into an existing process.
- OpenCode's current plugin API does not dynamically unregister native tools.
  Definitions remain visible after Device Canvas disconnects, but every
  operation is hard-disabled with `integrationUnavailable` until reconnection.
- User-installed OpenCode plugins execute inside the same trusted backend
  process. Capability isolation protects other bridge backends and model shell
  commands; it is not a sandbox against a malicious in-process OpenCode plugin.
- Remote video and control are not part of Phase 1 ownership behavior.

## Sources

- `bridge/app/lib/src/services/device_canvas_claim_service.dart`
- `bridge/app/lib/src/services/device_canvas_agent_tool_service.dart`
- `bridge/app/lib/src/bridge/device_canvas/`
- `bridge/sesori_plugin_opencode/lib/src/runtime/open_code_device_canvas_tools.dart`
- `bridge/sesori_plugin_opencode/lib/src/runtime/open_code_runtime_policy.dart`
- Focused tests under `bridge/app/test/bridge/device_canvas/`,
  `bridge/app/test/bridge/services/`, and
  `bridge/sesori_plugin_opencode/test/runtime/`
- Active plan: `.plan/active/device-canvas-integration/`
