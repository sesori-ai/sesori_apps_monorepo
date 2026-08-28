# Analytics

## Capability

The mobile client reports a closed set of privacy-safe product events answering activation, retention, and feature
adoption questions. Account-linked events carry a server-derived pseudonymous key and are governed by an account
preference; five bounded account-less authentication events are the only exception: a three-event attempt funnel and
Firebase's recommended `sign_up`/`login` outcomes. Separately, eligible Android/iOS release builds start Singular for
install/session attribution and standard authentication conversion events with release-injected credentials. Desktop
uses a no-op sink, the bridge is excluded, and the warehouse is external.

## Required Behavior

- The contract is closed: only declared sealed variants and pinned enum parameters, never an arbitrary event name or
  parameter map. No account-linked event may carry code, prompts, transcripts, coding-provider, model, agent, tool, or
  command names, paths, repository, project, session, branch or worktree names, raw error text, OAuth identity, email,
  or raw or hashed project, session, bridge, or device identifiers. The account-less authentication catalog's pinned
  provider/method enum is the explicit provider-name exception.
- Account-linked events require an enabled runtime capability (release build, supported platform, sink present),
  authentication, and a server preference resolved to enabled for that generation; anything else suppresses them.
  They carry the validated server-derived key, never a raw account ID, and never set Firebase's global SDK identity.
- Disable applies immediately here and records durable local intent before any network work; a failed sync shows
  pending, never saved, and survives logout and restart. Enable activates only after server success plus local
  persistence.
- Account-less authentication events carry only a pinned provider or method plus the attempt funnel's bounded failure
  kind, and no user key. Settings copy must not claim the switch stops vendor automatic events, these authentication
  events, or older installed binaries.
- Screens use the pinned route mapping with vendor automatic reporting disabled. Events fire at authoritative
  outcomes, not taps, capture occurrence time at their seam, and deferred candidates emit at most once, dropping on
  disable, logout, or account switch. Results state SDK acceptance, not delivery.
- Firebase Analytics collection defaults off at native startup and is enabled only after consent in an eligible release
  process. Debug/profile runs emit neither automatic nor Sesori-defined analytics events. The release lanes stamp each
  binary with its build time; for 48 hours after that stamp an unauthenticated Android launch is treated as a Play
  pre-launch crawl and stays off, while a device with a locally valid session reports at any time. An interactive
  login inside the window lifts the SDK suspension for the rest of that process so the session and user are counted,
  but the process-wide runtime capability stays disabled, so Sesori-defined events resume only at the next launch.
  The window is a heuristic on Play's crawl scheduling, so a late crawl can still register as an install, and a build
  promoted to production inside its window hides unauthenticated first launches for the remainder; the L5 pre-launch
  check measures the crawl residue.
- Singular starts only on Android/iOS, in the same eligible release-build population, with required credentials
  injected outside Git. An unauthenticated Android launch inside the Play crawl window arms startup but defers it until
  a successful interactive authentication reports its first conversion event; a crawler that never authenticates
  remains off. Startup and event reporting are best-effort and must not block the app. The configuration limits
  advertising identifiers and partner data sharing, removes Android advertising-ID permissions, and sets no custom
  user ID, custom events, deep-link handler, or uninstall token. The Basic Usage Analytics preference does not claim
  to control this separate attribution scope.
- A successful interactive authentication always reports Firebase's `login_attempt_completed`. A server-confirmed
  `created` status additionally reports the recommended `sign_up` event; `existing` reports the recommended `login`
  event; and forward-unknown status reports neither recommended event. `sign_up` and `login` are mutually exclusive,
  carry only the pinned `method`, remain account-less, and are not sent for restore, refresh, failure, cancellation, or
  a stale/displaced attempt. GA4 uses `sign_up` as an acquisition key event and leaves recurring `login` unmarked;
  neither event replaces the auth-server account record as the canonical registration metric.
- The same successful authentication reports Singular's parameter-free standard `sng_login` event. It first reports
  parameter-free `sng_complete_registration` only when the auth server's operation-scoped account status is `created`;
  `existing` and forward-unknown statuses report Singular login only. The client never infers creation from local state.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included because analytics must never gate the product heartbeat. |
| L2 Routine | Automated, mobile client, no plugin: wire names and pinned parameters, exhaustive route-to-screen and provider mappings, a check that no variant can carry a free-form string, preference storage state transitions, native default-off configuration, the build-window predicate, release-lane build stamp, typed account-status parsing, Firebase recommended authentication-event mapping, and Singular eligibility/deferred-start configuration plus standard-event mapping with fake adapters. |
| L3 Release | Automated with fake sinks: suppression while unknown, disabled, unauthenticated, or non-release; activation only after readiness and enabled preference; bounded deferral emitted once with preserved occurrence time; generation change dropping stale work; outcome seams firing on success only; mutually exclusive Firebase signup/existing-account login classification; and Singular registration-before-login only for server-confirmed account creation. |
| L4 Extended | Client end to end on the release-target client platform against the real auth-server preference endpoint: disable and re-enable, pending state after a sync failure, persistence across restart, logout with a pending disable, account switch isolation, and no product event while disabled. |
| L5 Full | Release build against the real analytics properties: expected pinned events and parameters observed upstream, `sign_up` configured as a GA4 key event while `login` remains a normal event, automatic screen reporting confirmed off at runtime, a Play pre-launch report producing no Firebase or Singular rows inside the build window, Singular install/session attribution and standard login/registration events observed without an advertising ID, custom user identity, or event attributes, and warehouse checks that exported rows carry no prohibited field and internal accounts are excluded. |

## Exploration Guidance

Vary the preference and auth lifecycle rather than one path: cold start disabled, disable while offline, disable then
kill the app before sync, log out with a pending change, switch accounts in one process, toggle during an in-flight
event. Vary outcomes too: cancel a send, fail a creation, reject a permission, abort a turn. Prefer a disposable
account against a real property.

## Failure Signals

- Any event carries a prohibited field, a free-form string, or an entity identifier including a hashed one; or a login
  event carries a user key.
- Firebase reports `sign_up` and `login` for the same completed attempt, reports either for a forward-unknown account
  status, omits the status-appropriate event, adds parameters beyond pinned `method` and shared schema, marks recurring
  `login` as a GA4 key event, or treats installation-level `sign_up` as the canonical account-registration count.
- An account-linked event is emitted while unknown, disabled, unauthenticated, or in a debug or profile build.
- Any automatic or Sesori-defined event is emitted by a debug/profile process, or by an unauthenticated release
  process inside its build window.
- Disable is delayed, reported saved while sync failed, or lost across restart or logout; enable activates before
  server success plus local persistence.
- An event fires on a tap or failed operation, is duplicated after deferral, has a rewritten occurrence time, or
  carries a route path instead of a pinned screen.
- Automatic screen reporting is observed, a failure blocks a product outcome, or copy overclaims.
- Singular starts in debug/profile/unsupported builds or before successful interactive authentication during the gated
  Android crawl window; requests an advertising-ID permission, sets a custom user identity, sends custom events,
  attaches authentication-event attributes, broadens partner sharing, omits login after successful interactive
  authentication, reports registration
  without a server-confirmed `created` status, or reports either event for a non-interactive or unsuccessful flow.

## Known Limitations

- The vendor SDK, property, warehouse, and dashboards are external; their correctness is never passed from client
  evidence. SDK acceptance is not delivery: a missing upstream row may be sampling, latency, retention, or exclusion.
- Firebase's Active users report counts active app instances, not authenticated Sesori accounts. Internal release
  installs still appear there, and account-less `sign_up`/`login` outcomes can include internal/test traffic; use the
  auth export for registration counts and curated account-keyed reporting for product user counts.
- The preference governs account-linked events here and server reporting only, and a remote change applies on the next
  authenticated generation, process start, or explicit settings action. It does not stop Singular install/session
  attribution. Warehouse rollout remains an active plan.
- Singular's bundled iOS privacy manifest declares linked device-ID tracking and advertising/analytics purposes, so
  store-metadata review is a release gate. Vendor-side retention, deletion, and campaign setup are external and cannot
  be proven from this repository.

## Sources

`client/module_core/test/foundation/`, `client/module_core/test/services/`,
`client/module_core/test/cubits/product_analytics_preference/`, `client/app/test/core/platform/`; production contracts
under `client/module_core/lib/src/foundation/models/product_analytics/`; account-outcome dispatch lives in
`client/module_core/lib/src/services/installation_analytics_service.dart`; Firebase delivery lives in
`client/app/lib/core/platform/firebase_analytics_client.dart`; Singular startup and delivery live under
`client/app/lib/core/platform/singular/` and `client/app/lib/core/platform/singular_attribution_startup.dart`.
