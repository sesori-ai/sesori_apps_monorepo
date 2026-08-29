# Account Deletion

## Goal

Deliver a cancellable, user-initiated account-deletion flow that starts after a
24-hour grace period, cancels automatically after a successful sign-in during
that period, and then removes account-owned Sesori data without breaking the
existing analytics privacy-deletion and aggregate-rebuild guarantees.

Deletion must remove every project glossary scope owned by the account. It must
not directly mutate analytics aggregates, delete the analytics source tombstone,
or bypass the existing keyed-data deletion pipeline.

## Confirmed Product Decisions

- The user schedules deletion through an authenticated API with an exact typed
  confirmation body.
- The grace period is 24 hours.
- Scheduling revokes refresh sessions, registered bridges, and notification
  delivery. Existing stateless access tokens may remain valid for their existing
  maximum of 15 minutes; no new per-request user lookup is added solely to close
  that accepted window.
- The account remains recoverable during the grace period. A **successful
  credential sign-in**, not merely a sign-in attempt or refresh request,
  atomically cancels deletion before the deadline and issues new tokens.
- Scheduling the same account again is idempotent and does not extend its
  original deadline.
- At the deadline, cancellation closes and deletion becomes irreversible. The
  user-facing claim is that deletion **begins after 24 hours**, not that every
  provider, warehouse, retained backup, or legally retained record disappears
  at exactly the deadline.
- Account identities remain available only during the grace period so verified
  sign-in can cancel. Finalization removes them.
- A minimal auth-server tombstone remains after operational deletion because the
  current analytics system requires permanent source suppression and delayed-
  upload non-repopulation protection.
- Automatic-only analytics data that was never account-linked remains governed
  by the existing upstream and raw-export retention limitations. The product
  must not promise deletion of data that cannot be linked back to the account.

## Current Behavior

### Auth server

- There is no self-service account-deletion route or account-deletion state.
- `POST /auth/revoke` revokes bridges, invalidates refresh tokens through
  `User.tokenVersion`, and deletes device tokens. Access tokens are stateless and
  expire after 15 minutes.
- Verified privacy requests currently use the operator command
  `suppress-product-analytics-export`. It permanently suppresses source export
  and hands a bounded deletion target to the analytics privacy dataset.
- `glossaryEntries` stores one document per exact account-owned scope, but the
  repository currently exposes only bridge-specific deletion, not an
  account-wide purge.
- MongoDB has no cascade deletion. Account-owned records span `oauthAccounts`,
  `passwordAccounts`, `glossaryEntries`, `dailyUsage`, `deviceTokens`, `bridges`,
  `activationStates`, and `settingsConfiguration`, plus the `users` source row.

### Analytics platform

- Privacy deletion is an isolated, idempotent source-to-warehouse workflow, not
  a public application route.
- A permanent source tombstone and warehouse exclusion prevent repopulation.
- Keyed raw/auth/curated contributions are removed, currently linkable GA
  installations are submitted through Analytics Admin, and the fixed
  `20 -> 30 -> 40` aggregate chain is rebuilt and verified.
- Identifier-free reporting tables are not ad hoc deletion targets. Rebuilding
  their authoritative sources removes the deleted account's contribution
  without introducing user identifiers into reporting.
- The recurring sweep handles delayed keyed uploads for existing permanent
  exclusions, but it intentionally does not discover or initiate newly handed-
  off privacy requests. Automatic account deletion therefore needs a reviewed
  processor for pending/retryable targets.

### Client and bridge

- The app has logout but no account-deletion scheduling UI.
- A successful OAuth/password/native sign-in receives normal auth tokens and no
  deletion-cancellation outcome.
- Bridge revocation already causes active bridge credentials to stop refreshing;
  released clients and bridges must continue to degrade safely while deletion is
  pending or completed.

### Legal documents

- The Privacy Policy and Terms cover voice audio/transcripts and broad limited
  readable feature processing, but do not clearly disclose durable,
  server-stored, privacy-filtered project vocabulary or that applicable terms
  are sent to the configured transcription sub-processor.
- They do not describe a self-service 24-hour account-deletion grace period,
  successful-sign-in cancellation, the minimal permanent suppression tombstone,
  or the limits for unlinkable automatic analytics data.
- The Cookie Statement concerns website/mobile tracking technologies and does
  not require a glossary-specific change.

## Concrete Implementation Ownership

### Auth scheduling and successful-sign-in cancellation (Step 2)

Production ownership stays `Route -> AccountDeletionService -> repositories`:

- `src/types/account-deletion.ts` defines `AccountDeletionState` and typed
  pending/finalizing/completed domain variants.
- `src/models/documents.ts` adds the optional discriminated
  `User.accountDeletion` subdocument. Absence means no request and needs no
  backfill.
- `src/models/api.ts` adds a strict
  `scheduleAccountDeletionBodySchema = z.object({confirmation:
  z.literal("DELETE")}).strict()` and the typed pending response with an ISO UTC
  `scheduledFor`.
- `src/repositories/user-repo.ts` owns every atomic state transition and returns
  parsed domain outcomes. It also owns the due-state index access; routes and
  services never assemble Mongo filters.
- `src/services/account-deletion-service.ts` owns scheduling side effects and
  the pre-token successful-sign-in decision. It depends on `UserRepository`,
  `BridgeService`, and `DeviceTokenRepository`.
- `src/routes/account-deletion.ts` exposes authenticated
  `POST /auth/account/deletion`; it validates the exact body, takes `userId`
  only from `request.user`, calls `AccountDeletionService.schedule`, and maps
  the trusted deadline. It does not touch repositories.
- `src/repositories/oauth-account-repo.ts` replaces the profile-mutating upsert
  with an insert-or-find operation whose existing-account path performs no
  mutation, plus a separate post-authorization profile update and
  `deleteAllForUser`.
- `src/repositories/password-account-repo.ts` gains `deleteAllForUser` for Step
  3. Password rehash remains in `AuthService` but moves after the account-
  deletion decision.
- `src/services/auth-service.ts` receives `AccountDeletionService`. Every
  password, browser OAuth, and native Apple flow verifies provider credentials,
  resolves the existing user through the service, and only then updates identity
  metadata/rehashes or signs tokens. New OAuth users retain the current
  insert-or-find plus `UserRepository.create` race handling. Refresh-token flow
  is unchanged and cannot cancel deletion.
- `src/db/mongo-db-accessor.ts` adds an index beginning with
  `accountDeletion.state`, then `accountDeletion.scheduledFor` and `_id`, for
  bounded due scans.
- `src/index.ts`, `src/server.ts`, and test helpers construct and register the
  service/route. Focused tests live under `tests/repositories/user-repo.test.ts`,
  `tests/services/account-deletion-service.test.ts`,
  `tests/services/auth-service.test.ts`, and
  `tests/account-deletion/schedule.test.ts`.

`AccountDeletionService.schedule` first calls the one atomic user-repository
operation that creates the pending request and increments `tokenVersion` only
on the absent-to-pending transition. It then calls existing
`BridgeService.revokeAllForUser` and `DeviceTokenRepository.deleteAllForUser`.
A partial side-effect failure is observable and retryable: the repeated request
returns the original deadline/request and reruns idempotent revocation without
extending the grace period or incrementing the token version again.

### Auth finalization and account-owned cleanup (Step 3)

- `src/services/account-deletion-finalizer-service.ts` owns one-user
  finalization. It depends on `UserRepository`, existing
  `ProductAnalyticsDeletionService`, `BridgeService`, and the eight
  account-owned repositories. It never receives a raw Mongo collection.
- `src/scripts/product-analytics-deletion-runtime.ts` extracts the current
  approved privacy composition shared by
  `suppress-product-analytics-export.ts` and the new worker; the web server does
  not receive BigQuery credentials.
- `src/scripts/process-due-account-deletions.ts` is the bounded scheduled entry
  point. It reads at most the configured 1-100 users, processes them
  sequentially, continues after one user's sanitized failure, emits only
  aggregate counts/failure kinds, and exits non-zero when work remains
  retryable. `package.json` exposes the command and `README.md` documents the
  externally overlap-skipped schedule.
- `UserRepository.findAccountDeletionWorkBatch` returns sorted pending-due and
  finalizing users. `beginAccountDeletionFinalization` atomically changes only a
  pending request whose database deadline is due into finalizing;
  `completeAccountDeletion` changes only the same request ID from finalizing to
  completed. A finalizing record is deliberately resumable after process
  failure and never cancellable.
- Add repository-owned, `userId`-filtered idempotent deletion methods:
  `OAuthAccountRepository.deleteAllForUser`,
  `PasswordAccountRepository.deleteAllForUser`,
  `GlossaryEntryRepository.deleteAllForUser`,
  `DailyUsageRepository.deleteAllForUser`,
  `BridgeRepository.deleteAllForUser`, and
  `ActivationStateRepository.deleteAllForUser`. Reuse existing
  `DeviceTokenRepository.deleteAllForUser` and
  `SettingsConfigurationRepository.deleteAllForUser`.
- `BridgeService.revokeAllForUser` runs before bridge documents are deleted so
  its `BridgeStateTracker` timer cancellation and bridge-local glossary cleanup
  remain authoritative. `GlossaryEntryRepository.deleteAllForUser` then removes
  repository and any residual bridge-local scopes.
- Focused finalizer/command tests prove handoff-first ordering, every collection,
  target-user isolation, stable request IDs, retry after every boundary, and
  completed-tombstone retention.

The completed `users` row retains exactly the fields required by the current
schema/export contract: `_id`, `tokenVersion`, original `createdAt`, `updatedAt`,
all product-analytics preference/revision fields forced to disabled state,
`productAnalyticsExportSuppressedAt`, and completed deletion `{state,
requestId, completedAt}`. It retains no OAuth/password identity, bridge, device,
usage, activation, settings, or glossary document. Existing
`findProductAnalyticsExportBatch` continues exporting this row as suppressed so
warehouse reconciliation and delayed-upload protection remain valid.

### Analytics target automation (Step 4)

Production ownership stays `API -> Repository -> Batch service -> existing
request service`:

- `privacy_deletion/privacy_deletion_api.dart` adds
  `loadProcessableRequestIds`, querying only `pending`, `processing`, and
  `retryable` targets, ordered by `updated_at, request_id`, with a validated
  bounded limit. Updating a failed target already advances `updated_at`, so one
  retryable target does not permanently starve later requests.
- `privacy_deletion/privacy_deletion_repository.dart` validates/maps that closed
  target-ID page through `loadProcessableRequestIds`; the batch service never
  owns SQL.
- `privacy_deletion/privacy_deletion_batch_service.dart` loads one page and
  invokes existing `PrivacyDeletionService.runRequest` sequentially. It catches
  a recovery exception per target, continues the page, and returns only
  aggregate completed/already-completed/retryable counts.
- `privacy_deletion/privacy_deletion_runtime.dart` extracts the currently
  duplicated ADC, BigQuery, GA Admin, schema, API, repository, and service
  composition from `run_privacy_deletion.dart` and
  `sweep_privacy_deletions.dart`.
- `privacy_deletion/process_privacy_deletions.dart` is the scheduled entry
  point. Its batch limit is closed and bounded, overlap is disabled by the
  deployment, and any retryable target produces a non-zero result after the
  rest of the page has been attempted.
- `privacy_deletion/privacy_deletion_test.dart`, a focused batch-service test,
  `docs/privacy-deletion.md`, and `docs/reference/full-runbook.md` cover the new
  command and preserve the separate recurring tombstone sweep.

No new queue/table/status is introduced: the existing handoff target and its
`pending/processing/retryable/completed` states remain authoritative.

### Client API/domain foundation (Step 5)

- `client/module_auth/lib/src/client/authenticated_http_api_client.dart` adds
  `postForUser`, matching the existing account-generation guard used by
  `getForUser`/`putForUser` so an account switch cannot apply another user's
  destructive response.
- `client/module_core/lib/src/api/account_deletion_api.dart` owns the strict wire
  request/response Freezed models and maps authenticated transport to a closed
  success/timeout/failure result.
- `client/module_core/lib/src/repositories/models/account_deletion.dart` owns the
  domain deadline/result; `account_deletion_repository.dart` maps API variants
  without exposing transport errors.
- `client/module_core/lib/src/services/account_logout_service.dart` becomes the
  one owner of the existing local logout pipeline: product-analytics
  preparation/recovery, notification unregistration/recovery, and
  `AuthSession.logoutCurrentDevice`. A closed `AccountLogoutReason` distinguishes
  regular logout (restore local subsystems if credential clearing fails) from a
  server-confirmed deletion schedule (do not resume account-linked work after
  the server has already revoked the account). It adds no mutable state.
- Existing `SettingsCubit.logout` is changed in this foundation step to consume
  `AccountLogoutService` instead of orchestrating those three collaborators
  inline. Its externally visible success/failure behavior remains unchanged.
- `client/module_core/lib/src/services/account_deletion_service.dart` depends
  only on `AccountDeletionRepository` and `AccountLogoutService`. Its
  `schedule({required String userId})` receives the current account ID from the
  cubit, schedules through the repository's generation-guarded call, and only
  after server success invokes the shared logout service with the account-
  deletion reason. It never clears local state when the scheduling request
  itself fails. Retrying uncertain post-response local cleanup is safe because
  the server deadline is idempotent.
- Module exports, injectable configuration, and focused API/repository/logout-
  service/account-deletion-service tests are generated/updated in this step. No
  UI invokes account deletion yet, so deploying the additive feature foundation
  changes only the ownership—not the behavior—of ordinary logout.

### Client presentation (Step 6)

- `client/module_core/lib/src/cubits/settings/settings_cubit.dart` continues to
  consume `AccountLogoutService` for ordinary logout and additionally receives
  `AccountDeletionService`; `settings_state.dart` adds a sealed deletion action
  with idle/in-progress/success(deadline)/failure variants. The cubit passes its
  current authenticated account ID to the deletion service and never reaches an
  API or repository.
- `client/app/lib/features/settings/profile_screen.dart` adds the destructive
  row, exact confirmation sheet, busy/failure handling, and the server deadline
  success message before routing to sign-in. Existing `context.watch` and
  listener patterns remain.
- `client/app/lib/features/login/login_screen.dart` adds only generic recovery
  copy when appropriate to the flow: a successful sign-in during the 24-hour
  grace cancels deletion. It does not need or infer the server deadline.
- The exact deadline lives only in the in-memory SettingsCubit success variant
  long enough to render the post-schedule confirmation. It is not persisted,
  put in `state.extra`, added to auth tokens, or reconstructed on login. The
  pre-schedule confirmation states the same recovery rule, so a user knows it
  before local credentials are cleared.
- App composition injects the new service into `SettingsCubit`; localization
  ARBs/generated files and focused profile/login/settings tests complete the
  UI step. Splitting foundation from UI keeps each generated PR under the line
  cap.

## Target State And Data Flow

### 1. Schedule

1. An authenticated client submits the exact confirmation required by the new
   account-deletion endpoint.
2. `UserRepository.scheduleAccountDeletion` uses one Mongo update pipeline and
   database `$$NOW` to create pending `{state, requestId, requestedAt,
   scheduledFor}` and increment `tokenVersion`. `scheduledFor` is exactly
   `$$NOW + 24 hours`. The pipeline preserves an existing pending subdocument
   and token version, so concurrent/retried requests return one winner without
   extending the deadline.
3. Only after the pending state is durable, `AccountDeletionService` reruns
   idempotent bridge revocation and device-token deletion. The response returns
   the fixed database deadline so the client can explain the grace period before
   clearing local credentials.
4. No permanent analytics suppression, identity deletion, glossary deletion, or
   warehouse handoff happens during the reversible grace period.

### 2. Cancel by successful sign-in

1. OAuth/password/native credentials are fully verified first, but an existing
   OAuth profile or password hash is not mutated yet.
2. `UserRepository.cancelPendingAccountDeletionForSignIn` atomically unsets only
   `state == pending` with `scheduledFor > $$NOW`, again using Mongo database
   time. `AccountDeletionService.prepareSuccessfulSignIn` returns the resulting
   current User to `AuthService`, which then updates identity metadata/rehashes
   and signs tokens with its current token version.
3. A refresh-token request never calls the cancellation operation; scheduling
   already invalidated every pre-request refresh token.
4. At or after the deadline, sign-in cannot cancel the request. It returns a
   bounded account-deletion error until the due finalizer removes the old login
   identity. A later genuine sign-up creates a new account identity rather than
   resurrecting the deleted account or its analytics key.

`UserRepository.beginAccountDeletionFinalization` is the other half of the same
boundary: it atomically changes only `state == pending` with `scheduledFor <=
$$NOW` to `finalizing`. Cancellation only matches pending-before-now and the
claim only matches pending-due-now, so neither a stale application read nor
clock skew between API/worker processes can let cancellation cross an
irreversible claim. Do not add process-local timers, per-user locks, or a second
cancellation registry.

### 3. Finalize account-owned service data

A dedicated, idempotent scheduled command under the approved privacy identity
loads a bounded page of pending-due and already-finalizing users. It does not run
inside an API request and does not use an in-process 24-hour timer.

For each user it first obtains/resumes the atomic `finalizing` variant, then:

1. applies the permanent source analytics suppression and writes the existing
   privacy deletion handoff using the variant's stable request ID;
2. revokes bridges/tokens again idempotently;
3. deletes all account-owned operational documents, including **every
   repository and bridge-local glossary scope**;
4. deletes OAuth/password login identities;
5. calls `UserRepository.completeAccountDeletion`, filtered by finalizing state
   and the same request ID, to retain only the completed-deletion/source-
   suppression tombstone required by auth export and delayed-upload protection.

A handoff or cleanup failure leaves the user finalizing and therefore
observable/resumable in the next bounded run. The same stable request ID and
idempotent repository deletes make retries safe. Finalization never returns to
pending and must not erase the source tombstone to make a failed analytics run
appear clean.

### 4. Complete analytics erasure

A separately deployed analytics privacy processor consumes pending/retryable
handoffs through the existing `PrivacyDeletionService` boundary. It:

- creates/verifies the permanent warehouse exclusion first;
- performs immediate keyed/raw cleanup and Analytics Admin submissions;
- waits across scheduled invocations for a fresh tombstone-aware auth export;
- removes auth-private and curated keyed rows;
- rebuilds and verifies the fixed aggregate chain;
- marks completion only after non-repopulation checks pass.

The recurring delayed-upload sweep remains independent and continues revisiting
all permanent exclusions. No auth endpoint receives BigQuery credentials and no
operator-selected SQL or table list is introduced.

### 5. Client behavior

- Profile/settings presents destructive account deletion with explicit 24-hour
  grace, successful-sign-in cancellation, and analytics-retention limitations.
- The confirmation UI sends the strict confirmation body once.
- After the schedule response is received, the app clears local credentials and
  returns to sign-in.
- The pre-schedule and post-schedule copy explains that a successful sign-in
  before the deadline cancels deletion. Login itself needs no persisted
  deadline. No analytics event identifies a deletion request, account, or
  outcome.

## Persistence And Contract Shape

`src/types/account-deletion.ts` and `src/models/documents.ts` preserve these
exact discriminated variants rather than nullable coordination fields:

- absence of `User.accountDeletion`: no deletion request;
- `pending`: non-null `requestId`, `requestedAt`, and `scheduledFor`;
- `finalizing`: those same values plus non-null `startedAt`;
- `completed`: non-null `requestId` and `completedAt`.

All dates are persisted BSON dates and validated as finite. Request IDs use the
existing `productAnalyticsDeletionRequestIdSchema`; the service creates an
`account_deletion_<UUID>` candidate, while the atomic schedule operation chooses
and preserves one candidate under concurrent calls.

`UserRepository` is the sole state owner:

- `scheduleAccountDeletion` uses database `$$NOW`, writes absent-to-pending, and
  increments token version once;
- `cancelPendingAccountDeletionForSignIn` unsets only pending-before-deadline;
- `findAccountDeletionWorkBatch` returns sorted pending-due/finalizing work with
  a hard limit;
- `beginAccountDeletionFinalization` atomically claims pending-due work;
- `completeAccountDeletion` requires finalizing plus the same request ID and
  writes the completed tombstone only after handoff and cleanup succeed.

The worker deployment prohibits overlap, but correctness does not depend on a
process-local lease: a duplicate worker can only repeat stable-ID handoff and
idempotent deletes against the same finalizing user. No route or service writes
these state fields directly.

The scheduling request is strict and requires the exact closed confirmation
value. Its response returns the database deadline. Existing auth/login
contracts remain compatible; older clients never call the additive route, and
older bridges observe ordinary revocation.

## Privacy And Legal Updates

Update `sesori_auth_server/assets/legal/privacy.md` and `terms.md` before rollout
to disclose:

- the bridge derives bounded, privacy-filtered project vocabulary locally from
  tracked names and selected metadata evidence;
- Sesori stores only the resulting terms under opaque account/project scopes,
  not raw repository origins, local paths, filenames, metadata source text, or
  source file contents for this feature;
- applicable terms are provided to the configured transcription sub-processor
  as recognition context;
- project vocabulary remains until replaced/removed, bridge-local ownership is
  removed with its bridge, and all glossary scopes are deleted during account
  finalization;
- the 24-hour grace period and successful-sign-in cancellation behavior;
- the minimal permanent suppression tombstone and delayed/unlinkable analytics
  limitations;
- deletion begins after the deadline and external/privacy cleanup may complete
  later under disclosed retention and legal limits.

Review `cookies.md` but do not change it unless implementation introduces a new
cookie or tracking technology; the glossary and account-deletion API do not.

This plan records product/data behavior, not legal advice. Final wording still
requires the product owner's legal approval before publication.

## Planned PR Series

The fixed series slug is `account-deletion` and the total is nine PRs.

1. **`🌿 [account-deletion] Approve cancellable deletion plan [step 1/9]`** —
   monorepo. Add this plan/tracker after architecture-plan review. This is
   documentation-only and has no runtime dependency.
2. **`🚧 [account-deletion] Schedule deletion and cancel on sign-in [step 2/9]`** —
   auth server. Implement the Step 2 files/classes listed under Concrete
   Implementation Ownership: typed User state, `UserRepository` transitions,
   `AccountDeletionService`, authenticated route, OAuth/password mutation
   ordering, index, composition, and focused tests. It deploys safely while no
   released client calls the additive route.
3. **`🚨 [account-deletion] Finalize due account data [step 3/9]`** — auth
   server. Implement `AccountDeletionFinalizerService`, the shared approved
   privacy runtime, the bounded command, and repository-owned cleanup methods
   listed above. It depends on Step 2 persistence but is operationally inert
   until its external schedule is enabled.
4. **`🚨 [account-deletion] Automate privacy target processing [step 4/9]`** —
   analytics platform. Implement `loadProcessableRequestIds` through
   API/repository, `PrivacyDeletionBatchService`, shared runtime composition,
   scheduled command, tests, and runbook updates. It reuses current targets and
   can deploy before any account-generated handoff exists.
5. **`⚙️ [account-deletion] Add client account deletion domain [step 5/9]`** —
   monorepo. Implement `postForUser`, `AccountDeletionApi`, repository models/
   mapper, shared `AccountLogoutService`, `AccountDeletionService`, ordinary-
   logout SettingsCubit migration, DI/exports, code generation, and focused
   tests. It depends on the additive Step 2 route; ordinary logout retains its
   behavior and no account-deletion UI is exposed.
6. **`🚧 [account-deletion] Add account deletion recovery UX [step 6/9]`** —
   monorepo. Add the deletion SettingsCubit state/consumer call through
   `AccountDeletionService`, profile confirmation and exact deadline result,
   fixed recovery messaging, localization/codegen, and widget/cubit tests. It
   depends on Step 5 and remains release-gated until both scheduled jobs are
   operational.
7. **`🌿 [account-deletion] Publish deletion and glossary disclosures [step 7/9]`** —
   auth server. Update `assets/legal/privacy.md` and `terms.md`; record the
   reviewed no-change outcome for `cookies.md`; validate legal route rendering
   and links. It has no production code or database impact.
8. **`🌿 [account-deletion] Reconcile account deletion regression coverage [step 8/9]`** —
   monorepo. Update `docs/regression/account-and-onboarding.md`,
   `analytics.md`, and `voice-input.md` with supported behavior, failure
   signals, proof boundaries, and the final external matrix. This is the
   required penultimate documentation step.
9. **`⚙️ [account-deletion] Verify rollout and retire plan [step 9/9]`** —
   monorepo. Run the recorded destructive non-production matrix, confirm both
   scheduled jobs and legal publication, record results, and move this directory
   to `.plan/completed/account-deletion/` only after every required boundary
   passes.

Each implementation step remains below roughly 1,500 changed lines. If one
cannot remain independently correct under that cap, update this plan before
opening the affected PR rather than silently widening it.

## Verification Strategy

### Automated package/repository checks

- Auth server: build, lint, format check, repository/service/route tests, existing
  auth/revoke/bridge/glossary/analytics tests, and account-deletion clock/race/
  idempotency tests.
- Analytics platform: format/analyze changed Dart, privacy deletion tests,
  render-only deployment validation, keyed-table inventory tests, pending target
  processing tests, fixed aggregate rebuild tests, and non-repopulation checks.
- Client: strict analysis and focused auth/settings/routing/widget tests on every
  changed package; no arbitrary deletion analytics event.
- Legal: rendered legal endpoints preserve headings/links and current versioning;
  Markdown diff/link validation passes.

### Required destructive boundary: L5 Full

Use isolated non-production identities, MongoDB, auth deployment, analytics
property/datasets, and app accounts. Do not use production user data.

The matrix must prove:

1. scheduling stores one immutable 24-hour deadline, revokes refresh sessions,
   bridges, and device tokens, and does not delete data during grace;
2. a successful OAuth/password/native sign-in before the deadline atomically
   cancels deletion and issues valid new tokens; refresh and failed sign-in do
   not cancel;
3. at/after the deadline sign-in cannot cancel, and repeated finalizer runs are
   idempotent;
4. every target user's glossary scope and all other declared account-owned
   operational rows are gone while a second user's same-shaped records survive;
5. login identities are removed and a later sign-up creates a new account rather
   than restoring the deleted user/key;
6. the source suppression tombstone, restricted handoff, permanent warehouse
   exclusion, fresh auth export, keyed raw/auth/curated deletion, GA submission,
   aggregate rebuild, and completion verification all succeed;
7. a delayed keyed upload is removed by the recurring sweep and does not
   repopulate reporting;
8. identifier-free reporting remains queryable and reconciled after aggregate
   rebuild;
9. an automatic-only installation that cannot be linked follows the documented
   retention limitation rather than being falsely reported as deleted;
10. released older clients and bridges continue normal operation because the
    new route/state is additive, while revoked credentials eventually stop at
    their existing expiry boundaries.

Required client/platform matrix: iOS and Android production-shaped builds;
password plus every configured OAuth/native sign-in path for cancellation;
current packaged bridge plus one older public bridge for revocation compatibility.

## Rollout

1. Deploy auth scheduling before exposing the client action.
2. Deploy and drill the due-account finalizer and analytics target processor.
3. Publish legal updates.
4. Enable client UI only after both jobs are scheduled, monitored, and have
   completed the non-production destructive drill.
5. Monitor pending age, retryable target count, finalizer failures, and privacy
   sweep freshness using bounded aggregate diagnostics only.

A kill switch may hide the client action during rollout, but it must not undo a
pending request, source tombstone, warehouse exclusion, or scheduled cleanup.

## Complexity Budget

New durable mutable parts:

1. one account-deletion variant on the existing User document;
2. one stable privacy request ID/deadline per pending account;
3. existing analytics deletion target/exclusion rows, reused rather than
   duplicated;
4. one scheduled auth finalizer and one scheduled analytics target processor.

No new per-user timers, process-local cancellation maps, access-token blacklist,
account-to-installation map, arbitrary aggregate command, operator-selected table
inventory, or reversible permanent analytics tombstone will be added.

The accepted 15-minute access-token lifetime is harmless to final cleanup
because sessions are revoked when scheduling occurs, 24 hours before the account
becomes due. All such tokens have expired before destructive finalization.

## Cleanup Assessment

- Add user-wide deletion methods only to repositories that own account-scoped
  documents; do not let the account service reach raw Mongo collections.
- Reuse bridge revocation, device-token cleanup, source suppression, privacy
  target handoff, aggregate rebuilding, and recurring delayed-upload sweep.
- Remove no existing privacy tombstone or compatibility path.
- No glossary migration is required. Finalization deletes every exact scope by
  `userId` regardless of repository/bridge-local type.
- Do not retain obsolete pending deletion requests after successful pre-deadline
  sign-in; the normal no-request user variant is authoritative.

## Material Risks

- **Irreversible cancellation race:** controlled by one server-time predicate;
  login cancels only strictly before the deadline, finalization processes only
  at/after it.
- **Partial cross-system deletion:** controlled through permanent source
  suppression first, stable request IDs, idempotent jobs, retryable states, and
  completion only after warehouse verification.
- **Analytics distortion:** direct aggregate edits are forbidden; fixed
  authoritative transforms rebuild from remaining keyed sources.
- **Data recreation:** refresh and bridge sessions are revoked at schedule time,
  and their 15-minute access-token window expires long before the 24-hour due
  time.
- **False legal promise:** copy says deletion begins after 24 hours and preserves
  disclosed provider/legal/automatic-data limitations.
- **Credential expansion:** auth API processes receive no BigQuery credentials;
  dedicated jobs keep metadata-server identities and closed dataset/table
  inventories.
