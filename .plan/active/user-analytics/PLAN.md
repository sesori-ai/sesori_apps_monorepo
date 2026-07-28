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
3. Optional product-interaction analytics is enabled by default for an account
   after its authenticated preference is known. Users receive an account-wide
   opt-out in Settings.
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
| Full activation | Earliest successful `session_message_sent` or `session_created_with_message` | App event |

`mobileSetupAt` is **not** “mobile setup”: it proves notification registration.
`firstSessionAt` is **not** full activation: it is recorded before downstream
session creation completes and does not prove that the user sent a message.
Reporting aliases both fields to their factual meanings and never substitutes
the legacy signal for full activation.

Behavioral milestones cannot be backfilled before the new event release. Store
an instrumentation start timestamp and restrict activation/retention cohorts to
accounts created on or after it. Historical server milestones may still support
honestly labeled setup trends.

### Headline metrics

| Metric | Exact definition |
| --- | --- |
| Weekly new accounts | All auth accounts created during the complete week. This comes from aggregate server export and is not reduced by product-analytics opt-out. |
| 7-day bridge setup conversion | Accounts whose first bridge registration is within 7 x 24 hours of account creation, divided by accounts at least 7 days old in the cohort. |
| 7-day full activation conversion | Analytics-enabled accounts whose full activation is within 7 x 24 hours of account creation, divided by measurable accounts at least 7 days old and created after instrumentation start. Show behavioral coverage beside it; do not extrapolate to opted-out accounts. |
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

- Immediate Firebase/GA4 -> BigQuery linking and a recorded measurement start.
- Account-wide optional product-analytics preference and mobile Settings UI.
- A surface-neutral typed analytics contract in `module_core`, implemented by
  Firebase in mobile and by a no-op adapter on unsupported products.
- Authenticated identity lifecycle, release-build collection, stable screen
  views, campaign attribution, and the outcome events below.
- A daily privacy-safe auth export and aggregate all-account setup cohorts.
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
| `sesori_auth_server` | `src/types/product-analytics.ts` (domain enum), `src/models/{documents,api,product-analytics-export}.ts` (persisted/API/export contracts), `src/repositories/{user-repo,activation-state-repo,product-analytics-export-repo}.ts` (data access/aggregation), `src/services/{product-analytics-preference-service,product-analytics-export-service}.ts` (business logic), `src/clients/bigquery-product-analytics-client.ts` and `src/api/product-analytics-export-api.ts` (external sink layers), `src/routes/product-analytics.ts` (HTTP boundary), `src/scripts/{backfill-product-analytics-preference,export-product-analytics,product-analytics-export-config}.ts` (separate command composition) | Persist preference behind a dedicated service, expose GET/PUT endpoints, and export privacy-safe data. | Existing auth responses and clients remain unchanged. The web process constructs only the preference service; it never constructs export/BigQuery classes. |
| `shared/sesori_shared` | No production change | Keep `AuthUser` authentication-only; do not add a product preference to the shared auth/persisted contract. | No bridge/shared migration or compatibility default is introduced. |
| `client/module_auth` | No production change | Continue to own tokens, OAuth, auth state, and `AuthenticatedHttpApiClient` only. | `module_core` observes `AuthSession` read-only and injects `AuthenticatedHttpApiClient` into its own Layer-1 preference API. |
| `client/module_core` | `lib/src/models/product_analytics/`, `lib/src/platform/analytics_client.dart`, `lib/src/api/{analytics_api,product_analytics_preference_api}.dart`, `lib/src/storage/{product_analytics_preference_storage,campaign_attribution_storage}.dart`, `lib/src/repositories/{product_analytics,product_analytics_preference,campaign_attribution}_repository.dart`, `lib/src/services/{product_analytics,campaign_attribution}_service.dart`, `lib/src/listeners/{analytics_route,campaign_attribution}_listener.dart`, `lib/src/cubits/product_analytics_preference/`, existing project/session/diff cubits and notification dispatcher, DI/barrel/generated files | Expose architectural layers explicitly; own preference HTTP/persistence, pseudonymous hashing, route/campaign lifecycle, Settings state, and authoritative business-outcome emission. | Mobile supplies only the Firebase platform client. Desktop supplies a no-op client. Cubit constructor call sites/tests update in lockstep. |
| `client/app` | `lib/core/platform/firebase_analytics_client.dart`, `lib/core/di/`, `lib/features/{settings,project_list,new_session,session_detail,session_diffs}/`, `lib/l10n/`, `lib/main.dart`, iOS/Android analytics defaults | Implement the thin Firebase SDK adapter, start core services/listeners, render preference UI, and inject services into core consumers. | Existing app event sources move to core; `AnalyticsUserIdTracker` and obsolete app `DeepLinkService` are removed. No new voice logic is added. |
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

The mobile app starts Firebase Analytics collection **disabled in native
configuration**. A core `ProductAnalyticsService` combines the locally persisted
preference/sync intent with the authenticated server preference:

- Unknown, unauthenticated, debug/profile, or disabled state keeps collection
  off and `user_id` clear.
- After post-splash readiness, an authenticated account fetches the server
  preference. Only a returned enabled value in a release build sets the
  pseudonymous user ID, grants analytics/functionality storage, and enables
  collection; a local cached enabled value alone never enables a new run.
- Disabling turns collection off immediately, denies analytics storage, clears
  identity, resets queued/local analytics data, persists a pending disable if
  the server is unavailable, and retries only after post-splash readiness or an
  explicit user retry.
- Enabling waits for a successful server update before collection starts.
- Logout disables collection until another authenticated preference is known.

Model preference and synchronization status as separate sealed states; do not
flatten “disabled”, “unknown”, “pending sync”, and “failed” into nullable flags.
The Settings copy must say that optional pseudonymous feature interactions are
controlled by the toggle, list the prohibited content categories, and explain
that account/bridge records required to operate Sesori remain outside this
optional collection. Product/privacy counsel must approve the final text and
store disclosures before release.

### Pseudonymous join key

Continue using lowercase hex SHA-256 over the UTF-8 auth user ID. Implement the
same algorithm in TypeScript and in the core `ProductAnalyticsRepository`, and
pin both repositories to one documented golden test vector. The mobile Firebase
adapter receives only the resulting value; it never receives a raw account ID.
Raw user IDs are permitted only in auth/core process memory and
the auth database/existing encrypted local auth or preference storage; they must
not reach Firebase, BigQuery, logs, SQL assets, or dashboard URLs.

The deterministic hash allows cross-device and auth-to-GA4 joins but remains
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
| `AnalyticsEvent`, bounded enums, `AnalyticsScreen`, `AnalyticsDeliveryResult`, `ProductAnalyticsPreference`, `ProductAnalyticsState`, `CampaignCode`, and persisted record variants under `module_core/lib/src/models/product_analytics/` | Domain models; no SDK/Flutter dependencies | Closed event/screen/preference/state values. `AnalyticsScreen` is independent of routing; `AnalyticsRouteListener` performs the exhaustive `AppRouteDef -> AnalyticsScreen` mapping. Delivery is `acceptedBySdk` or `failed`, never an untruthful “reported” boolean. |
| `AnalyticsClient` in `module_core/lib/src/platform/analytics_client.dart` | Foundation external-sink capability | Typed `logEvent`, `logScreenView`, `enable({required String userKey})`, and `disable({required bool resetData})`. The key is already pseudonymous. Methods throw SDK failures; they accept no arbitrary map/name or raw account ID. |
| `AnalyticsApi` in `module_core/lib/src/api/analytics_api.dart` | Layer 1; constructor requires `AnalyticsClient` | Thin API over the external client. It is the only core class that invokes the platform sink. |
| `ProductAnalyticsPreferenceApi` in `module_core/lib/src/api/product_analytics_preference_api.dart` | Layer 1; constructor requires `AuthenticatedHttpApiClient` | Calls authenticated GET/PUT `/product-analytics/preference`, serializes the closed enum, parses external strings at the boundary, and returns explicit success/failure. It does not mutate auth state. |
| `ProductAnalyticsPreferenceStorage` and `CampaignAttributionStorage` in `module_core/lib/src/storage/` | Layer 1 storage; each constructor requires `SecureStorage` | Read/write/delete only their closed persisted records. They do not reconcile accounts, call APIs, hash IDs, or emit analytics. |
| `ProductAnalyticsRepository` in `module_core/lib/src/repositories/product_analytics_repository.dart` | Layer 2; constructor requires `AnalyticsApi` | Converts raw authenticated user ID to lowercase SHA-256, passes only the pseudonymous key downward, and maps API exceptions to explicit `AnalyticsDeliveryResult` without redundant logging. It adds `schema_version=1` through the typed event serialization contract. |
| `ProductAnalyticsPreferenceRepository` in `module_core/lib/src/repositories/product_analytics_preference_repository.dart` | Layer 2; requires `ProductAnalyticsPreferenceApi` and `ProductAnalyticsPreferenceStorage` | Fetch/update server preference, scope local records to one account, persist only `synced(userId, preference)` or `pendingDisable(userId)`, and expose explicit results. Enable is never persisted pending. |
| `CampaignAttributionRepository` in `module_core/lib/src/repositories/campaign_attribution_repository.dart` | Layer 2; requires `CampaignAttributionStorage` | Enforces first touch and persists `pending(code)` or `acceptedBySdk(code)`. Absence genuinely means no campaign. It never stores a full URI/UTM text. |
| `ProductAnalyticsService` in `module_core/lib/src/services/product_analytics_service.dart` | Layer 3, `@lazySingleton`; requires `AuthSession` (read-only), `ProductAnalyticsRepository`, and `ProductAnalyticsPreferenceRepository` | Sole owner of preference/collection lifecycle and Consumer methods `logEvent`/`logScreenView`. Exposes a replaying state stream plus `start`, `markPostSplashReady`, `setPreference`, `retryPendingDisable`, and `dispose`. It performs no network work until readiness. |
| `CampaignAttributionService` in `module_core/lib/src/services/campaign_attribution_service.dart` | Layer 3, `@lazySingleton`; requires `CampaignAttributionRepository` and `ProductAnalyticsService` | Captures a validated first touch and attempts the event only on an active transition/start. It marks `acceptedBySdk` only when the service returns that typed result; failure leaves `pending` for a later lifecycle attempt without a timer loop. |
| `AnalyticsRouteListener` in `module_core/lib/src/listeners/analytics_route_listener.dart` | Consumer/listener, `@lazySingleton`; requires `RouteSource` and `ProductAnalyticsService` | Owns route subscription, maps `AppRouteDef` exhaustively to `AnalyticsScreen`, signals readiness on the first non-splash route, and reports stable screens only while active. It never passes a route model/path to Foundation. |
| `CampaignAttributionListener` in `module_core/lib/src/listeners/campaign_attribution_listener.dart` | Consumer/listener, `@lazySingleton`; requires `DeepLinkSource` and `CampaignAttributionService` | Replaces the obsolete app `DeepLinkService`, owns the one URI subscription, validates only approved `sesori.com/link` campaign codes, and ignores all other/legacy callback URIs without logging complete values. |
| `ProductAnalyticsPreferenceCubit` in `module_core/lib/src/cubits/product_analytics_preference/` | Consumer; constructor requires `ProductAnalyticsService` | Subscribes to service state and exposes toggle/retry intents. Mobile Settings constructs it; it is not in DI. |
| `FirebaseAnalyticsClient` in `app/lib/core/platform/firebase_analytics_client.dart` | Thin mobile Foundation adapter, `@LazySingleton(as: AnalyticsClient)`; requires `FirebaseAnalytics` | Serializes typed events/screens, applies consent/collection/identity SDK calls, and throws failures upward. It receives an already hashed key and contains no route/campaign/preference/hash business logic. Firebase-disabled environments use the existing no-op SDK object. |
| `NoOpAnalyticsClient` in `desktop/lib/core/platform/no_op_analytics_client.dart` | Desktop phase-1 Foundation adapter | Satisfies shared core DI and accepts operations without collection. No desktop listeners are started. |

`AnalyticsScreen` pins snake-case wire values for login, projects, settings and
its subpages, sessions, new session, session detail, and session diffs. The
route listener's exhaustive switch also handles splash explicitly (readiness
only, no report while collection is inactive), so adding an `AppRouteDef`
cannot silently omit its analytics mapping.

The client API may return SDK acceptance, not delivery to Google's backend.
That distinction is sufficient for truthful local campaign state and must remain
explicit in names/docs. Normal outcome consumers may ignore a failed result,
but the result remains explicit to callers; analytics cannot alter product
success.

### DI and process lifecycle

1. Mobile/desktop phase 1 registers `AnalyticsClient` (Firebase or no-op) plus
   existing `SecureStorage`, `RouteSource`, and `DeepLinkSource` adapters.
2. Auth phase 2 registers `AuthSession` and `AuthenticatedHttpApiClient` without
   any analytics-specific method.
3. Core phase 3 registers both APIs, both Storage classes, three repositories,
   two services, and two listeners. Dependencies therefore resolve only
   downward through the declared layers.
4. Mobile bootstrap awaits `ProductAnalyticsService.start()`, then starts
   `CampaignAttributionService`, `AnalyticsRouteListener`, and
   `CampaignAttributionListener` for process lifetime. Their dispose methods are
   owned by GetIt/test teardown. Starting them on the initial splash route
   performs local reads/subscriptions only.
5. Cubits remain constructed in `BlocProvider` and receive
   `getIt<ProductAnalyticsService>()` explicitly. Existing mobile-only
   onboarding widgets call the same service rather than the Foundation client.

### Preference and lifecycle data flow

**Startup and readiness:** Native iOS/Android defaults deny analytics storage
and disable collection. `ProductAnalyticsService.start()` calls repository
disable with `resetData: false`, reads only local pending state, and subscribes
to `AuthSession.authStateStream`; it never validates auth or calls the
preference API. `AnalyticsRouteListener` sees initial `splash` but does not mark
readiness. On the first non-splash route it calls `markPostSplashReady()`. Only
then may the service fetch/reconcile for the currently authenticated account.
If login is still unauthenticated, it waits for the later auth emission. Thus
`restoreLocalSession()` cannot trigger a splash-time network request.

**Reconciliation:** A same-account local `pendingDisable` keeps collection off
and PUTs disabled after readiness. Otherwise the repository GETs the server
preference; returned disabled stays off, while returned enabled in a release
build asks `ProductAnalyticsRepository` to hash the account ID and enable the
SDK. Debug/profile/unsupported builds retain the desired preference but publish
`AnalyticsCollectionState.inactive(buildUnsupported)`.

**Disable:** The cubit calls `ProductAnalyticsService.setPreference(disabled)`.
The service first disables/resets the SDK through the analytics repository,
then persists `pendingDisable(userId)`, then calls the preference repository
PUT. Success stores synchronized disabled; failure remains pending and exposes
generic retry state. Retry occurs only from Settings or a later post-splash
lifecycle, never from a timer or splash auth emission.

**Enable:** Collection remains off while the preference repository PUTs
enabled. Only server success followed by synchronized local persistence allows
the analytics repository to hash/enable. Failed enable remains disabled and is
not persisted for automatic future activation.

**Logout/account switch:** Any unauthenticated state disables without reset,
clears SDK identity, and publishes unauthenticated. Local records are scoped by
raw ID inside encrypted storage and never apply to another account. Explicit
opt-out is the only path requesting SDK data reset.

**Screen flow:** The route listener retains the latest `AnalyticsScreen` while
inactive. Inactive-to-active emits that screen once; later changed screen enums
emit once. Foundation sees neither `AppRouteDef` nor a concrete URI.

**Campaign flow:** The campaign listener converts only an approved URI to
`CampaignCode`; the service/repository stores first touch before auth. On active
state it attempts `campaign_attributed`. `acceptedBySdk` is persisted only from
the typed accepted result. A failed result leaves pending, with at most one
attempt per active lifecycle; BigQuery selects the earliest event if a crash
between SDK acceptance and local persistence causes a duplicate.

### Outcome event catalog

Existing wire names remain unchanged. Add only the following initial events:

| Event | Emit only when | Bounded parameters | Reporting use |
| --- | --- | --- | --- |
| `project_inventory_loaded` | Initial project inventory succeeds | `inventory_state=empty/non_empty` | First project available, onboarding friction |
| `session_activity_viewed` | A session snapshot successfully loads for the first time in a cubit lifetime | `activity_state=empty/non_empty` | Meaningful monitoring when non-empty |
| `session_message_sent` | Existing-session send returns success, including a queued send that later succeeds | `submission_kind=text/command` | Full activation, control activity |
| `session_created_with_message` | `createSessionWithMessage` returns success | `submission_kind`, `workspace_kind=project/dedicated_worktree` | Full activation, remote creation, worktrees |
| `session_creation_failed` | That creation returns an explicit failure | `failure_reason` from bounded `RemoteFailureReason`, `workspace_kind` | Creation friction; never activation |
| `session_question_answered` | Question reply returns success | none | Remote interventions |
| `session_question_rejected` | Question rejection returns success | none | Remote interventions |
| `session_permission_answered` | Permission reply returns success | `decision=once/always/reject` | Remote interventions |
| `session_abort_succeeded` | Root and active-child abort requests all return success | none | Remote interventions |
| `session_diff_viewed` | Initial diff fetch succeeds | `change_state=empty/non_empty` | Diff adoption; meaningful only when non-empty |
| `notification_opened` | A valid notification is dispatched after authentication | `source=push/local`, `launch_context=cold/warm`, bounded `category`, bounded `event_type` | Notification engagement |
| `campaign_attributed` | The first valid campaign code receives an SDK-accepted attempt for an authenticated analytics-enabled account/install | `campaign_code` only | Acquisition coverage and cohorts; earliest event wins |
| Firebase `screen_view` | `RouteSource` emits a changed non-null `AppRouteDef` | stable enum name only | Navigation/friction, never meaningful activity |

For `session_activity_viewed`, `non_empty` means there is at least one message,
pending question/permission, or an active/retrying status.

The send events fire after repository success, never on a tap or queue insert.
The direct-send and queue-drain paths must call the same helper so retries do not
double count. New-session success emits one `session_created_with_message`, not
an additional `session_message_sent`.

### Authoritative emission seams

- `ProjectListCubit`: successful initial inventory.
- `SessionDetailCubit._loadMessages`: first successful activity view.
- `SessionDetailCubit.sendMessage` and `_drainQueuedMessages`: accepted
  existing-session messages.
- `NewSessionCubit.createSession`: accepted created session/message and bounded
  creation failure.
- `SessionDetailCubit.replyToQuestion`, `rejectQuestion`,
  `replyToPermission`, and `abort`: successful control outcomes.
- `DiffCubit._fetchAndEmit`: first successful diff load.
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
| `ProjectListCubit` | Add required `ProductAnalyticsService`. After the initial `ProjectListService` load returns a successful inventory, emit `project_inventory_loaded` once for that cubit lifetime with only empty/non-empty. Refreshes do not repeatedly report the same inventory. |
| `SessionDetailCubit` view | Add required product analytics service and a `_hasReportedInitialView` guard. The first successful snapshot after initial load/wait/reconnect emits one activity-view event based only on bounded activity state; reload/SSE refresh does not. |
| `SessionDetailCubit` send paths | Direct `sendMessage` and `_drainQueuedMessages` call one private `_reportAcceptedSubmission` only on `SuccessResponse`. The queued item retains only text/command for sending; analytics derives text/command without reading content. Error/requeue emits nothing, and each dequeued successful item reports once. |
| `NewSessionCubit` | Add required product analytics service. Capture workspace/submission classifications before awaiting. `SuccessResponse` makes one `session_created_with_message` call; `ErrorResponse` emits only bounded `session_creation_failed`. It never also emits the existing-session event. |
| `SessionDetailCubit` question/permission/abort | Report after each existing method's success branch. Question answers/rejections carry no answer data; permission maps the existing `PermissionReply` enum; abort reports only after every root/active-child response succeeds. |
| `DiffCubit` | Add required product analytics service and `_hasReportedInitialDiff` guard. First successful fetch emits empty/non-empty; SSE refreshes and retries after an already successful first fetch do not. |
| `NotificationOpenRequest` / `NotificationOpenDispatcher` | Extend the internal request with required bounded category/event type already present in `NotificationData`. Push/local adapters provide `unknown` for legacy local payload omissions. Add required product analytics service to the injectable dispatcher; `_dispatch` reports source and cold/warm context after authentication and route dispatch, never project/session/title. |
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

Core stores the first valid code locally and attempts it only after an
authenticated enabled analytics identity exists, retaining pending state until
the SDK accepts an attempt. BigQuery's restricted
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
  `productAnalyticsPreference` with an honest decode default of `Enabled` for
  existing Mongo documents, while `UserRepository.create` always writes the
  field. `src/scripts/backfill-product-analytics-preference.ts` performs an
  idempotent `$set` only where missing and reports/validates counts. After the
  write-first version is live and backfill reaches zero missing documents, the
  next PR removes the decode default and enforces the field as required.
- `src/models/api.ts` defines Zod-validated GET/PUT preference replies/body only;
  it does not modify `UserProfile` or auth token/login contracts.
- `UserRepository.updateProductAnalyticsPreference(userId, preference)` owns
  the Mongo update; `findProductAnalyticsPreference` reads it with the temporary
  migration default only in the write-first release.
- `ProductAnalyticsPreferenceService` in
  `src/services/product-analytics-preference-service.ts` requires only
  `UserRepository` and owns get/update business operations.
- `src/routes/product-analytics.ts` adds authenticated
  `GET /product-analytics/preference` and
  `PUT /product-analytics/preference`; PUT body is
  `{ "preference": "enabled" | "disabled" }` and both reply with
  `{ "preference": ... }`. The existing auth middleware supplies the user; the
  route validates and delegates to the dedicated service. `src/server.ts` and
  `src/index.ts` register/construct this service without changing `AuthService`.
- The Dart client owns this contract in core
  `ProductAnalyticsPreferenceApi`; `AuthManager`/`AuthSession` are unchanged.

### Export classes and composition

| Class/file | Constructor dependencies and layer | Responsibility |
| --- | --- | --- |
| `UserRepository` additions in `src/repositories/user-repo.ts` | Existing `MongoDbAccessor` | `findProductAnalyticsExportBatch({afterUserId, batchLimit, createdAtOrBefore})` returns string user ID, creation time, and preference in deterministic ObjectId order; no Mongo `ObjectId` leaves the repository. |
| `ActivationStateRepository.findByUserIds` in `src/repositories/activation-state-repo.ts` | Existing Mongo collection | Batch-loads only the four milestone fields for one user page and returns a map keyed by string user ID. It does not expose reminder fields to the export service. |
| `ProductAnalyticsExportRow` / `ProductAnalyticsSetupCohortRow` in `src/models/product-analytics-export.ts` | Plain internal models | Make BigQuery row shapes closed and prevent external-sink calls with auth/OAuth/bridge documents. |
| `BigQueryProductAnalyticsClient` in `src/clients/bigquery-product-analytics-client.ts` | Foundation external client; requires `@google-cloud/bigquery` `BigQuery`, project ID, private dataset ID, and location | Thin SDK operations for creating expiring tables, inserting typed safe rows, and executing parameterized queries/transactions. It never receives raw IDs/Mongo documents or decides export semantics. |
| `ProductAnalyticsExportApi` in `src/api/product-analytics-export-api.ts` | Layer 1; requires `BigQueryProductAnalyticsClient` | Defines the external BigQuery operations used by this product area and maps SDK responses/errors; no pagination, aggregation, or publication policy. |
| `ProductAnalyticsExportRepository` in `src/repositories/product-analytics-export-repo.ts` | Layer 2; requires `ProductAnalyticsExportApi` | Owns a run's staging-table lifecycle, safe-row batching, validation queries, and atomic two-target promotion. The service never calls the client/API directly. |
| `ProductAnalyticsExportService` in `src/services/product-analytics-export-service.ts` | Layer 3; requires `UserRepository`, `ActivationStateRepository`, and `ProductAnalyticsExportRepository` | Owns cutoff pagination, SHA-256 transformation, enabled-user filtering, weekly all-account accumulation, reconciliation inputs, and repository promotion. `run({ runCutoff }: { runCutoff: Date })` receives one immutable cutoff. |
| `product-analytics-export-config.ts` in `src/scripts/` | Zod over process environment | Validates only job concerns: Mongo connection/database, GCP project, private dataset, location, and bounded batch size. It does not import the web server's full OAuth/FCM configuration or accept a service-account JSON key. |
| `export-product-analytics.ts` in `src/scripts/` | Command composition root | Constructs Mongo repositories, ADC BigQuery client, export API/repository/service; invokes one run, awaits jobs, and closes Mongo in `finally`. It is compiled into the production image and run as `node dist/scripts/export-product-analytics.js`; `src/index.ts` does not import it. |

The web server constructs the dedicated preference service but never constructs
`BigQuery` or any export API/repository/service. The scheduled job uses the same
built image with a command override, so auth HTTP availability and latency
cannot depend on BigQuery.

The job takes a fixed run cutoff, pages users deterministically, batch-loads
activation states, and writes two products through temporary tables before an
atomic replace/merge:

1. `private.auth_user_milestones`: only accounts whose optional product
   analytics preference is enabled; fields are `user_key`,
   `account_created_at`, `notification_registered_at`,
   `bridge_registered_at`, `legacy_first_metadata_request_at`, and
   `exported_at`.
2. `private.auth_weekly_setup_cohorts`: identifier-free all-account cohort
   totals, including total accounts, enabled-account coverage, notification and
   bridge registration within 1/7/30 days, and the legacy signal. This supports
   honest account/setup totals without exposing opted-out user rows.

Never export provider identity or reminder scheduling/sent timestamps. Replace
the eligible-user snapshot each run so currently disabled accounts no longer
join behavioral reports. Keep raw all-account rows inside Mongo; only aggregate
cohorts leave the auth boundary.

For each page, the service builds a user-ID-to-activation-state map in memory,
updates weekly counters for every account, and creates a pseudonymous row only
when preference is enabled. It hashes before invoking the export repository,
then drops the raw page before requesting the next. Run-scoped staging tables contain only
hashed/aggregate rows, expire within 24 hours, and are invisible to reporting.
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
- source and staging row counts are recorded without raw IDs;
- a partial/failed run leaves the previous published tables intact.

Use Application Default Credentials, Secret Manager for Mongo access, and a
service account limited to BigQuery Job User plus Data Editor on the private
staging/target datasets. The auth web runtime receives no BigQuery role.

## BigQuery Design

### Day-zero setup

Do this before waiting for application PRs because Firebase export is not
retroactive:

1. Confirm the Firebase project is `sesori-ai`, identify the GA4 property ID,
   billing status, property timezone, and existing BigQuery link.
2. If not linked, enable daily Analytics export. Streaming/intraday export is
   optional and not needed for the initial complete-day/week dashboards.
3. Record the immutable raw dataset location. If no location exists, choose the
   privacy/operations-approved location (prefer EU when compatible); every
   derived dataset must use the same location.
4. Record `measurement_start_at`, owner, service accounts, and dashboard access
   group in the restricted deployment configuration.
5. Verify one existing custom event reaches `analytics_<property_id>.events_*`.

### Datasets

All names below are deployment defaults and remain configurable for the real
property/project IDs:

| Dataset | Access | Contents |
| --- | --- | --- |
| `analytics_<property_id>` | Raw restricted | Firebase-managed GA4 daily tables |
| `sesori_analytics_private` | Security/analytics admins and export job | Auth eligible-user snapshot, aggregate setup cohorts, campaign registry, internal-user exclusions, measurement config |
| `sesori_analytics_curated` | Analytics engineers | Flattened allowlisted events, daily user activity, user milestones, scheduled intermediate tables |
| `sesori_analytics_reporting` | Looker service account/product leadership | Identifier-free authorized views and dashboard tables |

Version deployable assets under `tool/product_analytics/`: a data dictionary,
templated DDL and scheduled-query SQL, a small deployment command accepting
project/GA4 dataset/location, BigQuery `ASSERT` fixture tests, and an operations
runbook. Never commit service-account material or live internal user keys.

The initial file ownership is fixed:

- `tool/product_analytics/deploy.dart` validates named project, location, raw
  dataset, private/curated/reporting dataset, and measurement-start arguments;
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
- Firebase automatic events are excluded except stable `screen_view` and a
  transient `first_open`/traffic-source projection in the acquisition model;
  app opens never define activity;
- the privacy notice must disclose Firebase's pseudonymous install/device and
  approximate-location processing even though those fields are discarded from
  Sesori reporting.

If the linked property cannot apply the required raw expiration or Google
Signals/ad settings, stop dashboard rollout and resolve that cloud posture; do
not weaken the written privacy boundary to fit an unchecked property.

### Curated models

1. **`events_flattened`**: flatten only catalogued events/parameters from GA4,
   use `event_timestamp` in UTC, require schema version for Sesori custom
   events, and retain Firebase platform/app version/build. Permit Firebase
   `screen_view` only when its screen name is in `AnalyticsScreen` and its app
   version is at/after instrumentation start. Exclude null `user_id`,
   internal/test keys, and users absent from the current eligible auth snapshot
   before downstream behavioral reporting. Raw bundle/install fields may be
   used transiently to discard byte-identical export duplicates but are not
   selected into the table.
2. **`user_activity_daily`**: one row per user/date with monitor, control,
   message, notification, diff, and feature flags/counts.
3. **`user_milestones`**: auth timestamps plus earliest project availability,
   full activation, monitor activity, and feature milestones. Full activation
   is the minimum of the two successful message event names only.
4. **`activation_cohorts`**: account-cohort denominators, 1/7/30-day milestone
   flags, times to milestone, cohort maturity, and behavioral coverage.
5. **`retention_cohorts`**: activation-anchored W1/W4 eligibility and activity.
6. **`acquisition_first_touch`**: earliest strict custom campaign code or
   approved automatic store/source class per eligible user. It uses raw
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
  user keys. A disabled account disappears from joinable reporting on the next
  successful export.
- Restrict raw/private datasets; give Looker and routine viewers access only to
  reporting views. Do not expose `user_key` in Looker fields, extracts, or URLs.
- Maintain internal/test exclusions as hashes in a restricted table with owner,
  reason, and optional expiry. Never put the list in Git.
- Apply campaign segmentation suppression when a cell has fewer than
  the approved minimum users; totals retain sample sizes.
- Configure dataset/table expiration, scheduled-query byte limits, billing
  alerts, and a monthly cost check before dashboard sharing.
- Document a privacy-request runbook for suppressing a user key from curated
  reporting and deleting warehouse rows when policy requires it.

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

- Add the persisted enum and temporarily default missing Mongo fields to the
  honest prior value (`enabled`) at decode/read boundaries.
- Make every new `UserRepository.create` write the field before exposing GET/PUT
  preference behavior.
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
- Add BigQuery Client -> export API -> export repository -> export service,
  isolated job config/composition, package dependency, and production image
  command.
- Publish the eligible pseudonymous snapshot and identifier-free weekly setup
  cohorts through staging/validation/transactional promotion.
- Test hashing golden vector, opt-out filtering, aggregate reconciliation,
  pagination cutoff, staging cleanup, rerun idempotency, and failed-run safety.
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
- Implement only the thin `FirebaseAnalyticsClient` and desktop no-op adapter in
  product shells; add pure-Dart `crypto` to `module_core` and keep SHA-256,
  route mapping, state, and lifecycle in core.
- Make native Analytics default-off, remove `AnalyticsUserIdTracker`, gate
  collection to post-splash authenticated enabled release builds, and add
  stable `AnalyticsScreen` reporting.
- Add the Settings toggle, explanatory/localized copy, pending/error behavior,
  and privacy/legal/store-disclosure updates.
- Test API parsing, layer wiring, fail-closed splash, post-splash fetch, local
  pending disable, disable/reset/logout/account switch, enable-after-server
  success, debug suppression, core identity hash, route-to-screen mapping,
  event wire pins, and Firebase-enabled/disabled/desktop DI.
- Release only after both auth PRs are deployed. Once users can opt out, this
  lifecycle becomes a non-rollback privacy floor: subsequent client fixes must
  preserve it or disable all collection.

### PR 4/5 — Outcome and campaign instrumentation

**Title:** `[user-analytics] Instrument activation and engagement outcomes [step 4/5]`

**Repository:** apps monorepo

- Add the event catalog variants and bounded enum serialization.
- Instrument the authoritative core/app seams listed above, including both
  direct and queued message success, while keeping analytics best-effort and
  non-blocking.
- Preserve bounded notification category/event type through open dispatch and
  classify push/local plus cold/warm.
- Add core campaign Storage -> repository -> service -> deep-link listener,
  typed SDK-acceptance result, and remove the obsolete app `DeepLinkService` and
  full URI logging.
- Regenerate only source-generated outputs.
- Add focused tests that failures/taps/queued-only operations do not activate,
  each successful message path makes one service call, new-session success is not
  double counted, sensitive inputs cannot enter parameter maps, notification
  classification survives, and campaign values are bounded.

### PR 5/5 — Warehouse models and dashboards

**Title:** `[user-analytics] Add BigQuery metrics and Looker dashboards [step 5/5]`

**Repository:** apps monorepo plus cloud deployment

- Add `tool/product_analytics/` data contract, parameterized deployment tool,
  DDL, transforms, fixture assertions, scheduled-query definitions, and runbook.
- Create private/curated/reporting datasets in the raw GA4 location; configure
  IAM, expiration, budget alerts, campaign registry, internal exclusions, and
  measurement start.
- Schedule the auth export and three-day event recomputation, then reconcile
  source counts and freshness.
- Build and permission the seven-page Looker report.
- Run a release-build smoke test through account -> bridge -> project -> message
  and verify the event, auth join, full activation, complete-day table, and
  reporting view without inspecting sensitive payloads.
- Record dashboard owner, refresh schedule, metric definitions, and rollback/
  incident steps in the runbook.

### Deployability, compatibility, and rollback by step

| State | Independently usable behavior | Deployment prerequisites/order | Rollback boundary |
| --- | --- | --- | --- |
| Before 1/5 | Existing clients/events continue. Firebase daily export should already be linked so its non-retroactive clock has started. | Complete BigQuery day-zero preflight only. | Unlinking loses future export and is not a useful rollback; correct IAM/location before derived datasets. |
| After 1/5 | Dedicated GET/PUT preference endpoints work; old clients are unaffected because auth responses did not change. New users always write preference; old documents read as enabled during migration. | Deploy write-first web code to all serving instances, verify new writes, run/re-run backfill, and record zero missing. | Roll back before any opt-out client release if necessary. The added field is ignored by old code; do not remove it. Re-run backfill after returning to step 1. |
| After 2/5 | Preference schema is required and export command/job image is deployable but unscheduled. Existing clients remain unaffected. | Require recorded zero-missing evidence from step 1; deploy enforcement; smoke-test account creation and endpoints; deploy job disabled. | Roll back web/job to step 1, whose honest missing-field default can read every document. Stop any job; published tables stay at last good state. |
| After 3/5 | Mobile can opt out/in; existing seven events and stable screens obey lifecycle; desktop remains no-op. No activation event is needed for app correctness. | Both auth endpoints/schema must be live. If unavailable, GET/enable fails closed and disable remains local pending. | **Forward-fix only after public release.** Never republish a pre-step-3 client that grants analytics at startup and ignores account preference. For a severe defect, hotfix while retaining the preference/readiness layers, or remotely/release-disable all analytics collection. Server preference data is never rolled back. |
| After 4/5 | New activation/engagement events accumulate in GA4 raw export. Product operations remain unchanged if Firebase is unavailable. | Step 3 identity/consent/schema must be released. BigQuery needs no GA4 custom-dimension registration. | Forward-fix the app while retaining step-3 privacy behavior; event-specific defects may be disabled/removed. Missing future event names yield null/zero data, not product failure. |
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
  collection back on for convenience.

### Auth server

- `npm run build`, `npm run lint`, `npm run format:check`, and focused Node test
  suites; run the full DB-backed tests when MongoDB is available.
- Run export dry-run/staging against synthetic accounts including enabled,
  disabled, no activation state, out-of-order milestones, and page-boundary
  cases.
- Compare published aggregate totals to direct Mongo aggregate counts without
  exporting raw comparison rows.

### BigQuery and Looker

- Dry-run every deployed query and run fixture `ASSERT`s for activation event
  inclusion, failed/queued exclusion, earliest-message selection, 7-day cohort
  maturity, W1/W4 boundaries, internal/disabled filtering, unknown campaign,
  and late-event replacement.
- Reconcile GA4 custom event counts -> flattened events -> daily activity ->
  reporting totals for at least three complete days.
- Verify Looker credentials cannot query raw/private datasets or expose user
  keys, and verify sample-size/partial-period labels.

## Rollout And Two-Month Readiness

1. **Day 0:** Link Firebase to BigQuery and record the measurement start; this
   cannot be recovered later.
2. **Week 1:** Land/deploy write-first auth preference, run/verify backfill,
   then land enforcement/export.
3. **Weeks 1-2:** Land the client foundation and ship its fail-closed opt-out
   release.
4. **Weeks 2-3:** Land instrumentation and ship the mobile release as early as
   store review permits.
5. **Weeks 3-4:** Deploy warehouse models, run data QA, and build Looker.
6. **Weeks 4-8:** Monitor data-quality alerts weekly, correct only demonstrated
   schema/metric defects, and let cohorts mature.

W1 retention becomes available after two weeks of production behavior. W4
requires at least 35 days after a user's activation to close the full 28-34 day
window; any release delay directly reduces the W4 sample available by the
two-month deadline. Show the cohort size and use null—not a fabricated zero—if
no cohort has matured.

## Risks And Mitigations

- **No retroactive behavioral data:** link/export and ship early; label the
  measurement start and do not backfill full activation from metadata requests.
- **Developer/internal pollution:** collection is release-only and reporting
  excludes a restricted internal-user list; monitor app version/schema mix.
- **Opt-out bias:** show eligible coverage with every behavioral funnel and do
  not extrapolate activation/retention to all accounts.
- **Cross-repository deployment mismatch:** deploy write-first server behavior,
  backfill/verify, then enforce, and only then release the client. Preference
  GET/PUT failure is fail-closed; auth profiles remain unchanged.
- **Privacy rollback floor:** a pre-opt-out mobile binary can grant collection
  regardless of server preference. After the opt-out release, use forward fixes
  that preserve the lifecycle or disable all collection; never republish the
  old startup behavior as rollback.
- **Analytics affecting product behavior:** all reports are best-effort,
  unawaited after confirmed outcomes, and failure-isolated.
- **High-cardinality or sensitive leakage:** closed event variants, bounded
  enums/campaign codes, raw-ID prohibition, wire-pin tests, and allowlisted SQL.
- **Misleading acquisition:** label known coverage and platform limitations;
  never relabel unknown as organic.
- **Late/incomplete GA4 exports:** recompute recent partitions and show freshness
  plus complete-period defaults.
- **Small-cohort investor overstatement:** show denominators, maturity, and
  thresholded segments; keep directional W4 claims explicitly directional.
- **Cloud location/hosting uncertainty:** discover before dataset creation;
  colocate all BigQuery data and use an isolated scheduler that can securely
  reach MongoDB rather than coupling export to auth requests.

## Completion Criteria

The work is complete when:

- A production release makes one analytics emission attempt per confirmed
  first-message success path with a pseudonymous authenticated ID and honors
  account-wide disable/re-enable; duplicate delivery cannot change the earliest
  full-activation milestone.
- The auth job publishes validated eligible milestones and all-account setup
  cohorts without raw identity.
- BigQuery derives the metric contract above from versioned SQL, passes fixture
  assertions, and remains fresh after late data.
- Looker exposes only aggregate authorized views and shows complete-period,
  denominator, coverage, maturity, and freshness labels.
- The executive page can truthfully report new accounts, setup, full
  activation, WAU/growth, W1/W4 retention when mature, activity depth, and the
  selected feature-adoption metrics without manual spreadsheet logic.
