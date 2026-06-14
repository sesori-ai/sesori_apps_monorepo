# Auth / E2E Reconnect UX Improvement Plan

Status: **in progress** · Owner: mobile/transport · Branch strategy: **one small PR per step**

## Current stage

**PR 1 implemented** (proactive reconnect on resume, including the
bridge-offline state).

> **Maintenance rule:** this **Current stage** line (and the Status tracker
> table at the bottom) MUST be updated as part of **every** PR in this series.
> Whenever the next step is implemented, bump the stage here in the same PR so
> the document always reflects exactly what has been done.

## Problem

When the app returns from background to foreground, re-establishing the relay
connection feels slow. The cost is **not** the cryptography (X25519 + HKDF +
XChaCha20 run in sub-millisecond time) and **not** usually token refresh
(15-min access tokens are reused from cache ~87% of the time). The latency comes
from reconnect **orchestration**:

1. **Zombie/half-open socket (worst case).** The relay closes backgrounded
   phones once its ping/pong window lapses (pings every 30s, 15s pong deadline —
   `sesori_relay_server/internal/relay/handler.go`), because a suspended app
   can't answer. On resume, the mobile client often still believes it is
   `ConnectionConnected` and does **nothing** (`ConnectionService._onAppResumed`
   only reconnects when status is already `ConnectionLost`/`ConnectionReconnecting`).
   The dead socket is then discovered only when a request hits the **30s**
   `_requestTimeout` (`RelayClient`), or never until the OS delivers the close.
2. **Artificial ~1s backoff before the first reconnect attempt**
   (`_reconnectRelayWithRefresh` always waits `_relayReconnectBackoff` before
   attempting, even on a user-initiated foreground).
3. **Redundant `GET /health` round-trip after a successful resume**
   (`resume_ack` already proves the bridge is reachable).
4. **Per-reconnect secure-storage reads** of the room key (and token), even
   though both were already in memory before backgrounding.

### Verified facts (source of truth)

| Fact | Location |
| --- | --- |
| Access token TTL = 15 min; refresh = 30 days | `sesori_auth_server/src/services/token-service.ts:12-13` |
| `getFreshAccessToken` only refreshes on the critical path when TTL left < `minTtl` (2 min) | `mobile/module_auth/lib/src/auth_manager.dart:72-92` |
| Resume sends encrypted `resume` → bridge replies `resume_ack`; decrypt-fail → `rekey_required` → full DH | `bridge/app/lib/src/bridge/orchestrator.dart:600-623,576-588` |
| Room key generated once per bridge process (lost on restart) | `bridge/app/lib/src/bridge/orchestrator.dart:148` |
| Relay pings every 30s, 15s pong deadline, closes on failure | `sesori_relay_server/internal/relay/handler.go:23,126-145` |
| Reconnecting banner already exists (no work needed) | `mobile/app/lib/core/widgets/connection_overlay.dart:62-92` |

## Guiding constraints

- **One concern per PR.** Each step is independently reviewable and revertable.
- **Testable in isolation.** Every PR ships unit tests using the existing
  `ConnectionService` test seams (`ClockProvider`, `RelayClientFactory`,
  `LifecycleSource`).
- **Attributable.** If a regression appears, the offending PR is obvious.
- **No security regressions in Tiers 1–3.** The only security trade-off is
  isolated to Tier 4 and is optional/product-gated.

---

## Tier 1 — Foreground reconnect latency (no security trade-off)

### PR 1 — Proactive reconnect on resume *(implementing now)*
- **Goal:** stop trusting a stale `ConnectionConnected` after a meaningful
  background period; enter the reconnect path (which also surfaces the existing
  banner) instead of waiting for a 30s timeout.
- **Change:** in `ConnectionService._onAppResumed`, add a
  `_resumeReconnectThreshold` (≈20s). If the app was backgrounded longer than
  this and status still reads `connected`, treat the socket as dead and
  reconnect.
- **Files:** `mobile/module_core/lib/src/capabilities/server_connection/connection_service.dart`
- **Tests:** `connection_service_stale_test.dart` — resume past threshold →
  `ConnectionReconnecting`; quick resume → stays `ConnectionConnected`.
- **Risk:** low. Worst case is an occasional unnecessary (cheap) resume for
  20–45s backgrounds. **Security:** none.

### PR 2 — Immediate first reconnect attempt; back off only on failure
- **Goal:** remove the ~1s pre-attempt delay on foreground resume.
- **Change:** add an `immediate` path to `_reconnectRelayWithRefresh` (skip the
  pre-delay on the first attempt); keep the existing exponential backoff +
  jitter for subsequent retries (`:567`/`:578`).
- **Files:** `connection_service.dart`
- **Tests:** first attempt fires with no delay; second attempt waits backoff.
- **Risk:** low. **Security:** none.

### PR 3 — Skip redundant `GET /health` after a successful resume
- **Goal:** drop one bridge round-trip on the common reconnect path.
- **Change:** expose `bool get didResume` on `RelayClient` (it already knows at
  `relay_client.dart:116-122`); in `_connectViaRelay`, only health-check on a
  fresh DH path. Optionally health-check in the background after resume.
- **Files:** `relay_client.dart`, `connection_service.dart`
- **Tests:** resumed connect → no health request sent, status `connected`;
  fresh-DH connect → health request still sent.
- **Risk:** low (health also reflects backend liveness; surfaced anyway via
  `bridgeOffline` + first real request). **Security:** none.

---

## Tier 2 — Micro-latency & robustness (low / no trade-off)

### PR 4 — In-memory room-key cache
- **Goal:** avoid a Keychain read on every reconnect.
- **Change:** `RoomKeyStorage` keeps the last read/written key in memory and
  serves reads from it; writes are write-through; clear clears both.
- **Files:** `mobile/module_core/lib/src/capabilities/relay/room_key_storage.dart`
- **Tests:** read-after-write hits memory; clear invalidates; secure-storage
  read happens at most once.
- **Risk:** very low. **Security:** none — key is already in memory during an
  active session; persistence is unchanged.

### PR 5 — In-memory access-token read cache (the correctly-scoped version of "use current token")
- **Goal:** avoid a Keychain read for the token on the hot reconnect path; keep
  the existing TTL-based refresh semantics.
- **Change:** cache the decoded token + expiry in `TokenStorageService`,
  invalidated on write/refresh/logout.
- **Files:** `mobile/module_auth/lib/src/storage/token_storage_service.dart`
- **Tests:** cache hit avoids storage read; refresh/logout invalidates.
- **Risk:** low (must invalidate correctly). **Security:** negligible.

> Note: the earlier "use a near-expired token for WS auth and refresh after"
> idea is **not** pursued — analysis showed refresh is only on the critical path
> in the token's final 2 minutes (~13% of reconnects), so the real win is
> removing the storage read, not changing the freshness window.

---

## Tier 3 — Cross-component (larger, still bounded)

### PR 6 — Bridge-side SSE auto-resume
- **Goal:** save the post-reconnect `sse_subscribe` round-trip and reduce
  refetches.
- **Change:** on `resume_ack`, re-subscribe the phone to its previous SSE path
  server-side. Requires tracking subscription state by a persistent identity
  (room/device) rather than the per-connection `connID` (which the relay rotates
  on every reconnect).
- **Files:** `bridge/app/lib/src/bridge/sse/sse_manager.dart`,
  `bridge/app/lib/src/bridge/orchestrator.dart`
- **Tests:** bridge unit tests for resume → auto re-subscription + orphan replay.
- **Risk:** medium (touches replay/orphan logic). **Security:** none.

---

## Tier 4 — Security trade-off (optional, product-gated)

### PR 7 — Persist the room key on the bridge across restarts
- **Goal:** avoid forcing a full DH (`rekey_required`) for every phone after a
  bridge restart (e.g. laptop sleep/wake).
- **Change:** persist the room key in the bridge's OS credential store; keep
  X25519 keys ephemeral; rotate periodically.
- **Files:** bridge `orchestrator.dart` + a persistence collaborator.
- **Risk / Security:** **weakens forward secrecy** — a persisted symmetric key
  means bridge-disk compromise could expose session traffic. Bounded by keychain
  storage + rotation. Lower priority than Tier 1 because bridge restarts are far
  rarer than app backgrounding. **Do not start without an explicit product call.**

---

## Considered and rejected

- **Shorter relay ping interval** — more battery/data for marginal gain;
  superseded by PR 1.
- **Warm/background-prewarmed socket** — iOS background limits make it
  unreliable.
- **Longer access-token TTL** — widens token-misuse window for little benefit.
- **Plaintext room-key storage** — materially weaker on rooted/jailbroken
  devices; PR 4 gets the speed without it.
- **Disabling resume / always full DH** — slower, not faster.

## Sequencing

PR 1 → 2 → 3 are independent and can merge in any order, but the listed order
front-loads the biggest win (PR 1). Tier 2 is independent of Tier 1. Tier 3 and
Tier 4 stand alone. Ship and validate each before starting the next.

## Status tracker

| PR | Tier | Status |
| --- | --- | --- |
| PR 1 — proactive reconnect on resume | 1 | implemented (#262) |
| PR 2 — immediate first attempt | 1 | not started |
| PR 3 — skip health after resume | 1 | not started |
| PR 4 — room-key memory cache | 2 | not started |
| PR 5 — token read memory cache | 2 | not started |
| PR 6 — bridge SSE auto-resume | 3 | not started |
| PR 7 — persist room key on bridge | 4 | not started (needs product decision) |
