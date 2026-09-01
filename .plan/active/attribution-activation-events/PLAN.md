# Attribution Activation Events

**Status:** Implemented and locally verified in PR #1236; monitoring CI and review feedback.

**Plan slug:** `attribution-activation-events`

**Created:** 2026-09-01

## Goal

Extend Singular attribution so acquisition sources can be measured by **activated
users**, not just installs and signups. Today the attribution sink only reports
`accountCreated` and `accountLogin`; the funnel ends before the events that matter
for distribution decisions. The phone app observes the entire funnel (install →
signup → bridge pairing → first session), so no account linkage or server work is
needed — this is a small, phone-app-only change.

## What to do

1. Add two events to the attribution event model and deliver them through the
   existing attribution sink (`AttributionClient` → Singular) as custom events with
   stable snake_case names:
   - `bridge_paired` — the first time this installation successfully pairs with a
     bridge.
   - `first_session_run` — the installation reaches **full activation**. Reuse the
     exact definition in `.plan/active/user-analytics/PLAN.md` Product Decision 1
     (first successfully accepted user-authored message to any coding session;
     command submissions qualify, offline queueing / opening a session / answering
     a permission / creating an empty session do not). Do not invent a divergent
     definition.
2. Each event fires **at most once per installation**, persisted locally.
   Per-install, not per-account and not per-session. Pairing a second machine or
   starting later sessions must not re-fire. A reinstall re-firing is expected and
   acceptable.
3. Events carry **no properties** — no harness identity, machine info, session
   data, or identifiers. Consistent with the existing bounded-analytics stance and
   the deliberate decoupling of Singular from account-linked product analytics.
4. Existing startup semantics stay: events respect the crawl gate and the
   deferred-start-until-interactive-authentication behavior already in the
   Singular startup path.
5. Flip `limitDataSharing` from `true` to `false` in the Singular startup
   configuration (single occurrence, plus its startup test assertion). Owner
   decision 2026-09-01: partner data sharing is allowed so Singular can share
   attribution data with ad-network partners when paid acquisition starts. The
   current code comment defers this pending a consent design — replace it with
   the decided stance, and make sure the privacy policy discloses attribution
   data sharing with advertising partners. `limitAdvertisingIdentifiers` stays
   `true`; this decision does not add IDFA/GAID collection or an ATT prompt.

## Product decision

**Owner decision 2026-09-01:** keep both activation attribution events independent
of the product-analytics preference, matching the existing Singular attribution
sink. The Basic Usage Analytics control therefore does not suppress
`bridge_paired` or `first_session_run`. The privacy disclosure and regression
contract must state this boundary explicitly.

## Implementation approach

- Extend the closed `AttributionEvent` model with `bridgePaired` and
  `firstSessionRun`; Singular maps them to the exact parameter-free custom names
  in this plan.
- Add one Layer-3 coordinator at
  `client/module_core/lib/src/services/attribution_service.dart`.
  `AttributionService` is the sole owner of `AttributionRepository` dispatch:
  `InstallationAnalyticsService` routes login/registration outcomes through it,
  it classifies the existing `sessionMessageSent` and
  `sessionCreatedWithMessage` product outcomes as full activation before the
  product-preference gate, and it owns the bridge-connection listener.
- `AttributionService.start()` subscribes to `ConnectionService.status` and
  treats `ConnectionConnected` as proof of successful E2E bridge pairing. The
  mobile `bootstrapSesoriApp` composition starts this always-on coordinator only
  after the asynchronous crawl-gate result has been applied to Singular, so a
  returning signed-in connection cannot bypass an unresolved deferral. The
  service owns and disposes the subscription; replayed connection status still
  covers a connection established before the coordinator starts.
- `ProductAnalyticsService` forwards its closed product outcome to
  `AttributionService` before consulting the product preference. The coordinator
  alone decides whether that outcome is the existing full-activation definition,
  so the two sinks cannot drift and the owner decision above remains true. If a
  qualifying outcome arrives before crawl-gated startup completes, the
  coordinator retains one bounded pending milestone and dispatches it after
  `start()` rather than starting Singular early.
- Enforce one-shot mobile delivery in `SingularAttributionClient`: after Singular
  is available under its existing crawl/deferred-start gate, claim each custom
  event in local storage before invoking the SDK. Concurrent claims coalesce,
  stored claims survive process restart, and storage uncertainty fails closed
  rather than risking a duplicate. Standard registration/login events remain
  repeatable under their existing semantics.
- Update the privacy disclosure and `docs/regression/analytics.md`, then cover
  event mapping, persistence/deduplication, preference independence, exact
  outcome seams, and the partner-sharing startup flag with focused tests.

## Delivery

This is one moderate-complexity PR: it crosses the shared event/service seams,
the mobile Singular adapter and local persistence, startup privacy configuration,
and the analytics disclosure/regression contract, without changing wire or
database contracts.

## Out of scope

- Desktop shell (Singular runs in the mobile app only).
- Singular dashboard work: tracking links, SKAN conversion model, cohort reports.
- Ad-network integrations, Info.plist SKAN entries, paid-acquisition setup.
- Any bridge, auth-server, or BigQuery changes.

## Acceptance

- Fresh install on a test device: sign up → pair a bridge → send a first message
  produces `sng_complete_registration`/`sng_login`, `bridge_paired`, and
  `first_session_run` in Singular's SDK/testing console, exactly once each.
- Repeating pairing or sessions on the same install fires nothing further.
- The consent decision above is implemented and written down.
