# User Analytics

**Status:** Revised after rejected architecture review; valid findings applied,
not re-reviewed

**Plan slug:** `user-analytics`

**Created:** 2026-07-28

## Goal

Give Sesori a privacy-safe product analytics system that can answer, within the
next two months:

- Are new accounts growing?
- Do users complete bridge setup and reach product value?
- Do activated users return and use Sesori repeatedly?
- Which remote-control and differentiating features create engagement?
- Where do onboarding and core actions fail?

The system must produce reproducible BigQuery metrics and restricted Looker
Studio dashboards without exporting source code, prompts, transcripts, paths,
project/session names, raw entity identifiers, or unbounded backend data.

Revenue metrics are out of scope because Sesori is currently free.

## Product Decisions

1. **Full activation is the first successfully accepted user-authored message
   to any coding session.** Both sending to an existing session and creating a
   session with an initial message qualify. A command submission qualifies;
   tapping Send, queueing offline, merely opening a session, answering a
   permission/question, or creating an empty session does not.
2. The implementation spans the apps monorepo, the Sesori auth server,
   Firebase/GA4, BigQuery, and Looker Studio.
3. Optional Sesori-defined product-interaction events are enabled by default
   after the authenticated server preference is known. Settings disables them
   immediately on this installation and synchronizes a reporting/supported-
   client preference to the server. It does not claim to stop Firebase's
   automatic install-level events or already-installed legacy binaries.
4. Acquisition work starts with campaign links and automatic store/Firebase
   attribution. No onboarding survey is added in this scope.
5. Looker Studio is the reporting surface; it reads aggregate authorized views,
   not raw event or per-user tables.

## Metric Contract

All reporting uses UTC. Weekly metrics use complete Monday-Sunday weeks unless
the dashboard explicitly labels a live partial week. Every rate displays its
numerator, denominator, and cohort maturity; an incomplete cohort must never be
silently compared with a mature one.

### Canonical milestones

| Milestone | Definition | Source |
| --- | --- | --- |
| Account created | `users.createdAt` | Auth server |
| Notifications registered | First device-token registration (`ActivationState.mobileSetupAt`) | Auth server |
| Bridge registered | First bridge registration (`ActivationState.bridgeSetupAt`) | Auth server |
| Project available | First successful project inventory containing at least one project after instrumentation starts | App event |
| Legacy session signal | First accepted `/sessions/generate-metadata` request (`ActivationState.firstSessionAt`) | Auth server |
| Analytics-ready exposure | Earliest schema-v1 `analytics_schema_ready` or other accepted schema-v1 custom event, provided it occurs within 24 hours of account creation | App event |
| Full activation | Earliest successful `session_message_sent` or `session_created_with_message` | App event |

`mobileSetupAt` is **not** “mobile setup”: it proves notification registration.
`firstSessionAt` is **not** full activation: it is recorded before downstream
session creation completes and does not prove that the user sent a message.
Reporting aliases both fields to their factual meanings and never substitutes
the legacy signal for full activation.

Behavioral milestones cannot be backfilled before the new event release. Store
two timestamps: `raw_export_start_at` when Firebase export begins and
`behavioral_schema_v1_start_at` only after the production app version has
successfully exported the new event schema. Restrict activation/retention
cohorts to accounts created on or after the behavioral timestamp **and** with
per-account analytics-ready exposure no later than 24 hours after creation.
Calendar eligibility alone is insufficient because a newly created account can
still run a legacy binary. Historical server milestones may still support
honestly labeled setup trends.

### Headline metrics

| Metric | Exact definition |
| --- | --- |
| Weekly new accounts | Non-internal, non-deletion-suppressed auth accounts created during the complete week. This comes from aggregate server export and is not reduced by ordinary product-analytics opt-out. |
| 7-day bridge setup conversion | Accounts whose first bridge registration is within 7 x 24 hours of account creation, divided by accounts at least 7 days old in the cohort. |
| 7-day full activation conversion | Analytics-eligible accounts whose full activation is within 7 x 24 hours of account creation, divided by accounts at least 7 days old, created on/after `behavioral_schema_v1_start_at`, and observed on schema v1 within 24 hours of creation. Show both schema-exposure and preference coverage; accounts lacking timely exposure are unmeasurable, not non-activations. |
| Time to activation | P50 and P75 of `full_activation_at - account_created_at` among activated measurable accounts. |
| Meaningful WAU | Distinct users with a non-empty session activity view or a confirmed control event in the complete week. A screen view/app open never qualifies. |
| Controller WAU | Distinct users with a successful message, question answer/rejection, permission answer, session abort, or session creation with message. |
| W1 retention | Activated users with meaningful activity 7-13 days after their activation timestamp, divided by users whose full W1 window has elapsed. |
| W4 retention | Activated users with meaningful activity 28-34 days after activation, divided by users whose full W4 window has elapsed. |
| Active days per WAU | P50/P75 distinct UTC meaningful-activity dates per meaningful user in each complete week. |
| Remote interventions per controller | Successful control events divided by Controller WAU. Keep message counts and other control actions separately visible. |
| Four-week WAU growth | `(latest complete week meaningful WAU / meaningful WAU four complete weeks earlier) - 1`; return null when either sample is unavailable, not zero. |

### Diagnostic and differentiation metrics

- Setup funnel: account created -> bridge registered -> project available ->
  full activation. Notification registration is a side-adoption metric, not a
  required step.
- First-message activation split by existing-session versus remotely created
  session.
- Dedicated-worktree share among successful remotely created sessions.
- Diff-review users, question/permission interventions, and aborts.
- Notification open-to-meaningful-action conversion within 30 minutes for the
  same user. This is intentionally an open-to-action metric, not a delivery or
  click-through rate; there is no delivery denominator in this scope.
- Campaign-attributed accounts, known-attribution coverage, and activation by
  campaign. Unknown attribution remains `unknown`, never “organic”.
- Onboarding support/install interactions already present in the event schema.

## Current Behavior

### Apps monorepo

- `client/app` has Firebase Analytics; desktop and bridge do not.
- `client/app/lib/core/analytics/analytics_event.dart` is a Freezed closed event
  union with seven onboarding/support/install events.
- `FirebaseAnalyticsReporter` serializes that union and best-effort logs it.
- `AnalyticsUserIdTracker` sends SHA-256 of `AuthUser.id` as Firebase
  `user_id`. This identifier is pseudonymous, not anonymous.
- Ad storage, ad user data, ad personalization, ad-network registration, IDFV,
  and Android AD_ID are disabled. Analytics storage is currently granted at
  startup, with no user preference.
- Analytics currently runs in developer builds, and screens are not explicitly
  tracked.
- Stable route names are already available through
  `RouteSource.currentRouteStream` and `AppRouteDef`; route paths with project
  or session IDs do not need to be logged.
- Confirmed message/session/question/permission/diff outcomes live in
  `module_core`, while the analytics contract currently lives in the mobile
  shell. The contract must move down to a backend-neutral core boundary so
  cubits can report authoritative outcomes without widget-tap proxies.

### Auth server

- `User.createdAt` and one `ActivationState` per user already persist the
  available setup timestamps.
- Activation reconciliation/backfill already preserves earliest evidence.
- No BigQuery export or product-analytics preference exists.
- The server is a separate TypeScript repository and must never send Mongo
  ObjectIds, OAuth identifiers, usernames, email addresses, bridge IDs, device
  tokens, or IP data to BigQuery.

### Cloud/reporting

- No BigQuery SQL, reporting datasets, dashboard definitions, or data-quality
  checks are versioned in the apps monorepo.
- Whether Firebase is already linked to BigQuery, its property ID/location,
  billing state, and current Looker assets cannot be established from source.

## Scope

### In scope

- Immediate Firebase/GA4 -> BigQuery linking with raw controls and a recorded
  raw-export start; record the separate behavioral start at production rollout.
- Installation-enforced optional custom product-analytics preference, mobile
  Settings UI, and a server preference for reporting/supported clients.
- A surface-neutral typed analytics contract in `module_core`, implemented by
  Firebase in mobile and by a no-op adapter on unsupported products.
- Authenticated custom-event key lifecycle, release-build custom-event sharing,
  stable screen views, campaign attribution, and the outcome events below.
- A daily privacy-safe auth export and aggregate external-account setup cohorts
  after internal/deletion suppression.
- Versioned BigQuery DDL/transforms/tests and Looker Studio dashboards.
- Internal/test-user exclusion, retention, access, cost, and data-quality
  controls.

### Out of scope

- Desktop or bridge product-interaction analytics.
- Prompt/transcript/tool/model/agent/command-name analytics.
- Sesori-defined raw project, session, bridge, device, repository, account, or
  notification identifiers—even hashed per-entity identifiers. Firebase's
  unavoidable raw app-install identifier is confined as documented below.
- FCM delivery export, delivery-rate claims, session-level notification
  correlation, heatmaps, session replay, ad attribution, or third-party mobile
  attribution SDKs.
- Backend/harness adoption. Plugin identity remains behind the plugin boundary
  and is not classified into a client analytics dimension.
- Voice interaction analytics. The current orchestration lives in the mobile
  shell; instrument it only after a separately approved migration behind core
  platform/API/repository/service boundaries. Auth-server aggregate
  transcription usage is not added merely as a substitute.
- A “How did you hear about us?” prompt.
- Predictive scoring, experimentation infrastructure, revenue analytics, or a
  general-purpose event bus.
- Pretending historical metadata requests are historical full activations.

### Touched repositories and workspaces

| Repository/workspace | Production paths and layer | Change | Downstream impact |
| --- | --- | --- | --- |
| `sesori_auth_server` | `src/types/product-analytics.ts` (domain enum), `src/models/{documents,api,product-analytics-export}.ts` (persisted/API/export contracts), `src/repositories/{user-repo,activation-state-repo,product-analytics-export-repo,product-analytics-control-repo}.ts` (data access/aggregation), `src/services/{product-analytics-preference-service,product-analytics-export-service}.ts` (business logic), `src/clients/bigquery-product-analytics-client.ts` and `src/api/product-analytics-export-api.ts` (external sink layers), `src/routes/product-analytics.ts` (HTTP boundary), `src/scripts/{backfill-product-analytics-preference,suppress-product-analytics-export,export-product-analytics,product-analytics-export-config}.ts` (separate command composition) | Persist preference/privacy-suppression state behind a dedicated service, expose GET/PUT endpoints, and export privacy-safe data after source/internal exclusion. | Existing auth responses and clients remain unchanged. The web process constructs only the preference service; it never constructs export/BigQuery classes. |
| `shared/sesori_shared` | No production change | Keep `AuthUser` authentication-only; do not add a product preference to the shared auth/persisted contract. | No bridge/shared migration or compatibility default is introduced. |
| `client/module_auth` | No production change | Continue to own tokens, OAuth, auth state, and `AuthenticatedHttpApiClient` only. | `module_core` observes `AuthSession` read-only and injects `AuthenticatedHttpApiClient` into its own Layer-1 preference API. |
| `client/module_core` | `lib/src/models/product_analytics/`, `lib/src/platform/analytics_client.dart`, `lib/src/api/{analytics_api,product_analytics_preference_api}.dart`, `lib/src/storage/{product_analytics_preference_storage,campaign_attribution_storage}.dart`, `lib/src/repositories/{product_analytics,product_analytics_preference,campaign_attribution}_repository.dart`, `lib/src/services/{product_analytics,campaign_attribution}_service.dart`, `lib/src/listeners/{analytics_route,campaign_attribution,notification_open_analytics}_listener.dart`, `lib/src/cubits/product_analytics_preference/`, existing project/session/diff cubits and notification dispatcher, DI/barrel/generated files | Expose architectural layers explicitly; own preference HTTP/persistence, pseudonymous hashing, route/campaign/notification lifecycle, Settings state, and authoritative business-outcome emission. | Mobile supplies only the Firebase platform client. Desktop supplies a no-op client. Cubit constructor call sites/tests update in lockstep. |
| `client/app` | `lib/core/platform/{firebase_analytics_client,firebase_analytics_identity_migration}.dart`, `lib/core/di/`, `lib/features/{settings,project_list,new_session,session_detail,session_diffs}/`, `lib/l10n/`, `lib/main.dart`, iOS/Android analytics defaults | Clear legacy global identity at earliest post-Firebase bootstrap, implement the thin custom-event adapter, start core services/listeners, render preference UI, and inject services into core consumers. | Existing app event sources move to core; `AnalyticsUserIdTracker` and obsolete app `DeepLinkService` are removed. The only global Firebase `user_id` call sets null for migration; no account key or runtime collection override is added. No new voice logic is added. |
| `client/desktop` | `lib/core/platform/no_op_analytics_client.dart`, DI generated file | Satisfy the shared core platform capability without collecting desktop analytics. | No desktop product events or UI are added. Analyze/test verifies core DI remains resolvable. |
| `client/module_desktop_core` | No planned production edit; tests/build are downstream validation | Continue unchanged. | Shared core DI/downstream validation only. |
| `bridge/app` | No planned production or contract edit | Remain outside product analytics. | No additional bridge validation beyond normal CI is caused by this plan. |
| Apps monorepo tooling | `tool/product_analytics/` (deployment tooling/SQL/runbook) | Version BigQuery DDL, transforms, assertions, and dashboard contract. | Cloud deployment supplies property/project/location; no credentials or live exclusion values enter Git. |

## Privacy And Identity Contract

### Account preference

Define the same closed wire values (`enabled`, `disabled`) at the two language
boundaries, but do **not** add the preference to `AuthUser`, `AuthSession`, JWTs,
or auth login/refresh responses. It is product state, not authentication state.
The auth server persists it on `User`, exposes dedicated authenticated GET/PUT
product-analytics endpoints through a dedicated preference service, and writes
`enabled` for every new account. Existing accounts are backfilled to the honest
prior behavior before the server schema becomes non-null/enforced.

In the client, a `module_core` Layer-1 preference API uses the already exported
`AuthenticatedHttpApiClient`; its repository combines the server operation with
encrypted local pending-disable storage. `AuthSession` is observed only for the
authenticated user ID and logout/account-switch lifecycle. A server fetch or
pending update may start only after an explicit non-splash readiness signal or
a Settings action—never as a side effect of `restoreLocalSession()` during
splash.

Do not use Firebase's persisted `setAnalyticsCollectionEnabled` override or
global `setUserId` as the preference mechanism. Firebase automatic install-level
events remain governed by the privacy-minimized property/native configuration
and are disclosed separately; they never define product activity. Every
Sesori-defined custom event instead carries the pseudonymous `user_key` as a
typed parameter, and `ProductAnalyticsService` refuses to create those events
unless the local/server gate is active. This avoids a cold-start race with a
persisted Firebase enable override and prevents the new design from assigning
an account key to automatic events.

The one compatibility exception is an earliest-bootstrap `setUserId(null)` to
clear the hash persisted by current releases. It runs immediately after Firebase
initialization and before custom sources. Vendor automatic initialization can
precede that supported reset, so the plan treats possible pre-clear automatic
rows as legacy raw data rather than promising an impossible zero-width window.
If clear fails, classify/disclose that whole process as potentially legacy-
keyed; disabling only custom events is not described as stopping automatic data.

The core service combines installation-local intent with the server preference:

- Unknown, unauthenticated, debug/profile, locally disabled, or server-disabled
  state suppresses all Sesori-defined custom events.
- After post-splash readiness, an authenticated installation fetches the server
  preference. Only returned enabled in a release build activates custom event
  sharing; a local cached enabled value alone never activates a new run.
- Disable synchronously transitions the service to inactive, then makes durable
  `pendingDisable(userId)` its **first awaited operation**, before any SDK/network
  work, and only then PUTs disabled. A crash after that write leaves recoverable
  local intent; no SDK disable/reset call is required for custom-event
  enforcement.
- A local storage read error keeps custom events inactive rather than treating
  missing state as enabled. If the write-ahead write fails, the process remains
  inactive and still attempts the authenticated server disable, but the UI does
  not report saved success unless either durable local intent or server disabled
  is confirmed; a double failure requires explicit retry.
- Server success stores synchronized disabled. Failure preserves the pending
  record and surfaces “disabled on this device; account sync pending”; retry is
  allowed only after post-splash readiness or explicit user action.
- Enable first persists inactive `pendingEnable`, then keeps custom sharing
  inactive through server success until synchronized local persistence. A final
  local write failure remains a truthful pending-finalization state across
  restart, never a displayed failure followed by silent activation.
- Logout/account loss never deletes a pending disable. The logout flow attempts
  one authenticated sync before credentials are cleared; if it fails, it
  preserves the record and requires reauthentication to finish server sync.
  Every preference operation has a 10-second deadline, so it cannot hold logout
  or the foreground reconciliation slot indefinitely.

The setting is not advertised as a universal Firebase or legacy-client kill
switch. It immediately controls Sesori-defined custom events on this
installation; the server preference suppresses reporting and is honored by
analytics-capable releases. Already-installed older binaries can continue their
previous Firebase behavior until upgraded/retired, so account-wide wording is
forbidden unless a future minimum-version enforcement mechanism makes it true.
Supported clients re-read the preference on every foreground transition and at
most every 15 minutes while continuously foregrounded. Thus a remote change is
applied by the next successful check (within 15 minutes when online), not
instantaneously; offline and legacy limitations must remain explicit in copy.

Model preference and synchronization status as separate sealed states; do not
flatten “disabled”, “unknown”, “pending sync”, and “failed” into nullable flags.
The Settings copy must say “Share pseudonymous product usage from this device,”
list the prohibited content categories, identify the pending server-sync state,
and explain that Firebase automatic install-level events plus account/bridge
records required to operate Sesori are not controlled by this switch. Product/
privacy counsel must approve the final text and store disclosures before
release.

### Pseudonymous join key

Continue using lowercase hex SHA-256 over the UTF-8 auth user ID. Implement the
same algorithm in TypeScript and in the core `ProductAnalyticsRepository`, and
pin both repositories to one documented golden test vector. The mobile Firebase
adapter receives the resulting value only inside typed custom event envelopes;
it never receives a raw account ID and never sets Firebase's global `user_id`.
Raw user IDs are permitted only in auth/core process memory and
the auth database/existing encrypted local auth or preference storage; they must
not reach Firebase, BigQuery, logs, SQL assets, or dashboard URLs.

The deterministic custom `user_key` allows cross-device and auth-to-GA4 joins but remains
pseudonymous personal data. Documentation and access controls must call it that.

### Allowed dimensions

- Event schema version.
- Stable screen enum.
- Platform and app version/build supplied by Firebase.
- Bounded onboarding, notification, interaction, and failure enums.
- Strict opaque campaign code (lowercase ASCII letters/digits plus `_`/`-`,
  maximum 32 characters) mapped to human labels only in a restricted BigQuery
  registry.

### Prohibited dimensions

Do not add fields capable of carrying code, prompts, responses, transcript
text, reasoning, filenames/paths, repository/project/session/branch/worktree
names, provider/model/agent/tool/command names, raw error text/status payloads,
OAuth identity, email, IP/geography, or raw/hashed project/session/bridge/device
IDs. The event union should make these fields impossible to pass.

This prohibition governs Sesori-defined event parameters and every curated or
reporting model. It does not falsely claim that the vendor-managed raw GA4
schema lacks installation/device metadata; that unavoidable boundary is
documented and restricted below.

## Client Architecture

### Layered ownership

Move the existing event union out of the Flutter shell, but do not create a
mixed `src/analytics/` bucket. The concrete dependency direction is:

`AnalyticsClient (Foundation) -> AnalyticsApi / *Storage (Layer 1) ->
*Repository (Layer 2) -> *Service (Layer 3) -> Listener/Cubit/UI (Consumer)`.

| Class/file | Layer and constructor collaborators | Responsibility and lifecycle |
| --- | --- | --- |
| `AnalyticsEvent`, bounded enums, `AnalyticsScreen`, `AnalyticsDeliveryResult`, `ProductAnalyticsPreference`, `ProductAnalyticsState`, `CampaignCode`, and persisted record variants under `module_core/lib/src/models/product_analytics/` | Domain models; no SDK/Flutter dependencies | Closed event/screen/preference/state values. `AnalyticsScreen` is independent of routing; `AnalyticsRouteListener` performs the exhaustive `AppRouteDef -> AnalyticsScreen` mapping. Delivery is `acceptedBySdk`, `deferredUntilPreference`, or `failed`, never an untruthful “reported” boolean. Campaign completion is account-scoped; the in-memory pending activation variant carries only one typed message-success event and its auth generation. |
| `AnalyticsClient` in `module_core/lib/src/platform/analytics_client.dart` | Foundation external-sink capability | Typed `logEvent({required AnalyticsEvent event, required String userKey})`. The key is already pseudonymous and is serialized as the custom `user_key` event parameter, never global SDK identity. Methods throw SDK failures; they accept no arbitrary map/name or raw account ID. |
| `AnalyticsApi` in `module_core/lib/src/api/analytics_api.dart` | Layer 1; constructor requires `AnalyticsClient` | Thin API over the external client. It is the only core class that invokes the platform sink. |
| `ProductAnalyticsPreferenceApi` in `module_core/lib/src/api/product_analytics_preference_api.dart` | Layer 1; constructor requires `AuthenticatedHttpApiClient` | Calls authenticated GET/PUT `/product-analytics/preference` under a fixed 10-second operation deadline, serializes the closed enum, parses external strings at the boundary, and returns explicit success/timeout/failure. It does not mutate auth state; late transport completion is detached and cannot complete the bounded operation twice. |
| `ProductAnalyticsPreferenceStorage` and `CampaignAttributionStorage` in `module_core/lib/src/storage/` | Layer 1 storage; each constructor requires `SecureStorage` | Read/write/delete only their closed persisted records. They do not reconcile accounts, call APIs, hash IDs, or emit analytics. |
| `ProductAnalyticsRepository` in `module_core/lib/src/repositories/product_analytics_repository.dart` | Layer 2; constructor requires `AnalyticsApi` | Converts raw authenticated user ID to lowercase SHA-256, passes only the pseudonymous key downward, and maps API exceptions to explicit `AnalyticsDeliveryResult` without redundant logging. It adds `schema_version=1` through the typed event serialization contract. |
| `ProductAnalyticsPreferenceRepository` in `module_core/lib/src/repositories/product_analytics_preference_repository.dart` | Layer 2; requires `ProductAnalyticsPreferenceApi` and `ProductAnalyticsPreferenceStorage` | Fetch/update server preference, scope local records to one account, and persist only `synced(userId, preference)`, `pendingDisable(userId)`, or `pendingEnable(userId)`. `pendingEnable` is an inactive write-ahead/finalization state, never permission to emit. |
| `CampaignAttributionRepository` in `module_core/lib/src/repositories/campaign_attribution_repository.dart` | Layer 2; requires `CampaignAttributionStorage` | Enforces a 24-hour TTL and persists pre-auth `pendingUnbound(code, capturedAt)`, post-attempt `pendingRetry(userId, code, capturedAt)`, or `acceptedBySdk(userId, code, completedAt)`. The first authenticated attempt binds any failure to that user; another account can never consume it. Any later valid pre-auth capture after logout replaces completed/failed state before the next account is known. Absence genuinely means no campaign. It never stores a full URI/UTM text. |
| `ProductAnalyticsService` in `module_core/lib/src/services/product_analytics_service.dart` | Layer 3, `@lazySingleton`; requires `AuthSession` (read-only), existing `LifecycleSource`, `ProductAnalyticsRepository`, and `ProductAnalyticsPreferenceRepository` | Sole owner of preference/custom-event lifecycle and Consumer `logEvent`. Exposes a replaying state stream plus `start`, `markPostSplashReady`, `setPreference`, `retryPendingDisable`, and `dispose`. It performs no network work until readiness, revalidates while foregrounded, serializes reconciliation per auth generation, and sends no custom event unless active. While preference is unknown, it may retain exactly one bounded activation-candidate event for the current generation; all other inactive events remain unbuffered. |
| `CampaignAttributionService` in `module_core/lib/src/services/campaign_attribution_service.dart` | Layer 3, `@lazySingleton`; requires read-only `AuthSession`, `CampaignAttributionRepository`, and `ProductAnalyticsService` | Holds at most one bounded URI classification while auth restoration is unknown. It persists pre-auth first touch only after restoration conclusively yields unauthenticated, discards it if authenticated, and attempts only when the bound/current account matches. SDK failure changes unbound pending to account-bound retry; accepted state is also account-scoped. |
| `AnalyticsRouteListener` in `module_core/lib/src/listeners/analytics_route_listener.dart` | Consumer/listener, `@lazySingleton`; requires `RouteSource` and `ProductAnalyticsService` | Owns route subscription, maps `AppRouteDef` exhaustively to `AnalyticsScreen`, signals readiness on the first non-splash route, and reports stable screens only while active. It never passes a route model/path to Foundation. |
| `CampaignAttributionListener` in `module_core/lib/src/listeners/campaign_attribution_listener.dart` | Consumer/listener, `@lazySingleton`; requires `DeepLinkSource` and `CampaignAttributionService` | Replaces the obsolete app `DeepLinkService`, owns the one URI subscription, validates only approved `sesori.com/link` campaign codes, and ignores all other/legacy callback URIs without logging complete values. |
| `NotificationOpenAnalyticsListener` in `module_core/lib/src/listeners/notification_open_analytics_listener.dart` | Consumer/listener, `@lazySingleton`; requires the bounded notification-open source and `ProductAnalyticsService` | Buffers at most the one validated cold-start open until preference reconciliation, emits it only if the same account becomes active, and drops it on disable, logout/account switch, or process-lifetime timeout. No entity ID enters the buffer. |
| `ProductAnalyticsPreferenceCubit` in `module_core/lib/src/cubits/product_analytics_preference/` | Consumer; constructor requires `ProductAnalyticsService` | Subscribes to service state and exposes toggle/retry intents. Mobile Settings constructs it; it is not in DI. |
| `FirebaseAnalyticsClient` in `app/lib/core/platform/firebase_analytics_client.dart` | Thin mobile Foundation adapter, `@LazySingleton(as: AnalyticsClient)`; requires `FirebaseAnalytics` | Serializes only typed custom events plus `schema_version` and `user_key`, and throws failures upward. It never applies global identity/collection overrides and contains no route/campaign/preference/hash business logic. Firebase-disabled environments use the existing no-op SDK object. |
| `FirebaseAnalyticsIdentityMigration` in `app/lib/core/platform/firebase_analytics_identity_migration.dart` | Mobile-only pre-core bootstrap helper; requires `FirebaseAnalytics` | Immediately after Firebase initialization and before DI/listeners, awaits `setUserId(id: null)` to clear the hash persisted by prior releases. It does nothing else to consent/collection. Failure leaves the process custom-event adapter disabled and retries next launch; because automatic collection cannot then be safely reconfigured without another persisted override, the **entire failed process** is classified/disclosed as potentially legacy-keyed and remains covered by recurring legacy deletion. Keep this cleanup through minimum-supported-version adoption plus the 90-day raw window, then remove it explicitly. |
| `NoOpAnalyticsClient` in `desktop/lib/core/platform/no_op_analytics_client.dart` | Desktop phase-1 Foundation adapter | Satisfies shared core DI and accepts operations without collection. No desktop listeners are started. |

`AnalyticsScreen` pins snake-case wire values for login, projects, approved
settings groupings, sessions, new session, session detail, and session diffs.
`settingsHarnesses` and `settingsHarnessManagement` both map to generic
`settings`; they never produce harness-specific wire values. Screen
activity is the Sesori custom `product_screen_viewed` event rather than Firebase
`screen_view`, so the custom-event gate and `user_key` always apply. The
route listener's exhaustive switch also handles splash explicitly (readiness
only, no report while custom sharing is inactive), so adding an `AppRouteDef`
cannot silently omit its analytics mapping.

The client API may return SDK acceptance, not delivery to Google's backend.
That distinction is sufficient for truthful local campaign state and must remain
explicit in names/docs. `ProductAnalyticsService` itself owns the sole deferred
first-message variant; ordinary outcome consumers may ignore delivery results,
but the result remains explicit and analytics cannot alter product success.

### DI and process lifecycle

1. Mobile/desktop phase 1 registers `AnalyticsClient` (Firebase or no-op) plus
   existing `SecureStorage`, `RouteSource`, and `DeepLinkSource` adapters.
2. Auth phase 2 registers `AuthSession` and `AuthenticatedHttpApiClient` without
   any analytics-specific method.
3. Core phase 3 registers both APIs, both Storage classes, three repositories,
   two services, and three listeners. Dependencies therefore resolve only
   downward through the declared layers.
4. Mobile bootstrap awaits `ProductAnalyticsService.start()`, then starts
   `CampaignAttributionService`, `AnalyticsRouteListener`,
   `CampaignAttributionListener`, and `NotificationOpenAnalyticsListener` for
   process lifetime. Their dispose methods are
   owned by GetIt/test teardown. Starting them on the initial splash route
   performs local reads/subscriptions only.
5. Cubits remain constructed in `BlocProvider` and receive
   `getIt<ProductAnalyticsService>()` explicitly. Existing mobile-only
   onboarding widgets call the same service rather than the Foundation client.

Before mobile phase 1, `main()` initializes Firebase and awaits
`FirebaseAnalyticsIdentityMigration`. No Sesori custom event source or core
listener exists yet. A native automatic startup event can still occur between
vendor SDK initialization and this earliest supported reset; treat any such
legacy-keyed row as restricted raw legacy data, exclude automatic events from
behavioral models, cover it through the legacy `USER_ID` deletion path, and do
not claim that upgrade retroactively removes it. If the clear fails, this legacy
classification applies to every automatic event for that whole process—not only
startup—while all custom events remain disabled. Recurring deletion sweeps keep
submitting the legacy user key; do not claim automatic collection was stopped.

### Preference and lifecycle data flow

**Startup and readiness:** Firebase retains its privacy-minimized automatic
event configuration, but custom reporting starts inactive.
`ProductAnalyticsService.start()` reads only local pending state and subscribes
to `AuthSession.authStateStream`; it never validates auth, calls the preference
API, sets global Firebase identity, or changes SDK collection state.
`AnalyticsRouteListener` sees initial `splash` but does not mark
readiness. On the first non-splash route it calls `markPostSplashReady()`. Only
then may the service fetch/reconcile for the currently authenticated account.
If login is still unauthenticated, it waits for the later auth emission. Thus
`restoreLocalSession()` cannot trigger a splash-time network request.

**Reconciliation:** A same-account local `pendingDisable` keeps custom sharing
off and PUTs disabled after readiness. `pendingEnable` also stays inactive: GET
disabled returns to synchronized disabled; GET enabled must first finalize
synchronized enabled storage before event acceptance. Otherwise the repository
GETs the server preference; returned disabled stays off, while returned enabled
in a release build allows `ProductAnalyticsRepository` to hash the account ID
for each typed event. Debug/profile/unsupported builds retain the desired
preference but publish `ProductAnalyticsState.inactive(buildUnsupported)`.

Every auth emission/account switch/logout increments a monotonically increasing
service generation. Each GET, PUT, persistence operation, and scheduled refresh
captures `(generation, userId)`; after every await and immediately before any
state transition/event acceptance it verifies both still match current auth.
Stale completions may finish only their account-scoped storage/server operation;
they cannot activate another generation. Reconciliations are non-overlapping
within one generation. After initial readiness the service refreshes on each
`LifecycleState.resumed` transition and schedules one 15-minute recheck at a
time while continuously resumed. A returned disabled value synchronously marks
the current generation inactive before any follow-up persistence await. Network
failure preserves the honest prior local state and last-successful-check time;
the UI makes the conditional online propagation bound explicit. Every preference
GET/PUT has the API's 10-second operation deadline. Timeout releases the sole
reconciliation slot and advances no state; generation checks ignore any detached
late completion. Disable intent remains durable, so neither logout nor future
15-minute checks can be held indefinitely by one request.

**Schema exposure and first-message deferral:** On each process's first active
transition, the service attempts `analytics_schema_ready` before later buffered
work. Warehouse exposure is the earliest accepted schema-v1 event of any name,
so an outcome event also proves capability if readiness delivery fails. If a
confirmed `session_message_sent` or `session_created_with_message` occurs while
the same generation is preference-unknown (and not locally disabled),
`logEvent` retains only the first typed candidate in memory and returns
`deferredUntilPreference`. Active resolution emits it once; disabled resolution,
logout/account switch, or generation change drops it. No prompt/message content
or session identifier enters the buffer, and no other outcome event is queued.

**Disable:** The cubit calls `ProductAnalyticsService.setPreference(disabled)`.
The service immediately publishes inactive, then first durably persists
`pendingDisable(userId)` before any subsequent await, then calls the preference
repository PUT. Success stores synchronized disabled; network failure remains
pending and exposes the truthful local-disabled/server-sync-pending state. A
storage-write failure keeps in-memory suppression, attempts server disable, and
surfaces unsaved failure unless the server confirms disabled. Retry occurs only
from Settings or a later post-splash lifecycle, never from a timer or splash
auth emission.

**Enable:** Custom sharing remains off. The first awaited operation writes
`pendingEnable(userId)`; if that write fails, no server PUT occurs. The service
then PUTs enabled under the bounded deadline and, on success, must persist
synchronized enabled before activation. If final persistence fails,
`pendingEnable` remains durable and the UI reports “enabled on account; local
finalization pending,” not failure; restart/retry stays inactive until final
storage succeeds. PUT failure/timeout also remains inactive and requires
explicit retry/cancellation, or a later reconciliation that confirms server
enabled and successfully finalizes local storage. The UI always says pending,
not failed, until one of those outcomes; no later activation contradicts the
displayed result.

**Logout/account switch:** Before explicit logout clears credentials, the auth
consumer asks the service to attempt one pending disable sync. Regardless of
success it immediately suppresses custom events. Failure must not block logout:
the encrypted pending record remains scoped by raw ID and is retried after that
account reauthenticates; it never applies to another account. Unexpected token
loss preserves the same record. The attempt is bounded by the 10-second API
deadline, after which logout clears credentials and continues. No path claims or
requests a Firebase-wide data reset.

**Screen flow:** The route listener retains the latest `AnalyticsScreen` while
inactive. Inactive-to-active emits `product_screen_viewed` once; later changed
screen enums emit once. Foundation sees neither `AppRouteDef` nor a concrete URI.

**Campaign flow:** During splash/session restoration, authenticated state is
`unknown`, not unauthenticated. The listener may hold one validated bounded code
in memory, but stores nothing until restoration resolves: authenticated drops
it; conclusively unauthenticated stores `pendingUnbound(code, capturedAt)`.
Authenticated/post-signup opens are ignored. On active state it attempts
`campaign_attributed`. `acceptedBySdk` is persisted only from the typed accepted
result as `acceptedBySdk(userId, code, completedAt)` and deduplicates only that
account. Any later valid pre-auth link after logout replaces prior completion
with pending before the next account is known; if account B then signs up, A's
completion cannot consume B's first touch. If A logs back in instead, the
warehouse age/earliest rules make the extra attempt harmless. The first failed
SDK attempt converts unbound state to `pendingRetry(userId, ...)`; only that same
current account may retry, and account switch discards it. BigQuery accepts
attribution only when the account is at most 24 hours old at event time and
selects the earliest eligible event. Existing
accounts opening campaign links before login therefore remain unattributed.

**Cold notification flow:** The notification dispatcher first performs its
normal validated navigation dispatch and publishes only bounded analytics
metadata. The analytics listener buffers at most that one cold-start open while
preference is unknown. It emits after same-account active reconciliation; it
drops the buffer on disabled, logout/account switch, or if reconciliation does
not complete during that process. Warm opens while active emit immediately;
inactive warm opens are not retained.

### Outcome event catalog

Existing wire names remain unchanged. Add only the following initial events:

| Event | Emit only when | Bounded parameters | Reporting use |
| --- | --- | --- | --- |
| `analytics_schema_ready` | The process first becomes active for an authenticated account under schema v1 | none beyond shared schema/key | Per-account instrumentation-capable exposure; never activity |
| `project_inventory_loaded` | The first successful empty inventory and the first successful non-empty inventory in a cubit lifetime | `inventory_state=empty/non_empty` | First project available from earliest non-empty; empty is onboarding friction |
| `session_activity_viewed` | The first successful empty snapshot in a cubit lifetime, and at most one successful non-empty snapshot per UTC date while that session detail is visible/foregrounded | `activity_state=empty/non_empty` | Earliest non-empty is the monitoring milestone; dated non-empty events support WAU/retention without SSE inflation |
| `session_message_sent` | Existing-session send returns success, including a queued send that later succeeds | `submission_kind=text/command` | Full activation, control activity |
| `session_created_with_message` | `createSessionWithMessage` returns success | `submission_kind`, `workspace_kind=project/dedicated_worktree` | Full activation, remote creation, worktrees |
| `session_creation_failed` | That creation returns an explicit failure | `failure_reason` from bounded `RemoteFailureReason`, `workspace_kind` | Creation friction; never activation |
| `session_question_answered` | Question reply returns success | none | Remote interventions |
| `session_question_rejected` | Question rejection returns success | none | Remote interventions |
| `session_permission_answered` | Permission reply returns success | `decision=once/always/reject` | Remote interventions |
| `session_abort_succeeded` | Root and active-child abort requests all return success | none | Remote interventions |
| `session_diff_viewed` | The first successful empty diff and the first successful non-empty diff in a cubit lifetime | `change_state=empty/non_empty` | Diff adoption from earliest non-empty; empty is diagnostic only |
| `notification_opened` | A valid notification is dispatched after authentication | `source=push/local`, `launch_context=cold/warm`, bounded `category`, bounded `event_type` | Notification engagement |
| `campaign_attributed` | A pre-auth first-touch code captured in the prior 24 hours receives an SDK-accepted attempt for an authenticated custom-sharing-enabled install | `campaign_code` only | Acquisition coverage and cohorts; warehouse also requires account age <= 24 hours and earliest eligible event wins |
| `product_screen_viewed` | `RouteSource` emits a changed non-null `AppRouteDef` while custom sharing is active | stable `screen` enum only | Navigation/friction, never meaningful activity |

For `session_activity_viewed`, `non_empty` means there is at least one message,
pending question/permission, or an active/retrying status.

The send events fire after repository success, never on a tap or queue insert.
The direct-send and queue-drain paths must call the same helper so retries do not
double count. New-session success emits one `session_created_with_message`, not
an additional `session_message_sent`.

### Authoritative emission seams

- `ProductAnalyticsService`: schema-ready exposure on first active transition.
- `ProjectListCubit`: first successful empty and first successful non-empty
  inventory states.
- `SessionDetailCubit._loadMessages` plus its existing lifecycle handling: first
  empty diagnostic and one visible/foreground non-empty activity per UTC date.
- `SessionDetailCubit.sendMessage` and `_drainQueuedMessages`: accepted
  existing-session messages.
- `NewSessionCubit.createSession`: accepted created session/message and bounded
  creation failure.
- `SessionDetailCubit.replyToQuestion`, `rejectQuestion`,
  `replyToPermission`, and `abort`: successful control outcomes.
- `DiffCubit._fetchAndEmit`: first successful empty and first successful
  non-empty diff states.
- `NotificationOpenDispatcher`: valid push/local cold/warm dispatch. Extend the
  internal open request to preserve existing bounded notification category and
  event type, but never an entity identifier in analytics.
- `GoRouterRouteSource`: stable screen names.
- `CampaignAttributionListener`: replace `DeepLinkService` as the sole URI
  listener, parse only strict campaign links, and never log complete URIs.

Every changed cubit/service receives `ProductAnalyticsService` through required
constructor injection. The service reaches the platform sink only through
`ProductAnalyticsRepository`; consumers never hold `AnalyticsClient` or
`AnalyticsApi`. Do not use global service location inside `module_core`, add
optional compatibility parameters, or move success reporting to widget taps
merely to avoid updating tests.

### Outcome emission data flow

| Owner change | Exact flow and deduplication |
| --- | --- |
| `ProjectListCubit` | Add required `ProductAnalyticsService` and retain the bounded inventory states already emitted in that cubit lifetime. Emit the first successful `empty` once and the first later/same-lifecycle `non_empty` once; refreshes never repeat either classification. The warehouse milestone uses only earliest non-empty. |
| `SessionDetailCubit` view | Add required product analytics service. Retain one lifetime empty-diagnostic guard plus the last UTC date for which visible/foreground non-empty activity was emitted. Initial or later empty emits once; the first successful non-empty load/refresh/SSE on each UTC date emits once while the route is visible and lifecycle resumed. Background events emit nothing; resume reload can emit for a new date. This preserves earliest monitoring while supporting later WAU/retention without per-SSE counts. |
| `SessionDetailCubit` send paths | Direct `sendMessage` and `_drainQueuedMessages` call one private `_reportAcceptedSubmission` only on `SuccessResponse`. The queued item retains only text/command for sending; analytics derives text/command without reading content. Error/requeue emits nothing, and each dequeued successful item reports once. |
| `NewSessionCubit` | Add required product analytics service. Capture workspace/submission classifications before awaiting. `SuccessResponse` makes one `session_created_with_message` call; `ErrorResponse` emits only bounded `session_creation_failed`. It never also emits the existing-session event. |
| `SessionDetailCubit` question/permission/abort | Report after each existing method's success branch. Question answers/rejections carry no answer data; permission maps the existing `PermissionReply` enum; abort reports only after every root/active-child response succeeds. |
| `DiffCubit` | Add required product analytics service and retain reported change states. Emit first empty and first later non-empty once each; only non-empty defines adoption, and SSE refreshes do not repeat either state. |
| `NotificationOpenRequest` / `NotificationOpenDispatcher` / `NotificationOpenAnalyticsListener` | Extend the internal request with required bounded category/event type already present in `NotificationData`. Push/local adapters provide `unknown` for legacy local payload omissions. Dispatcher publishes bounded source/cold-warm/category/event-type metadata after validated route dispatch, never project/session/title. The listener applies the one-event cold-start buffer and preference/account rules above before calling product analytics. |
| Screen constructors/tests | `ProjectListScreen`, `NewSessionScreen`, `SessionDetailScreen`, and `SessionDiffsScreen` pass the phase-3 product analytics service from GetIt into required cubit constructors. Core tests inject a mock/recording service and assert event count/shape. |

## Campaign Attribution

Use `https://sesori.com/link/...` campaign links, which the current Android App
Link and iOS associated-domain configuration already accepts. Define a link
runbook that generates:

- a strict opaque campaign code;
- Google Play URL/referrer UTM values for automatic Firebase attribution;
- Apple App Store campaign/provider tokens for App Store Connect aggregate
  reporting; and
- the same code in installed-app universal/app links.

Core stores the first valid pre-auth code plus capture time locally, expires it
after 24 hours, and attempts it only after authenticated custom-event sharing
becomes active, retaining pending state until the SDK accepts an attempt.
BigQuery independently requires the event to occur no later than 24 hours after
account creation, so a campaign opened by an established account never becomes
acquisition. The restricted
`campaign_registry` maps code to source, medium, campaign display name, and
active dates. Do not accept or emit arbitrary UTM text from an inbound URI.

Firebase/Play and App Store attribution have different identity and deferred
deep-link limits. The dashboard reports “known attribution coverage” and keeps
unknown separate; it must not claim that cross-platform attribution is
complete. App Store Connect aggregate data remains a separately labeled source
unless a privacy-reviewed join becomes available later.

## Auth Export

Implement a one-shot auth-server export command, designed to run daily as a
least-privileged Cloud Run Job (or an equivalently isolated scheduler on the
existing host if GCP cannot reach MongoDB). Do not add BigQuery credentials or
export work to request handlers or the long-running auth process.

### Auth preference endpoint and persistence

- `src/types/product-analytics.ts` defines the string-valued
  `ProductAnalyticsPreference.Enabled/Disabled` enum and its Zod schema.
- `src/models/documents.ts` initially adds
  `productAnalyticsPreference` plus `productAnalyticsPreferenceUpdatedAt` with
  an honest decode default of enabled/account creation time for existing Mongo
  documents, while `UserRepository.create` always writes both fields.
  `src/scripts/backfill-product-analytics-preference.ts` performs an idempotent
  `$set` only where either is missing and reports/validates counts. After the
  write-first version is live and backfill reaches zero missing documents, the
  next PR removes both decode defaults and enforces both fields as required.
  It also permits genuinely absent `productAnalyticsExportSuppressedAt`; a
  privacy-deletion workflow sets that timestamp, so no default/backfill exists.
- `src/models/api.ts` defines Zod-validated GET/PUT preference replies/body only;
  it does not modify `UserProfile` or auth token/login contracts.
- `UserRepository.updateProductAnalyticsPreference(userId, preference)` owns one
  atomic Mongo update of value and server timestamp;
  `findProductAnalyticsPreference` reads them with temporary migration defaults
  only in the write-first release.
- `UserRepository.suppressProductAnalyticsExport(userId, suppressedAt)`
  atomically sets preference disabled, updates its timestamp, and sets the
  permanent export-suppression tombstone before any warehouse deletion. GET
  remains disabled and PUT enabled returns an explicit conflict for suppressed
  accounts; ordinary opt-out never sets this tombstone.
- `ProductAnalyticsPreferenceService` in
  `src/services/product-analytics-preference-service.ts` requires only
  `UserRepository` and owns get/update plus permanent export-suppression
  business operations.
- `src/routes/product-analytics.ts` adds authenticated
  `GET /product-analytics/preference` and
  `PUT /product-analytics/preference`; PUT body is
  `{ "preference": "enabled" | "disabled" }` and both reply with
  `{ "preference": ... }`. The existing auth middleware supplies the user; the
  route validates and delegates to the dedicated service. `src/server.ts` and
  `src/index.ts` register/construct this service without changing `AuthService`.
- The Dart client owns this contract in core
  `ProductAnalyticsPreferenceApi`; `AuthManager`/`AuthSession` are unchanged.
- `src/scripts/suppress-product-analytics-export.ts` is the isolated privacy-
  operator composition root. It reads a verified raw account ID from protected
  stdin (never argv/logs), invokes the service suppression operation, verifies
  disabled+tombstoned state, prints only the external privacy request ID/status,
  and closes Mongo. There is no public suppression route.

### Export classes and composition

| Class/file | Constructor dependencies and layer | Responsibility |
| --- | --- | --- |
| `UserRepository` additions in `src/repositories/user-repo.ts` | Existing `MongoDbAccessor` | `findProductAnalyticsExportBatch({afterUserId, batchLimit, createdAtOrBefore})` returns string user ID, creation time, preference/update time, and optional export-suppression time in deterministic ObjectId order. `findPreferenceChanges({after, atOrBefore})` supports the final conservative exclusion pass; no Mongo `ObjectId` leaves the repository. |
| `ActivationStateRepository.findByUserIds` in `src/repositories/activation-state-repo.ts` | Existing Mongo collection | Requires `runCutoff`, batch-loads only the four milestone fields for one user page, and projects each milestone to null when its timestamp is later than that cutoff. It returns a map keyed by string user ID and exposes no reminder fields. |
| `ProductAnalyticsExportRow` / `ProductAnalyticsSetupCohortRow` in `src/models/product-analytics-export.ts` | Plain internal models | Make BigQuery row shapes closed and prevent external-sink calls with auth/OAuth/bridge documents. |
| `BigQueryProductAnalyticsClient` in `src/clients/bigquery-product-analytics-client.ts` | Foundation external client; requires `@google-cloud/bigquery` `BigQuery`, project ID, auth-export dataset ID, one fully qualified authorized internal-exclusion view, and location | Thin SDK operations for creating/inserting/querying **inside the auth-export dataset only**, plus one typed read of active `user_key` values from the authorized view. It exposes no controls write/DDL method and never receives raw IDs/Mongo documents or export semantics. |
| `ProductAnalyticsExportApi` in `src/api/product-analytics-export-api.ts` | Layer 1; requires `BigQueryProductAnalyticsClient` | Defines external auth-dataset operations and read-only active-exclusion retrieval, and maps SDK responses/errors; no pagination, aggregation, or publication policy. |
| `ProductAnalyticsExportRepository` in `src/repositories/product-analytics-export-repo.ts` | Layer 2; requires `ProductAnalyticsExportApi` | Owns a run's staging-table lifecycle, safe-row batching, validation queries, and atomic two-target promotion. The service never calls the client/API directly. |
| `ProductAnalyticsControlRepository` in `src/repositories/product-analytics-control-repo.ts` | Layer 2; requires `ProductAnalyticsExportApi` | Loads and validates the bounded active internal-user key set from the one authorized view. It cannot write controls or auth export tables. |
| `ProductAnalyticsExportService` in `src/services/product-analytics-export-service.ts` | Layer 3; requires `UserRepository`, `ActivationStateRepository`, `ProductAnalyticsControlRepository`, and `ProductAnalyticsExportRepository` | Owns cutoff pagination, SHA-256 transformation, suppression/internal filtering before all counters, enabled-user filtering, weekly external-account accumulation, reconciliation inputs, and repository promotion. `run({ runCutoff }: { runCutoff: Date })` receives one immutable cutoff. |
| `product-analytics-export-config.ts` in `src/scripts/` | Zod over process environment | Validates only job concerns: Mongo connection/database, GCP project, auth-export dataset, authorized exclusion-view name, location, and bounded batch/exclusion-set size. It cannot configure control writes or curated/reporting datasets, does not import the web server's full OAuth/FCM configuration, and accepts no service-account JSON key. |
| `export-product-analytics.ts` in `src/scripts/` | Command composition root | Constructs Mongo repositories, ADC BigQuery client, export API/repository/service; invokes one run, awaits jobs, and closes Mongo in `finally`. It is compiled into the production image and run as `node dist/scripts/export-product-analytics.js`; `src/index.ts` does not import it. |

The web server constructs the dedicated preference service but never constructs
`BigQuery` or any export API/repository/service. The scheduled job uses the same
built image with a command override, so auth HTTP availability and latency
cannot depend on BigQuery.

The job takes a fixed `runCutoff`, pages only users created by then, and
batch-loads activation states with the same cutoff so later milestone writes
are always null regardless of which page observes them. Preference updates are
privacy-conservative: rows whose `productAnalyticsPreferenceUpdatedAt` is after
`runCutoff` are never eligible in that run. Immediately before promotion the
service captures `preferenceScanCutoff`, queries all preference changes in
`(runCutoff, preferenceScanCutoff]`, removes those keys from staging/eligible
coverage, and validates none remain. A preference update after that second
cutoff belongs to the next run; a disable still disappears from reporting on
that next successful export. This explicit rule avoids reconstructing unknown
historical preference values while ensuring pagination timing cannot admit a
post-cutoff enable/disable. The job writes two products through temporary tables
before an atomic replace/merge:

1. `auth_private.auth_user_milestones`: only enabled accounts that are neither
   internally excluded nor source-suppressed; fields are `user_key`,
   `account_created_at`, `notification_registered_at`,
   `bridge_registered_at`, `legacy_first_metadata_request_at`, and
   `exported_at`.
2. `auth_private.auth_weekly_setup_cohorts`: identifier-free external-account
   cohort totals after internal and source-deletion suppression, including total
   accounts, enabled-account coverage, notification and bridge registration
   within 1/7/30 days, and the legacy signal. Ordinary opted-out accounts remain
   in these aggregate setup totals without exposing keyed rows.

Never export provider identity or reminder scheduling/sent timestamps. Replace
the eligible-user snapshot and rebuild setup cohorts each run so currently
disabled/suppressed accounts no longer join behavioral reports and suppression
can remove prior aggregate contribution. Keep raw account rows inside Mongo;
only filtered aggregate cohorts leave the auth boundary.

At run start, the service loads the active internal `user_key` set and records
its control-view update/cutoff in run metadata. Missing, stale, malformed, or
over-limit control output aborts the run before source pagination; it never
falls back to an empty exclusion set. For each page it builds a user-
ID-to-activation-state map, hashes each raw user ID in memory, and first skips a
row entirely when source-suppressed or present in the internal set. Only then
does it update weekly counters; it creates a keyed milestone row only when the
remaining account preference is enabled. This also excludes opted-out internal
accounts before irreversible aggregation. It drops raw IDs/page hashes before
requesting the next page. Run-scoped staging tables contain only hashed/
aggregate rows, expire within 24 hours, and are invisible to reporting.
After all pages and checks succeed, one BigQuery multi-statement transaction
deletes/inserts both published targets from staging; a failure rolls back both,
leaving the prior snapshot/cohorts visible. Cleanup is best-effort because table
expiry is the final guard.

Job acceptance checks before promotion:

- one unique, non-null 64-character lowercase hex `user_key` per eligible
  account;
- milestone ordering and timestamp types are valid without assuming setup
  occurs in a fixed order;
- exported enabled count reconciles with aggregate coverage count;
- internal/suppressed source counts reconcile with exclusions before weekly
  aggregation, and neither class appears in keyed or aggregate outputs;
- source and staging row counts are recorded without raw IDs;
- a partial/failed run leaves the previous published tables intact.
- milestones written after `runCutoff` and preferences changed before
  `preferenceScanCutoff` remain excluded regardless of the page on which the
  concurrent write occurs.

Use Application Default Credentials, Secret Manager for Mongo access, and an
export service account limited to BigQuery Job User plus Data Editor on
`sesori_analytics_auth_private` plus table-level Data Viewer on the one
authorized active-internal-exclusion view. It has no controls dataset write/DDL
role and no role on raw, curated, or reporting datasets, so it cannot mutate
campaign/exclusion/config tables. A separate scheduled-transform identity has read-only access to raw,
auth-private, and controls plus write access to curated; the deployment identity
alone owns schemas/IAM/control-table writes. The auth web runtime receives no
BigQuery role.

## BigQuery Design

### Day-zero setup

Do this before waiting for application PRs because Firebase export is not
retroactive:

1. Confirm the Firebase project is `sesori-ai`, identify the GA4 property ID,
   billing status, property timezone, current GA retention/deletion posture, and
   existing BigQuery link. If already linked, audit and remediate every existing
   raw table before any dashboard or application rollout.
2. Before creating a new link, put the sink in a dedicated/restricted GCP
   project: remove broad project dataset-reader roles, establish the approved
   admin and scheduled-query identities, and prepare automation that applies a
   90-day default table expiration plus dataset ACL immediately when GA creates
   `analytics_<property_id>`. Enable **daily only**, not streaming/intraday, so
   those controls can be verified before the first daily table lands. If a table
   appears before verification, stop rollout, apply expiration to it explicitly,
   and treat the miss as a privacy preflight failure.
3. Record the immutable raw dataset location. If no location exists, choose the
   privacy/operations-approved location (prefer EU when compatible); every
   derived dataset must use the same location.
4. Configure GA4 event/user-data retention to two months, disable Google Signals,
   ad personalization, ad storage/user-data features, and verify Firebase native
   advertising identifiers remain disabled before collecting production data.
5. Record `raw_export_start_at` only when the first controlled daily export is
   verified. Record `behavioral_schema_v1_start_at` separately only after the
   released event schema is observed in export. Also record owner, identities,
   deletion-job owner, and dashboard access group in restricted configuration.
6. Verify one existing event reaches `analytics_<property_id>.events_*`, then
   verify the new custom schema before setting its behavioral timestamp.

### Datasets

All names below are deployment defaults and remain configurable for the real
property/project IDs:

| Dataset | Access | Contents |
| --- | --- | --- |
| `analytics_<property_id>` | Raw restricted | Firebase-managed GA4 daily tables |
| `sesori_analytics_auth_private` | Security/analytics admins, auth export job; transform identity read-only | Auth eligible-user snapshot/staging and aggregate setup cohorts only |
| `sesori_analytics_controls` | Security/analytics admins and deployment identity; transform identity read-only; auth-export identity can read only an authorized active-exclusion view | Campaign registry, internal-user exclusions, dual measurement timestamps, export freshness policy |
| `sesori_analytics_curated` | Analytics engineers | Flattened allowlisted events, daily user activity, user milestones, scheduled intermediate tables |
| `sesori_analytics_reporting` | Looker service account/product leadership | Identifier-free authorized views and dashboard tables |

Version deployable assets under `tool/product_analytics/`: a data dictionary,
templated DDL and scheduled-query SQL, a small deployment command accepting
project/GA4 dataset/location, BigQuery `ASSERT` fixture tests, and an operations
runbook. Never commit service-account material or live internal user keys.

The initial file ownership is fixed:

- `tool/product_analytics/deploy.dart` validates named project, location, raw,
  auth-private/controls/curated/reporting datasets, and both start timestamps;
  renders identifier placeholders from the checked-in SQL; and invokes `bq`
  non-interactively with the explicit location. It does not perform `gcloud`
  login or read key files.
- `tool/product_analytics/sql/00_datasets.sql` creates/configures derived
  datasets and reference tables; `10_events_flattened.sql`,
  `20_user_activity_daily.sql`, `25_acquisition_first_touch.sql`,
  `30_user_milestones.sql`,
  `40_activation_retention.sql`, and `50_reporting_views.sql` own the dependency
  order described below.
- `tool/product_analytics/sql/schedules.json` is a credential-free manifest of
  query file, destination, cadence, recent-date recomputation window, and max
  bytes; the deploy command creates/updates those transfer configs only after a
  `--apply-schedules` flag.
- `tool/product_analytics/tests/metric_contract_assertions.sql` uses temporary
  fixture tables and BigQuery `ASSERT`; `schema_allowlist_assertions.sql` fails
  when curated columns/event parameters exceed the approved contract.
- `tool/product_analytics/README.md` is the operator runbook/data dictionary;
  `LOOKER_STUDIO.md` pins page sources, filters, formulas, access group, and
  manual dashboard verification because Looker Studio report layout is not a
  safely deployable repository artifact.

### Vendor-managed raw GA4 boundary

Firebase's BigQuery export schema unavoidably includes more than Sesori's custom
parameters. In the restricted `analytics_<property_id>` dataset this includes
`user_pseudo_id` (an app-install identifier), GA session identifiers, platform,
device category/brand/model/OS fields, derived geographic fields, app metadata,
traffic-source strings, event bundle/stream metadata, and Firebase automatic
events. The source IP is not an exported column, but Google may derive the geo
fields before export. With AD_ID, IDFV, ad storage, ad user data, Google Signals,
and personalization disabled, advertising/vendor identifier fields are expected
to be null; verify that assumption from production rows rather than relying on
configuration alone.

These vendor fields change the controls and disclosure, not the event contract:

- raw GA4 access is limited to the analytics/security admin group and scheduled
  query service account; Looker and ordinary product viewers receive none;
- raw daily tables receive a 90-day expiration, sufficient for late-data repair
  and the planned retention windows, while longer history comes from minimized
  curated facts and identifier-free aggregates;
- `events_flattened` deliberately does **not** select `user_pseudo_id`, GA
  session ID, device brand/model, geo, user properties, advertising/vendor IDs,
  bundle sequence, stream ID, or arbitrary traffic-source strings;
- curated acquisition maps only a strict Sesori campaign code/registry match or
  a small approved source class; unmatched raw traffic text becomes `unknown`;
- Firebase automatic events are excluded from behavioral facts. Only a
  transient `first_open`/traffic-source projection may participate in the
  acquisition model; app/screen opens never define activity;
- the privacy notice must disclose Firebase's pseudonymous install/device and
  approximate-location processing even though those fields are discarded from
  Sesori reporting.

If the linked property cannot apply the required raw expiration or Google
Signals/ad settings, stop dashboard rollout and resolve that cloud posture; do
not weaken the written privacy boundary to fit an unchecked property.

### Curated models

1. **`events_flattened`**: flatten only catalogued Sesori custom events/parameters
   from GA4, use `event_timestamp` in UTC, require schema version and non-null
   custom `user_key`, and retain Firebase platform/app version/build. Anti-join
   both active internal/test keys and the permanent deletion-exclusion keys on
   every build/recomputation, but deliberately do **not** join the time-varying
   current auth eligibility snapshot here. Raw bundle/install fields may be used
   transiently to discard
   byte-identical export duplicates but are not selected into the table. This
   recoverable 90-day fact layer prevents a transient auth-export outage from
   permanently discarding otherwise eligible events.
2. **`user_activity_daily`**: one row per user/date with monitor, control,
   message, notification, diff, and feature flags/counts.
3. **`user_milestones`**: auth timestamps plus earliest schema-v1 exposure,
   project availability, full activation, monitor activity, and feature
   milestones. Full activation is the minimum of the two successful message
   event names only; `analytics_schema_ready_at` is the earliest schema-v1 event
   of any name.
4. **`activation_cohorts`**: account-cohort denominators only when schema-v1
   exposure occurs within 24 hours of account creation, plus 1/7/30-day
   milestone flags, times to milestone, cohort maturity, and separate
   preference/schema coverage.
5. **`retention_cohorts`**: activation-anchored W1/W4 eligibility and activity.
6. **`acquisition_first_touch`**: earliest strict custom campaign code or
   approved automatic store/source class per eligible user, provided the event
   occurs no later than 24 hours after account creation. It uses raw
   install/traffic fields only inside the scheduled query, persists no
   `user_pseudo_id` or arbitrary source text, and labels unmatched values
   `unknown`.

Materialize partitioned daily/intermediate tables where repeated Looker scans
would be expensive; cluster event facts by event name/user key. Scheduled
queries recompute at least the last three UTC event dates because GA4 daily
exports can receive late events. Reporting uses only completed recomputations,
and data-quality views expose source/export/query freshness.
Every user-level reporting build also inner-joins the **current** eligible auth
snapshot and anti-joins the current internal exclusion table. Therefore a
disable or newly added internal exclusion takes effect after the next auth
export/report refresh even when an older curated partition exists; those gates
are not applied only at the historical partition's original build time.

The auth export atomically publishes snapshot metadata (`run_id`, immutable
source cutoff, completion time, eligible/source counts) with its tables. Before
any eligible user-level transform writes or replaces output, BigQuery `ASSERT`s
that the latest successful snapshot is no more than 36 hours old and its
reconciliation checks passed. A stale/missing/partial snapshot aborts before
mutation and leaves the previous reporting tables plus an explicit stale status
visible; it never publishes an empty day. `events_flattened` can continue
ingesting recoverable custom facts without that join. Once auth export recovers,
the user-level schedules recompute from the first date after the last
successfully published reporting watermark through the current three-day late-
arrival window (bounded by the 90-day recoverable retention) before advancing
freshness. Thus a week-long outage backfills the whole missed week rather than
only three days.

### Reporting views

- `investor_snapshot`: latest complete-week headline metrics, prior comparison,
  sample sizes, coverage, and as-of timestamps.
- `weekly_kpis`: new accounts, meaningful/controller WAU, growth, activity
  depth, and activation/setup conversion.
- `activation_funnel`: account -> bridge -> project -> message, with matured
  1/7/30-day cohorts and notification registration beside the main path.
- `retention`: W1/W4 cohorts with eligible denominators.
- `feature_adoption`: worktree, diff, question/permission, abort, and
  remote-created-session adoption.
- `notification_engagement`: opens and 30-minute open-to-action conversion by
  bounded category/event type.
- `acquisition_performance`: known coverage, accounts, activation, and
  retention by registered campaign; suppress small segmented cells.
- `onboarding_friction`: empty project/session states, bounded creation
  failures, and existing support/install interactions.
- `data_quality`: event freshness, schema/app versions, null identity, unknown
  enums, excluded internal traffic, preference coverage, and cohort maturity.

### Retention, access, and cost

- Keep raw GA4 tables for 90 days and minimized pseudonymous curated event data
  for 14 months initially; retain identifier-free weekly aggregates longer only
  after privacy approval.
- Keep the current eligible auth snapshot rather than historical copies with
  user keys. A disabled or source-suppressed account disappears from joinable
  reporting on the next successful export.
- Restrict raw/private datasets; give Looker and routine viewers access only to
  reporting views. Do not expose `user_key` in Looker fields, extracts, or URLs.
- Maintain internal/test exclusions as hashes in a restricted table with owner,
  reason, and optional expiry. Never put the list in Git.
- Apply campaign segmentation suppression when a cell has fewer than
  the approved minimum users; totals retain sample sizes.
- Configure dataset/table expiration, scheduled-query byte limits, billing
  alerts, and a monthly cost check before dashboard sharing.
- Implement a privacy-request runbook/job that first calls the auth-source
  suppression operation, verifies preference disabled plus
  `productAnalyticsExportSuppressedAt`, and only then adds `user_key` to a
  restricted deletion-exclusion control. It deletes matching auth-private/
  curated/reporting rows and rebuilds identifier-free setup cohorts. It does not
  declare warehouse completion until an auth export with
  `runCutoff >= productAnalyticsExportSuppressedAt` has published, then performs
  one final delete/rebuild and verifies the key/contribution remains absent.
  Thus an export staged before the tombstone may finish, but cannot restore data
  after the verified tombstone-aware run/final cleanup; no broad cross-system
  lock is required.
- From the still-retained raw window, resolve only `user_pseudo_id` values whose
  installation emitted a matching keyed custom event and submit GA4 User
  Deletion API requests as app-instance IDs. Also submit the hashed key as legacy
  GA `USER_ID` for data produced before this design removed global `user_id`.
  An automatic-only installation that disabled before ever emitting a keyed
  event has no account link by design and cannot be targeted by an account-based
  deletion request; do not claim otherwise. Its unlinked GA4 data is governed by
  the verified two-month upstream retention. State this limit in the privacy
  notice/deletion response rather than creating a persistent account-device map.
- Keep deletion-exclusion tombstones permanent and run a daily upstream deletion
  sweep over newly landed raw partitions. For every tombstoned key it discovers
  newly uploaded keyed installation IDs (including events queued while a
  supported client was offline), resubmits GA app-instance deletion, deletes any
  matching warehouse rows, and always submits the legacy `USER_ID` while that
  migration window remains possible. The request can report source/warehouse
  deletion plus recurring enforcement installed, but must not promise that an
  offline client's future upload can never transiently reach restricted raw.
  Record request IDs/completion without raw account/install IDs. Test the API
  credential, request format, in-flight export ordering, delayed offline upload,
  flattened anti-join/non-repopulation, aggregate rebuild, and a non-production
  deletion before rollout.

## Looker Studio

Create one restricted report backed only by `sesori_analytics_reporting`:

1. **Executive snapshot** — headline scorecards, complete-week trends,
   activation funnel, W1/W4 retention, sample size, behavioral coverage, and
   last refresh.
2. **Activation** — cohort funnel and time-to-step distributions; optional
   notification registration is visually separate.
3. **Retention and engagement** — cohort heatmap, meaningful/controller WAU,
   active days, interventions, and message depth.
4. **Feature adoption** — worktree/diff/remote interaction trends.
5. **Acquisition** — known-attribution coverage and thresholded campaign
   quality; unknown remains explicit.
6. **Product quality** — onboarding states and bounded failures.
7. **Data quality** — freshness, coverage, exclusions, versions, and incomplete
   cohorts so a broken pipeline cannot look like declining usage.

Default every page to complete periods. Allow a clearly marked live-period
filter for operators, but never use live partial values in exported investor
screenshots.

## Implementation Sequence

This implementation intentionally spans five PRs. The extra auth-server slice
is required to make the persisted-field migration write-first and race-free.
Every implementation PR uses
the fixed series title wrapper shown below; `user-analytics` is this plan's
directory name.

### PR 1/5 — Write-first auth preference

**Title:** `[user-analytics] Add write-first analytics preference [step 1/5]`

**Repository:** `sesori_auth_server`

- Add the persisted enum/value-update timestamp, temporarily default missing
  fields to honest prior values at decode/read boundaries, and add genuinely
  nullable `productAnalyticsExportSuppressedAt` without a default.
- Make every new `UserRepository.create` write preference plus update timestamp
  before exposing GET/PUT preference behavior.
- Add the dedicated repository-backed preference service and authenticated
  product-analytics routes; leave all auth profiles/tokens untouched.
- Add the idempotent backfill/count command.
- Test auth/validation, new-user writes, missing-document default, concurrent
  updates, and unchanged OAuth/password/refresh responses.
- Deploy this version fully, verify every new user writes the field, then run
  backfill until repeated validation reports zero missing. PR 2 cannot merge or
  deploy before that evidence is recorded.

### PR 2/5 — Enforce preference and add auth export

**Title:** `[user-analytics] Enforce analytics preference and add export [step 2/5]`

**Repository:** `sesori_auth_server`

- Remove the temporary missing-field default and make the Mongo model required;
  add a startup/test assertion that fixture creation always supplies it.
- Add BigQuery Client -> export API -> export/control repositories -> export
  service, source suppression operation/command, isolated job config/composition,
  package dependency, and production image command.
- Publish the eligible pseudonymous snapshot and identifier-free weekly setup
  cohorts through staging/validation/transactional promotion, excluding source-
  suppressed and active internal keys before keyed rows or aggregate counters.
- Test hashing golden vector, opt-out filtering, aggregate reconciliation,
  pagination cutoff, milestones/preferences changing on already-read and future
  pages, conservative preference exclusion, staging cleanup, rerun idempotency,
  source/internal suppression before aggregation, tombstone non-repopulation,
  and failed-run safety.
- Deploy web enforcement only after step-1 zero-missing evidence. Deploy the job
  definition disabled; schedule it in PR 5 after private datasets/IAM exist.

### PR 3/5 — Client analytics foundation and preference

**Title:** `[user-analytics] Add client analytics foundation and opt-out [step 3/5]`

**Repository:** apps monorepo

- Add the explicitly layered core models, Analytics Client/API/repository,
  preference API/Storage/repository/service, route listener/readiness gate, and
  Settings cubit. `module_auth` and shared `AuthUser` remain unchanged.
- Move the existing seven-event contract into core models and route existing
  onboarding UI calls through `ProductAnalyticsService`.
- Implement the thin `FirebaseAnalyticsClient`, pre-core legacy-identity cleanup,
  and desktop no-op adapter in product shells; add pure-Dart `crypto` to
  `module_core` and keep SHA-256, route mapping, state, and lifecycle in core.
- Remove `AnalyticsUserIdTracker`, clear its persisted global Firebase user ID
  immediately after Firebase initialization, never set another account key or
  persisted collection override, gate every Sesori custom event to post-splash
  authenticated enabled release builds, and add schema-ready/custom stable-
  screen reporting.
- Add the Settings toggle, explanatory/localized copy, pending/error behavior,
  explicit installation/automatic-event limitations, and privacy/legal/store-
  disclosure updates.
- Test API parsing, layer wiring, fail-closed custom events during splash,
  post-splash fetch, pending-disable storage as the first awaited operation,
  storage failure, crash/restart pending recovery, pending-enable write-ahead/
  finalization failure, 10-second timeout releasing logout/reconciliation,
  legacy-ID clear success/failure ordering and whole-process disclosure, logout
  sync failure/account-switch preservation, enable-after-server success, delayed
  GET/PUT/storage completions across rapid login/logout/account switches,
  foreground/15-minute refresh propagation, harness routes mapping only to
  generic settings, debug suppression, core identity hash, route-to-screen
  mapping, event wire pins, and mobile/desktop DI.
- Release only after both auth PRs are deployed. Once users can opt out, this
  custom-event lifecycle becomes a non-rollback privacy floor: subsequent
  client fixes must preserve it or suppress all Sesori custom events.

### PR 4/5 — Outcome and campaign instrumentation

**Title:** `[user-analytics] Instrument activation and engagement outcomes [step 4/5]`

**Repository:** apps monorepo

- Add the event catalog variants and bounded enum serialization.
- Instrument the authoritative core/app seams listed above, including both
  direct and queued message success, while keeping analytics best-effort and
  non-blocking.
- Buffer only the first activation-candidate outcome while same-generation
  preference is unknown, then emit on active or drop on disabled/auth change;
  report first empty/non-empty transitions for milestones and at most one
  visible non-empty session activity per UTC date for WAU/retention.
- Preserve bounded notification category/event type through open dispatch and
  classify push/local plus cold/warm; buffer the single cold-start open until
  same-account preference resolution and drop it on disable/logout/timeout.
- Add core campaign Storage -> repository -> service -> deep-link listener,
  auth-restoration hold, 24-hour pre-auth capture/attribution rules, account-
  bound failed retry, typed SDK-acceptance result, and remove the obsolete app
  `DeepLinkService` and full URI logging.
- Regenerate only source-generated outputs.
- Add focused tests that failures/taps/queued-only operations do not activate,
  each successful message path makes one service call, new-session success is not
  double counted, sensitive inputs cannot enter parameter maps, notification
  classification and first-message deferral survive preference resolution,
  empty-to-non-empty transitions report once, resumed/later-date monitoring can
  report again without SSE inflation, auth-unknown links wait for restoration,
  post-signup/old-account links cannot become acquisition, and account A failed/
  completed state cannot consume account B's first touch.

### PR 5/5 — Warehouse models and dashboards

**Title:** `[user-analytics] Add BigQuery metrics and Looker dashboards [step 5/5]`

**Repository:** apps monorepo plus cloud deployment

- Add `tool/product_analytics/` data contract, parameterized deployment tool,
  DDL, transforms, fixture assertions, scheduled-query definitions, and runbook.
- Create auth-private/controls/curated/reporting datasets in the raw GA4
  location; keep export-job write access confined to auth-private and grant only
  authorized-view reads for internal exclusion; configure IAM, expiration,
  budget alerts, campaign registry, source/control exclusions, upstream GA4
  retention/deletion limits, and separate raw/behavioral start timestamps.
- Schedule the auth export and three-day event recomputation, then reconcile
  source counts and freshness; verify stale auth snapshots abort publication and
  recovery backfills the missed window.
- Apply deletion exclusion in flattened facts, schedule the recurring upstream
  tombstone sweep, and require a tombstone-aware auth export plus final cleanup
  before declaring warehouse deletion complete.
- Build and permission the seven-page Looker report.
- Run a release-build smoke test through account -> bridge -> project -> message
  and verify the event, auth join, full activation, complete-day table, and
  reporting view without inspecting sensitive payloads.
- Record dashboard owner, refresh schedule, metric definitions, and rollback/
  incident steps in the runbook.

### Deployability, compatibility, and rollback by step

| State | Independently usable behavior | Deployment prerequisites/order | Rollback boundary |
| --- | --- | --- | --- |
| Before 1/5 | Existing clients/events continue. Firebase daily export should be linked only through the controlled day-zero sequence so its non-retroactive clock starts safely. | Complete restricted-project IAM, daily-only link, raw expiration/settings verification, and record `raw_export_start_at`. | Unlinking loses future export and is not a useful rollback; stop rollout and correct IAM/expiration/location before derived datasets or new instrumentation. |
| After 1/5 | Dedicated GET/PUT preference endpoints work; old clients are unaffected because auth responses did not change. New users always write preference; old documents read as enabled during migration. | Deploy write-first web code to all serving instances, verify new writes, run/re-run backfill, and record zero missing. | Roll back before any opt-out client release if necessary. The added field is ignored by old code; do not remove it. Re-run backfill after returning to step 1. |
| After 2/5 | Preference schema is required and export command/job image is deployable but unscheduled. Existing clients remain unaffected. | Require recorded zero-missing evidence from step 1; deploy enforcement; smoke-test account creation and endpoints; deploy job disabled. | Roll back web/job to step 1, whose honest missing-field default can read every document. Stop any job; published tables stay at last good state. |
| After 3/5 | Mobile clears the prior global Firebase user ID before custom sources, can disable/enable Sesori custom events on this installation, and syncs its server reporting/supported-client preference; existing custom events and stable screens obey the lifecycle; Firebase automatic install events retain the separately disclosed property behavior; desktop remains no-op. | Both auth endpoints/schema must be live. If legacy-ID clear fails, custom events stay disabled and all automatic events for that process are classified as potentially legacy-keyed; if preference is unavailable, GET/enable fails closed and disable remains local pending without blocking logout. | **Forward-fix only after public release.** Preserve both legacy-ID cleanup and local custom-event gating through their declared floors. For a severe defect, suppress all custom events; do not claim automatic collection stopped on clear failure or that legacy behavior is controlled. Server preference data is never rolled back. |
| After 4/5 | New activation/engagement events accumulate in GA4 raw export. Product operations remain unchanged if Firebase is unavailable. | Step 3 custom-key/preference/schema lifecycle must be released. BigQuery needs no GA4 custom-dimension registration. | Forward-fix the app while retaining step-3 privacy behavior; event-specific defects may be disabled/removed. Missing future event names yield null/zero data, not product failure. |
| After 5/5 | Auth job, curated models, authorized reporting views, and Looker provide the complete metric contract. | Create same-location datasets/IAM; deploy SQL/tests; schedule auth export; validate its first publish; schedule event transforms; then connect Looker. | Pause schedules/job and revert reporting views/dashboard sources to last known-good SQL. Raw GA4 and prior auth published tables remain; app behavior is unaffected. |

There is no `AuthUser` compatibility field, alternate endpoint, optional
internal constructor parameter, dual event name, or product behavior in
`module_auth`. Server write-first/backfill/enforce ordering handles persistence;
client fail-closed behavior plus a declared forward-fix privacy floor handles
the separately released app.

## Verification

### Apps monorepo

- Run code generation after changing Freezed/Injectable sources; never edit
  generated files manually.
- `dart test` and `dart analyze` in `client/module_core`; add API/repository/
  service/listener/cubit tests with fake platform clients/storage.
- `flutter test` and `dart analyze` in `client/app`.
- `dart test`/`dart analyze` in `client/module_desktop_core` and
  `flutter test`/`dart analyze` in `client/desktop` when shared DI/constructor
  changes affect desktop.
- Inspect a release-build Firebase DebugView/BigQuery sample using synthetic
  content and verify no forbidden field/value appears. Do not turn normal debug
  custom-event sharing on for convenience.
- Seed the current release's global Firebase user ID, upgrade to the new build,
  and verify null-clear completes before any custom source starts; force clear
  failure and verify custom events remain disabled while product startup works,
  then verify the runbook classifies the whole process's automatic rows as
  potentially legacy-keyed rather than claiming collection stopped.

### Auth server

- `npm run build`, `npm run lint`, `npm run format:check`, and focused Node test
  suites; run the full DB-backed tests when MongoDB is available.
- Run export dry-run/staging against synthetic accounts including enabled,
  disabled, internal enabled/disabled, source-suppressed, no activation state,
  out-of-order milestones, and page-boundary cases.
- Compare published aggregate totals to direct Mongo aggregate counts without
  exporting raw comparison rows.

### BigQuery and Looker

- Dry-run every deployed query and run fixture `ASSERT`s for activation event
  inclusion, failed/queued exclusion, deferred first-message selection, timely
  per-account schema exposure, legacy-without-exposure exclusion, 7-day cohort
  maturity, W1/W4 boundaries, internal/disabled/suppressed filtering before
  aggregates, deletion exclusion in flattened recomputation, daily monitoring
  activity without SSE duplication, the 24-hour campaign rule, unknown campaign,
  stale-auth-snapshot publication abort/recovery, and late-event replacement.
- Reconcile GA4 custom event counts -> flattened events -> daily activity ->
  reporting totals for at least three complete days.
- Verify auth export credentials cannot write controls/curated/reporting, Looker
  credentials cannot query raw/private datasets or expose user keys, and verify
  sample-size/partial-period labels.
- Verify raw ACL/default expiration and GA4 two-month retention before data
  acceptance, then complete one non-production GA User Deletion API exercise
  through auth-source tombstone, warehouse suppression/deletion, aggregate
  rebuild/non-repopulation after an in-flight pre-tombstone export, delayed
  offline-client upload plus recurring sweep, and upstream request status.
  Verify the deletion response states both the transient future-upload and
  automatic-only never-keyed installation limits.

## Rollout And Two-Month Readiness

1. **Day 0:** Establish restricted project IAM, link daily Firebase export,
   verify raw ACL/90-day expiration before the first table, and record
   `raw_export_start_at`; this data cannot be recovered later.
2. **Week 1:** Land/deploy write-first auth preference, run/verify backfill,
   then land enforcement/export.
3. **Weeks 1-2:** Land the client foundation and ship its fail-closed opt-out
   release.
4. **Weeks 2-3:** Land instrumentation and ship the mobile release as early as
   store review permits; set `behavioral_schema_v1_start_at` only after its
   schema appears in controlled raw export.
5. **Weeks 3-4:** Deploy warehouse models, run data QA, and build Looker.
6. **Weeks 4-8:** Monitor data-quality alerts weekly, correct only demonstrated
   schema/metric defects, and let cohorts mature.

W1 retention becomes available after two weeks of production behavior. W4
requires at least 35 days after a user's activation to close the full 28-34 day
window; any release delay directly reduces the W4 sample available by the
two-month deadline. Show the cohort size and use null—not a fabricated zero—if
no cohort has matured.

## Risks And Mitigations

- **No retroactive behavioral data:** link/export and ship early; label raw and
  behavioral starts separately and do not backfill full activation from
  metadata requests.
- **Developer/internal pollution:** custom events are release-only and reporting
  excludes a restricted internal-user list; monitor app version/schema mix.
- **Opt-out bias:** show eligible coverage with every behavioral funnel and do
  not extrapolate activation/retention to all accounts.
- **Legacy denominator bias:** require timely per-account schema-v1 exposure;
  global rollout time or server default-enabled state alone never makes an
  account measurable.
- **Cross-repository deployment mismatch:** deploy write-first server behavior,
  backfill/verify, then enforce, and only then release the client. Preference
  GET/PUT failure is fail-closed; auth profiles remain unchanged.
- **Legacy/automatic-event limitation:** a pre-opt-out binary can continue its
  prior Firebase behavior, and Firebase automatic install events are outside the
  custom-event toggle. Narrow UI/legal promises accordingly, use current
  preference only for supported-client custom events and reporting eligibility,
  and never claim account-wide enforcement without minimum-version controls.
- **Legacy global identity on upgrade:** clear it at earliest post-Firebase
  bootstrap before custom sources and keep the migration for the raw-retention
  window. Automatic events before a successful reset—or for the whole process
  when reset fails—remain restricted legacy raw data and are never represented
  as fully preventable.
- **Offline upload after deletion:** permanent source/control tombstones,
  flattened anti-join, and daily upstream resweeps prevent durable reporting and
  repeatedly delete newly discovered keyed installs; the response remains
  honest that a later upload may transiently enter restricted vendor/raw data.
- **Privacy rollback floor:** after the opt-out release, use forward fixes that
  preserve local pending-disable/custom-event gating or suppress all custom
  events; never republish old startup emission as rollback.
- **Analytics affecting product behavior:** all reports are best-effort,
  unawaited after confirmed outcomes, and failure-isolated.
- **High-cardinality or sensitive leakage:** closed event variants, bounded
  enums/campaign codes, raw-ID prohibition, wire-pin tests, and allowlisted SQL.
- **Misleading acquisition:** label known coverage and platform limitations;
  never relabel unknown as organic.
- **Late/incomplete GA4 exports:** recompute recent partitions and show freshness
  plus complete-period defaults.
- **Auth-export outage:** keep flattened facts independent, assert a fresh
  completed snapshot before user-level publication, retain last-good reporting,
  and backfill the recent raw window after recovery.
- **Small-cohort investor overstatement:** show denominators, maturity, and
  thresholded segments; keep directional W4 claims explicitly directional.
- **Cloud location/hosting uncertainty:** discover before dataset creation;
  colocate all BigQuery data and use an isolated scheduler that can securely
  reach MongoDB rather than coupling export to auth requests.

## Completion Criteria

The work is complete when:

- A production release makes one analytics emission attempt per confirmed
  first-message success path with a pseudonymous custom `user_key`, immediately
  honors installation-local disable/re-enable semantics, preserves pending
  disable/enable sync across logout/restart, bounds preference operations,
  defers the first same-generation message while preference is unknown, clears
  legacy global identity before custom sources, and never claims to control
  legacy or automatic events; duplicate delivery cannot change activation.
- The auth job publishes validated eligible milestones and external-account
  setup cohorts without raw identity or internal/deletion-suppressed accounts.
- BigQuery derives the metric contract above from versioned SQL, passes fixture
  assertions, survives stale auth snapshots without permanent event loss, and
  remains fresh after recovery/late data.
- Privacy deletion remains excluded from flattened/reporting rebuilds, survives
  an in-flight old auth export, and has recurring upstream enforcement for later
  keyed uploads with its unavoidable transient/never-keyed limits disclosed.
- Looker exposes only aggregate authorized views and shows complete-period,
  denominator, coverage, maturity, and freshness labels.
- The executive page can truthfully report new accounts, setup, full
  activation, WAU/growth, W1/W4 retention when mature, activity depth, and the
  selected feature-adoption metrics without manual spreadsheet logic.
