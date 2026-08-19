# User Analytics

**Status:** Step 5 cloud rollout is substantially deployed and autonomous.
The daily pipeline is live: 03:00 UTC scheduled auth export, 04:00-05:00 UTC
transform chain, reporting views, all guarded and verified. Remaining
acceptance work is the privacy runtime + deletion drill, the Looker report,
the per-user quota restoration, and three-complete-day reconciliation before
the deployment record flips to configured and the plan archives. Earlier
architecture-review findings were applied directly without a prohibited third
review, so do not describe the corrected plan as reviewer-approved. Current
operational truth and the exact remaining procedures live in `TRACKER.md`
under "Exact resume sequence" (steps 7-9).

**Last operational checkpoint:** `2026-08-08` — scheduler-triggered export
`analytics-auth-export-nszrn` published cleanly and all five transforms
succeeded with aligned watermarks.

**Plan slug:** `user-analytics`

**Created:** 2026-07-28

## Goal

Give Sesori a durable, privacy-safe product analytics system. The first
trustworthy reporting release should answer within the next two months:

- Are new accounts growing?
- Do users complete bridge setup and reach product value?
- Do activated users return and use Sesori repeatedly?
- Which remote-control and differentiating features create engagement?
- Where do onboarding and core actions fail?

The system remains the product's analytics foundation after that fundraising
window. It must produce reproducible BigQuery metrics and restricted Looker
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
4. Three bounded pre-auth login-funnel events are an explicit exception to the
   authenticated product-event preference: started, completed, and failed
   attempts carry only a pinned login-provider enum plus a bounded failure kind.
   They carry no `user_key`, attempt identifier, OAuth identity, or payload,
   remain release-only, follow two-month upstream GA retention plus the
   restricted 90-day exported-raw expiration, and are
   disclosed as installation-level operational analytics outside the product-
   interaction toggle. Because they intentionally retain no account/install
   mapping, internal/test release traffic cannot be removed reliably; reports
   label that limitation and keep login conversion out of investor headline
   metrics.
5. `GoRouterRouteSource` is the authoritative screen source. Automatic Firebase
   screen reporting is disabled, and the typed route listener maps each
   `AppRouteDef` to a pinned `AnalyticsScreen`. The Firebase adapter mirrors that
   same transition through `logScreenView` for correct native Firebase screen
   reporting while the account-linked custom `product_screen_viewed` event
   remains the canonical BigQuery fact.
6. Voice-first adoption is part of the initial metric contract: successful
   sends classify `input_mode=typed/voice_assisted`, and successful
   transcription completion emits one content-free event.
7. Looker Studio is the reporting surface; it reads aggregate authorized views,
   not raw event or per-user tables.
8. Campaign attribution, notification open-to-action conversion, and expanded
   dashboard pages are durable follow-up extensions, not part of the fixed
   first implementation series. Deferral does not discard them after the
   fundraising window.

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
| Foundation analytics exposure | Earliest schema-v1 `analytics_schema_ready` | App event; diagnostic schema-readiness coverage only |
| Activation-capable exposure | Earliest `analytics_activation_ready(activation_schema_version=1)` or accepted full-activation outcome, provided it occurs within 24 hours of account creation | App event from the outcome-instrumentation release |
| Full activation | Earliest successful `session_message_sent` or `session_created_with_message` | App event |

`mobileSetupAt` is **not** “mobile setup”: it proves notification registration.
`firstSessionAt` is **not** full activation: it is recorded before downstream
session creation completes and does not prove that the user sent a message.
Reporting aliases both fields to their factual meanings and never substitutes
the legacy signal for full activation.

Behavioral milestones cannot be backfilled before the new event release. Store
two timestamps: `raw_export_start_at` when Firebase export begins and
`behavioral_schema_v1_start_at` only after the production outcome-instrumentation
version has successfully exported `analytics_activation_ready`. Restrict activation/retention
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
| 7-day full activation conversion | Analytics-eligible accounts whose full activation is within 7 x 24 hours of account creation, divided by accounts at least 7 days old, created on/after `behavioral_schema_v1_start_at`, and observed on activation schema v1 within 24 hours of creation. Foundation-only exposure never qualifies. Show activation-capability and preference coverage; accounts lacking timely capability are unmeasurable, not non-activations. |
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
- Weekly users and successful-message share using voice-assisted input.
- Pre-auth login starts, completions, failures/timeouts, and completion rate by
  pinned provider; these are installation-level diagnostics that may include
  internal/test release traffic, not account funnel milestones/headline metrics.
- Screen popularity and navigation sequences from the exhaustive GoRouter-to-
  `AnalyticsScreen` mapping. Account-level reporting uses
  `product_screen_viewed`; Firebase-native `screen_view` is diagnostic only.
- Diff-review users, question/permission interventions, and aborts.
- Onboarding support/install interactions already present in the event schema.

## Current Behavior

### Apps monorepo

- `client/app` has Firebase Analytics; desktop and bridge do not.
- `client/app/lib/core/analytics/analytics_event.dart` is a Freezed closed event
  union with seven onboarding/support/install events.
- Several existing call sites emit outcome-worded events before the platform
  operation: support link before launcher success and copy/share before
  clipboard/share handoff. Migration must correct those seams rather than merely
  move the same tap proxies into the new service.
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
  GoRouter-backed Firebase/custom screen views, bounded pre-auth login events,
  voice-first adoption, and the outcome events below.
- A daily privacy-safe auth export and aggregate external-account setup cohorts
  after internal/deletion suppression.
- Versioned BigQuery DDL/transforms/tests and Looker Studio dashboards.
- Internal/test-user exclusion for all account-linked/keyed reporting, plus an
  explicit non-excludable internal/test limitation on account-less login
  diagnostics; retention, access, cost, and data-quality controls.

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
- Campaign attribution and campaign link persistence in the first release.
- Notification open-to-action conversion in the first release. Existing
  notification behavior remains unchanged.
- More than the initial three Looker pages. Additional feature, acquisition,
  product-quality, and data-quality pages may be added after the core pipeline
  is stable; the underlying bounded feature/data-quality facts remain durable.
- A “How did you hear about us?” prompt.
- Predictive scoring, experimentation infrastructure, revenue analytics, or a
  general-purpose event bus.
- Pretending historical metadata requests are historical full activations.

### Touched repositories and workspaces

| Repository/workspace | Production paths and layer | Change | Downstream impact |
| --- | --- | --- | --- |
| `sesori_auth_server` | `src/types/product-analytics.ts` (domain enum), `src/models/{documents,api,product-analytics-export}.ts` (persisted/API/export/deletion-target contracts), `src/repositories/{user-repo,activation-state-repo,product-analytics-export-repo,product-analytics-control-repo,product-analytics-deletion-target-repo}.ts`, `src/services/{product-analytics-preference-service,product-analytics-export-service,product-analytics-deletion-service}.ts`, separate `src/clients/{bigquery-product-analytics-client,bigquery-product-analytics-deletion-target-client}.ts` and `src/api/{product-analytics-export-api,product-analytics-deletion-target-api}.ts`, `src/routes/product-analytics.ts`, `src/scripts/{backfill-product-analytics-preference,suppress-product-analytics-export,export-product-analytics,product-analytics-export-config}.ts` | Persist revisioned preference/privacy-suppression state behind dedicated services, expose GET/PUT replies with a server-derived HMAC user key, export privacy-safe data after source/internal exclusion, and hand tombstoned deletion targets to a separately permissioned privacy-private dataset. | Existing auth profile/token responses remain unchanged. The web process receives the pseudonymization secret and constructs only the preference service; export/deletion BigQuery classes and identities remain isolated from each other and exist only in command composition. |
| `shared/sesori_shared` | No production change | Keep `AuthUser` authentication-only; do not add a product preference to the shared auth/persisted contract. | No bridge/shared migration or compatibility default is introduced. |
| `client/module_auth` | Existing HTTP client interfaces/implementations/tests | Add named-parameter JSON `PUT` support to `SafeApiClient`, `HttpApiClient`, and `AuthenticatedHttpApiClient`; keep tokens, OAuth, and auth state otherwise unchanged. | `module_core` injects the authenticated client into its Layer-1 preference API; no wrong-verb workaround or compatibility path is introduced. |
| `client/module_core` | `lib/src/foundation/{models/product_analytics/,platform/analytics_client.dart}`, `lib/src/api/{analytics_api,product_analytics_preference_api.dart,storage/product_analytics_preference_storage.dart}`, `lib/src/repositories/{models/,product_analytics,installation_analytics,product_analytics_preference}_repository.dart`, `lib/src/services/{models/,product_analytics,installation_analytics}_service.dart`, existing `services/draft_store.dart` plus typed composer-draft model, `lib/src/routing/{analytics_route,session_activity_analytics}_listener.dart`, `lib/src/cubits/{product_analytics_preference,settings}/`, existing login/project/session/diff cubits, DI/barrel/generated files | Mirror the declared layers explicitly; own preference HTTP/persistence, validated server-derived pseudonymous-key flow, bounded account-less login telemetry, typed draft/input-origin restoration, route/visibility lifecycle, pre-logout orchestration, Settings state, and authoritative business-outcome emission. | Mobile supplies the Firebase client plus immutable runtime capability. Desktop supplies no-op/disabled Foundation adapters. Cubit constructor call sites/tests update in lockstep. |
| `client/app` | `lib/core/platform/{firebase_analytics_client,firebase_analytics_identity_migration}.dart`, `lib/core/di/`, `lib/features/{login,settings,project_list,new_session,session_detail,session_diffs}/`, composer widgets/callbacks, `lib/l10n/`, `lib/main.dart`, iOS/macOS/Android analytics defaults | Clear legacy global identity at earliest post-Firebase bootstrap, pass its immutable capability into phase-1 DI, implement the thin Firebase adapter, disable automatic screen reporting, mirror GoRouter-derived screens through `logScreenView`, begin Apple analytics before the native authorization sheet, report successful content-free transcription completion, start core services/listeners, render preference UI, and inject services into core consumers. | Existing app event sources move to core; `AnalyticsUserIdTracker` is removed. The only global Firebase `user_id` call sets null for migration; no account key or runtime collection override is added. Existing `DeepLinkService` remains unchanged because campaign work is deferred. |
| `client/desktop` | `lib/core/platform/no_op_analytics_client.dart`, DI generated file | Satisfy the shared core platform capability without collecting desktop analytics. | No desktop product events or UI are added. Analyze/test verifies core DI remains resolvable. |
| `client/module_desktop_core` | No planned production edit; tests/build are downstream validation | Continue unchanged. | Shared core DI/downstream validation only. |
| `bridge/app` | No planned production or contract edit | Remain outside product analytics. | No additional bridge validation beyond normal CI is caused by this plan. |
| Private analytics platform repository | `sesori-ai/sesori_analytics_platform`: root deployment tooling/SQL plus `privacy_deletion/` layered command flow and gradual-disclosure `docs/` | Version BigQuery DDL, transforms, assertions, dashboard contract, deletion exclusion/upstream submission, and recurring keyed-upload sweep outside the product-app repository. | Cloud deployment supplies property/project/location and ADC identities; no credentials or live identifiers enter Git. |

## Privacy And Identity Contract

### Account preference

Define the same closed wire values (`enabled`, `disabled`) at the two language
boundaries, but do **not** add the preference to `AuthUser`, `AuthSession`, JWTs,
or auth login/refresh responses. It is product state, not authentication state.
The auth server persists it on `User`, exposes dedicated authenticated GET/PUT
product-analytics endpoints through a dedicated preference service, and writes
`enabled` for every new account. Those endpoint replies also carry the
server-derived pseudonymous `userKey`; auth profile/token contracts remain
unchanged. Existing accounts are backfilled to the honest prior behavior before
the server schema becomes non-null/enforced.

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
authenticated Sesori product event carries the pseudonymous `user_key` as a
typed parameter, and `ProductAnalyticsService` refuses to create those events
unless the local/server gate is active. This avoids a cold-start race with a
persisted Firebase enable override and prevents the new design from assigning
an account key to automatic events.

The only custom-event exception is the pre-auth login funnel. Its three closed
event variants carry no `user_key` and no identifier other than Firebase's
vendor-managed installation identifier, are emitted only by
`InstallationAnalyticsService` in release builds, and are excluded from
account-level curated facts. They are not controlled by the authenticated
product-interaction preference because no account preference is available yet.
Privacy/Settings copy must disclose this narrowly bounded operational telemetry;
new pre-auth exceptions require a separate product/privacy decision and may not
be added by extending a generic map API.

The client never calls Firebase's global `setUserId`. Fresh installs start with
native collection disabled, and foreground startup enables it only after the
process is confirmed as an eligible release outside Firebase Test Lab and
consent is configured. Account identity exists only as the typed `user_key`
parameter on authenticated Sesori product events, so vendor automatic events
remain installation-level.

The product analytics service combines installation-local intent with the server
preference:

- Unknown, unauthenticated, debug/profile, locally disabled, or server-disabled
  state suppresses all authenticated Sesori product events. The separate,
  account-less login variants remain governed by their release-only installation
  service contract above.
- After post-splash readiness, an authenticated installation fetches the server
  preference. Only returned enabled in a release build activates custom event
  sharing; a local cached enabled value alone never activates a new run.
- Disable synchronously transitions the service to inactive, then makes durable
  `pendingDisable(userId)` its **first awaited operation**, before any SDK/network
  work, and only then PUTs disabled. A crash after that write leaves recoverable
  local intent; no SDK disable/reset call is required for custom-event
  enforcement.
- A local storage read error keeps account-linked product events inactive rather than treating
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
  or the reconciliation slot indefinitely.

The setting is not advertised as a universal Firebase or legacy-client kill
switch. It immediately controls authenticated Sesori product events on this
installation; the server preference suppresses reporting and is honored by
analytics-capable releases. It does not control the disclosed, account-less
login-funnel events or Firebase automatic install-level events. Already-
installed older binaries can continue their previous Firebase behavior until
upgraded/retired, so account-wide wording is forbidden unless a future minimum-
version enforcement mechanism makes it true.
Supported clients read once after post-splash readiness for each authenticated
generation and on explicit Settings refresh/actions. Thus a remote change is
applied on next process/auth establishment or an explicit online Settings
refresh, not instantaneously; offline and legacy limitations must remain
explicit in copy.

Model preference and synchronization status as separate sealed states; do not
flatten “disabled”, “unknown”, “pending sync”, and “failed” into nullable flags.
The Settings copy must say “Share pseudonymous product usage from this device,”
list the prohibited content categories, identify the pending server-sync state,
and explain that Firebase automatic install-level events, the bounded pre-auth
login funnel, plus account/bridge records required to operate Sesori are not
controlled by this switch. Privacy/deletion disclosures distinguish GA's two-
month upstream retention from the restricted exported BigQuery raw copy's 90-day
expiration. Product/privacy counsel must approve the final text and store
disclosures before release.

### Pseudonymous join key

The auth server is the sole derivation authority: lowercase the canonical auth
user ID, then derive lowercase hex HMAC-SHA-256 with one long-lived secret of at
least 32 random bytes. The same secret is required by the web preference
service, auth export job, and suppression command, but never enters a client,
BigQuery, logs, or source control. The dedicated authenticated preference API
returns the already-derived `userKey`; the client validates and carries that
value rather than hashing the raw account ID. Pin the TypeScript derivation to
one documented golden vector and test that different keys produce different
outputs. The mobile Firebase adapter receives the resulting value only inside
typed custom event envelopes; it never receives a raw account ID and never sets
Firebase's global `user_id`.
Raw user IDs are permitted only in auth/core process memory and
the auth database/existing encrypted local auth or preference storage; they must
not reach Firebase, BigQuery, logs, SQL assets, or dashboard URLs.

Generate the secret once as canonical base64, store it in the web/export/
suppression secret environments, and configure the exact same value everywhere
before Step 2 deploys. Rotation requires a coordinated re-key migration across
client state, auth snapshots, and deletion targets; an uncoordinated rotation
would silently break joins and privacy deletion.

The deterministic custom `user_key` allows cross-device and auth-to-GA4 joins but remains
pseudonymous personal data. Documentation and access controls must call it that.

### Allowed dimensions

- Event schema version.
- Account-linked product `occurred_at_micros`, captured at the authoritative
  seam and used only as validated warehouse time—not registered as a GA custom
  dimension.
- Stable screen enum.
- Platform and app version supplied by Firebase. Build number is not emitted by
  the typed clients or exposed by the GA4 raw app-info record, so it is not a
  warehouse/reporting dimension.
- Bounded onboarding, interaction, voice-input, login-provider, login-failure,
  and product-failure enums.

### Prohibited dimensions

Do not add fields capable of carrying code, prompts, responses, transcript
text, reasoning, filenames/paths, repository/project/session/branch/worktree
names, provider/model/agent/tool/command names, raw error text/status payloads,
OAuth identity, email, IP/geography, or raw/hashed project/session/bridge/device
IDs. The event union should make these fields impossible to pass.

Here “provider” in the prohibited list means a coding/model provider. The
separate `AnalyticsLoginProvider` enum is allowed and pins only
`github/google/apple/email`; it never carries provider user identity.

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
| `ProductAnalyticsEvent`, typed `ProductAnalyticsEnvelope(event, occurredAtUtc)`, `InstallationAnalyticsEvent`, `AnalyticsScreen`, `AnalyticsInputMode`, pinned event enums, and immutable `AnalyticsRuntimeCapability` under `module_core/lib/src/foundation/models/product_analytics/` | Foundation contracts; no SDK/Flutter dependencies | Separate closed account-linked and account-less sink contracts. Every product outcome captures occurrence time at its authoritative seam before analytics work; deferred candidates retain the envelope. `AnalyticsScreen` is independent of routing; `AnalyticsRouteListener` performs the exhaustive `AppRouteDef -> AnalyticsScreen` mapping. `AnalyticsLoginProvider` is independently pinned and exhaustively mapped from the sealed auth provider. Runtime capability is `enabled` or a closed disabled reason and is produced before phase-1 DI. |
| `AnalyticsClient` in `module_core/lib/src/foundation/platform/analytics_client.dart` | Foundation external-sink capability | Typed `logProductEvent({required ProductAnalyticsEnvelope envelope, required String userKey})` and `logInstallationEvent({required InstallationAnalyticsEvent event})`. Product serialization adds `occurred_at_micros`; methods throw SDK failures and accept no arbitrary map/name or raw account ID. Only the product method can receive the already-pseudonymous key. |
| `AnalyticsApi` in `module_core/lib/src/api/analytics_api.dart` | Layer 1; constructor requires `AnalyticsClient` | Thin typed API over both external-client operations. It is the only core class that invokes the platform sink. |
| `ProductAnalyticsPreferenceApi` in `module_core/lib/src/api/product_analytics_preference_api.dart` | Layer 1; constructor requires `AuthenticatedHttpApiClient` | Calls authenticated GET/PUT `/product-analytics/preference` under a fixed 10-second operation deadline. GET parses `{preference, revision, userKey}`; PUT requires `{preference, expectedRevision, operationId}` and parses the same key on success/conflict. It validates the key as 64-character lowercase hex, serializes closed values, parses external strings at the boundary, and returns explicit success/conflict/timeout/failure. A timed-out transport may finish, but server compare-and-set prevents it from overwriting a newer committed revision. |
| `ProductAnalyticsPreferenceStorage` in `module_core/lib/src/api/storage/` | Layer 1 data source; constructor requires `SecureStorage` | Reads/writes/deletes only closed preference synchronization records. It does not reconcile accounts, call APIs, hash IDs, or emit analytics. |
| `AnalyticsDeliveryResult`, `ProductAnalyticsPreference`, versioned synchronized/pending preference records, and explicit repository results under `module_core/lib/src/repositories/models/` | Layer-2 contracts | Delivery is `acceptedBySdk`, `deferredUntilPreference`, or `failed`, never an untruthful “reported” boolean. Preference records carry the last server revision and validated server-derived `userKey` required for ordered compare-and-set updates and event delivery. |
| `AnalyticsRepository` in `module_core/lib/src/repositories/analytics_repository.dart` | Layer 2; constructor requires `AnalyticsApi` | Exposes distinct typed product and installation delivery methods, applies the shared bounded SDK deadline, and maps API exceptions/timeouts to explicit `AnalyticsDeliveryResult` without redundant logging. Product delivery accepts only the already-validated server-derived pseudonymous key, never a raw account ID, while installation delivery accepts only `InstallationAnalyticsEvent` and cannot receive a `user_key`. Each event contract adds its pinned schema version during typed serialization. |
| `ProductAnalyticsPreferenceRepository` in `module_core/lib/src/repositories/product_analytics_preference_repository.dart` | Layer 2; requires `ProductAnalyticsPreferenceApi` and `ProductAnalyticsPreferenceStorage` | Fetch/update server preference, scope local records to one account, and persist only versioned `synced`, `pendingDisable`, or `pendingEnable` records. Every PUT uses the last observed revision plus stable operation ID. Conflict on disable triggers one bounded GET/retry against the new revision; conflict on enable remains inactive and returns explicit refresh-required state so an older enable cannot automatically override a newer disable. `pendingEnable` is never permission to emit. |
| `ProductAnalyticsState`, independent preference/synchronization variants, and closed fixed-capacity `DeferredProductAnalyticsCandidates` under `module_core/lib/src/services/models/` | Layer-3 service state | Represents active/inactive/pending/failure truth plus only activation/project-available/diff-adoption/current-date-session-activity deferred slots without nullable coordination fields or a generic queue; it is not part of the Foundation sink contract. |
| `ProductAnalyticsPreferenceService` in `module_core/lib/src/services/product_analytics_preference_service.dart` | Layer 3, injected collaborator; requires immutable `AnalyticsRuntimeCapability`, read-only `AuthSession`, and `ProductAnalyticsPreferenceRepository` | Sole owner of authenticated generation, preference reconciliation, local/runtime snapshots, logout preparation, and the replaying `ProductAnalyticsState`. `ProductAnalyticsService` is its single disposal owner. It exposes only validated current/deferrable delivery-generation context to the facade. |
| `ProductAnalyticsService` in `module_core/lib/src/services/product_analytics_service.dart` | Layer 3 delivery facade, `@lazySingleton`; requires `AnalyticsRepository` and `ProductAnalyticsPreferenceService` | Owns Consumer `logEvent`, generation readiness dispatchers, the fixed same-generation deferred candidate slots, ordered one-shot draining, delivery observability, and facade disposal. Preference/account lifecycle stays in its injected collaborator. It delegates preference commands/state, never polls, never owns raw auth state, and sends no product event without a validated active delivery context. |
| `InstallationAnalyticsService` in `module_core/lib/src/services/installation_analytics_service.dart` | Layer 3, `@lazySingleton`; requires immutable `AnalyticsRuntimeCapability` and `AnalyticsRepository` | Accepts only typed login-attempt lifecycle methods, maps the sealed auth provider exhaustively to `AnalyticsLoginProvider`, classifies timeout versus bounded authentication/launch failure, and reports best-effort. It has no account/preference state, buffers nothing, and remains inactive whenever the runtime capability is disabled. |
| `AnalyticsRouteListener` in `module_core/lib/src/routing/analytics_route_listener.dart` | Layer-4 routing listener, `@lazySingleton`; requires `RouteSource` and `ProductAnalyticsService` | Owns route subscription, maps `AppRouteDef` exhaustively to `AnalyticsScreen`, signals readiness on the first non-splash route, and reports stable screens only while active. It never passes a route model/path to Foundation. |
| `SessionActivityAnalyticsListener` in `module_core/lib/src/consumers/analytics/session_activity_analytics_listener.dart` | Explicit stream listener above Layer-4 state; constructed/owned by one `SessionDetailScreen`, requires its `SessionDetailCubit`, `LifecycleSource`, `ProductAnalyticsService`, and an initial per-instance visibility value | Combines bounded loaded-state classification with resumed lifecycle and a typed `setRouteVisible` intent supplied by the owning Flutter route instance. It never infers visibility from global `AppRouteDef`. It emits first empty once and non-empty at most once per UTC date only while that exact detail page is current; covered parents, nested diffs, and background SSE cannot create false monitoring activity. The service owns any envelope after `deferredUntilPreference`. |
| `ComposerDraftStorage` in `module_core/lib/src/api/storage/composer_draft_storage.dart` | Layer 1 in-memory data source | Stores only immutable `ComposerDraft` values by existing/session-new-session key for the current process. Whitespace clear removes the row; it owns no edit or analytics decisions. |
| `ComposerDraftRepository` in `module_core/lib/src/repositories/composer_draft_repository.dart` | Layer 2; requires `ComposerDraftStorage` | Provides typed read/write/clear operations to existing- and new-session Cubits. Product shells and widgets never resolve storage directly. |
| `ComposerDraft`, half-open `VoiceOriginSpan(start, end)`, and `ComposerDraftCalculator` under `module_core/lib/src/services/models/` and `services/` | Layer-3 immutable state plus pure shared business transformation | Draft state contains text plus normalized, ordered, non-overlapping voice-origin spans. The calculator applies explicit typed replacement and voice insertion transforms; the model validates data but owns no edit policy. `inputMode` is derived from whether any voice span survives. |
| `ProductAnalyticsPreferenceCubit` in `module_core/lib/src/cubits/product_analytics_preference/` | Consumer; constructor requires `ProductAnalyticsService` | Subscribes to service state and exposes toggle/retry intents. Mobile Settings constructs it; it is not in DI. |
| `FirebaseAnalyticsClient` in `app/lib/core/platform/firebase_analytics_client.dart` | Thin mobile Foundation adapter, `@LazySingleton(as: AnalyticsClient)`; requires `FirebaseAnalytics` and immutable `AnalyticsRuntimeCapability` | Rejects all operations unless capability is enabled, serializes only typed product/installation events plus their permitted shared fields, and throws canonical-event failures upward. For `product_screen_viewed`, after the canonical custom event is accepted it also best-effort calls `FirebaseAnalytics.logScreenView` with the same pinned screen name and stable `GoRouter` screen class; mirror failure is logged but does not rewrite canonical delivery. It never applies global identity/collection overrides and contains no route/preference/hash business logic. Firebase-disabled environments use the no-op client plus disabled capability. |
| `FirebaseAnalyticsStartup` in `app/lib/core/platform/firebase_analytics_startup.dart` | Mobile-only pre-DI helper; constructed directly with `FirebaseAnalytics.instance` after Firebase initialization in foreground `main` | Enforces collection off before custom sources start. It leaves ineligible processes disabled; eligible releases configure privacy-minimized consent and then enable collection. It never sets Firebase's global user ID. The FCM background handler independently initializes Firebase for messaging and contains no analytics compatibility work. |
| `NoOpAnalyticsClient` in `desktop/lib/core/platform/no_op_analytics_client.dart` | Desktop phase-1 Foundation adapter | Satisfies shared core DI and accepts operations without collection. No desktop listeners are started. |

`AnalyticsScreen` pins snake-case wire values for login, projects, approved
settings groupings, sessions, new session, session detail, and session diffs.
`settingsHarnesses` and `settingsHarnessManagement` both map to generic
`settings`; they never produce harness-specific wire values. Disable Firebase's
automatic screen reporter in Android metadata and each Firebase-enabled Apple
target so Navigator/Flutter internals cannot emit duplicate or incorrect names.
Use `google_analytics_automatic_screen_reporting_enabled=false` in Android
metadata and `FirebaseAutomaticScreenReportingEnabled=false` in each relevant
Apple `Info.plist`; verify the runtime result in DebugView instead of assuming
the source setting took effect.
`GoRouterRouteSource.currentRouteStream` is the sole route source; the listener's
exhaustive switch handles splash explicitly (readiness only), reports the
account-linked custom `product_screen_viewed`, and causes the adapter to mirror
the same pinned name through standard Firebase `logScreenView`. Curated facts
use only `product_screen_viewed`; standard `screen_view` rows are diagnostic and
carry no `user_key`. Adding an `AppRouteDef` therefore cannot silently omit or
rename its analytics mapping.

The client API may return SDK acceptance, not delivery to Google's backend.
That distinction remains explicit in names/docs. Product analytics owns only the
closed deferred candidates listed above; ordinary outcome consumers may ignore
delivery results, but the result remains explicit and analytics cannot alter
product success.

### DI and process lifecycle

1. Before mobile phase 1, `main` produces one immutable
   `AnalyticsRuntimeCapability` from Firebase support, build/Test Lab eligibility,
   and the awaited startup configuration. Mobile phase 1 registers that exact
   instance plus `AnalyticsClient`, `SecureStorage`, and `RouteSource`; desktop
   registers disabled capability plus no-op client.
   Existing deep-link wiring remains unrelated because campaign attribution is
   deferred.
2. Auth phase 2 registers `AuthSession` and the internal HTTP clients, including
   the new JSON PUT operation used by the core preference API.
3. Core phase 3 registers both APIs, preference Storage, two repositories,
   two services, and the route listener. Dependencies therefore resolve only
   downward through the declared layers.
4. Mobile bootstrap awaits `ProductAnalyticsService.start()`, then starts
   `AnalyticsRouteListener` for process lifetime. Disposal is owned by GetIt/test
   teardown. Starting on the initial splash route performs only local reads and
   subscription work.
5. Cubits remain constructed in `BlocProvider` and receive
   `getIt<ProductAnalyticsService>()` explicitly. `LoginCubit` additionally
   receives `InstallationAnalyticsService`; desktop resolves the same service
   through its no-op client. `SettingsCubit` requires
   `ProductAnalyticsService` and owns pre-logout preparation. The session-detail
   screen constructs/disposes its route-aware activity consumer alongside its
   cubit. Onboarding/composer widgets perform Flutter-only platform work, then
   dispatch confirmed bounded outcomes to explicit methods on their owning core
   Cubits; widgets never call a Layer-3 analytics service directly.

Before mobile phase 1, `main()` initializes Firebase, resolves build and Firebase
Test Lab eligibility, awaits `FirebaseAnalyticsStartup`, and passes the returned
immutable capability into `configureDependencies`. Native configuration keeps
fresh installs off before Dart starts. Eligible releases configure consent and
then enable collection; every ineligible or failed startup remains disabled. No
Sesori custom event source or core listener exists before that decision, and the
flow never calls Firebase's global `setUserId`.

The `@pragma("vm:entry-point")` FCM background handler independently initializes
Firebase for messaging. It never constructs core DI, emits custom analytics, or
performs identity migration. Vendor automatic events remain installation-level
and are excluded from account-level behavioral models.

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
off and PUTs disabled after readiness using its last revision; conflict performs
one bounded GET/retry. `pendingEnable` also stays inactive: GET disabled returns
to synchronized disabled; GET enabled must first finalize synchronized enabled
storage before event acceptance. Otherwise the repository GETs the server
preference once for each post-readiness auth generation; returned disabled stays
off, while returned enabled with a validated server-derived key in a capable
release build allows `AnalyticsRepository` to emit each typed event with
that key.
Disabled runtime capability/debug/profile/unsupported builds retain the desired
preference but publish the matching inactive reason.

Every auth emission/account switch/logout increments a monotonically increasing
service generation. Each GET, PUT, and persistence operation captures
`(generation, userId)`; after every await and immediately before any
state transition/event acceptance it verifies both still match current auth.
Stale completions may finish only their account-scoped storage/server operation;
they cannot activate another generation. Reconciliations are non-overlapping
within one generation. There is no foreground polling or timer. A later server
change is observed on the next auth generation/process start or an explicit
Settings refresh/action. A returned disabled value synchronously marks the
current generation inactive before any follow-up persistence await. Network
failure preserves the honest prior local state and last-successful-check time;
the UI makes this explicit propagation contract visible. Every preference
GET/PUT has the API's 10-second operation deadline. Timeout releases the sole
reconciliation slot and advances no state; a stable operation ID plus server
revision compare-and-set makes detached late mutation completion idempotent and
unable to overwrite a newer revision.

**Capability exposure and bounded deferral:** On each authenticated generation's
first active transition, the foundation release attempts
`analytics_schema_ready`. The later outcome release additionally attempts
`analytics_activation_ready(activation_schema_version=1)` before buffered work.
Only the latter readiness event or an accepted full-activation outcome proves
activation capability; an old foundation-only binary remains unmeasurable.
While the same generation is preference-unknown (and not locally disabled), the
service may return `deferredUntilPreference` and retain only the closed
activation/project-available/diff-adoption/session-activity candidates. Active resolution emits
each retained semantic once; disabled resolution, logout/account switch, or
generation change drops them. No prompt/message content, project/session ID, or
unbounded event enters this fixed model. Each candidate retains its typed
`occurredAtUtc`, captured before analytics invocation, so later emission cannot
move activation eligibility, latency, project availability, or adoption time.
Empty diagnostics are not buffered.

Readiness guards live in generation-scoped service state, not a process-global
boolean. Logout/account switch clears them; account B in the same process emits
its own foundation/activation readiness even when it never activates, preventing
success-conditioned cohort eligibility.

`SessionActivityAnalyticsConsumer` creates the candidate only while the detail
route is topmost/resumed, then submits its original envelope/occurrence time to
the service's fixed slot. It advances its date guard after `acceptedBySdk` or
`deferredUntilPreference`; once deferred, the already-authoritative view remains
valid across route exit or UTC rollover because the service solely owns and
emits it when the same generation becomes enabled; the consumer retains no
second deferred candidate. Disable or auth generation change drops it. This
preserves brief real views without allowing background/nested-route state to
create candidates.

**Disable:** The cubit calls `ProductAnalyticsService.setPreference(disabled)`.
The service immediately publishes inactive, then first durably persists
`pendingDisable(userId)` before any subsequent await, then calls the preference
repository PUT. Success stores synchronized disabled; network failure remains
  pending and exposes the truthful local-disabled/server-sync-pending state. A
  storage-write failure keeps in-memory suppression, attempts server disable, and
  surfaces unsaved failure unless the server confirms disabled. Retry occurs only
  from explicit Settings action or the next post-readiness auth generation,
  never from a timer or lifecycle polling.

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

**Logout/account switch:** `SettingsCubit.logout()` first awaits
`ProductAnalyticsService.prepareForLogout()`, which immediately suppresses the
current generation and makes one bounded pending-disable sync attempt while the
authenticated client still has credentials. It then performs existing
notification unregistration and finally calls
`AuthSession.logoutCurrentDevice()`. The analytics method is best-effort and
never throws into or blocks the logout flow beyond its operation deadline. On failure,
the encrypted pending record remains scoped by raw ID and is retried after that
account reauthenticates; it never applies to another account. Unexpected token
loss preserves the same record. The attempt is bounded by the 10-second API
deadline, after which logout clears credentials and continues. No path claims or
requests a Firebase-wide data reset.

**Screen flow:** `GoRouterRouteSource` resolves the actual router configuration
to `AppRouteDef`; no Navigator runtime-type or URL with entity IDs is used. The
route listener retains the latest `AnalyticsScreen` while inactive. Inactive-to-
active emits `product_screen_viewed` once; later changed screen enums emit once.
The Firebase adapter also mirrors each accepted custom screen event through
`logScreenView` using the same pinned name. Automatic Firebase screen reporting
is disabled, so DebugView/GA4 screen reports identify the real GoRouter screen
without duplicate framework-generated names. Foundation sees neither
`AppRouteDef` nor a concrete URI.

**Pre-auth login flow:** `LoginCubit` reports a started event only after a valid
provider intent is accepted, then exactly one completed or failed terminal event
for that attempt. Apple is the exception to Cubit-owned platform execution: the
mobile call site first calls typed `LoginCubit.beginAppleLoginAttempt()` before
opening `SignInWithApple.getAppleIDCredential`; its opaque attempt handle is
carried through every native callback so stale work cannot terminate a replacement
attempt. Native cancellation stays distinct, missing-token/server-auth failures
map to authentication, and other SDK exceptions map to platform-neutral unknown
without translating SDK codes in the widget. A credential continues the already-
started attempt through its server login method without a second start. OAuth
polling timeout maps to bounded `timeout`. No exception text, OAuth user, account
key, or random attempt ID is emitted. Installation events are not buffered or
joined to later accounts; BigQuery reports aggregate provider completion rates
and excludes them from account-level funnel/retention tables.

`LoginCubit` retains one closed in-memory `ActiveLoginAnalyticsAttempt(provider,
terminalReported)` independently from transient UI states. OAuth poll
interruption/backgrounding does not clear it; `_onAppResumed` uses that provider
for the eventual completion/failure and then clears it. Logout/cubit close or a
new validated attempt clears/replaces it without emitting a fabricated terminal
event. The context is never persisted or sent as an identifier.

**Voice flow:** A successful non-empty transcription adds one half-open
voice-origin span for the inserted transcript and dispatches a typed completion
to the owning Cubit, which emits one content-free
`voice_transcription_completed` through `ProductAnalyticsService`. A pure
`ComposerDraftCalculator` transforms normalized spans for typed insertion,
deletion, partial/full replacement, and identical selected-text replacement.
Untouched voice fragments preserve contribution; replaced/deleted fragments do
not. `inputMode` is derived as `voice_assisted` only while at least one voice
span survives and resets to typed when none remains or the composer clears.
Existing-session queued items retain only that derived enum alongside their
existing content/command; successful send is reported later with the enum.
New-session creation threads the same enum into its successful outcome.
`ComposerDraftRepository` stores immutable `ComposerDraft(text, voiceSpans)` for
both session and `new-session:<projectId>` keys through `ComposerDraftStorage`,
so disposal/restoration preserves exact mixed attribution. Whitespace clear
removes the whole draft/origin. No transcript, duration, audio metadata, or text
length is emitted or durably persisted.

### Outcome event catalog

Existing wire names remain unchanged. Add only the following initial account-
linked product events:

Every account-linked row uses `ProductAnalyticsEnvelope` and therefore includes
shared `occurred_at_micros` captured at the authoritative seam. It is transport/
warehouse metadata, not a GA custom dimension; deferred delivery never rewrites
it. Account-less login events are immediate and do not add this field.

| Event | Emit only when | Bounded parameters | Reporting use |
| --- | --- | --- | --- |
| `analytics_schema_ready` | The foundation becomes active once per authenticated generation | none beyond shared schema/key | Per-account foundation deployment/preference coverage only; never activation capability/activity |
| `analytics_activation_ready` | An outcome-instrumented build becomes active once per authenticated generation | `activation_schema_version=1` | Per-account activation-capable exposure including unsuccessful accounts; never activity |
| `project_inventory_loaded` | The first successful empty inventory and the first successful non-empty inventory in a cubit lifetime | `inventory_state=empty/non_empty` | First project available from earliest non-empty; empty is onboarding friction |
| `session_activity_viewed` | The first successful empty snapshot in a cubit lifetime, and at most one successful non-empty snapshot per UTC date while that session detail is visible/foregrounded | `activity_state=empty/non_empty` | Earliest non-empty is the monitoring milestone; dated non-empty events support WAU/retention without SSE inflation |
| `session_message_sent` | Existing-session send returns success, including a queued send that later succeeds | `submission_kind=text/command`, `input_mode=typed/voice_assisted` | Full activation, control activity, voice-assisted share |
| `session_created_with_message` | `createSessionWithMessage` returns success | `submission_kind`, `input_mode`, `workspace_kind=project/dedicated_worktree` | Full activation, remote creation, worktrees, voice-assisted share |
| `session_creation_failed` | That creation returns an explicit failure | `failure_reason` from bounded `RemoteFailureReason`, `workspace_kind` | Creation friction; never activation |
| `voice_transcription_completed` | A successful non-empty transcription is applied to a composer | none | Voice feature adoption; never contains transcript/audio metadata |
| `session_question_answered` | Question reply returns success | none | Remote interventions |
| `session_question_rejected` | Question rejection returns success | none | Remote interventions |
| `session_permission_answered` | Permission reply returns success | `decision=once/always/reject` | Remote interventions |
| `session_abort_succeeded` | Root and active-child abort requests all return success | none | Remote interventions |
| `session_diff_viewed` | The first successful empty diff and the first successful non-empty diff in a cubit lifetime | `change_state=empty/non_empty` | Diff adoption from earliest non-empty; empty is diagnostic only |
| `product_screen_viewed` | `RouteSource` emits a changed non-null `AppRouteDef` while custom sharing is active | stable `screen` enum only | Canonical account-level navigation/friction; adapter mirrors Firebase-native screen reporting, never meaningful activity |

For `session_activity_viewed`, `non_empty` means there is at least one message,
pending question/permission, or an active/retrying status.

The send events fire after repository success, never on a tap or queue insert.
The direct-send and queue-drain paths must call the same helper so retries do not
double count. New-session success emits one `session_created_with_message`, not
an additional `session_message_sent`. A command-only submission always uses
`input_mode=typed`; `voice_assisted` means a successful transcript contributed
to the submitted composer value, not that the final text was unedited.

The separate account-less installation event catalog contains exactly:

| Event | Emit only when | Bounded parameters | Reporting use |
| --- | --- | --- | --- |
| `login_attempt_started` | A valid GitHub/Google/Apple/email login flow begins | `provider` from `AnalyticsLoginProvider` | Provider demand and attempt denominator |
| `login_attempt_completed` | That flow reaches `LoginSuccess` | `provider` | Provider completion count/rate |
| `login_attempt_failed` | That flow reaches failure, native cancellation, or timeout | `provider`, `failure_kind=authentication/launch/cancelled/timeout/unknown` | Bounded pre-auth friction |

These three events carry no `user_key`, attempt ID, or auth payload and are never
used as account creation or activation evidence.

### Authoritative emission seams

- `ProductAnalyticsService`: schema-ready exposure on first active transition.
- `LoginCubit` plus the Apple mobile entry call site: account-less started/
  completed/failed outcomes, including native cancellation and the distinct
  OAuth timeout terminal state, through `InstallationAnalyticsService`.
- `ProjectListCubit`: first successful empty and first successful non-empty
  inventory states.
- `SessionActivityAnalyticsListener` combining `SessionDetailCubit` state,
  `LifecycleSource`, and the owning Flutter route instance's typed visibility
  intent: first empty diagnostic and one actually visible/foreground non-empty
  activity per UTC date.
- `SessionDetailCubit.sendMessage` and `_drainQueuedMessages`: accepted
  existing-session messages with the captured input-mode enum.
- `NewSessionCubit.createSession`: accepted created session/message and bounded
- Mobile composer transcription success call sites: perform the Flutter
  transcription operation, then pass the content-free completion and
  voice-assisted input classification to an explicit owning-Cubit intent.
- `SessionDetailCubit.replyToQuestion`, `rejectQuestion`,
  `replyToPermission`, and `abort`: successful control outcomes. Permission reply
  must first correct the current fallthrough by pattern-matching its
  `ApiResponse`; `ErrorResponse` is false/failure and never an analytics success.
- `DiffCubit._fetchAndEmit`: first successful empty and first successful
  non-empty diff states.
- `AnalyticsRouteListener` over `GoRouterRouteSource`: exhaustive stable screen
  names for both the canonical custom event and Firebase-native mirror.

Every changed cubit/service receives `ProductAnalyticsService` through required
constructor injection. The service reaches the platform sink only through
`AnalyticsRepository`; consumers never hold `AnalyticsClient` or
`AnalyticsApi`. Do not use global service location inside `module_core`, add
optional compatibility parameters, or move success reporting to widget taps
merely to avoid updating tests.

### Outcome emission data flow

| Owner change | Exact flow and deduplication |
| --- | --- |
| `ProjectListCubit` | Add required `ProductAnalyticsService`. Empty diagnostic advances only after SDK acceptance and is not buffered. First non-empty is submitted to the service's fixed project-available slot while preference is unknown; the cubit consumes its lifetime guard only after `acceptedBySdk` or `deferredUntilPreference`, because the service owns that deferred semantic. Refreshes never repeat an accepted/deferred classification. The warehouse milestone uses only earliest non-empty. |
| `SessionActivityAnalyticsListener` | Each `SessionDetailScreen` constructs this explicit higher-layer listener with the screen-owned cubit, `LifecycleSource`, product analytics service, and `ModalRoute.of(context)?.isCurrent` as initial visibility. `didChangeDependencies` sends later visibility edges through `setRouteVisible`; core never imports Flutter or infers instance visibility from global route type. The listener retains only accepted/deferred visibility/date guards. The service exclusively retains a deferred envelope across route/date changes for the same generation. Background/covered-parent SSE never creates a candidate; disable/auth change drops service-held state. |
| `LoginCubit` / Apple mobile call site | Add required `InstallationAnalyticsService` and one closed `ActiveLoginAnalyticsAttempt`. Cubit intents pass the sealed `AuthProvider` and typed terminal cause; `InstallationAnalyticsService` solely owns exhaustive provider/failure mapping to analytics enums. Report one start after input validation and exactly one terminal completion/failure; interrupted OAuth polling retains provider through `_onAppResumed`, and timeout is failed. For Apple, the UI invokes the Cubit begin intent before the native sheet, then exactly one credential continuation or cancelled/failure terminal intent. Desktop resolves shared methods through its no-op client. |
| `SessionDetailCubit` send paths | Direct `sendMessage` and `_drainQueuedMessages` call one private `_reportAcceptedSubmission` only on `SuccessResponse`. The queued item retains its existing text/command plus the closed input-mode enum; analytics derives text/command classification without reading content. Error/requeue emits nothing, and each dequeued successful item reports once. |
| `NewSessionCubit` | Add required product analytics service and required input-mode argument on creation. Capture workspace/submission/input classifications before awaiting. `SuccessResponse` makes one `session_created_with_message` call; `ErrorResponse` emits only bounded `session_creation_failed`. It never also emits the existing-session event. |
| Mobile composer call sites / owning Cubits / draft layers | `PromptInput` sends typed edit, voice insertion, save, restore, and clear intents through its owning Cubit; it does not resolve storage. Existing- and new-session Cubits require `ComposerDraftRepository` and share `ComposerDraftCalculator`. The calculator updates half-open spans for insertion, deletion, partial/full replacement, and identical selected replacement; restoration uses the exact saved spans. After `stopAndTranscribe()` returns non-empty, the owning Cubit reports completion and returns the transformed draft. Product behavior does not await analytics delivery. |
| `SessionDetailCubit` question/permission/abort | Report after each verified success branch. Question answers/rejections carry no answer data. Change `replyToPermission` to pattern-match `SuccessResponse`/`ErrorResponse` instead of treating every non-throwing response as true; only success maps the existing `PermissionReply` enum and reports. Abort reports only after every root/active-child response succeeds. |
| `DiffCubit` | Add required product analytics service. Empty diagnostic advances only after SDK acceptance and is not buffered. First non-empty may occupy the service's fixed diff-adoption slot while preference is unknown; consume its guard only after accepted/deferred result. Only non-empty defines adoption, and SSE refreshes do not repeat accepted/deferred state. |
| `AnalyticsRouteListener` / `FirebaseAnalyticsClient` | Listener maps every `AppRouteDef` to pinned `AnalyticsScreen`, deduplicates unchanged routes, and reports only after product analytics activates. The adapter logs canonical `product_screen_viewed`, then best-effort calls `logScreenView` with the same name. Native automatic screen reporting is disabled and standard rows are excluded from account-level models. |
| Screen constructors/tests | `ProjectListScreen`, `NewSessionScreen`, `SessionDetailScreen`, and `SessionDiffsScreen` pass phase-3 services/repositories from GetIt into required cubit constructors. `SessionDetailScreen` also owns/disposes its per-route `SessionActivityAnalyticsListener` and supplies visibility edges. Core tests inject recording services/lifecycle and assert event count/shape. |

## Deferred Extensions

Campaign attribution and notification open-to-action conversion remain useful
future additions after the core identity, preference, activation, retention,
voice, login, and screen pipeline is stable. They are not silently discarded:

- Campaign work may later add strict opaque campaign codes, store attribution,
  pre-auth capture with a bounded TTL, a restricted registry, and honest known-
  attribution coverage. It must not replace `DeepLinkService` or add persistence
  in the initial series.
- Notification work may later preserve bounded source/category/event type and
  measure open-to-meaningful-action conversion. It must not claim delivery or
  click-through rates without a delivery denominator.
- Any follow-up must reuse the typed Client -> API -> Repository -> Service ->
  Consumer path and go through the normal architecture-plan review. It may not
  broaden the initial event union with arbitrary strings or identifiers.

## Auth Export

Implement a one-shot auth-server export command, designed to run daily as a
least-privileged Cloud Run Job (or an equivalently isolated scheduler on the
existing host if GCP cannot reach MongoDB). Do not add BigQuery credentials or
export work to request handlers or the long-running auth process.

### Auth preference endpoint and persistence

- `src/types/product-analytics.ts` defines the string-valued
  `ProductAnalyticsPreference.Enabled/Disabled` enum and its Zod schema.
- `src/models/documents.ts` initially adds
  `productAnalyticsPreference`, `productAnalyticsPreferenceUpdatedAt`, integer
  `productAnalyticsPreferenceRevision`, and genuinely nullable
  `productAnalyticsPreferenceLastOperationId`. Existing documents receive honest
  temporary decode defaults of enabled/account creation time/revision 1, while
  `UserRepository.create` always writes the first three fields and null last ID.
  `src/scripts/backfill-product-analytics-preference.ts` performs an idempotent
  `$set` only where required fields are missing and reports/validates counts.
  After the
  write-first version is live and backfill reaches zero missing documents, the
  next PR removes all required-field decode defaults and enforces preference,
  update time, and revision as required.
  It also permits genuinely absent `productAnalyticsExportSuppressedAt`; a
  privacy-deletion workflow sets that timestamp, so no default/backfill exists.
- `src/models/api.ts` defines Zod-validated GET/PUT preference replies/body only;
  it does not modify `UserProfile` or auth token/login contracts.
- `UserRepository.updateProductAnalyticsPreference` owns one atomic compare-and-
  set by `(userId, expectedRevision)`: it updates value/server timestamp/last
  operation ID and increments revision. Repeating the same operation ID returns
  the already-committed result; a different stale revision returns conflict.
  `findProductAnalyticsPreference` reads versioned state with temporary
  migration defaults only in the write-first release.
- `UserRepository.suppressProductAnalyticsExport(userId, suppressedAt)`
  atomically sets preference disabled, updates its timestamp, and sets the
  permanent export-suppression tombstone while incrementing preference revision
  before any warehouse deletion. GET
  remains disabled and PUT enabled returns an explicit conflict for suppressed
  accounts; ordinary opt-out never sets this tombstone.
- `ProductAnalyticsPreferenceService` in
  `src/services/product-analytics-preference-service.ts` requires only
  `UserRepository` and owns get/update plus permanent export-suppression
  business operations.
- `src/routes/product-analytics.ts` adds authenticated
  `GET /product-analytics/preference` and
  `PUT /product-analytics/preference`; PUT body is
  `{ "preference": "enabled" | "disabled", "expectedRevision": number,
  "operationId": uuid }`; success replies with `{ "preference": ...,
  "revision": number, "userKey": string }` and stale revision returns an
  explicit conflict with the same current versioned state. The existing auth
  middleware supplies the user; the
  route validates and delegates to the dedicated service. `src/server.ts` and
  `src/index.ts` register/construct this service without changing `AuthService`.
- The Dart client owns this contract in core
  `ProductAnalyticsPreferenceApi`; `AuthManager`/`AuthSession` are unchanged.
- `src/scripts/suppress-product-analytics-export.ts` is the isolated privacy-
  operator composition root. It reads a verified raw account ID from protected
  stdin (never argv/logs), constructs the deletion service described below,
  verifies disabled+tombstoned state plus restricted target handoff, prints only
  the external privacy request ID/status, and closes Mongo/BigQuery clients.
  There is no public suppression route.

### Export classes and composition

| Class/file | Constructor dependencies and layer | Responsibility |
| --- | --- | --- |
| `UserRepository` additions in `src/repositories/user-repo.ts` | Existing `MongoDbAccessor` | `findProductAnalyticsExportBatch({afterUserId, batchLimit, createdAtOrBefore})` returns string user ID, creation time, preference/update time, and optional export-suppression time in deterministic ObjectId order. `findProductAnalyticsPreferenceChangeBatch({afterUserId, batchLimit, changedAfter})` scans every current latest preference timestamp after the run cutoff for the final conservative exclusion pass; no Mongo `ObjectId` leaves the repository. |
| `ActivationStateRepository.findByUserIds` in `src/repositories/activation-state-repo.ts` | Existing Mongo collection | Requires `runCutoff`, batch-loads only the four milestone fields for one user page, and projects each milestone to null when its timestamp is later than that cutoff. It returns a map keyed by string user ID and exposes no reminder fields. |
| `ProductAnalyticsExportRow` / `ProductAnalyticsSetupCohortRow` in `src/models/product-analytics-export.ts` | Plain internal models | Make BigQuery row shapes closed and prevent external-sink calls with auth/OAuth/bridge documents. |
| `BigQueryProductAnalyticsClient` in `src/clients/bigquery-product-analytics-client.ts` | Foundation external client; requires `@google-cloud/bigquery` `BigQuery`, project ID, auth-export dataset ID, one fully qualified authorized internal-exclusion view, and location | Thin SDK operations for creating/inserting/querying **inside the auth-export dataset only**, plus one typed read of active `user_key` values from the authorized view. It exposes no controls write/DDL method and never receives raw IDs/Mongo documents or export semantics. |
| `ProductAnalyticsExportApi` in `src/api/product-analytics-export-api.ts` | Layer 1; requires `BigQueryProductAnalyticsClient` | Defines external auth-dataset operations and read-only active-exclusion retrieval, and maps SDK responses/errors; no pagination, aggregation, or publication policy. |
| `ProductAnalyticsExportRepository` in `src/repositories/product-analytics-export-repo.ts` | Layer 2; requires `ProductAnalyticsExportApi` | Validates deployment-owned permanent schemas, owns the distributed run lease plus monotonic-cutoff guard, a run's expiring staging-table lifecycle, safe-row batching, validation queries, and atomic two-target promotion. The service never calls the client/API directly. |
| `ProductAnalyticsControlRepository` in `src/repositories/product-analytics-control-repo.ts` | Layer 2; requires `ProductAnalyticsExportApi` | Loads and validates the bounded permanent internal/test-user key set from the one authorized view. It cannot write controls or auth export tables. |
| `ProductAnalyticsExportService` in `src/services/product-analytics-export-service.ts` | Layer 3; requires `UserRepository`, `ActivationStateRepository`, `ProductAnalyticsControlRepository`, `ProductAnalyticsExportRepository`, and the validated pseudonymization key | Owns cutoff pagination, HMAC-SHA-256 transformation, suppression/internal filtering before all counters, enabled-user filtering, weekly external-account accumulation, reconciliation inputs, and repository promotion. `run({ runCutoff }: { runCutoff: Date })` receives one immutable cutoff. |
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
`runCutoff` are never eligible in that run. Immediately before the final
preference pass the service captures `preferenceScanCutoff`, then scans every
document whose **current latest** preference timestamp is after `runCutoff`,
deliberately without an upper timestamp bound. Mongo stores only the latest
preference timestamp, so a later write must not hide an earlier change inside
`(runCutoff, preferenceScanCutoff]`. The service removes observed keys from
staging/eligible coverage. A change after scan start may therefore be excluded
conservatively when observed; if it lands after that document's scan, it belongs
to the next run. Any observed source-suppression change aborts publication
rather than leaving page-order-dependent aggregate contribution. Immediately
before cohort write/promotion, the service reloads the internal-exclusion
control and aborts if the observed version/set changed. A control update after
that final snapshot belongs to the next run; do not add a cross-dataset lock for
this operational exclusion list. This explicit rule avoids reconstructing
unknown historical preference values while ensuring pagination timing cannot
admit a known post-cutoff enable/disable. The job writes two products through
temporary tables before an atomic replace/merge:

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

At run start, the service loads the permanent internal/test `user_key` set and records
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
Permanent target, successful-run metadata, and singleton export-state schemas
are provisioned only by the deployment identity. Each runtime validates their
exact schemas, acquires a distributed lease in the auth-private export-state
table, and creates only expiring staging tables. After all pages and checks
succeed, one BigQuery multi-statement transaction verifies lease ownership plus
a strictly newer `runCutoff`, deletes/inserts both published targets from
staging, appends aggregate run metadata, and advances the monotonic state. A
concurrent, expired, equal-cutoff, or older run cannot overwrite a newer
snapshot. A failure rolls back publication, leaving the prior snapshot/cohorts
visible. Cleanup releases an owned lease best-effort; lease and staging expiry
are the final guards after process loss.

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
- milestones written after `runCutoff` and preferences known to have changed by
  `preferenceScanCutoff` remain excluded regardless of the page on which the
  concurrent write occurs; later current preference timestamps cannot hide an
  earlier in-window update.
- overlapping runs cannot publish concurrently, and promotion rejects a cutoff
  that is equal to or older than the last successful snapshot.

Use Application Default Credentials, Secret Manager for Mongo access, and an
export service account limited to BigQuery Job User plus Data Editor on
`sesori_analytics_auth_private` plus table-level Data Viewer on the one
authorized permanent-internal-exclusion view. It has no controls dataset
write/DDL role and no role on privacy-private, raw, curated, or reporting
datasets, so it cannot mutate deletion targets, exclusions, or config. A
separate scheduled-transform identity has read-only access to raw, auth-private,
and controls, table-scoped update access only to the keyed-publication guard,
and write access to curated; the deployment identity alone owns schemas, IAM,
and every other control-table write. The auth web runtime receives no BigQuery
role.

### Privacy deletion executable architecture

Deletion is an isolated cross-repository command flow, never a web request
handler and never an informal sequence of console queries.

**Auth-source handoff (`sesori_auth_server`):**

| Class/file | Layer/dependencies | Responsibility |
| --- | --- | --- |
| `ProductAnalyticsDeletionTarget` in `src/models/product-analytics-export.ts` | Closed internal model | Contains only external privacy request ID, lowercase HMAC `user_key`, deletion-only `legacy_firebase_user_id` (the prior SHA-256 Firebase user ID), source tombstone time, and status; no raw account ID. The legacy value never enters analytics exports and exists only to delete data from releases that set the old global Firebase `user_id`. |
| `BigQueryProductAnalyticsDeletionTargetClient` / `ProductAnalyticsDeletionTargetApi` | Foundation/Layer 1; scoped only to `privacy_private.product_analytics_deletion_targets` | Typed target upsert/read/status operations. It cannot access export-owned auth-private tables, controls, raw, curated, or reporting. |
| `ProductAnalyticsDeletionTargetRepository` in `src/repositories/product-analytics-deletion-target-repo.ts` | Layer 2; requires `ProductAnalyticsDeletionTargetApi` | Idempotently upserts the restricted deletion target and reads status; it never reuses the export API/client. |
| `ProductAnalyticsDeletionService` in `src/services/product-analytics-deletion-service.ts` | Layer 3; requires `ProductAnalyticsPreferenceService` and deletion-target repository | Receives raw account ID only in protected process memory, rejects incomplete stored preference state before the irreversible write, atomically source-tombstones/disables, receives the HMAC-derived key from that preference operation, derives the deletion-only legacy SHA-256 Firebase user ID from the protected raw account ID, writes both derived values only to the restricted privacy target, drops raw ID/key locals, and returns only request ID/status. A target-write failure leaves the source tombstone intact and is safely retryable. |
| `src/scripts/suppress-product-analytics-export.ts` | Protected command composition root | Reads verified raw account ID from stdin and external request ID from a protected input channel, constructs Mongo plus the privacy-private target client/API/repository/service, invokes once, prints only request ID/status, and closes both clients in `finally`. |

The script identity has Mongo suppression access plus append/update/read status
only on `privacy_private.product_analytics_deletion_targets`; it cannot query GA4
raw data or mutate controls/curated/reporting. The restricted target table is the
only raw-ID-to-`user_key` handoff, and raw account ID never crosses it.

**Warehouse/upstream deletion (`sesori_analytics_platform/privacy_deletion/`):**

| Class/file | Layer/dependencies | Responsibility |
| --- | --- | --- |
| `google_api_foundation.dart`, `bigquery_privacy_deletion_client.dart`, and `ga_user_deletion_client.dart` | Neutral Google credential/transport foundation plus peer Foundation clients | Shared metadata-first credential acquisition and bounded Google API failures live in the neutral file. The peer clients own typed BigQuery operations within allowlisted datasets and typed GA User Deletion API submission; neither client depends on the other, orchestrates deletion, or receives a raw account ID. |
| `privacy_deletion_api.dart` | Layer 1; requires both clients | Loads pending privacy-private targets for request processing; transactionally advances the keyed-publication epoch while upserting/reading the permanent deletion-exclusion control; range-joins the overlapping raw window against **all** permanent tombstones for sweeps; discovers currently linkable installation IDs, deletes matching warehouse rows, submits app-instance/legacy-user deletion, rebuilds aggregates, and updates target status through typed operations. |
| `privacy_deletion_repository.dart` | Layer 2; requires API | Owns idempotent request status, target validation, run checkpoints, typed latest-auth-snapshot retrieval, and explicit operation/result mapping. It never decides lifecycle readiness, orchestrates cross-system cleanup, or persists discovered installation IDs. |
| `privacy_deletion_service.dart` | Layer 3; requires repository and clock | Orchestrates exclusion-before-delete, evaluates one-shot tombstone-aware auth readiness using the configured publication-age/clock policy plus cutoff, then owns upstream/raw/keyed deletion, fixed rebuild, verification, and completion. When no fresh successful auth export has `runCutoff >= suppressedAt`, it returns retryable and relies on the external job/operator to invoke the idempotent command again rather than polling in-process. A sweep applies that gate to the newest permanent tombstone before auth-private cleanup or checkpoint advancement. |
| `run_privacy_deletion.dart` / `sweep_privacy_deletions.dart` | Manual and scheduled composition roots | Construct with the attached metadata-server identity by default (with explicit local ADC fallback only for approved operator runs), process one request or a checkpointed raw-partition range, return only aggregate status, and close clients. Each daily sweep starts from the earlier of the last-success watermark continuation and the latest three UTC event dates, matching GA4 late-arrival recomputation; it joins every scanned version against all permanent deletion tombstones regardless of target completion/age. Submission/deletion is idempotent and acts only on future **keyed** uploads. |

Use a dedicated deletion service account with BigQuery Job User, read of the
restricted privacy-target/raw datasets, write only to the deletion-exclusion
control, keyed-publication guard, sweep checkpoint, and privacy-target status,
delete/rebuild permission on auth-private/curated and matching retained raw
rows, metadata-only reporting inventory access, plus the minimum GA deletion
API role. It has no Mongo access,
reporting mutation, or general controls/deployment role. The attached identity
supplies production credentials; no service-account key enters Git.

No persistent account-to-installation map is created. Once currently linkable
app-instance IDs are submitted and raw keyed rows are deleted/expired, later
automatic-only events cannot be associated with the account. Recurring sweeps
therefore promise enforcement only for future keyed uploads; automatic-only
future rows remain under upstream two-month retention and may remain in the
already-exported restricted BigQuery raw copy until its 90-day expiration.
Privacy responses must state both limits instead of claiming indefinite
automatic-event deletion.

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
   outcome release's `analytics_activation_ready` is observed in export. Also
   record owner, identities, deletion-job owner, and dashboard access group in
   restricted configuration.
6. Verify one existing event reaches `analytics_<property_id>.events_*`, then
   verify activation schema v1 before setting its behavioral timestamp.
   Foundation or installation-login schema does not qualify.

### Datasets

All names below are deployment defaults and remain configurable for the real
property/project IDs:

| Dataset | Access | Contents |
| --- | --- | --- |
| `analytics_<property_id>` | Raw restricted | Firebase-managed GA4 daily tables |
| `sesori_analytics_auth_private` | Security/analytics admins, auth export job; transform identity read-only | Auth eligible-user snapshot/staging and aggregate setup cohorts only |
| `sesori_analytics_privacy_private` | Security/privacy admins, auth suppression command limited writer, deletion job | Product-analytics deletion targets/status only; auth export identity has no access |
| `sesori_analytics_controls` | Security/analytics admins and deployment identity; transform identity read-only except table-scoped keyed-publication-guard updates; auth-export identity can read only an authorized permanent-internal-exclusion view | Internal-user and deletion exclusions, dual measurement timestamps, export freshness policy, keyed-publication guard |
| `sesori_analytics_curated` | Analytics engineers | Flattened allowlisted events, daily user activity, user milestones, scheduled intermediate tables |
| `sesori_analytics_reporting` | Looker service account/product leadership | Identifier-free authorized reporting views only; no stored keyed or materialized dashboard tables |

Version deployable assets in the private
`sesori-ai/sesori_analytics_platform` repository: a data dictionary, templated
DDL and scheduled-query SQL, a small deployment command accepting project/GA4
dataset/location, BigQuery `ASSERT` fixture tests, and an operations runbook.
Never commit service-account material or live internal user keys.

The initial file ownership is fixed:

- `deploy.dart` validates named project, location, raw,
  auth-private/privacy-private/controls/curated/reporting datasets, and both
  start timestamps;
  renders identifier placeholders from the checked-in SQL; and invokes `bq`
  non-interactively with the explicit location. It does not perform `gcloud`
  login or read key files.
- `sql/00_datasets.sql` creates/configures derived
   datasets and reference tables; `10_events_flattened.sql`,
   `15_installation_login_daily.sql`, `20_user_activity_daily.sql`,
   `30_user_milestones.sql`,
  `40_activation_retention.sql`, and `50_reporting_views.sql` own the dependency
  order described below.
- `sql/schedules.json` is a credential-free manifest of
  query file, destination, cadence, recent-date recomputation window, and max
  bytes; the deploy command creates/updates those transfer configs only after a
  `--apply-schedules` flag.
- `tests/metric_contract_assertions.sql` uses temporary
  fixture tables and BigQuery `ASSERT`; `schema_allowlist_assertions.sql` fails
  when curated columns/event parameters exceed the approved contract.
- Root `README.md` is a short navigation entry point; task guides under `docs/`
  provide gradual disclosure, `docs/reference/full-runbook.md` is the exhaustive
  operator/data reference, and `docs/reporting/looker-studio.md` pins page
  sources, filters, formulas, access, and manual dashboard verification.

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
- Firebase automatic events and native `screen_view` mirrors are excluded from
  behavioral facts. App/screen opens never define activity;
- account-less login events are aggregated directly to daily
  date/platform/app-version/provider/failure totals; `user_pseudo_id` is never
  selected into a curated or reporting table;
- the privacy notice must disclose Firebase's pseudonymous install/device and
  approximate-location processing even though those fields are discarded from
  Sesori reporting.

If the linked property cannot apply the required raw expiration or Google
Signals/ad settings, stop dashboard rollout and resolve that cloud posture; do
not weaken the written privacy boundary to fit an unchecked property.

### Curated models

1. **`events_flattened`**: flatten only catalogued account-linked Sesori product
   events/parameters from GA4, preserve export `event_timestamp` as
   `emitted_at` via `TIMESTAMP_MICROS(event_timestamp)`, parse required integer
   `occurred_at_micros` the same way as `occurred_at`,
   require schema version and non-null custom `user_key`, and retain Firebase
   platform/app version. Reject occurrence later than emitted time beyond
   the documented clock-skew allowance. User-milestone/cohort joins additionally
   require occurrence no earlier than account creation beyond that allowance;
   invalid timing remains a data-quality count and is excluded from time-bound
   metrics rather than silently falling back to emission. Anti-join
   both permanent internal/test keys and the permanent deletion-exclusion keys on
   every build/recomputation, but deliberately do **not** join the time-varying
   current auth eligibility snapshot here. Raw bundle/install fields may be used
   transiently to discard
   byte-identical export duplicates but are not selected into the table. This
   recoverable 90-day fact layer prevents a transient auth-export outage from
   permanently discarding otherwise eligible events.
2. **`installation_login_daily`**: identifier-free daily counts of the three
   account-less login events by platform, app version, pinned provider, and
   bounded failure kind. It scans raw rows but never persists
   `user_pseudo_id`, joins to an account, or contributes to account metrics.
   Because that privacy boundary prevents after-the-fact internal exclusion, the
   model/report carries `includes_internal_test_traffic=true` and is diagnostic
   only.
3. **`user_activity_daily`**: one row per user/date with monitor, control,
   message, voice-assisted, transcription, diff, screen, and feature
   flags/counts.
4. **`user_milestones`**: auth timestamps plus earliest schema-ready foundation and
   activation-capable exposure,
   project availability, full activation, monitor activity, and feature
   milestones. Full activation is the minimum of the two successful message
   event names only; `analytics_schema_ready_at` is diagnostic, while
   `activation_capable_at` is the earliest activation-ready event or activation
   outcome.
5. **`activation_cohorts`**: account-cohort denominators only when activation-
   capable schema-v1 exposure occurs within 24 hours of account creation, with
   order-validated bridge/project setup diagnostics, 1/7/30-day milestone flags,
   times to milestone, cohort maturity, and separate
   preference/foundation/activation-capability coverage.
   Headline activation, time-to-activation, and retention always use the
   authoritative message-based `full_activation_at`; missing, delayed, or
   out-of-order bridge/project milestones cannot omit or move that timestamp.
6. **`retention_cohorts`**: activation-anchored W1/W4 eligibility and activity.

Materialize partitioned daily/intermediate tables where repeated Looker scans
would be expensive; cluster event facts by event name/user key. Scheduled
queries recompute at least the last three UTC event dates because GA4 daily
exports can receive late events. Reporting uses only completed recomputations,
and data-quality views expose source/export/query freshness.
Every user-level reporting build also inner-joins the **current** eligible auth
snapshot and anti-joins the permanent internal exclusion table. Therefore a
disable or newly added internal exclusion takes effect after the next auth
export/report refresh even when an older curated partition exists; those gates
are not applied only at the historical partition's original build time.
Keyed transforms capture a shared publication epoch before staging and advance
it inside their publication transaction. Permanent tombstone insertion advances
the same singleton transactionally. An epoch mismatch or overlapping write
aborts rather than republishing a concurrently deleted user.

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
  remote-created-session, voice-transcription, and voice-assisted-message
  adoption.
- `installation_login_funnel`: identifier-free started/completed/failed counts
  and completion rates by pinned provider/app version, explicitly labeled as
  installation-level, potentially including internal/test release traffic, and
  never joined to account activation or the investor snapshot.
- `screen_usage`: account-level unique users/views by pinned
  `AnalyticsScreen`, sourced only from `product_screen_viewed`; standard
  Firebase screen rows are excluded.
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
- Maintain internal/test exclusions as permanent hashes in a restricted table
  with owner and reason. Accounts ever used for internal/test activity remain
  excluded from all historical/future account metrics; do not expire a row and
  retroactively reintroduce its history. Never put the list in Git.
- Configure dataset/table expiration, scheduled-query byte limits, billing
  alerts, and a monthly cost check before dashboard sharing.
- Implement a privacy-request runbook/job that first calls the auth-source
  suppression operation, verifies preference disabled plus
  `productAnalyticsExportSuppressedAt`, and only then adds `user_key` to a
  restricted deletion-exclusion control. It deletes matching auth-private and
  curated keyed rows and rebuilds identifier-free setup cohorts. Reporting is
  view-only and therefore has no stored contribution to delete. It does not
  declare warehouse completion until an auth export with
  `runCutoff >= productAnalyticsExportSuppressedAt` has published, then performs
  one final delete/rebuild and verifies the key/contribution remains absent.
  Thus an export staged before the tombstone may finish, but cannot restore data
  after the verified tombstone-aware run/final cleanup; no broad cross-system
  lock is required.
- From the still-retained raw window, resolve only `user_pseudo_id` values whose
  installation emitted a matching keyed custom event and submit GA4 User
  Deletion API requests as app-instance IDs. Also submit the restricted target's
  deletion-only legacy SHA-256 value as GA `USER_ID` for data produced before
  this design removed global `user_id`; never substitute the new HMAC because it
  does not match those historical rows.
  An automatic-only installation that disabled before ever emitting a keyed
  event has no account link by design and cannot be targeted by an account-based
  deletion request; do not claim otherwise. Its unlinked GA4 data is governed by
  verified two-month upstream retention, while rows already exported to the
  restricted BigQuery raw dataset may remain until the separate 90-day table
  expiration. State both limits in the privacy notice/deletion response rather
  than creating a persistent account-device map.
- Keep deletion-exclusion tombstones permanent and run a daily upstream deletion
  sweep over a checkpointed range with at least a three-UTC-date overlap for
  mutable GA4 late arrivals. For every tombstoned key it discovers
  future keyed installation IDs (including product events queued while a
  supported client was offline), it resubmits GA app-instance deletion, deletes
  matching warehouse rows, and submits the legacy `USER_ID` while that migration
  window remains possible. It persists no install mapping, so later automatic-
  only events after the last keyed row cannot be associated and remain governed
  by upstream two-month retention and the restricted exported-raw 90-day
  expiration. The request reports source/warehouse deletion plus recurring
  **keyed-upload** enforcement, never indefinite automatic-event enforcement.
  Record request IDs/completion without raw account/install IDs.
  Test the layered deletion command, IAM, request format, in-flight export
  ordering, delayed keyed upload appended to an already-swept partition,
  watermark-gap recovery, flattened anti-join/non-repopulation, aggregate
  rebuild, and a non-production deletion before rollout.

## Looker Studio

Create one restricted initial report backed only by
`sesori_analytics_reporting`:

1. **Executive snapshot** — headline scorecards, complete-week trends,
   activation funnel, W1/W4 retention, sample size, behavioral coverage, and
   last refresh.
2. **Activation** — cohort funnel and time-to-step distributions; optional
   notification registration is visually separate, and the account-less login
   funnel is a clearly separated diagnostic panel.
3. **Retention and engagement** — cohort heatmap, meaningful/controller WAU,
   active days, interventions, message depth, voice adoption, feature adoption,
   and screen usage.

Each page includes a compact freshness/coverage/maturity strip backed by the
`data_quality` view so a broken pipeline cannot look like declining usage.
Additional dedicated feature, acquisition, product-quality, and data-quality
pages are deferred extensions rather than deleted requirements.

Default every page to complete periods. Allow a clearly marked live-period
filter for operators, but never use live partial values in exported investor
screenshots.

## Implementation Sequence

This implementation intentionally retains five rollout steps. The extra
auth-server slice keeps the persisted-field migration write-first and race-free;
Step 3 is delivered as four stacked PR substeps (3.A-3.D) so each apps review
stays near 1,500 added lines. Every implementation PR uses
the fixed series title wrapper shown below; `user-analytics` is this plan's
directory name.

### PR 1/5 — Write-first auth preference

**Title:** `[user-analytics] Add write-first analytics preference [step 1/5]`

**Repository:** `sesori_auth_server`

- Add the persisted enum/value-update timestamp, temporarily default missing
  fields to honest prior values at decode/read boundaries, and add genuinely
  nullable `productAnalyticsExportSuppressedAt` without a default.
- Make every new `UserRepository.create` write preference, update timestamp,
  revision, and nullable last-operation ID before exposing GET/PUT preference
  behavior.
- Add the dedicated repository-backed preference service and authenticated
  product-analytics routes; leave all auth profiles/tokens untouched.
- Add the idempotent backfill/count command.
- Test auth/validation, new-user writes, missing-document default, concurrent
  compare-and-set updates, duplicate operation idempotency, stale revision
  conflict (including late older enable after newer disable), and unchanged
  OAuth/password/refresh responses.
- Deploy this version fully, verify every new user writes the field, then run
  backfill until repeated validation reports zero missing. PR 2 cannot merge or
  deploy before that evidence is recorded.

### PR 2/5 — Enforce preference and add auth export

**Title:** `[user-analytics] Enforce analytics preference and add export [step 2/5]`

**Repository:** `sesori_auth_server`

- Remove the temporary required-field defaults and make the Mongo model required;
  add a startup/test assertion that fixture creation always supplies it.
- Add BigQuery Client -> export API -> export/control repositories -> export
  service; add deletion-target repository/service plus source suppression/
  restricted-target handoff command; add isolated job config/composition,
  package dependency, and production image command.
- Publish the eligible pseudonymous snapshot and identifier-free weekly setup
  cohorts through staging/validation/transactional promotion, excluding source-
  suppressed and permanent internal keys before keyed rows or aggregate counters.
- Test the HMAC golden vector/key separation, opt-out filtering, aggregate reconciliation,
  pagination cutoff, milestones/preferences changing on already-read and future
  pages, conservative preference exclusion, staging cleanup, rerun idempotency,
  source/internal suppression before aggregation, tombstone non-repopulation,
  and failed-run safety.
- Configure one identical pseudonymization secret on the web/export/suppression
  runtimes, then deploy web enforcement only after step-1 zero-missing evidence.
  Deploy the job definition disabled; schedule it in PR 5 after private
  datasets/IAM exist.

### PR 3.A/5 — Client analytics contracts and delivery

**Title:** `[user-analytics] Add client analytics contracts and delivery [step 3.A/5]`

**Repository:** apps monorepo

- Add JSON PUT to `SafeApiClient`, `HttpApiClient`, and
  `AuthenticatedHttpApiClient` in `module_auth`, including auth/header/error/
  timeout tests. Bind token acquisition and any 401 refresh/retry to the
  initiating account so a delayed operation can never continue with a later
  account's token. Shared `AuthUser` remains unchanged.
- Add the closed product/installation event contracts, runtime capability,
  Analytics Client/API/repository, delivery result, and
  account-less installation service in `module_core`.
- Add the thin mobile `FirebaseAnalyticsClient` and desktop no-op adapter without
  starting either product lifecycle. Validate event names, bounded parameters,
  server-HMAC key shape, SDK failure mapping, and disabled-runtime behavior.
- Update root analytics guidance and `.opencode/skills/add-analytics/SKILL.md`
  in the same PR so the new core contracts are the source of truth.
- Keep the new adapters and services dormant; this slice changes no production
  reporting, preference, identity, routing, or Settings behavior.

### PR 3.B/5 — Durable analytics preference sync

**Title:** `[user-analytics] Add durable analytics preference sync [step 3.B/5]`

**Repository:** apps monorepo

- Add the revisioned preference API, versioned secure storage records, domain
  records/results, and preference repository on top of PR 3.A's account-bound PUT.
- Validate and carry only the server-derived HMAC user key. Keep GET/PUT bound to
  the initiating account across token refresh and 401 retry.
- Persist enable/disable write-ahead intent before the request, retain stable
  operation IDs across restart/retry, finalize only after server and local
  success, and preserve distinct durable/volatile failure states.
- Handle revision conflicts with one bounded stable-ID disable retry; never let
  an old enable overwrite a newer disable. Delete malformed local records before
  reconciling while leaving transient storage failures fail-closed.
- Test parsing, key validation, deadlines, storage encoding, write ordering,
  restart recovery, conflict/idempotency behavior, malformed-record recovery,
  and all explicit failure results. This slice remains dormant without a
  lifecycle consumer.

### PR 3.C/5 — Account-linked analytics lifecycle

**Title:** `[user-analytics] Add account-linked analytics lifecycle [step 3.C/5]`

**Repository:** apps monorepo

- Add `ProductAnalyticsService`, its composed preference/synchronization/
  availability state, and the thin preference Cubit over PR 3.B's repository.
- Subscribe to auth before startup storage work; synchronously suppress old
  account state on every generation change; keep post-splash reconciliation
  behind the latest generation's completed local initialization.
- Gate account-linked delivery to authenticated, synchronized, enabled release
  state; coalesce schema readiness; retain pending disable through logout; await
  an active disable within the fixed deadline; and restore exact state when
  logout fails.
- Replace Step 3.A's temporary root `AGENTS.md` prohibition on account-linked
  reporting with the final `ProductAnalyticsService` consumer guidance in this
  PR; no step-numbered or pre-lifecycle transitional instruction remains after
  Step 3.C.
- Test splash/readiness, one read per auth generation plus explicit refresh,
  pending/volatile disable, enable finalization, schema retry, logout timeout/
  recovery, rapid account switches, stale completions, and cross-account key
  suppression. The service remains dormant until the product-shell integration.

### PR 3.D/5 — Settings, routing, and product-shell integration

**Title:** `[user-analytics] Integrate analytics settings and routing [step 3.D/5]`

**Repository:** apps monorepo

- Keep Firebase Analytics collection off natively, resolve release/Test Lab
  eligibility before core startup, register the resulting immutable runtime
  capability, start `ProductAnalyticsService`, and keep desktop analytics
  disabled.
- Disable automatic Firebase screen reporting in Android and every Firebase-
  enabled Apple target. Drive screens only from
  `GoRouterRouteSource.currentRouteStream`, map exhaustively to pinned
  `AnalyticsScreen`, emit canonical `product_screen_viewed`, and mirror the same
  name through `FirebaseAnalytics.logScreenView`; never derive names from
  Navigator runtime classes or concrete paths.
- Remove `AnalyticsUserIdTracker`, never replace it with a global Firebase user
  ID, gate every account-linked Sesori product event
  to post-splash authenticated enabled release builds, while allowing only the separately
  typed, release-only, account-less login catalog; add schema-ready and stable
  GoRouter-backed screen reporting.
- Add a concise `Basic Usage Analytics` toggle to the account/profile page with
  inline pending/error state and a failure-only retry action. Keep detailed
  installation/login-funnel/automatic-event and retention limitations in the
  privacy/legal/store disclosures rather than dense control copy.
- Move the existing seven-event onboarding contract to confirmed platform
  outcomes through explicit `ProjectListCubit` intents backed by
  `ProductAnalyticsService`: widgets dispatch links after successful launch,
  copies after clipboard success, shares after non-dismissed native handoff, and
  menu/explainer outcomes after presentation. Failed actions emit nothing, and
  widgets never resolve the service directly.
- Test foreground/background identity cleanup, startup/DI, Settings and logout
  ordering, route mapping/deduplication/deadlines, automatic-screen suppression,
  one native mirror per changed route, truthful onboarding outcomes, and mobile/
  desktop shell behavior.
- Release only after both auth PRs are deployed. Once users can opt out, this
  account-linked custom-event lifecycle becomes a non-rollback privacy floor:
  subsequent client fixes must preserve it or suppress all account-linked
  Sesori product events.

### PR 4.A/5 — Bounded outcome contracts and delivery

**Title:** `[user-analytics] Add bounded outcome analytics contracts [step 4.A/5]`

**Repository:** apps monorepo

- Add the closed outcome event catalog, bounded enum serialization, and privacy
  contract tests without wiring product consumers yet.
- Put one bounded SDK deadline at the analytics repository boundary and keep
  explicit accepted/deferred/failed delivery results.
- Add generation-scoped fixed candidate slots for activation, project
  availability, diff adoption, and visible session activity while preference is
  genuinely unresolved. This is not a generic queue: schema-readiness failure
  retains the bounded slots for a later explicit preference-state trigger;
  accepted readiness drains each retained outcome once, and an SDK rejection is
  observable but does not create hidden retry or duplicate-delivery semantics.
- Keep `analytics_schema_ready` as the existing foundation diagnostic. Define
  but do not emit `analytics_activation_ready` in this substep.

### PR 4.B/5 — Account-less login outcomes

**Title:** `[user-analytics] Instrument account-less login outcomes [step 4.B/5]`

**Repository:** apps monorepo

- Instrument `LoginCubit` through `InstallationAnalyticsService` with one start
  and one terminal completion/failure (including timeout) per valid attempt.
- Keep provider and failure mapping exhaustive and account-less. Starting Apple
  sign-in is an explicit new login intent that leaves resumable OAuth before the
  native sheet; an opaque handle ensures cancellation, unknown native failure,
  missing-token authentication failure, and server authentication outcomes
  terminate only that Apple attempt.
- Wire mobile Apple and desktop no-op consumers and add focused lifecycle tests.

### PR 4.C/5 — Activation and voice outcomes

**Title:** `[user-analytics] Instrument activation and voice outcomes [step 4.C/5]`

**Repository:** apps monorepo

- Instrument authoritative direct/queued message and session-creation outcomes,
  plus successful content-free voice transcription completion.
- Thread `input_mode=typed/voice_assisted` through existing/new-session sends and
  queues. Immutable `ComposerDraft` contains validated compact half-open spans;
  `ComposerDraftCalculator` owns pure edit transformations, and owning Cubits
  persist through `ComposerDraftRepository`. Widgets do not resolve storage,
  maintain a per-code-unit bitmap, or infer restored mixed attribution from one
  aggregate flag.
- Verify full/partial/identical replacement, mixed-draft restoration, queueing,
  creation deduplication, and content-free parameters.

### PR 4.D/5 — Visible engagement outcomes and capability marker

**Title:** `[user-analytics] Instrument visible engagement outcomes [step 4.D/5]`

**Repository:** apps monorepo

- Instrument project inventory, questions, permissions, abort, diffs, and the
  route-instance-visible foreground `SessionActivityAnalyticsListener`.
- Emit `analytics_activation_ready(activation_schema_version=1)` only here, once
  the complete behavioral schema and authoritative consumers exist. Gate bounded
  candidate draining behind accepted schema and activation readiness.
- Verify empty/non-empty lifetime guards, resumed/later-UTC-date activity,
  hidden parent routes, non-throwing permission failures, bounded deferral, and
  sensitive-input exclusion.
- Do not release the partial 4.A-4.C state. Set `behavioral_schema_v1_start_at`
  and admit activation cohorts only after 4.D appears in production export.

### PR 5/5 — Warehouse models and dashboards

**Title:** `[user-analytics] Add BigQuery metrics and Looker dashboards [step 5/5]`

**Repository:** private `sesori-ai/sesori_analytics_platform` plus cloud deployment

- Add the analytics-platform data contract, parameterized deployment tool,
  DDL, transforms, fixture assertions, scheduled-query definitions, and runbook.
- Bootstrap datasets/reference tables first, publish and validate the initial
  auth snapshot, then apply auth-dependent transforms; full apply fails closed
  when no initial auth snapshot exists.
- Create auth-private/privacy-private/controls/curated/reporting datasets in the raw GA4
  location; keep export-job write access confined to auth-private and grant only
  authorized-view reads for internal exclusion; configure IAM, expiration,
  budget alerts, source/control exclusions, upstream GA4
  retention/deletion limits, and separate raw/behavioral start timestamps.
- Schedule the auth export and three-day event recomputation, then reconcile
  source counts and freshness; verify stale auth snapshots abort publication and
  recovery backfills the missed window.
- Apply deletion exclusion in flattened facts, schedule the recurring upstream
  tombstone sweep using the declared Foundation/API/Repository/Service command
  architecture, and require a tombstone-aware auth export plus final cleanup
  before declaring warehouse deletion complete. The sweep covers future keyed
  uploads only, rescans the mutable three-date late-arrival window plus any
  watermark gap, and persists no account-install mapping.
- Build and permission the three-page initial Looker report with freshness,
  coverage, maturity, voice, login, and GoRouter screen panels.
- Run a release-build smoke test through account -> bridge -> project -> message
  and verify the event, auth join, full activation, complete-day table, and
  reporting view without inspecting sensitive payloads.
- Record dashboard owner, refresh schedule, metric definitions, and rollback/
  incident steps in the runbook.

**Step 5 completion includes the cloud setup above.** Landing the standalone
repository implementation delivers the reviewed automation and contracts, but
does not complete Step 5 by itself. After the required security/privacy
decisions are approved, the same Step 5 work must use the checked-in runbook and
tools to create service identities and dataset ACLs, authorize views, apply
warehouse schemas, provision
auth export and privacy jobs, apply transform/deletion schedules, run deployed
assertions and deletion drills, build/restrict Looker, and record go-live
evidence. These are tracked delivery tasks, not an out-of-band setup handed to
the user. The user supplies approvals, restricted values, and any admin-only
authorization that cannot be delegated; the implementing operator performs and
verifies the setup. Keep Step 5 open until every applicable cloud and dashboard
acceptance item passes.

### Deployability, compatibility, and rollback by step

| State | Independently usable behavior | Deployment prerequisites/order | Rollback boundary |
| --- | --- | --- | --- |
| Before 1/5 | Existing clients/events continue. Firebase daily export should be linked only through the controlled day-zero sequence so its non-retroactive clock starts safely. | Complete restricted-project IAM, daily-only link, raw expiration/settings verification, and record `raw_export_start_at`. | Unlinking loses future export and is not a useful rollback; stop rollout and correct IAM/expiration/location before derived datasets or new instrumentation. |
| After 1/5 | Dedicated GET/PUT preference endpoints work; old clients are unaffected because auth responses did not change. New users always write preference; old documents read as enabled during migration. | Deploy write-first web code to all serving instances, verify new writes, run/re-run backfill, and record zero missing. | Roll back before any opt-out client release if necessary. The added field is ignored by old code; do not remove it. Re-run backfill after returning to step 1. |
| After 2/5 | Preference schema is required and export command/job image is deployable but unscheduled. Existing clients remain unaffected. | Require recorded zero-missing evidence from step 1; deploy enforcement; smoke-test account creation and endpoints; deploy job disabled. | Roll back web/job to step 1, whose honest missing-field default can read every document. Stop any job; published tables stay at last good state. |
| After 3.A/5 | Typed analytics contracts, account-bound PUT transport, and dormant platform delivery adapters are available without changing production collection. | Step 2 must be deployed. | Revert the dormant client contracts/adapters; product behavior is unchanged. |
| After 3.B/5 | Durable preference API/storage/repository behavior is available but has no lifecycle consumer or UI. | Step 3.A merged. | Revert the dormant preference stack; server preference data remains intact. |
| After 3.C/5 | The account-linked lifecycle and fail-closed state machine are testable but not started by a product shell. | Step 3.B merged. | Revert the dormant lifecycle; product behavior is unchanged. |
| After 3.D/5 | Mobile never sets a global Firebase user ID, keeps collection off until an eligible release configures consent, can disable/enable account-linked Sesori product events on this installation, and syncs its server reporting/supported-client preference; existing product events and GoRouter-backed screens obey the lifecycle; only the bounded account-less login catalog plus Firebase automatic install events retain the separately disclosed installation behavior; desktop remains no-op. | Both auth endpoints/schema must be live. If startup eligibility or configuration fails, analytics remains disabled; if preference is unavailable, account-linked events fail closed and disable remains local pending without blocking logout. | **Forward-fix only after public release.** Preserve local product-event gating through its declared floor. For a severe defect, suppress all custom events; server preference data is never rolled back. |
| After 4/5 | New activation/engagement events accumulate in GA4 raw export. Product operations remain unchanged if Firebase is unavailable. | Step 3.D custom-key/preference/schema lifecycle must be released. BigQuery needs no GA4 custom-dimension registration. | Forward-fix the app while retaining the step-3 privacy behavior; event-specific defects may be disabled/removed. Missing future event names yield null/zero data, not product failure. |
| After 5/5 | Auth job, curated models, authorized reporting views, and Looker provide the complete metric contract. | Create same-location datasets/IAM; deploy SQL/tests; schedule auth export; validate its first publish; schedule event transforms; then connect Looker. | Pause or revert reporting transforms, auth export, views, and dashboard sources to the last known-good version. Permanent exclusions, tombstone processing, and recurring upstream deletion enforcement continue; privacy defects receive a privacy-preserving forward fix. Raw GA4 and prior auth published tables remain; app behavior is unaffected. |

There is no `AuthUser` compatibility field, alternate endpoint, optional
internal constructor parameter, dual event name, or product behavior in
`module_auth`. Server write-first/backfill/enforce ordering handles persistence;
client fail-closed behavior plus a declared forward-fix privacy floor handles
the separately released app.

## Verification

### Apps monorepo

- Run code generation after changing Freezed/Injectable sources; never edit
  generated files manually.
- `dart test` and `dart analyze` in `client/module_auth` for the new PUT transport
  method and authenticated delegation.
- `dart test` and `dart analyze` in `client/module_core`; add API/repository/
  service/listener/cubit tests with fake platform clients/storage.
- `flutter test` and `dart analyze` in `client/app`.
- `dart test`/`dart analyze` in `client/module_desktop_core` and
  `flutter test`/`dart analyze` in `client/desktop` when shared DI/constructor
  changes affect desktop.
- Inspect a release-build Firebase DebugView/BigQuery sample using synthetic
  content and verify no forbidden field/value appears. Do not turn normal debug
  custom-event sharing on for convenience.
- Navigate every `AppRouteDef` through GoRouter and verify exactly one canonical
  `product_screen_viewed` plus one Firebase-native `screen_view` mirror with the
  same pinned name, no concrete route parameters, and no automatic duplicate.
- Verify login events carry no `user_key`/attempt identifier and voice events
  carry no transcript, audio metadata, duration, or text-derived value.
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
  per-account activation-capable exposure, foundation-only/legacy exclusion,
  7-day cohort
  maturity, W1/W4 boundaries, internal/disabled/suppressed filtering before
  aggregates, deletion exclusion in flattened recomputation, daily monitoring
  activity without SSE duplication, typed/voice-assisted classification,
  deferred occurrence-time preservation, clock-skew rejection, and occurrence-
  based activation/retention anchors,
  identifier-free login aggregation, custom-screen-only account reporting,
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
  offline-client upload into a previously swept mutable partition plus
  overlapping recurring sweep, and upstream request status.
  Verify the deletion response states transient future-upload/keyed-only sweep
  limits and, for automatic-only/never-keyed data, both two-month upstream GA
  retention and 90-day restricted BigQuery raw expiration.

## First Release And Ongoing Operation

1. **Day 0:** Establish restricted project IAM, link daily Firebase export,
   verify raw ACL/90-day expiration before the first table, and record
   `raw_export_start_at`; this data cannot be recovered later.
2. **Week 1:** Land/deploy write-first auth preference, run/verify backfill,
   then land enforcement/export.
3. **Weeks 1-2:** Land the client foundation and ship its fail-closed opt-out
   release.
4. **Weeks 2-3:** Land instrumentation and ship the mobile release as early as
   store review permits; set `behavioral_schema_v1_start_at` only after its
   `analytics_activation_ready` capability appears in controlled raw export.
5. **Weeks 3-4:** Deploy warehouse models, run data QA, and build Looker.
6. **Weeks 4-8:** Monitor data-quality alerts weekly, correct only demonstrated
   schema/metric defects, and let cohorts mature.

W1 retention becomes available after two weeks of production behavior. W4
requires at least 35 days after a user's activation to close the full 28-34 day
window; any release delay directly reduces the W4 sample available by the
two-month deadline. Show the cohort size and use null—not a fabricated zero—if
no cohort has matured. The deadline is the first investor-ready readout, not the
end of the system: keep the same metric definitions, schedules, privacy controls,
and data-quality monitoring in ongoing product operation, and add deferred
extensions only through versioned schema/model changes.

## Risks And Mitigations

- **No retroactive behavioral data:** link/export and ship early; label raw and
  behavioral starts separately and do not backfill full activation from
  metadata requests.
- **Developer/internal pollution:** custom events are release-only and account-
  linked reporting excludes a restricted internal-user list; the separately
  labeled login diagnostic cannot apply that exclusion. Monitor app version/
  schema mix and keep login out of headlines.
- **Opt-out bias:** show eligible coverage with every behavioral funnel and do
  not extrapolate activation/retention to all accounts.
- **Legacy/foundation-only denominator bias:** require timely per-account
  activation-capable exposure; foundation readiness, global rollout time, or
  server default-enabled state alone never makes an account measurable.
- **Cross-repository deployment mismatch:** deploy write-first server behavior,
  backfill/verify, then enforce, and only then release the client. Preference
  GET/PUT failure is fail-closed; auth profiles remain unchanged.
- **Legacy/automatic-event limitation:** a pre-opt-out binary can continue its
  prior Firebase behavior, and Firebase automatic install events are outside the
  custom-event toggle. The bounded pre-auth login catalog is also outside the
  authenticated product-event toggle by explicit decision. Narrow UI/legal
  promises accordingly, use current preference only for supported-client
  account-linked events and reporting eligibility, and never claim account-wide
  enforcement without minimum-version controls.
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
  preserve local pending-disable/product-event gating or suppress all account-
  linked product events; never republish old startup emission as rollback.
- **Analytics affecting product behavior:** all reports are best-effort,
  unawaited after confirmed outcomes, and failure-isolated.
- **High-cardinality or sensitive leakage:** closed event variants, bounded
  enums, raw-ID prohibition, wire-pin tests, and allowlisted SQL.
- **Misleading login conversion:** label pre-auth login metrics as installation-
  level aggregates that may include internal/test release traffic, keep them out
  of investor headlines, never join them to account creation/activation, and do
  not infer unique people from attempts or `user_pseudo_id`.
- **Incorrect screen names/duplicates:** disable Firebase automatic screen
  reporting, map GoRouter routes exhaustively to pinned screen values, mirror
  those through `logScreenView`, and use only the custom event in account-level
  reporting.
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
- The same release reports typed versus voice-assisted successful submissions
  and content-free transcription completion, reports bounded account-less login
  attempt outcomes without account/attempt identity, and derives every screen
  name from GoRouter with one canonical custom event plus one matching Firebase-
  native mirror and no automatic duplicate.
- The auth job publishes validated eligible milestones and external-account
  setup cohorts without raw identity or internal/deletion-suppressed accounts.
- BigQuery derives the metric contract above from versioned SQL, passes fixture
  assertions, survives stale auth snapshots without permanent event loss, and
  remains fresh after recovery/late data.
- Privacy deletion remains excluded from flattened/reporting rebuilds, survives
  an in-flight old auth export, and has recurring upstream enforcement for later
  keyed uploads with its unavoidable transient/never-keyed limits and distinct
  two-month upstream/90-day exported-raw retention disclosed.
- Looker exposes only aggregate authorized views and shows complete-period,
  denominator, coverage, maturity, and freshness labels.
- The executive page can truthfully report new accounts, setup, full
  activation, WAU/growth, W1/W4 retention when mature, activity depth, and the
  selected feature-adoption metrics without manual spreadsheet logic.

## Final Step — Archive The Completed Plan

After every completion criterion above and every in-scope tracker item is done,
record the final PR, cloud setup, access, deletion-drill, dashboard, and release
evidence in `TRACKER.md`. Then, as the last action of this plan, move the entire
plan directory (including its tracker and supporting files) from
`.plan/active/user-analytics/` to `.plan/completed/user-analytics/` and commit
that move. Do not copy it, leave an active duplicate, or archive it while any
required Step 5 setup or acceptance work remains.
