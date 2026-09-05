# Bridge Connectivity

## Capability

The live link between a client and a bridge: registration, the authenticated relay
socket and its reconnect policy, encrypted key exchange, single-live-bridge ownership,
explicit restart, and the connection states the app presents.

## Required Behavior

- A start is ready only after registration, socket open, auth frame sent, listeners and
  initial summary set up, and the first inbound read armed; earlier failure tears down
  what was acquired and surfaces the error.
- Relay traffic is end-to-end encrypted and a joining client completes key exchange
  before it is served; one room-key encryptor is shared across that bridge
  session while every encrypted frame receives a fresh nonce.
- Frames are handled sequentially per connection, but a slow route or unresponsive
  harness must not stall key exchange, disconnect detection, or further requests.
- Matched handler failures are mapped at one route boundary: unmatched routes
  remain 404, status-bearing plugin failures preserve their status, statusless
  plugin-operation failures remain 502, and unexpected handler or router
  failures return 500.
- Drops reconnect with bounded backoff and a fresh read iterator; takeover backs off on
  a longer jittered curve, a revoked bridge re-registers, and a token change re-auths.
- Ordered mutation and event lanes continue processing later work after one operation fails, and graceful shutdown drains work accepted before shutdown began.
- The bridge forwards only event kinds something consumes. OpenCode editor and
  runtime housekeeping (PTY, file-watcher, LSP, MCP, installation-updated,
  workspace and worktree notifications) and Codex MCP startup notices stop
  inside their plugins; toast, VCS, file-edited, installation-update-available
  (which feeds the immediate push), command-catalog and lifecycle signals still
  reach clients. A client ignores an unknown event type from an older bridge.
- Deliberate shutdown is not an outage; a handshake cancelled mid-flight closes at
  once and can never later authenticate.
- Client relay disconnect closes active SSE streams and the socket without
  attempting encrypted sends after disposal. The bridge releases the connection's
  SSE subscription when it receives the phone-disconnected notification.
- One live bridge per account holds the slot; a second start resolves ownership
  explicitly, and an explicit restart hands off to its successor cleanly.
- Bridge registration uses a stable machine name. On macOS, transient
  network-derived numeric hostnames must not replace the machine's LocalHostName.
- The client distinguishes connected, reconnecting, connection lost, bridge offline, and
  disconnected, and returns to connected when the bridge is back. The desktop shell
  roots the same `ConnectionService` beside the supervised control channel, shows
  its relay-client state separately from helper relay status, and hosts the typed
  connection banner at the window root. When project loading reports either no
  registered bridge or a registered-but-offline bridge, desktop recovery asks
  the supervisor to Start and establishes an authenticated relay client; it
  never falls through to mobile CLI installation or relay-only reconnect
  guidance.
- The client relay socket pings on an interval, so a silently dead network path
  (Wi-Fi drop, VPN toggle, sleep/wake) surfaces as a socket close and enters
  reconnect within roughly two ping intervals instead of waiting on request
  timeouts or relay-side reaping.
- A reconnect that outlasts the overlay grace window surfaces the reconnecting
  banner on all surfaces; reconnects that resolve within the window (foreground
  resume, bridge handover) stay bannerless.
- The desktop root constructs `ConnectionOverlayCubit` and `SseToastCubit` outside
  the auth-gated content. Backend `tui.toast.show` events reach the desktop Prego
  popup listener rather than being silently consumed; handled shared failures are
  retained in local logs through a privacy-safe reporter that records error/stack
  and operation/event context while reducing payload-bearing information to shape
  metadata. A token-only local restore entering the signed-in desktop destination
  hands off one fresh auth-backed connection to the desktop auth/connection
  coordinator even while the auth session remains provisionally `AuthInitial`;
  the overlay cubit remains stream-derived.
- Fresh connections require the typed health body, including explicit filesystem-access
  degradation state; missing or malformed fields fail the connection rather than being
  treated as healthy. Resumed connections retain the last validated health state.
- The configured sleep policy applies at standalone startup and releases its wake lock on
  shutdown; unsupported lid-close prevention and wake-lock failures warn without aborting.
- In supervised mode, the authenticated local control channel answers helper token
  pulls, reports aggregate status, resolves prompts, unregisters, and accepts clean
  shutdown; loss of its owner exits after the grace period without orphaning backend
  processes. Restart intent is authoritative only through the child exit sentinel.
  The desktop persists the registered bridge ID with its account owner, restores it
  before supervision, and performs idempotent GUI-side deletion only after owner
  verification; token-only local sessions are verified through `/auth/me` when
  connectivity is available.
- Aggregate plugin health is degraded iff any eligible plugin is degraded or failed;
  dormant, not-installed, and zero-eligible snapshots are healthy because eligibility
  is independent from runtime residency. The wire emits healthy/degraded while unknown
  remains the forward-parse fallback.
- A GUI `shutdown` performs the same ordered graceful teardown as standalone stop,
  exits 0 without unregistering, and cannot be reclassified as auth-required when
  teardown cancels an in-flight bootstrap token request.
- The supervised bridge leads a dedicated POSIX process group before starting
  sleep prevention or any other long-lived child; force-stop signals that
  complete live group atomically. Windows uses
  `taskkill /T /F` for the equivalent descendant-tree guarantee.
- Desktop supervision continuously drains both helper pipes with malformed-UTF-8
  tolerance, bounds partial lines and pending persistence, retains the latest 200
  entries, and rotates owner-only local logs. Storage failures and queue overflow
  remain observable without stopping either pipe drain.
- Desktop spawn is authenticated-session-gated. Each attempt starts a fresh
  loopback control server, passes only its URL in argv, writes the fresh secret
  through child stdin, attaches both log pipes, and observes the repository exit
  stream. Any startup failure expected-stops a created child, stops the server,
  restores retryable state, and rethrows the original failure.
- The desktop's single inbound control dispatcher subscribes during shell
  bootstrap, before any helper spawn, so the first token request is answered.
- Desktop exit policy treats 86 as one immediate restart, 87 as login-required
  until a later successful sign-in when desired On, 88 as machine contention,
  and clean or expected exits as stopped. Other exits retry after 1, 2, 4, 8,
  and 16 seconds, then give up with the latest 20 helper log lines. Five minutes
  of control-connected runtime resets that crash budget; every manual Start or
  Off cancels a pending timer before acting.
- Conversational GUI prompt answers are sent only for a prompt still owned by
  the connected helper and clear that prompt only after the frame is accepted
  by the live control socket. Expected shutdown remains repository-owned.
- The desktop tray derives its status, active-session count, and On/Off action
  from the process service and control-status tracker. Quit expected-stops the
  helper before process exit; a stop failure keeps the desktop alive.
- Tray initialization failure keeps the desktop window visible. Linux claims a
  usable tray only when the session bus has a live StatusNotifier watcher, so a
  stock GNOME session without an AppIndicator host cannot become tray-only.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | A started bridge reaches readiness and answers a health request; a connected client reports connected. Headless bridge plus relay integration for the client-visible state; no plugin. |
| L2 Routine | Relay integration for key exchange, a normal drop and reconnect, and clean shutdown; automated and headless bridge for stable machine-name registration plus sleep-policy enable, disable, warning, and wake-lock release. No plugin. |
| L3 Release | The full connection state machine as presented, explicit restart with successor handoff, second-start ownership resolution, and a slow in-flight request not blocking key exchange or further requests. Client end to end plus headless bridge; a representative harness supplies the slow operation. |
| L4 Extended | Relay integration or client end to end for takeover, revocation, pull-driven live token re-authentication, handshake shutdown, app/network recovery, several clients, and alternate client platforms; the cross-platform supervised E2E suite builds and runs a real helper against fake auth/relay/control endpoints for control authentication, token pulls, registration, restart sentinel 86, fresh respawn, unregister, and process cleanup; desktop tests for authenticated spawn gating, first-token handshake, transactional spawn rollback/retry, every supervised exit class, bounded crash retry/give-up, stable-runtime budget reset, manual retry cancellation, prompt-answer ownership, account-bound persisted registration, concurrent logout/stop ordering, token-only deletion verification, tray menu/status updates, Linux host detection, ordered Quit, malformed/newline-free output, bounded persistence, rotation, permissions, and transient storage-path failure recovery. |
| L5 Full | Store-distributed app against a released bridge over production relay, older app against newer bridge and the reverse for the client/bridge wire contract, and a long-lived headless VM run over repeated reconnects. Packaged or external. |

## Exploration Guidance

Vary how the connection breaks: process kill, network drop, relay-side close,
backgrounding, token expiry, competing bridge. Vary whether a client is connected before
the bridge starts, how many clients are present, and whether restart is explicit.

## Failure Signals

- Readiness claimed before registration, auth send, listener setup, or read arming.
- Plaintext session content crossing the relay, or a client served without key exchange.
- Health keeps responding while clients cannot reach the bridge after relay
  acceptance or client reachability was independently established, or one slow
  route freezes all traffic.
- Equivalent route failures produce different statuses depending on the handler
  type, or an unexpected bridge failure is reported as an upstream 502.
- Reconnect tight-looping, an exhausted iterator reused, or two bridges displacing each
  other without backoff.
- A bridge registering a network-derived numeric hostname as its machine name.
- A clean shutdown producing reconnects, a cancelled handshake later sending auth, or an
  app stuck reconnecting after the bridge returns. A desktop disconnected
  project surface offers mobile CLI setup/reconnect instead of supervised Start,
  Start applies toggle semantics and turns a desired-On bridge Off, or helper
  startup never establishes the desktop relay client.
- A dead network path leaving the app claiming connected for minutes, or the
  reconnecting banner flashing on every routine foreground resume.
- GUI shutdown unregistering the bridge, emitting login-needed, or exiting with the
  auth-required sentinel because teardown cancelled the bootstrap token request.
- A forced stop leaving a backend alive, targeting only one process-table snapshot,
  or reporting success after process-group/tree termination was rejected.
- Helper output blocking a child pipe, an unterminated line or persistence backlog
  growing without bound, log files losing owner-only permissions, or one transient
  application-support lookup failure permanently disabling persisted diagnostics.
- A signed-out desktop spawning a helper, the control dispatcher starting after
  the helper, the control secret appearing in argv, a first token request going
  unread, an unsolicited token write bypassing pull correlation, or a failed spawn
  leaving its server or child alive and blocking retry.
- A persisted bridge ID being submitted with a different account, token-only local
  sign-out skipping a verifiable owner, a late unregister following an ordinary
  shutdown, or an undelivered unregister leaving the helper waiting for an avoidable
  full graceful deadline.
- A dormant, not-installed, or zero-eligible plugin snapshot degrading aggregate
  health; or one eligible degraded/failed plugin still reporting healthy.
- Exit 86 spawning twice, exit 87 retrying before auth changes, exit 88 entering
  crash backoff, an expected/clean exit respawning, an unbounded crash loop,
  stable runtime failing to reset the budget, or a cancelled retry later
  spawning a second helper after manual Start or Off.
- A stale prompt answer reaching a newer helper, a failed prompt send removing
  the pending prompt, or conversational sends bypassing the command service.
- A stale tray menu, an invisible Linux tray causing the only window to hide,
  Quit exiting before helper teardown, or a failed stop still terminating the app.

## Known Limitations

- The relay does not acknowledge bridge auth, so local readiness is the strongest
  available claim.
- Takeover backoff is minutes-order and jittered; the full curve belongs at L4 or above.
- The real supervised helper E2E suite uses fake loopback auth/relay/control services;
  it validates outbound relay authentication and local control sequencing, but does
  not claim production-service or server-side JWT coverage.
- The desktop route source identifies project and session-list routes, but no
  desktop session-detail route exists yet. Session-attributed toast events are
  therefore withheld, and the desktop notification-open stack remains unbound.
- Relay capacity and provider outages are out of scope.

## Sources

- Bridge orchestrator, relay, key exchange, server ownership, auth, sleep, and control code.
- Client relay and connection-overlay capabilities and their owning tests.
- Bridge orchestrator, `client_test.dart`, `key_exchange_test.dart`, sleep, and control suites.
- `bridge/app/test/integration/supervised_e2e_test.dart` (native helper + fake auth/relay/control).
- Historical: `.plan/completed/relay-request-concurrency/`
