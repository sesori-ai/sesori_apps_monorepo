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
The shared client authentication API, repository, connection-fenced owner and
observing Cubit are implemented; the next presentation step exposes their intents.
Existing permission flows remain separate. Read-only inventory may inspect an
archived session if its native process remains live; it grants no session mutation.

## Required Behavior

- Request-scoped GET recovers the current native attempt on identity establishment,
  reconnect, explicit refresh and `mcp.authentication.changed`. SSE carries no
  challenge or callback URL, and recovery never opens a browser automatically.
- GET remains usable while the original start POST waits for preparation. The
  reserved attempt can be cancelled; a late start acknowledgement cannot replace
  a newer terminal read. Likewise, a read begun before a mutation cannot overwrite
  that mutation's newer response. Transport uncertainty preserves its typed cause
  and triggers recovery rather than asserting native rejection or success.
- Native observation, request progress and browser presentation are independent.
  Failed refreshes retain the known challenge. Browser busy retains it for explicit
  retry; matching listener retry uses the exact accepted owner and challenge.
- Browser callbacks are bound to the native attempt and connection epoch. A
  disconnect or bridge replacement closes only the matching local owner and fences
  old responses. Recovered attempts require explicit browser intent. Local direct
  browser ownership lasts through native settlement. Closing a Cubit does not
  cancel the shared operation; service disposal waits for already-started cleanup.
- Missing bridge-identity support is an explicit limitation while connected;
  missing authentication routes, unknown results and original API failures stay
  distinct. Browser launch requires HTTPS without user info and an HTTP loopback
  callback. No client credential store or server-configuration writer is added.
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

## Connection controls and sign-in presentation

- Mutable inventory views open “Manage connection” as a separate modal layer.
  Inventory and server details keep their scroll position beneath it. Read-only,
  audit, child and archived session surfaces retain inspection only.
- Only declared native capabilities expose sign-in, reconnect, enable/disable or
  credential forgetting. Every action explains its native effect scope. Unknown
  or unavailable capabilities show the corresponding handoff or limitation.
- Sign-in does not open a browser automatically. A matching native challenge
  exposes an explicit Open browser action; a busy or failed launch retains the
  challenge for retry. Private callback destinations and attempt IDs are absent
  from the presentation. A provider-owned browser is never cancelled by MCP.
- Native observation, request uncertainty and browser state remain independent.
  Native completion remains primary after a lost request response. Fixed status
  slots and reduced-motion-aware text transitions leave controls in place.
- Cancel sign-in targets the observed attempt and respects native-settlement-only
  cancellation. Check sign-in performs an explicit read. Closing a layer or the
  inventory stops observing without cancelling the shared authentication owner;
  reopening reads its current state.
- Credential forgetting requires confirmation explaining native effect scope,
  preserved server definitions and the possibility of an existing live connection.
  Cancelling the confirmation dispatches nothing. Pending native work disables
  repeated management requests, including observed busy authentication operations.
- An action result retains its server target and is not presented as another
  server's outcome. Large text on a phone-sized surface remains scrollable.
- Focused widget coverage: `mcp_inventory_view_test.dart` and
  `mcp_server_controls_view_test.dart` in the shared UI MCP feature tests.

## Native authentication boundary

The shared client entry-action API/repository and per-view owner expose native
server controls and credential forgetting. Shell composition supplies the
read-only posture. Pending actions retain inventory;
completed results apply the native read and supersede earlier inventory requests.
Staleness received during an action still requires a fresh read. API failure
retains the original cause and requires a fresh inventory read, including when an
earlier read is still in flight, without resending the action. Reconnecting the
same bridge restores idle actions while inventory refreshes. An unrecognized
result retains a readable snapshot or reports an unrecognized inventory when
there is no snapshot. Entry actions have a bounded 210-second request budget for
native management and its subsequent inventory discovery.
Late responses after connection replacement, disconnect or view disposal cannot
replace the current snapshot. Result state retains its request/target so later
presentation can distinguish actions on different servers in one inventory view.
The action Cubit observes the inventory owner and does not dispose it. Closing
the inventory view sends no native action cancellation. No action registry,
queue, timer, configuration writer or credential store is added. Focused cases:
`client/module_core/test/services/mcp_service_test.dart` and
`client/module_core/test/repositories/mcp_repository_test.dart` and
`client/module_core/test/api/mcp_api_test.dart`.

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
  unchanged. It does not disable or remove a server. The headless entry action
  accepts only a server target, resolves catalog ownership/archive eligibility
  before native access, and never activates an inactive integration.
  Login and credential forgetting reserve the same native owner in both start
  orders; GET reports busy during forgetting, and shutdown awaits native settlement.
  Successful forgetting invalidates the native declared effect scope and returns
  an authoritative inventory read. A resident may remain connected; no local
  logged-out/disconnected state is invented.
- Servers declare independent sign-in and credential-forgetting availability;
  authorization and configuration mutability do not imply either capability.
  Claude declarations and context resolution use the same eligibility mapping:
  native-configured HTTP servers on terminal-supported hosts are available with
  harness credential effects; stdio is unsupported, SSE/Windows are not implemented,
  and dynamic/unknown/missing configuration requires native setup.
- Public v1.9.1 bridges omit these availability fields: current clients retain
  inventory and decode capability availability as unknown. Exact released
  v1.9.1 MCP codecs accept the added fields without losing existing inventory
  or server-control tags. Preserve both directions of this wire compatibility.
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
presentation retains its issued challenge for explicit retry. The transport seam and shared MCP client lifecycle are
implemented, including request-scoped recovery and explicit browser intent. Visible MCP authentication controls remain
pending. The headless owner and final qualification matrix are unchanged.
