# MCP Management

## Capability

Backend-neutral inventory contracts describe configured servers and offered
connectors. The optional plugin read interface and shared wire models are
implemented. `POST /mcp/inventory` reads Claude Code inventory from an existing
resident session. Phone and desktop expose a shared read-only inventory and
server-details view backed by the typed loading lifecycle. `POST /mcp/entry/action`
exposes explicit live-session Claude reconnect, enable and disable controls to
headless consumers. Claude native plugin authentication is implemented for
existing configured HTTP servers. Headless read/start/continue/cancel routes are
implemented; product action UI remains pending.
Existing permission flows remain separate. Read-only inventory may inspect an
archived session if its native process remains live; it grants no session mutation.

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
- Known native control rejection, process-exit and timeout failures produce a
  typed read-failed state. Original causes and stacks remain in local bridge logs;
  native error payloads are not returned as inventory metadata.
- An inventory read does not launch or resume an agent, authenticate a server,
  execute a tool, or write configuration. The optional API declares this contract;
  Claude reads only the named resident process and reports live-session-required
  when none exists. The bridge uses active lifecycle access without starting a plugin.
- Each server declares supported controls and their effect scope separately from
  configuration source/access. Claude controls affect only the resident session;
  they do not rewrite configuration or grant authentication/tool permission.
- Action requests carry a server target; connector targets are rejected even with
  equal key text. The bridge validates stored session ownership and rejects archived
  mutations. Unsupported/inactive scopes do not activate a plugin or agent session.
- Completed controls return an authoritative inventory read. A failed read after
  completion remains read-failed; an acknowledgement never implies connection.
  Known native control failures keep original causes/stacks in local logs and
  produce a typed failure without raw native error data on the wire.
- The bridge emits `mcp.inventory.changed` after native completion. Open client
  views refresh only when the selected plugin and scope match, using their existing
  reconnect/coalescing lifecycle. No background polling or configuration writer.
- Session requests must name the owning integration; the bridge resolves the
  native session ID from its durable binding. Project reads resolve the current
  catalog path; missing IDs never become native paths. Claude supports session
  inventory only, with explicit unsupported states for project/harness reads.
- Each client inventory view owns its loading service. Scope changes and changed
  connection configuration clear prior inventory and discard older responses.
- Refresh errors and reconnects with the same connection configuration preserve
  readable details, with a separate refresh state. Staleness signals wait while
  offline and coalesce into reads after reconnect; no background polling occurs.
- A staleness signal arriving during a read still triggers a follow-up read, even
  if the first read fails. Closing the view cancels listeners and fences its read.
- HTTP 404 retains a missing-route-or-entity result; it does not assert that the
  bridge is old. A 404 refresh preserves readable inventory with a distinct
  refresh result. Native read failures remain distinct from unsupported inventory.
- Unrecognized inventory results are explicit read states, never loaded catalogs.
  An unrecognized refresh preserves the last readable snapshot.

- Session menus request the session scope; harness settings request harness scope.
  Unsupported scope/integration messages do not imply empty inventory.
- The inventory opens above the underlying session/settings page. Server details
  use a separate presentation layer; closing either returns to the previous view.
- Refresh feedback occupies a stable header area. Existing inventory remains
  scrollable, with stable target keys and no offset reset during refresh failure.
- Archived and sub-agent sessions retain the read-only MCP menu entry; session mutations stay hidden.
- Archived control requests return HTTP 409 with the canonical session ID and
  `archived_read_only` reason, without accessing the native plugin.
- Unknown entries show an upgrade hint instead of claiming an empty available catalog.
- Offline refresh controls are disabled. Server details retain the fixed refresh
  status header and distinguish a removed server from a failed inventory read.
- Connection, authentication, configuration origin/access, and tools are shown
  separately. Endpoint origins are plain text, not browser-launch actions.

## Native authentication boundary

The shared authentication wire contract carries one attempt's ID, plugin and
server target, native cancellation availability, and sealed current states.
Callback-challenge state carries the authorization and expected callback URLs;
the continue request carries the submitted `callbackUrl` and matching attempt ID.
These URL values are request-scoped, never SSE replay or persistence. The cancel
request also carries the matching attempt ID. Unknown response,
state and enum values degrade explicitly. Callback request presentation and
malformed-body errors do not reflect credential input, while errors retain a
typed original cause. Codec and privacy coverage lives in
`shared/sesori_shared/test/models/mcp_authentication_test.dart`.
Headless read/start/continue/cancel routes use this contract. Client authentication
actions remain pending.

The optional plugin API can sign in to an existing live Claude session's
native-configured HTTP server and clear its native credentials. This is a
native plugin boundary used by the headless attempt owner. Client action UI
remains pending.

- Resolve the exact server and resident directory without starting a session.
  Dynamic/unknown configuration returns a handoff instead of addressing a
  possibly different CLI configuration with the same name.
- Login runs in a terminal through the host process seam. Native exit and cleanup
  establish completion; browser opening alone does not.
- Callback origin, path and OAuth state must match the native challenge. Reject
  invalid callbacks without writing to the child; provider denial stops it.
- URL/completion deadlines and cancellation, including an in-flight spawn, stop
  the owned child and release subscriptions. Errors retain their causes without
  printing authentication URLs or callbacks. A simultaneous native and cleanup
  failure retains both causes/stacks and the original failure classification.
- Credential clearing uses the native CLI and leaves MCP server definitions
  unchanged. It does not disable or remove a server.
- macOS arm64 is qualified with both pins. Linux qualification, Windows terminal
  integration and SSE authentication remain pending; retain explicit unavailable
  results until those boundaries land and pass their native checks.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Inspect live Claude MCP inventory and exercise controls without changing persisted configuration. |
| L2 Routine | Automated codec, adapter/route, and client lifecycle coverage described below. |
| L3 Release | No additional coverage. |
| L4 Extended | No additional coverage. |
| L5 Full | No additional coverage. |

For L1, read a live Claude session through the headless route, compare its
servers/tools with native status, and inspect them from a client session menu.
Exercise explicit live-session controls and confirm persisted configuration is unchanged.

Automated codec checks preserve distinct targets, empty/unavailable/failed tool
states, authorization without grants, independent section availability, and
unknown response states. These require no plugin or native process. Adapter and
route tests prove safe metadata, resident-only reads, owner validation, scope
rebinding, and inactive/unsupported states. Client tests cover refresh failures,
offline staleness, reconnect, scope/connection changes, and disposal in flight.

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
- Old responses appear under a changed scope or connection, a refresh failure
  removes readable details, or an offline client polls for inventory.

## Evidence

The owning automated coverage is `shared/sesori_shared/test/models/mcp_test.dart`.
Pinned native protocol evidence is recorded in
[HARNESS_CAPABILITIES.md](../HARNESS_CAPABILITIES.md); it does not qualify a
full Sesori management flow on its own; native protocol evidence, adapter tests,
and real route/client qualification are distinct.

Native authentication lifecycle, callback validation, denial and expiry coverage
is in `bridge/sesori_plugin_claude/test/claude_mcp_login_repository_test.dart`.
Resident context coverage remains in the process-repository tests below.

Automated adapter/route coverage:

- `bridge/sesori_plugin_claude/test/claude_mcp_mapper_test.dart`
- `bridge/sesori_plugin_claude/test/claude_session_process_repository_test.dart`
- `bridge/app/test/bridge/routing/post_mcp_inventory_handler_test.dart`
- `client/module_core/test/services/mcp_service_test.dart`
- `client/module_core/test/repositories/mcp_repository_test.dart`
- `client/module_app_ui/test/features/mcp/mcp_inventory_view_test.dart`

### Headless attempt ownership

- One attempt per bridge is reserved before native preparation. A competing start
  returns busy and leaves its native process, target and challenge untouched.
- Existing runtime generations stay leased through native stream settlement;
  stopped integrations are not activated by authentication. Scope resolution
  checks exact session ownership and canonical archive rejection before starting
  or forwarding a callback. Cancellation remains available for cleanup after archive.
- GET recovers only the current state across client reconnects. Challenge URLs
  remain request-scoped; `mcp.authentication.changed` contains only its event type.
- Authorization launch destinations must be absolute HTTPS with a nonempty host
  and no user info. HTTP, relative, file, data, javascript and custom schemes are
  rejected before any challenge reaches a client. Native callbacks are distinct
  and validated by the owning plugin; they are never arbitrary HTTP forwarding.
- A callback needs the active attempt ID and current challenge. Rejected native
  callbacks preserve the challenge for retry. Unexpected native submission errors
  retain settling because delivery may have occurred. Submitted callbacks enter settling;
  a browser return alone does not complete authentication.
- Read-only preparation can be cancelled without waiting for a stalled native
  status request. A late prepared operation is discarded without subscribing,
  and native effects start only after the owner knows cancellation availability.
- Cancellation waits for native resource cleanup and releases the leased stream;
  it does not depend on the native stream voluntarily emitting done. Duplicate
  cancel requests return settling, while cancellation after callback submission
  remains available when the native API supports it. An API
  without cancellation returns an explicit unavailable result and retains the
  attempt until native settlement; dismissing client UI does not cancel it.
  Forced runtime/bridge teardown interrupts the owner before routed request drain,
  resolves request waiters even on cleanup failure, and does not claim native
  cancellation on such APIs.
- Native completion invalidates the declared affected inventory. Harness-wide
  credential changes refresh open session inventories for that plugin. Connection
  and tool discovery remain separate native facts requiring refreshed inventory.
- Route/ownership/privacy coverage is in
  `bridge/app/test/bridge/routing/mcp_authentication_handler_test.dart`; active-only
  lease coverage is in the runtime suite and harness-wide client invalidation is
  covered by `client/module_core/test/services/mcp_service_test.dart`.

### Client browser sharing

The existing browser transport now accepts bridge/connection/purpose-bound owner handles and returns typed busy for a
competing flow. Matching retry/cancel protects provider and MCP callback listeners in both start orders. Provider busy
presentation retains its issued challenge for explicit retry. This transport seam is implemented; MCP client lifecycle
and visible MCP authentication controls remain pending. The headless owner and final qualification matrix are unchanged.
