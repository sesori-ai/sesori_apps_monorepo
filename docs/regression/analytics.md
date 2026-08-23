# Analytics

## Capability

The mobile client reports a closed set of privacy-safe product events answering activation, retention, and feature
adoption questions. Account-linked events carry a server-derived pseudonymous key and are governed by an account
preference; a small account-less login funnel is the only exception. Desktop uses a no-op sink, the bridge is
excluded, and the warehouse is external.

## Required Behavior

- The contract is closed: only declared sealed variants and pinned enum parameters, never an arbitrary event name or
  parameter map. No account-linked event may carry code, prompts, transcripts, coding-provider, model, agent, tool, or
  command names, paths, repository, project, session, branch or worktree names, raw error text, OAuth identity, email,
  or raw or hashed project, session, bridge, or device identifiers. The account-less login funnel's pinned
  login-provider enum is the explicit provider-name exception.
- Account-linked events require an enabled runtime capability (release build, supported platform, sink present),
  authentication, and a server preference resolved to enabled for that generation; anything else suppresses them.
  They carry the validated server-derived key, never a raw account ID, and never set Firebase's global SDK identity.
- Disable applies immediately here and records durable local intent before any network work; a failed sync shows
  pending, never saved, and survives logout and restart. Enable activates only after server success plus local
  persistence.
- Login-funnel events carry only a pinned provider and bounded failure kind and no user key. Settings copy must not
  claim the switch stops vendor automatic events, the login funnel, or older installed binaries.
- Screens use the pinned route mapping with vendor automatic reporting disabled. Events fire at authoritative
  outcomes, not taps, capture occurrence time at their seam, and deferred candidates emit at most once, dropping on
  disable, logout, or account switch. Results state SDK acceptance, not delivery.
- Firebase Analytics collection defaults off at native startup and is enabled only after consent in an eligible release
  process. Debug/profile runs emit neither automatic nor Sesori-defined analytics events. The release lanes stamp each
  binary with its build time; for two hours after that stamp an unauthenticated launch is treated as a store pre-launch
  crawl and stays off, while a device with a locally valid session reports at any time. The window is a heuristic on
  Play's crawl scheduling, so a late crawl can still register as an install; the L5 pre-launch check measures that
  residue.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included because analytics must never gate the product heartbeat. |
| L2 Routine | Automated, mobile client, no plugin: wire names and pinned parameters, exhaustive route-to-screen and provider mappings, a check that no variant can carry a free-form string, preference storage state transitions, native default-off configuration, the build-window predicate, and the release-lane build stamp. |
| L3 Release | Automated with a fake sink: suppression while unknown, disabled, unauthenticated, or non-release; activation only after readiness and enabled preference; bounded deferral emitted once with preserved occurrence time; generation change dropping stale work; outcome seams firing on success only. |
| L4 Extended | Client end to end on the release-target client platform against the real auth-server preference endpoint: disable and re-enable, pending state after a sync failure, persistence across restart, logout with a pending disable, account switch isolation, and no product event while disabled. |
| L5 Full | Release build against the real analytics property: expected pinned events and parameters observed upstream, automatic screen reporting confirmed off at runtime, a Play pre-launch report producing no Analytics rows inside the build window, and warehouse checks that exported rows carry no prohibited field and internal accounts are excluded. |

## Exploration Guidance

Vary the preference and auth lifecycle rather than one path: cold start disabled, disable while offline, disable then
kill the app before sync, log out with a pending change, switch accounts in one process, toggle during an in-flight
event. Vary outcomes too: cancel a send, fail a creation, reject a permission, abort a turn. Prefer a disposable
account against a real property.

## Failure Signals

- Any event carries a prohibited field, a free-form string, or an entity identifier including a hashed one; or a login
  event carries a user key.
- An account-linked event is emitted while unknown, disabled, unauthenticated, or in a debug or profile build.
- Any automatic or Sesori-defined event is emitted by a debug/profile process, or by an unauthenticated release
  process inside its build window.
- Disable is delayed, reported saved while sync failed, or lost across restart or logout; enable activates before
  server success plus local persistence.
- An event fires on a tap or failed operation, is duplicated after deferral, has a rewritten occurrence time, or
  carries a route path instead of a pinned screen.
- Automatic screen reporting is observed, a failure blocks a product outcome, or copy overclaims.

## Known Limitations

- The vendor SDK, property, warehouse, and dashboards are external; their correctness is never passed from client
  evidence. SDK acceptance is not delivery: a missing upstream row may be sampling, latency, retention, or exclusion.
- Firebase's Active users report counts active app instances, not authenticated Sesori accounts. Internal release
  installs still appear there; use curated account-keyed reporting for product user counts.
- The preference governs account-linked events here and server reporting only, and a remote change applies on the next
  authenticated generation, process start, or explicit settings action. Warehouse rollout remains an active plan.

## Sources

`client/module_core/test/foundation/`, `client/module_core/test/services/`,
`client/module_core/test/cubits/product_analytics_preference/`, `client/app/test/core/platform/`; production contracts
under `client/module_core/lib/src/foundation/models/product_analytics/`.
