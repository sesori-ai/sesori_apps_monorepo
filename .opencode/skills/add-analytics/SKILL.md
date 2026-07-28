---
name: add-analytics
description: Design or add Sesori product analytics. Use when adding a user-facing feature, deciding whether an event is valuable, changing analytics identity/privacy, instrumenting an outcome, or adding BigQuery/Looker metrics. Covers authoritative hook points, layered delivery, bounded event design, GoRouter screen reporting, voice/login exceptions, and warehouse verification.
---

# add-analytics

Design analytics that answer a product question without creating misleading or
sensitive data.

## Before adding an event

An event is worthwhile only when all of these are concrete:

1. **Decision:** What product decision or investor metric changes if this moves?
2. **Meaning:** Is it an intent, confirmed outcome, state transition, or view?
3. **Authority:** Which business success/failure seam proves it happened?
4. **Population:** Is the unit an account, installation, or action? Never mix
   those denominators under one label.
5. **Privacy:** Can every parameter be a bounded enum/boolean or explicitly
   approved scalar without code, content, paths, identity, or entity IDs?
6. **Reporting:** Which curated model/view consumes it, and how are coverage,
   maturity, freshness, and deduplication handled?

If the answer is only “this button was tapped,” skip it unless that tap is the
only honest signal for a defined funnel step.

## Current and planned seams

Until `.plan/active/user-analytics/` step 3 lands, the existing event union is
`client/app/lib/core/analytics/analytics_event.dart` and the mobile shell owns
`AnalyticsReporter`. Do not pretend the planned core files already exist or
partially introduce the new architecture outside the series.

After step 3 lands, the source of truth is the closed models under
`client/module_core/lib/src/foundation/models/product_analytics/`, with
repository delivery/preference records under `repositories/models/` and service
state under `services/models/`:

- Consumers call `ProductAnalyticsService` for authenticated account-linked
  events.
- The three approved pre-auth login events call
  `InstallationAnalyticsService`; they are account-less and preference-exempt
  by explicit product decision.
- Delivery flows `Client (Foundation) -> API -> Repository -> Service ->
  Consumer`. Cubits/widgets/listeners never hold `AnalyticsClient` or
  `AnalyticsApi` directly.
- Mobile implements `AnalyticsClient` with Firebase; desktop uses a no-op
  adapter until desktop analytics has its own approved scope.

Remove this transitional “until step 3” paragraph in the step-3 implementation
PR after updating all in-repository consumers in lockstep.

## Choose the authoritative hook

| Event meaning | Correct seam | Example |
| --- | --- | --- |
| Confirmed outcome | Success branch after repository/service response | Message accepted, session created |
| Failure diagnostic | Explicit typed failure branch | Session creation failed |
| Reactive state | Dedicated listener or bounded transition guard | Bridge/screen state |
| Screen | `GoRouterRouteSource` -> exhaustive `AnalyticsScreen` mapping | `product_screen_viewed` |
| Flutter-only capability | UI call site after capability succeeds, calling Layer-3 service | Voice transcription completed |
| Pre-auth login | `LoginCubit` terminal state through `InstallationAnalyticsService` | Timeout by provider |

Never use a widget tap as a proxy when a confirmed outcome exists. Never emit a
success event when an operation is queued, merely attempted, or later requeued.
Capture product-event occurrence time at that authoritative seam before any
preference deferral; a later Firebase emission timestamp must not move funnel or
retention timing.

## Screen reporting

- `GoRouterRouteSource.currentRouteStream` is the sole screen source.
- Map every `AppRouteDef` exhaustively to a pinned `AnalyticsScreen`; never send
  concrete paths, project/session IDs, or Dart enum names as implicit wire
  values.
- Disable Firebase automatic screen reporting on Android and Firebase-enabled
  Apple targets.
- Emit canonical account-linked `product_screen_viewed`, then let the Firebase
  adapter best-effort mirror the same pinned name through `logScreenView`.
- Curated account metrics use only `product_screen_viewed`; standard
  `screen_view` is diagnostic. Test one custom + one native event per changed
  GoRouter route and no automatic duplicate.

## Parameters and naming

- Event/parameter names: pinned `snake_case`, max 40 characters.
- Use enums for closed values and explicit converters/mappings for existing
  sealed types. Do not assume a domain type is an enum.
- Max 25 parameters per GA4 event; fewer is better.
- Do not rename a released wire value. Add a schema version when semantics must
  change.
- `input_mode=voice_assisted` means a successful transcript contributed to the
  submitted composer value; it never means the final text was unedited. Preserve
  that bounded origin with any restored composer draft.

## Identity and privacy

Never report:

- prompt, response, transcript, code, reasoning, or tool content;
- file/repository/project/session/branch/worktree names or paths;
- raw or hashed project/session/bridge/device/notification IDs;
- OAuth identity, username, email, provider user ID, IP/geography, or raw error
  text;
- coding provider/model/agent/tool/command names unless a later approved plan
  changes the privacy contract.

Account-linked events use only the pseudonymous custom `user_key` produced in
the repository. Never set Firebase global `user_id` for the new design.
Installation login events carry no `user_key` or attempt ID and may not be
extended beyond their approved provider/failure enums without a new decision.

## Implementation checklist

1. Add a closed event variant and pinned parameter enums to the active source of
   truth.
2. Identify the authoritative success/failure/transition seam.
3. Route through the correct Layer-3 service; update every mobile/desktop
   constructor consumer in lockstep.
4. Keep product behavior independent: analytics is best-effort, failure-isolated,
   and never changes product success.
5. Generate source outputs; never hand-edit generated files.
6. Test exact wire names/parameters, success-only emission, failure/no-op paths,
   deduplication, and absence of sensitive values.
7. Add/update versioned BigQuery transforms and fixture `ASSERT`s. Account
   metrics use `user_key` plus the eligible auth snapshot; installation events
   aggregate without persisting `user_pseudo_id`.
8. Show complete periods, denominators, cohort maturity, coverage, and freshness.
9. Run analyze/tests for every touched module and affected downstream shell.

## Do not create raw-export dashboards

Investor and product dashboards read authorized aggregate reporting views, not
ad-hoc views over raw `events_*`. Raw GA4 timestamps are integer microseconds;
users/installations/accounts differ; rolling WAU needs a real seven-day range;
and retention requires matured, fixed windows. Encode those contracts in curated
SQL with fixture assertions rather than dashboard formulas.
