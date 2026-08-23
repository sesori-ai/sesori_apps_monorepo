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
- Deliberate shutdown is not an outage; a handshake cancelled mid-flight closes at
  once and can never later authenticate.
- One live bridge per account holds the slot; a second start resolves ownership
  explicitly, and an explicit restart hands off to its successor cleanly.
- Bridge registration uses a stable machine name. On macOS, transient
  network-derived numeric hostnames must not replace the machine's LocalHostName.
- The client distinguishes connected, reconnecting, connection lost, bridge offline, and
  disconnected, and returns to connected when the bridge is back.
- The configured sleep policy applies at standalone startup and releases its wake lock on
  shutdown; unsupported lid-close prevention and wake-lock failures warn without aborting.
- In supervised mode, the authenticated local control channel can supply tokens, report
  status and provisioning, resolve prompts, unregister, and request sentinel restarts;
  loss of its owner exits after the grace period without orphaning backend processes.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | A started bridge reaches readiness and answers a health request; a connected client reports connected. Headless bridge plus relay integration for the client-visible state; no plugin. |
| L2 Routine | Relay integration for key exchange, a normal drop and reconnect, and clean shutdown; automated and headless bridge for stable machine-name registration plus sleep-policy enable, disable, warning, and wake-lock release. No plugin. |
| L3 Release | The full connection state machine as presented, explicit restart with successor handoff, second-start ownership resolution, and a slow in-flight request not blocking key exchange or further requests. Client end to end plus headless bridge; a representative harness supplies the slow operation. |
| L4 Extended | Relay integration or client end to end for takeover, revocation, live token re-authentication, handshake shutdown, app/network recovery, several clients, and alternate client platforms; headless supervised harness for control authentication, token rotation, prompts, status, provisioning progress, unregister, restart sentinels, owner loss, and orphan cleanup. |
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
  app stuck reconnecting after the bridge returns.

## Known Limitations

- The relay does not acknowledge bridge auth, so local readiness is the strongest
  available claim.
- Takeover backoff is minutes-order and jittered; the full curve belongs at L4 or above.
- The desktop shell is not shipped; supervised control is covered with a headless harness.
- Relay capacity and provider outages are out of scope.

## Sources

- Bridge orchestrator, relay, key exchange, server ownership, auth, sleep, and control code.
- Client relay and connection-overlay capabilities and their owning tests.
- Bridge orchestrator, `client_test.dart`, `key_exchange_test.dart`, sleep, and control suites.
- Historical: `.plan/completed/relay-request-concurrency/`
