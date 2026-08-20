# User Analytics Tracker

> This is the durable operational source of truth for resuming the rollout after
> context compaction. Keep it current after every cloud mutation, verification,
> PR merge, user approval, or newly discovered blocker. Never put secret values,
> Mongo credentials, raw account/install identifiers, or internal-user keys in
> this file; use only secret/resource references and aggregate evidence.

## Current Operational Checkpoint — 2026-08-06

### Resume headline (updated 2026-08-08)

- **The pipeline is live and fully autonomous.** Raw GA4 daily export -> daily
  auth snapshot (Cloud Scheduler `analytics-auth-export-daily`, 03:00 UTC) ->
  five staggered BigQuery transforms (04:00-05:00 UTC) -> reporting views.
  Every layer is guarded: export lease + cutoff monotonicity, keyed-publication
  epoch, control-freshness asserts, fail-closed pre-promotion validation.
- **All start boundaries, exclusions, IAM, image digests, and schedules are
  recorded in SOPS and verified live.** Deployed schema/report assertions pass.
- **Step 7 (privacy acceptance) and 7a (quota restore) completed 2026-08-08:**
  deletion drill passed end to end, sweep runtime + 06:00 UTC schedule live,
  quotas restored, evidence in SOPS.
- **What remains for Step 5 acceptance (exact procedures below):**
  1. Three-page Looker report + access verification (step 8; owner UI action).
  2. Verify first clean scheduled sweep success (quota resets ~07:00 UTC,
     after the 06:00 sweep — check 2026-08-09/10).
  3. Three-complete-day reconciliation, final evidence, flip
     `DEPLOYMENT_RECORD_STATUS` to configured, archive the plan (step 9;
     earliest ~2026-08-11).
- **No auth-server work is outstanding**; the worktree was removed. All
  analytics-repo work is merged to `main` (`2c4b06d` at last check).

### Verified controlled-table evidence (2026-08-06)

`events_20260804` qualifies as the first fully controlled property day:

- Location `europe-west3`; created `2026-08-05T07:16:56Z`; expires
  `2026-11-03T07:16:56Z` (90 days); 2,403 rows.
- Event span is exactly `2026-08-03T21:00:08Z` .. `2026-08-04T20:57:44Z`,
  matching the GMT+3 property day.
- No table-level ACL override; dataset ACL is restricted to the security-admin
  group, the Firebase measurement account, the transform reader, and the privacy
  writer. No intraday tables exist; the daily series is continuous through
  `events_20260805` (landed `2026-08-06T07:51:57Z`).
- `device.advertising_id` and `device.vendor_id` are absent in every row,
  confirming the configured ad-identifier posture from actual data.
- Legacy global `user_id` appears only in binaries `<= 1.6.0`; 1.6.1 and 1.7.0
  rows carry the custom `user_key` parameter instead. This matches the disclosed
  legacy limitation and is not a regression.

**Wire-type note (important for future queries):** `activation_schema_version`
is exported as a **string** (`"1"`), not an integer. The client emits it as a
string in `product_analytics_event.dart:242`, and the warehouse correctly reads
`parameter.value.string_value` and compares against `'1'` in
`sql/10_events_flattened.sql:130,244`. Querying `value.int_value` returns null
and must not be mistaken for missing instrumentation.

### Corrected release-provenance finding

The previously recorded premise that "Android build 444 proves production
readiness" was **wrong** and has been corrected:

- Build 444 is `v1.6.1-internal.444`. There is **no public `v1.6.1` release**;
  only `v1.6.1-internal.320` .. `v1.6.1-internal.462` tags exist, and
  `gh release view v1.6.1` reports "release not found".
- Instrumented `analytics_activation_ready` has been emitting since
  `2026-07-31`, but exclusively from internal builds.
- `v1.7.0` is the **first public release** carrying outcome instrumentation,
  published `2026-08-05T13:27:41Z` from release commit `af60989a`. Its first
  production-channel (`com.android.vending`) activation-ready event was observed
  at `2026-08-05T15:11:40Z`, inside the controlled `events_20260805` table.
- Therefore the behavioral start is anchored to the public release, not to the
  first controlled day and not to internal exposure.

### Approved and recorded boundaries

| Field | Recorded value | Basis |
| --- | --- | --- |
| `CONTROLLED_DAILY_TABLE` | `events_20260804` | First complete property day under all approved controls |
| `RAW_EXPORT_START_AT_UTC` | `2026-08-03T21:00:00Z` | Start of that controlled property day |
| `BEHAVIORAL_SCHEMA_V1_START_AT_UTC` | `2026-08-05T13:27:41Z` | Owner-approved on 2026-08-06: `v1.7.0` publish time, the earliest moment a production user could run instrumented code |

The owner chose publish time over the first observed production event
(`2026-08-05T15:11:40Z`) to maximize the usable cohort window. This stays honest
because the per-account "activation-capable exposure within 24 hours of account
creation" gate classifies accounts still running older binaries as
**unmeasurable**, never as non-activations.

`BEHAVIORAL_SCHEMA_V1_SOURCE_REF` was added to both the encrypted record and the
example dictionary (now 53 matching keys) to preserve this provenance. SOPS
stores comments in plaintext, so the rationale lives inside the encrypted value
rather than in a comment. `DEPLOYMENT_RECORD_STATUS` remains `unconfigured`.

### Completed cloud work (2026-08-06)

**Bootstrap.** `dart deploy.dart --bootstrap` created all six derived datasets in
`europe-west3` with reference schemas: `sesori_analytics_auth_private`,
`sesori_analytics_auth_access`, `sesori_analytics_privacy_private`,
`sesori_analytics_controls`, `sesori_analytics_curated`, and
`sesori_analytics_reporting`. Curated tables carry day partitioning and a
14-month expiration. Auth-dependent transforms were deliberately not applied.

**Permanent internal exclusions.** The team account registry lives at
`landingpage/src/lib/analytics/internal-users.ts` (`INTERNAL_USER_ID_HEXES`,
five Mongo ObjectIds). Their `user_key` values were derived locally with the
same construction as `sesori_auth_server/src/lib/product-analytics-user-key.ts`:
`HMAC-SHA256(base64-decoded pseudonymization key, lowercase 24-hex ObjectId)`
rendered as hex. The key was read directly from Secret Manager into an
environment variable and never written to disk; all derived plaintext artifacts
were deleted afterwards. No Mongo access was required.

Five rows were loaded into
`sesori_analytics_controls.permanent_internal_user_exclusions`, and
`sesori_analytics_auth_access.auth_permanent_internal_exclusions` resolves to
five active rows plus the one null-key freshness sentinel.

This also independently confirms the Cloud Run job's HMAC secret copy matches
the auth server's canonical secret, because keys derived from the Secret Manager
copy match live client-emitted `user_key` values in raw export.

**Impact evidence (why exclusions had to precede any build).** Across
`events_20260804`/`events_20260805`, internal accounts dominate current keyed
traffic: `analytics_activation_ready` 23 internal vs 9 external,
`session_message_sent` 31 vs 5, and `session_created_with_message` 9 vs 0.

**Derived IAM.** Dataset roles were applied with etag-protected ACL patches that
preserve existing entries, plus table-scoped grants for
`keyed_publication_guard` and deployment act-as on the transform identity only.
The controls dataset authorizes the cross-dataset auth-access view.

**Access probes: 18 of 18 passed**, including the load-bearing boundary.

| Identity | Allowed | Denied |
| --- | --- | --- |
| auth-export | auth-access exclusion view; own auth-private tables | underlying controls table, raw GA4, privacy-private, curated |
| transform | raw GA4, controls read, auth-private read, curated | privacy-private |
| looker | (reporting only) | raw, curated user rows, auth-private, controls, privacy-private, auth-access view |

Pre-grant probes were denied first, so each allow is attributable to its exact
grant. Temporary verifier `roles/iam.serviceAccountTokenCreator` bindings on the
auth-export, transform, and looker identities were removed after probing; only
the intended resource-scoped `roles/iam.serviceAccountUser` on the scheduler
identity remains, and all seven service accounts have zero user-managed keys.

### Resolved: deployed image was missing `dist/scripts` (2026-08-06)

The first real execution of `analytics-auth-export` failed at startup with
`Cannot find module '/app/dist/scripts/export-product-analytics.js'`. A
read-only in-image probe proved `/app/dist` existed while `/app/dist/scripts`
did not.

**Wrong first diagnosis, since retracted.** The failure was initially blamed on
the unanchored `.dockerignore` pattern `scripts/`, and PR #62 "anchored" it to
`/scripts/`. Testing with Docker's actual matcher (`moby/patternmatcher`)
disproved both that diagnosis and the reviewer-bot objections to it:

- `.dockerignore` patterns are context-root anchored by default; `scripts/`
  excludes only root `scripts/` and never matched `src/scripts/`.
- The bots' claim that Docker strips leading slashes is also false;
  `filepath.Clean` keeps them, so `/scripts/` matches nothing and would have
  silently stopped excluding the root operator scripts.
- A real Docker build from unmodified `master` contains
  `dist/scripts/export-product-analytics.js`.

PR #62 was closed with that evidence and the branch deleted; `.dockerignore`
remains unchanged.

**Actual root cause: operator error two days earlier.** The Cloud Build ran at
`2026-08-04T12:09:31Z`, but commit `9cc4953` was created at `12:07Z` and merged
later. The build context was uploaded from a working tree that did not yet
contain `src/scripts/`, and the resulting image was tagged `9cc495397158` as if
it were built from that commit. The image contains the analytics services and
repositories (present since `043ee9f`, July 29) but no scripts directory,
which matches a stale tree and rules out repository defects. `gcloud meta
list-files-for-upload` confirms today's tree uploads all of `src/scripts/`.

**Lesson recorded:** a digest pin guarantees immutability, not correctness.
Always verify the image contains its configured entry point before pinning.

**Remediation completed:** rebuilt `linux/amd64` from clean `master`
(`65b1173`), verified `dist/scripts/export-product-analytics.js` inside the
local build **and** inside the registry copy pulled back by digest, pushed as
tag `65b11732544e`, and re-pinned the Cloud Run job to
`sha256:2b07bd660a31adcc6edc6184ddc5c634d059411cec2b6496fab24e62bc073b01`.
`AUTH_EXPORT_IMAGE_REF` in the encrypted record still names the stale digest and
must be updated once the export publishes successfully.

Note for future sessions: while pushing the (now-closed) PR branch, a stray
`git checkout` reset the local branch and the first push published `master`
rather than the fix commit. It was recovered from the reflog. Always re-verify
`git ls-remote --heads origin` after pushing here.

### Open: first export run failed pre-promotion validation (2026-08-06)

Execution `analytics-auth-export-t4zsn` with the corrected image ran the full
pipeline: Mongo over static NAT, authorized exclusion view, 797 users scanned,
790 milestone rows staged, cohorts staged, and exactly the 5 internal users
detected. Every BigQuery job in the run succeeded.

It then failed inside `validateAndPromote`
(`src/repositories/product-analytics-export-repo.ts:372-384`), where seven
staged aggregate values must equal Node-side expectations before the atomic
promote transaction. The failure preserved the empty last-known-good state:
`auth_user_milestones` and `auth_weekly_setup_cohorts` remain empty, no run row
was published, the lease was released, and staging was cleaned up. The 790 vs
797 difference is expected arithmetic (5 internal plus opted-out/unknown
accounts stage no milestone row), so the mismatch is one of the seven checks —
plausibly `invalid_timestamps` (a milestone earlier than account creation in
legacy data) or a cohort/total mismatch. The script logs only a privacy-safe
`errorType`, so the failing value is not in logs.

**Diagnosed 2026-08-06 via read-only undelete.** The deleted staging tables
were recovered with snapshot-decorator `bq cp` copies (`diag_`-prefixed, inside
auth-private), the exact seven validation aggregates were re-run, and the
copies were dropped afterwards. Result:

| Check | Value | Verdict |
| --- | --- | --- |
| milestone_rows | 790 | matches expectation |
| duplicate_keys | 0 | pass |
| invalid_keys | 0 | pass |
| **invalid_timestamps** | **5** | **the failing check** |
| total/enabled accounts | 0 in the pre-failure snapshot; a 2-second-later snapshot confirms cohorts staged after milestones, so these passed at validation time | pass |
| invalid_cohorts | 0 | pass |

All five invalid rows are the same pattern: `notification_registered_at`
**precedes** `account_created_at`, by 205 s, 220 s, 3 047 s, 14 356 s, and
877 945 s (~10 days), on accounts created 2026-05-18 through 2026-07-15. Only
aggregate offsets and creation dates were inspected; no `user_key` values were
read.

This is legacy production data, not an export defect: `ActivationState`
backfill takes the **earliest device-token `createdAt`** as the notification
milestone, and five historical accounts have token records predating
`users.createdAt` (plausibly account re-registration flows that reused device
rows). The plan already prescribes the remedy philosophy: invalid timing is a
data-quality count excluded from time-bound metrics, never silently rewritten.
`occurredWithin` already treats negative elapsed as "not within N days", so the
cohort counters are unaffected; only the raw staged timestamp violates the
validation invariant.

**Resolved 2026-08-06: owner chose to correct the source records.** A read-only
Mongo scan (over the SOPS-decrypted production URI, database `oauth`) found
**six** offenders, not five — the sixth (205 s deficit, no surviving token) was
created after the export cutoff difference and surfaced in the full scan. All
six shared `backfilledAt=2026-07-16T09:50:15.753Z`: the July 16 activation
backfill copied each account's earliest device-token `createdAt` into
`mobileSetupAt`, and `DeviceTokenRepository.upsertToken` preserves a token
row's original `createdAt` when the same token re-registers, so tokens carried
over from pre-account app installs (or prior accounts on the same device)
predate `users.createdAt`.

Remediation: per-record guarded `updateOne` filtered on the exact current
`mobileSetupAt` (concurrent changes would abort), setting the earliest provable
same-owner observation that is >= account creation — the token row's
post-creation `updatedAt` where one existed, the earliest post-creation token
`createdAt` for the re-registered case, or the backfill observation instant for
the two accounts with no surviving token rows. All six matched and modified
exactly one document; a re-scan reports zero offenders. The corrupted values
and replacements are recorded in the session evidence, not here, because they
pair timestamps with account ObjectIds.

**First auth snapshot published 2026-08-06.** Execution
`analytics-auth-export-xf544` completed: 798 users scanned, 5 internal
excluded, 793 external, 791 enabled, 2 opted out, 791 milestone rows and 14
cohort rows published, run cutoff `2026-08-06T14:58:24Z`. Post-publish checks:
exactly one run row, `last_published_run_id` set, and zero internal user keys
present in the published milestone table.

### Recurrence prevention: PR #63 (2026-08-06)

The owner chose a two-layer guard so a future pre-creation milestone can never
stall the export again:

- **Source guard:** `ActivationService` and `ActivationBackfillService` ignore
  reconciled milestone evidence earlier than `users.createdAt` (a warning with
  the milestone kind only); the directly observed occurrence stands instead.
- **Export guard:** `ProductAnalyticsExportService` drops any remaining
  pre-creation milestone timestamp at staging and counts it in the new
  `preCreationMilestonesDropped` progress/report field — a data-quality count,
  never a rewritten timestamp. Cohort within-N-day counters were already
  unaffected.

PR: <https://github.com/sesori-ai/sesori_auth_server/pull/63>, branch
`fix/pre-creation-milestone-guard`, commit `7812834`. Full suite 570 pass /
0 fail / 1 skipped; lint/format clean. Three new tests cover the export drop
count, the service-time guard, and the backfill guard;
`tests/helpers/setup.ts#createUser` gained an optional `createdAt`.

**Shared-repository coordination (important for future sessions).** Another
agent works concurrently in the base checkout at
`~/.local/share/opencode/repos/github.com/sesori-ai/sesori_auth_server`, and
that base tree gets reset to `origin/master` underneath local work — an earlier
edit pass and a commit were silently wiped there. Never modify that base tree
directly. This PR's work lives in a dedicated Git worktree:

- **Worktree path:**
  `~/.local/share/opencode/repos/github.com/sesori-ai/sesori_auth_server/.worktrees/pre-creation-milestone-guard`
- **Branch:** `fix/pre-creation-milestone-guard` (pushed; PR #63)
- All future auth-server edits for this plan happen in that worktree until it
  is removed.

### Internal/test exclusion decision (2026-08-06)

Internal distribution builds report the same `app_version` as production, so
version alone cannot separate them. For example, iOS `1.7.0` activation-ready
events at `2026-08-05T06:27:29Z` precede the public release, and
`app_info.install_source` shows `manual_install` for internal iOS installs
versus `com.android.vending` for the Play channel. Install source is a useful
signal but is not a reliable substitute for the permanent exclusion list.

The owner approved populating the permanent internal/test key set in
`sesori_analytics_controls` **before** warehouse apply. Do not build curated or
reporting tables with an empty exclusion list.

### Repository and PR baselines

| Repository | Branch/tip | Relevant merged work |
| --- | --- | --- |
| `sesori-ai/sesori_analytics_platform` | `main` at `25dead8945db41789173c5793dfdf8dcb99efd6c`, synchronized with `origin/main` | #1 `9157cce` fixed activation cohort ordering; #2 `e8d6fc5` added the SOPS deployment record; #3 `2797f7b` fixed the cross-dataset authorized view; #4 `25dead8` recorded/provisioned the dormant auth-export runtime and exact runbook |
| `sesori-ai/sesori_auth_server` | `master` at `9cc495397158722e4bf9c7ee2ed10f4b17b59e26`, synchronized with `origin/master` | Existing analytics preference/export work remains deployed; #58 patched runtime dependencies and supplied the image source used by the dormant job |
| apps monorepo plan host | worktree branch `user-analytics-platform-repo`; its former upstream is gone | This active plan/tracker is the durable cross-repository execution record. Do not archive it until all Step 5 acceptance work is complete. |

Analytics PRs: <https://github.com/sesori-ai/sesori_analytics_platform/pull/1>,
<https://github.com/sesori-ai/sesori_analytics_platform/pull/2>,
<https://github.com/sesori-ai/sesori_analytics_platform/pull/3>, and
<https://github.com/sesori-ai/sesori_analytics_platform/pull/4>. Auth dependency
patch: <https://github.com/sesori-ai/sesori_auth_server/pull/58>.

### Approved and verified cloud boundary

- **Project/property/raw source:** GCP project `sesori-ai`, GA4 property
  `529377727`, raw dataset `analytics_529377727`, immutable location
  `europe-west3`.
- **GA4 posture:** two-month event/user-data retention; Google Signals, ad
  personalization, ad storage/user-data features, and native advertising
  identifiers are disabled/approved as recorded in the encrypted deployment
  evidence.
- **Cost controls:** billing is active, budget alerts are configured, and
  bounded BigQuery on-demand query quotas are configured.
- **Raw inventory:** ten daily tables, `events_20260725` through
  `events_20260803`; no intraday tables; every landed table and the dataset
  default have 90-day expiration. The restricted ACL and expected allow/deny
  probes passed.
- **Human access:** `analytics-admins@vespr.xyz` and
  `analytics-viewers@vespr.xyz` are the approved groups. Raw/private data is not
  granted to ordinary viewers.
- **Keyless service identities already created:** `analytics-deploy`,
  `analytics-auth-export`, `analytics-auth-suppress`, `analytics-transform`,
  `analytics-privacy`, and `analytics-looker` in project `sesori-ai`; no
  user-managed JSON keys exist.
- **Enabled runtime APIs:** Cloud Run, Cloud Scheduler, Secret Manager, Artifact
  Registry, Cloud Build, and Compute. Cloud Asset was enabled only for an IAM
  inspection attempt and disabled afterward.

### Dormant auth-export runtime inventory

| Resource | Exact state/reference |
| --- | --- |
| Cloud Run job | `analytics-auth-export` in `europe-west3`; Ready, zero executions, no scheduler trigger |
| Runtime identity | `analytics-auth-export@sesori-ai.iam.gserviceaccount.com`; keyless |
| Scheduler identity | `analytics-auth-scheduler@sesori-ai.iam.gserviceaccount.com`; keyless |
| Job execution policy | command `node dist/scripts/export-product-analytics.js`; one task; no retries; one-hour timeout; 1 CPU; 512 MiB; all egress through the dedicated VPC/NAT |
| Network | VPC `analytics-auth-export`; subnet `analytics-auth-export-europe-west3` (`10.42.0.0/24`); router `analytics-auth-export-router`; NAT `analytics-auth-export-nat` |
| Static egress | `34.185.207.107`; the user confirmed the DigitalOcean trusted-source configuration and dedicated read-only Mongo URI setup |
| Artifact repository | regional immutable repository `analytics-auth-export`; image `auth-server` |
| Pinned image | `europe-west3-docker.pkg.dev/sesori-ai/analytics-auth-export/auth-server@sha256:02f87d5635997744db377298d561f6f46403d8f076407d979c7df53c02de5045`, built from merged auth commit `9cc495397158722e4bf9c7ee2ed10f4b17b59e26` |
| Mongo secret | regional Secret Manager secret `analytics-auth-export-mongodb-uri`, user-managed version 1; never copy its value into this tracker |
| HMAC secret | regional Secret Manager secret `analytics-pseudonymization-key`, version 1 copied from the canonical auth production secret without writing plaintext to disk |
| Schedule declaration | encrypted record says `proposed_daily_03:00_UTC`; this is a proposal only, not an enabled schedule |

Runtime IAM is intentionally narrow:

- Runtime identity has access to the two required secret versions; future
  BigQuery permissions must remain confined to auth-private plus the authorized
  permanent-internal-exclusion view.
- Scheduler identity has job-scoped `roles/run.invoker` only. It has no project,
  organization, public, transitive-group, or user-managed-key access.
- `user:alex@vespr.xyz` has resource-scoped
  `roles/iam.serviceAccountUser` on only the scheduler identity for scheduler
  creation/update. Do not broaden it to project scope.
- Cloud Asset Policy Analyzer could not inspect the organization because the
  operator lacks the organization-level analyzer permission. The fallback
  direct project/folder/organization policy and group-membership inspection
  found no inherited scheduler privilege; keep this limitation in evidence.

Cleanup already completed:

- Deleted the auto-created default Compute VPC and permissive firewall rules
  after verifying no dependents.
- Removed temporary Cloud Build IAM after the pinned image was built.
- Deleted the unintended US multi-region Cloud Build staging bucket and its
  three source archives; the project currently has no GCS buckets. The runbook
  requires a disposable regional staging bucket for future source builds.
- A superseded pre-patch candidate image/tag remains because immutable-tag
  enforcement rejected deletion (`fa831d183ea0`). No runtime references it; the
  job is pinned to the patched digest above. Do not repoint the job to a mutable
  tag or the superseded digest.

Auth PR #58 verification: production build/lint passed, 532 tests passed with
one skip, runtime audit has zero high/critical findings, and the patched lockfile
contains `fast-uri` 3.1.5 plus patched runtime/development `brace-expansion`.
Six moderate audit findings remain non-blocking and must not be misreported as a
clean zero-finding audit.

### Restricted deployment record

- Source of truth:
  `sesori_analytics_platform/config/production.deployment.sops.env`.
- The encrypted file and field-only example have matching 53-key schemas after
  adding `BEHAVIORAL_SCHEMA_V1_SOURCE_REF`.
- Runtime/network/egress/image/Mongo-secret/HMAC-secret/scheduler/operator
  references are populated. Secret values are never recorded in Git.
- `DEPLOYMENT_RECORD_STATUS=unconfigured` remains correct.
- `CONTROLLED_DAILY_TABLE`, `RAW_EXPORT_START_AT_UTC`, and
  `BEHAVIORAL_SCHEMA_V1_START_AT_UTC` are now recorded with evidence;
  `RAW_TABLE_INVENTORY` and the raw remediation status/evidence were refreshed
  for the twelve-table inventory and the verified controlled day.
- Encrypt/decrypt round-trip was verified identical, and the committed diff was
  checked to confirm no plaintext value leaked through SOPS comments.
- No final deployment, transfer-config, deletion-drill, or Looker evidence exists
  yet. Do not mark the record configured until all acceptance gates below pass.

### Exact resume sequence

1. ~~**Qualify the first controlled daily table.**~~ Completed 2026-08-06;
   evidence recorded above.
2. ~~**Record the approved boundaries.**~~ Completed 2026-08-06; owner approved
   the `v1.7.0` publish-time behavioral start.
2a. ~~**Populate permanent internal/test exclusions.**~~ Completed 2026-08-06;
   five keys loaded and the authorized view verified.
3. ~~**Bootstrap, then IAM.**~~ Completed 2026-08-06; six datasets created and
   18/18 access probes passed.
3a. ~~**Restore a runnable image.**~~ Completed 2026-08-06; rebuilt from clean
   `master`, entry point verified in the registry copy by digest, job re-pinned
   to `sha256:2b07bd66…`. PR #62 was closed as wrong; no repository change was
   needed. `AUTH_EXPORT_IMAGE_REF` update in SOPS is pending the first
   successful publish.
3b. ~~**Diagnose the validation failure read-only.**~~ Completed 2026-08-06:
   `invalid_timestamps=5` was the failing check; six corrupted source records
   were corrected with guarded updates after owner approval.
4. ~~**Publish the first auth snapshot manually.**~~ Completed 2026-08-06.
   Executions `analytics-auth-export-xf544` (791 rows) and `…-m56v2` (798 rows,
   final image) both published with all five internal accounts excluded.
   Stale-overwrite probes verified directly against the deployed lease SQL:
   equal-cutoff and older-cutoff lease acquisitions are rejected by the
   `last_published_cutoff` assert. A newer-cutoff probe correctly acquired the
   lease (proving the guard distinguishes, not blanket-rejects) and was
   released with the exact runtime release statement; state returned to
   published/idle with the real snapshot untouched.
5. ~~**Apply the warehouse.**~~ Completed 2026-08-06. Full
   `dart deploy.dart --apply` ran all seven assets against production after
   fixing three deploy-time defects (analytics PR #6, merged `67be779`):
   millisecond-vs-microsecond control-timestamp equality (JS Date round-trip)
   in three transforms + data_quality + assertions; correlated
   INFORMATION_SCHEMA subqueries BigQuery rejects inside ASSERT (de-correlated
   via pre-aggregated LEFT JOIN); and per-asset maxBytesBilled rebalancing
   within the unchanged 1.75 GiB/day total (10:256, 15:128, 20:512, 30:384,
   40:512 MiB). Deployed schema/report assertions pass end to end.
   `data_quality` reports `auth_snapshot: ok`, `pipeline: ok(5)`,
   `schema: supported`; the five `review` quality counters are expected
   context, not defects: 209 internal-excluded rows, and 29 rows missing
   identity/schema/occurrence which are legacy `<=1.6.0` events without
   `user_key` correctly rejected at flattening. Curated tables now hold data:
   798 user_milestones, 14 activation_cohorts, plus flattened/login/activity
   rows for the small controlled window.

   **Quota deviation (operator approved, must be restored).** The apply
   exhausted the approved 2 GiB/day per-principal BigQuery quota
   (`QueryUsagePerUserPerDay`), and the owner approved a temporary raise to
   6 GiB (`gcloud alpha services quota update … --value=6144`). **Restore to
   2048 after rollout completes** to match `APPROVED_QUERY_QUOTAS` in SOPS;
   until restored, the encrypted record intentionally still states the
   approved 2048 value.
4a. ~~**Land the milestone-guard fix and refresh the runtime image.**~~
   Completed 2026-08-06. Auth PR #63 squash-merged as `54df943` after two
   review rounds (four valid bot findings implemented, including the
   append-last schema-order catch and reminder-eligibility alignment; three
   declined with rationale; every thread replied). Image rebuilt from merged
   `master`, entry point verified in the registry copy, Cloud Run job
   re-pinned to `sha256:120ad00b…`. The live runs table gained nullable
   `pre_creation_milestones_dropped` via `ADD COLUMN IF NOT EXISTS` before
   the counter-writing runtime executed. Verification export
   `analytics-auth-export-m56v2` published 798 milestone rows / 14 cohorts,
   `preCreationMilestonesDropped: 0`, run row shows the counter populated and
   the pre-migration run row reads NULL. Note: the auth merge auto-deploys the
   web server; the guard is production behavior from that deploy onward.
   Analytics PR #5 (`fac17e3`) mirrored the column in `00_datasets.sql`
   (allowed-not-required in assertions) and recorded the verified image digest
   plus the approved start boundaries in SOPS.
4b. ~~**Remove the auth-server worktree when its work is complete.**~~
   Completed 2026-08-06: `git worktree remove
   .worktrees/pre-creation-milestone-guard` executed and the local branch
   pruned; `git worktree list` shows only the base checkout.
5. **Apply the warehouse.** Run auth-dependent apply only after the valid snapshot
   exists. Deploy schemas, transforms, and reporting views; run deployed schema
   allowlist assertions, metric fixtures, dry-run/byte bounds, access probes,
   raw-to-curated/reporting reconciliations, and stale-snapshot abort/recovery.
6. **Enable schedules in dependency order.** Transform half completed
   2026-08-08: all five transfer configs created under
   `analytics-transform@…` (verified via `ownerInfo`), staggered
   04:00/04:15/04:30/04:45/05:00 UTC, state RUNNING. Creation-time catch-up
   runs raced on the shared keyed-publication guard and three aborted exactly
   as designed (serialized keyed publication); ordered manual re-runs then
   succeeded for all five, with `transform_state` watermarks aligned at
   `source_end_date=2026-08-06`. Two deploy-tool fixes merged: analytics PR #7
   (`2c4b06d`, empty transfer-config listing treated as zero configs).
   Auth-export scheduler completed 2026-08-08 with owner approval of the
   proposed cron: Cloud Scheduler job `analytics-auth-export-daily`
   (europe-west3), `0 3 * * *` Etc/UTC, OAuth as `analytics-auth-scheduler@…`
   with cloud-platform scope against the Run v2 `:run` URI, Content-Type
   header, 30s attempt deadline, `retryCount: 0`. Verified: job-scoped
   `roles/run.invoker` only, no project-level scheduler binding, zero
   user-managed keys. A forced scheduler run produced execution
   `analytics-auth-export-nszrn`, which published cleanly (838 scanned,
   5 internal excluded, 827 milestone rows, `pre_creation_milestones_dropped=0`
   in run metadata). Both halves of step 6 are done; the runbook's cadence is
   scheduler 03:00 -> transforms 04:00-05:00 UTC.

   Transfer-config resource IDs (all under
   `projects/1068630921159/locations/europe-west3/transferConfigs/`):
   | Transform | Config ID | Cadence UTC |
   | --- | --- | --- |
   | 10 events_flattened | `6a791f35-0000-247e-8a10-14223bbab0fe` | 04:00 |
   | 15 installation_login_daily | `6a77f54a-0000-23ae-abb3-b8db38f4b302` | 04:15 |
   | 20 user_activity_daily | `6a77d69d-0000-27af-97f2-3c286d4b98de` | 04:30 |
   | 30 user_milestones | `6a7ca678-0000-21a9-a3e9-582429bd9df8` | 04:45 |
   | 40 activation_retention | `6a91cb30-0000-28a2-9515-3c286d378eca` | 05:00 |

   Operational notes for future sessions: `bq ls --transfer_run` in this CLI
   version crashes; use the BigQuery Data Transfer REST API
   (`…googleapis.com/v1/<config>/runs`) with a bearer token instead. Manual
   catch-up runs are `bq mk --transfer_run --run_time=<now>` and must be
   triggered in dependency order (10 -> 15 -> 20 -> 30 -> 40) because
   concurrent keyed publications abort on the shared guard by design.
7. **Finish privacy acceptance.** Drill completed 2026-08-08; runtime
   provisioning still pending (see below).

   **Completed 2026-08-08 — IAM completion + probes.** Added the missing
   privacy-phase grants: suppress -> table-scoped dataEditor on
   `product_analytics_deletion_targets`; privacy-delete -> table-scoped
   dataViewer on `analytics_measurement_config`,
   `permanent_internal_user_exclusions`, `internal_exclusion_control_state`
   (transform SQL reads them during rebuilds) and dataEditor on
   `permanent_deletion_exclusions` + `product_analytics_privacy_sweep_state`;
   privacy-delete -> `metadataViewer` dataset ACL entry on reporting
   (INFORMATION_SCHEMA-only inventory). 15/15 impersonation probes passed,
   including auth-export DENIED on deletion targets, suppress DENIED on
   auth-private/controls, privacy-delete DENIED on reporting view data and on
   the internal-exclusion key table until the transform-read grant was added.
   Temporary operator tokenCreator bindings were removed after the drill;
   all 7 SAs re-verified keyless.

   **Completed 2026-08-08 — GA4 Admin access.** `analyticsadmin.googleapis.com`
   enabled on the project; owner granted `analytics-privacy-delete@…` GA4
   property Editor via the UI (Admin API grant was blocked: Google blocks the
   gcloud OAuth client from analytics scopes — "This app is blocked"). SA-token
   access to property 529377727 verified.

   **Completed 2026-08-08 — deletion drill (request
   `drill-2026-08-08-step7`).** Synthetic Mongo user
   (owner-approved; no real GA4 traffic) created in prod `oauth.users`,
   suppressed via operator-run `npm run suppress-product-analytics-export`
   under sops env + impersonated suppress-identity ADC: preference flipped to
   disabled (revision 2), `productAnalyticsExportSuppressedAt` set, handoff row
   written (HMAC key + legacy ID, status pending). Ordered evidence:
   dry-run planned 28 raw + 3 keyed + 3 rebuilds; first apply correctly
   `retryable/auth_export_not_ready` (tombstone-aware gate) after epoch-bumped
   exclusion insert; manual export `analytics-auth-export-8k7rl` published
   cutoff `2026-08-08T12:42:03Z` >= suppressedAt with the drill key absent from
   the snapshot; final apply `completed` (2 upstream GA submissions executed
   — legacy user_id + discovered pseudo-id, 56 raw + 7 keyed deletions, 6
   rebuilds, 65 verification checks, 0 violations), target status `completed`
   `2026-08-08T13:08:57Z`. Delayed-upload simulation: keyed row inserted into
   already-swept `events_20260805` under the privacy identity; next sweep
   discovered it (1 installation discovery, 2 upstream submissions), deleted
   it, and re-verified 0 violations; post-check confirms zero drill rows in
   raw/flattened/auth/curated. Sweep watermark `2026-08-06`. Drill Mongo user
   deleted afterwards with a guarded filter. The permanent exclusion row and
   completed target row intentionally remain (tombstones are permanent).

   **Quota deviations during drill (owner-approved), now restored.** Rebuild
   chains at production size exceeded the raised quotas twice; per-user went
   6144 -> 12288 -> 30720 MiB and per-project 10240 -> 24576 -> 40960 MiB to
   finish, then were restored to **2048** (approved per-user value; step 7a
   satisfied) and **10240** (original per-project override). Operational note:
   one full request-deletion pass costs roughly 8-10 GiB billed; a future real
   deletion request will need a temporary quota raise or a slimmer rebuild.

   **Interactive-auth lessons.** ADC expires with `invalid_rapt`; the fix is
   `gcloud auth application-default login` (plain, no --scopes: Google blocks
   analytics scopes for the gcloud client). The Dart privacy CLI's operator
   fallback shells out to `gcloud auth application-default print-access-token
   --scopes=bigquery,analytics.edit`, which works when ADC itself is an
   impersonated-SA credential file (scopes pass through to the SA token). The
   drill used a temporary impersonated-ADC swap, restored afterwards.

   **Suppression posture (owner decision 2026-08-08): operator-run, no
   dedicated Cloud Run job.** The provisioned regional Mongo secret is
   read-only, suppression must WRITE Mongo, and the command reads protected
   stdin, which Cloud Run jobs lack. Approved workflow: from the auth repo
   root, pipe `{"userId":…,"requestId":…}` into
   `sops exec-env env/app/prod.env 'GOOGLE_APPLICATION_CREDENTIALS=<impersonated-suppress-ADC>
   PRODUCT_ANALYTICS_GCP_PROJECT_ID=sesori-ai
   PRODUCT_ANALYTICS_PRIVACY_DATASET_ID=sesori_analytics_privacy_private
   PRODUCT_ANALYTICS_BIGQUERY_LOCATION=europe-west3
   npm run --silent suppress-product-analytics-export'`.

   **Completed 2026-08-08 — sweep runtime + schedule.** Analytics PR #8
   (`021ccf0`) added the Dockerfile (dart:3.12.2, copies only `sql/` +
   `privacy_deletion/`, no secrets); merged after green CI and a no-issue
   review. `linux/amd64` image built from clean merged `main`, pushed to new
   immutable regional repo `analytics-privacy` as `privacy-sweep@sha256:01c7b3…`,
   pulled back by digest and smoke-run. Cloud Run job
   `analytics-privacy-sweep` (europe-west3) pinned to that digest under
   `analytics-privacy-delete@…`, full production args, no adc-fallback flag,
   1 task / no retries / 1h timeout. Scheduler `analytics-privacy-sweep-daily`
   `0 6 * * *` Etc/UTC, OAuth as `analytics-auth-scheduler@…` (job-scoped
   invoker only), 30s deadline, no retries. A manual execution
   (`…-sweep-rclsk`) proved the metadata-server credential path
   (`credential_source: metadata_server`) but exited retryable on the
   exhausted project quota — expected after the drill; the sweep is
   idempotent and self-heals. **Note:** the BigQuery quota day resets at
   midnight Pacific (~07:00 UTC), one hour AFTER the 06:00 sweep, so the
   first scheduled run on 2026-08-09 may also be quota-retryable; verify the
   first clean success on 2026-08-10 or force one run after 07:00 UTC.
   `PRIVACY_SWEEP_SCHEDULE_UTC=0 6 * * *`, `PRIVACY_RUNTIME_REF`, and
   `DELETION_DRILL_EVIDENCE_REF` recorded in SOPS (analytics `main`
   `7357ee6`; schema still 53/53 keys).
7a. ~~**Restore the per-user BigQuery quota.**~~ Completed 2026-08-08 after the
   drill: per-user restored to the approved 2048 MiB and per-project to its
   original 10240 MiB override (verified via quota list).
8. **Build and restrict Looker.** Not started. Values already approved in SOPS:
   `DASHBOARD_OWNER=alex@vespr.xyz`,
   `DASHBOARD_VIEWER_GROUP=analytics-dashboard-viewers@vespr.xyz`,
   `LOOKER_SERVICE_ACCOUNT=analytics-looker@…` (already READER on reporting
   only; all six deny probes passed 2026-08-06). Page/source/filter/formula
   pins live in `sesori_analytics_platform/docs/reporting/looker-studio.md` —
   follow it exactly. Three pages: executive snapshot, activation, retention +
   engagement; sources are ONLY `sesori_analytics_reporting` views; every page
   carries the freshness/coverage/maturity strip from `data_quality`.
   Looker Studio setup is click-driven: the operator (owner) must create the
   report in the UI; the agent verifies sharing (viewer group only, no link
   sharing), records `LOOKER_REPORT_ASSET_REF` /
   `LOOKER_DATA_SOURCE_ASSET_REFS` / access-verification fields in SOPS.
9. **Close Step 5 only after acceptance.** Reconcile at least three complete
   event days (earliest possible: raw tables through `events_20260810`, so
   ~2026-08-11) through raw -> flattened -> daily activity -> reporting totals.
   Then: capture final evidence refs in SOPS (`DEPLOYMENT_EVIDENCE_REF`,
   `TRANSFORM_TRANSFER_CONFIG_REFS` — the five config IDs are in step 6 notes),
   flip `DEPLOYMENT_RECORD_STATUS` from `unconfigured` to configured, update
   the Release Evidence checklist below, and move this directory from
   `.plan/active/user-analytics/` to `.plan/completed/user-analytics/` in one
   commit. Per PLAN.md, W1/W4 retention rows mature later; the dashboard must
   truthfully show no mature cohort rather than fabricated zeros.

### Non-negotiable stop conditions

- Do not bootstrap derived datasets before a qualified controlled table and
  recorded timestamps exist.
- Do not execute auth export before its destination schemas/view and narrow IAM
  exist; do not create its schedule before a manual publish and reconciliation
  succeed.
- Do not run auth-dependent transforms without a fresh successful auth snapshot.
- Do not grant raw/private access to Looker or ordinary viewer principals.
- Do not use service-account JSON keys, broad project roles, mutable image tags,
  secret plaintext on disk, or unbounded/raw identifier evidence.
- A failed control, IAM denial probe, stale snapshot, schema assertion,
  reconciliation, or privacy drill stops rollout and remains observable. Preserve
  the last known-good published state while correcting the demonstrated issue.

## Plan State

- [x] Audit current analytics, product journeys, identity, privacy, auth
  milestones, and reporting constraints.
- [x] Agree that first successfully accepted user-authored message is full
  activation.
- [x] Agree on cross-repository scope, default-on optional authenticated product
  analytics with an in-app opt-out, a narrowly exempt/disclosed account-less
  login funnel, and Looker Studio. The design narrows the enforceable preference
  promise to account-linked Sesori product events, server reporting/supported-
  client synchronization, and explicitly disclosed login/legacy/Firebase-
  automatic-event limits.
- [x] First architecture pre-review rejected the draft as too vague about
  workspace/class/DI ownership, auth export composition, data flow,
  compatibility/rollback, and unavoidable GA4 raw fields.
- [x] Clarify those six areas directly in `PLAN.md`.
- [x] Run the one permitted second review. It passed the detail gate but
  rejected the architecture for upward/layer-skipping dependencies, auth/shell
  ownership leakage, backend classification, untruthful campaign persistence,
  splash networking, migration race, and unsafe rollback.
- [x] Apply those valid findings directly: explicit Client/API/Storage/
  Repository/Service/Listener layers, core preference API and lifecycle,
  dedicated server service, core hashing/route behavior, no harness event,
  SDK-acceptance result, post-splash readiness, write-first split, and forward-
  fix privacy floor. Per review rules, these corrections were not
  sent for a third approval pass; do not describe the revised plan as reviewer-
  approved.
- [x] Apply valid automated PR findings: write-ahead local disable and logout
  retry preservation, generation-safe/foreground preference reconciliation,
  cold-open buffering, strict campaign window, immutable export cutoffs,
  split auth/control IAM, dual start timestamps, outage-recoverable transforms,
  day-zero raw controls, and upstream GA4 retention/deletion.
- [x] Apply valid second-round findings: timely per-account foundation exposure,
  bounded first-message deferral, empty-to-non-empty milestones, account-scoped
  campaign completion, internal exclusion before auth aggregation, source
  deletion tombstones, honest never-keyed deletion limits, and earliest upgrade
  clearing of legacy Firebase global identity.
- [x] Apply materially valid third-round findings: auth-bound campaign retries,
  auth-restoration link classification, generic harness screen mapping, bounded
  preference deadlines, durable pending enable, repeatable daily monitoring,
  whole-process legacy-ID-clear failure disclosure, deletion anti-join/recurring
  sweeps, and tombstone-aware export completion.
- [x] Compare the alternate plan and both PR review sets. Retain this plan's
  account-level identity, privacy, layering, curated warehouse, and authoritative
  activation seams; reject the alternate raw GA4 SQL after verified WAU,
  timestamp, cohort, identity, provider, and screen-schema defects.
- [x] Apply later product decisions: keep the foundation durable beyond the
  two-month readout; add bounded voice-assisted and pre-auth login metrics;
  explicitly drive Firebase screen reporting from GoRouter with automatic
  screen collection disabled; defer campaign attribution, notification
  conversion, and dedicated dashboard pages beyond the initial three-page
  report without discarding them from future work.
- [x] Review the considerable revised plan. The reviewer rejected its missing
  pre-logout owner, underspecified deletion command, preference polling,
  undeclared runtime-capability DI, and non-mirrored layer directories. Apply
  those valid findings directly: `SettingsCubit -> prepareForLogout`, concrete
  layered deletion commands/IAM, one read per auth generation plus explicit
  Settings refresh, immutable pre-phase-1 capability injected everywhere, and
  Foundation/API/Repository/Service/Layer-4 paths. Per review rules, do not claim
  the corrected version was re-reviewed/approved.
- [x] Apply valid current PR findings: add internal JSON PUT support; add server
  revision compare-and-set/idempotency so timed-out older enable cannot overwrite
  newer disable; move monitoring activity to a route-visible listener; defer the
  obsolete notification finding with its feature; and narrow recurring upstream
  deletion to future keyed uploads without a persistent account-install map.
- [x] Apply valid follow-up findings: retain fixed measurement-critical
  candidates until preference resolves without prematurely consuming guards;
  verify permission `ApiResponse` before success; sweep all permanent deletion
  tombstones for newly landed keyed rows; label account-less login diagnostics
  as including non-excludable internal/test traffic; move existing onboarding
  events to confirmed platform outcomes; add PR-4 activation-capable readiness;
  and begin Apple login analytics before the native authorization sheet.
- [x] Apply valid next-round findings: preserve authoritative occurrence time
  through deferred delivery; retain OAuth provider across interruption/resume;
  persist voice-assisted origin in typed in-memory drafts; disclose both two-
  month upstream and 90-day exported-raw retention; and make internal/test
  exclusions permanent so rebuilds never resurrect historical traffic.
- [x] Apply valid latest findings: clear legacy Firebase identity in foreground
  and FCM-background execution; scope readiness to each authenticated generation;
  service-own already-observed deferred session activity; isolate deletion
  targets from auth-export access; and overlap deletion sweeps across mutable
  late-arrival partitions plus watermark gaps.
- [x] Apply the 2026-08-19 product decision superseding the client identity
  cleanup above: remove the migration and its runtime failure state. Current
  clients never call Firebase's global `setUserId`; account identity exists only
  as the typed `user_key` parameter on authenticated product events.
- [x] Replace enumerable ObjectId SHA-256 join keys with server-derived
  HMAC-SHA-256. The authenticated preference API carries the derived key to
  clients; one shared secret serves web/export/suppression runtimes, while a
  deletion-only legacy SHA-256 value remains restricted to privacy targets for
  pre-migration Firebase `user_id` deletion.
- [x] Decompose Step 3.C's lifecycle implementation in supplemental PR #619,
  merged as `b65cb974` on 2026-07-30:
  keep `ProductAnalyticsService` as the delivery facade, move preference and
  account lifecycle into an injected collaborator with one disposal owner, and
  replace coordinated nullable fields with explicit snapshots/runtime states.
  Two implementation-review passes found premature local activation, hidden
  storage-read failure, split lifecycle ownership, and pass-through DI; all
  findings were applied directly. Per the two-pass cap, do not describe the
  final correction as reviewer-approved.
- [x] Apply the post-Step-3.D analytics preference UX decision: move the
  `Basic Usage Analytics` switch to the account/profile page, replace dense
  control disclosure with a short code/messages privacy hint, hide runtime
  implementation status, remove the permanent refresh row, and show one inline
  retry action only when preference loading or saving fails. Detailed limits
  remain in the privacy/legal/store disclosures.
- [ ] Complete the cloud preflight/start-boundary gate. Billing, budget, bounded
  query quotas, project/property/location, daily-only export, all ten landed raw
  tables, 90-day expiration, restricted raw IAM, GA4 privacy settings, groups,
  keyless service identities, scheduler connectivity design, and dashboard
  viewer group are verified and recorded. The remaining preflight item is the
  landed `events_20260804` evidence needed to approve the exact raw and
  behavioral start timestamps. Looker assets/ownership evidence remains a later
  acceptance item. Do not deploy transforms before that boundary is approved.
- [x] Implement the local Step 5 warehouse, reporting, deployment, and privacy-
  deletion assets. The final architecture pass approved neutral Google
  credential ownership, Service-owned deletion sequencing, one-shot auth
  readiness with external retry, and the layered API/Repository boundaries.
  Focused Dart formatting/analyze/privacy tests, render-only validation of seven
  SQL assets and five schedules, and `git diff --check` pass. The self-contained
  BigQuery metric fixture passed in `europe-west3` on 2026-07-31. Deployed-schema
  assertions remain deferred until an approved warehouse exists; no derived
  warehouse SQL, derived-dataset IAM, schedules, or dashboards have been applied
  to cloud resources.
- [x] Apply valid PR #641 review findings before migration: split first-run
  bootstrap from auth-dependent apply; make DDL dry-run limits explicit; bound
  schedule inventory and move schedule SQL out of argv; harden metadata/API
  timeouts and SQL boundaries; require fresh tombstone-aware request/sweep
  cleanup; serialize tombstones with keyed publication; guard transform
  watermarks; enforce ordered activation progression and schema-ready
  foundation; remove unsupported build dimensions; and extend focused
  Dart/BigQuery fixtures. A two-pass architecture
  review moved deployment policy to orchestration and freshness policy to the
  deletion Service, then approved the revised boundaries. All 34 bot review
  threads received `[Sesori reply]` assessments before the code moved. PR #650
  follow-up review found that the resulting setup-order gate also reached
  headline activation/retention; the required standalone correction is tracked
  below and blocks warehouse apply.
- [x] Move the complete Step 5 warehouse/reporting/deletion implementation and
  its scoped Git history out of the apps monorepo into private repository
  `sesori-ai/sesori_analytics_platform`. Commit `743e5330` was the migration
  baseline; current standalone `main` is `25dead8` after merged PRs #1-#4. Root
  documentation is a short entry point with task guides and deep references
  under `docs/`; standalone format, analyze, privacy tests, render validation,
  and Markdown-link validation pass.

## Immediate Operational Action

- [x] Before merging/deploying Step 2, generate one canonical-base64 32-byte
  pseudonymization secret and configure it on the auth web runtime. The value was
  configured as a managed DigitalOcean production secret on 2026-07-29 and its
  SOPS-encrypted counterpart was added in auth commit `183604a`.
- [ ] Reuse the exact canonical pseudonymization secret across every required
  runtime. The dormant auth-export job now references version 1 of the regional
  `analytics-pseudonymization-key` secret copied from the canonical production
  value without plaintext on disk. The suppression/privacy runtime is not yet
  provisioned; do not rotate or replace the value without a coordinated re-key
  migration.
- [ ] Complete the existing-link contingency. Restricted project/raw IAM,
  **daily-only** export, all ten landed-table ACL/90-day expiration remediations,
  and the original preflight-miss evidence are complete. The only remaining
  start-boundary work is to qualify `events_20260804` and derive exact UTC
  `raw_export_start_at` and `behavioral_schema_v1_start_at` from evidence rather
  than backdating. Foundation-only and account-less login events do not qualify.

## Step 5 Cloud Setup And Go-Live

This setup is required Step 5 delivery work, not a prerequisite delegated to the
user and not a separate future project. The private
`sesori-ai/sesori_analytics_platform` repository supplies the reviewed
automation and runbook; apps-monorepo PR #641 was closed as superseded by that
repository.

After the user approves the restricted values and security/privacy decisions,
the implementing operator must execute and verify all unchecked work:

- [ ] Record the approved GA4 privacy posture, exact raw/behavioral UTC start
  timestamps, service identities, schedule owners, dashboard owner/viewer group,
  and refresh policy in the restricted deployment record.
- [x] Apply and verify two-month GA4 event/user-data retention, disabled Google
  Signals, ad personalization, ad storage/user-data features, and disabled
  Firebase native advertising identifiers; store the evidence in the restricted
  deployment record.
- [ ] Complete identity and warehouse IAM setup. The separate deployment,
  auth-export, auth-suppression, transform, privacy-deletion, Looker, and runtime
  scheduler identities are created and keyless; broad raw/project access has
  been removed and the scheduler identity's effective access is verified. The
  derived datasets do not exist yet, so their table/dataset IAM matrix,
  authorized-view ACL, and positive/expected-deny probes remain pending.
- [x] Before warehouse apply, correct and verify the standalone activation-
  cohort SQL/fixtures so headline activation, time-to-activation, and retention
  use authoritative `full_activation_at` independently of bridge/project order;
  reserve ordered bridge/project timestamps for setup diagnostics.
- [ ] Run the checked-in bootstrap-only deployment to create the same-location
  datasets and reference schemas; do not apply auth-dependent transforms yet.
- [ ] Provision and smoke-test the isolated auth export and suppression jobs,
  publish the initial auth snapshot, and verify its freshness and reconciliation.
  The isolated auth-export network, secrets, patched image, runtime IAM, and
  dormant Cloud Run job are provisioned; it has zero executions and no schedule.
  Destination bootstrap/IAM, first publish/reconciliation, overlap/failure
  checks, suppression/privacy runtime, and schedules remain pending.
- [ ] Run the auth-dependent warehouse apply only after that snapshot exists;
  apply schemas/views, run deployed-schema assertions, and reconcile the first
  complete raw/auth/curated/reporting data.
- [ ] Provision and smoke-test transform schedules, the request deletion command,
  and recurring privacy sweep; complete the non-production in-flight export and
  delayed-upload deletion drill.
- [ ] Build the restricted three-page Looker report, verify its data sources,
  maturity/coverage/freshness labels and sharing controls, then record asset IDs
  and go-live evidence.
- [ ] Keep Step 5 open until all setup, verification, deletion, access, and
  dashboard acceptance items pass; creating the analytics repository alone does
  not complete it.
- [ ] **Final plan action:** after every completion criterion and tracker item is
  complete, record final evidence and move the entire
  `.plan/active/user-analytics/` directory to
  `.plan/completed/user-analytics/`; commit the move and leave no active copy.

## Implementation Series

The total remains fixed at five rollout steps. Titles retain this slug and step
count across both repositories; Steps 3 and 4 are delivered as stacked PR
substeps. The former combined apps PR #610 was frozen and closed as superseded by
PRs #611-#614. Oversized outcome PR #629 was likewise closed and preserved as a
reference before rebuilding Step 4 as 4.A-4.D. Each replacement targets a
coherent review below roughly 1,200 added lines rather than accumulating review
patches in one umbrella diff.

| Step | Repository | Required title | Status | Depends on |
| --- | --- | --- | --- | --- |
| 1/5 | `sesori_auth_server` | `[user-analytics] Add write-first analytics preference [step 1/5]` | Deployed; 2026-07-29 backfilled 656/656 and two repeated validations reported zero missing | Deploy before backfill; Firebase export preflight is independent |
| 2/5 | `sesori_auth_server` | `[user-analytics] Enforce analytics preference and add export [step 2/5]` | PR #49 merged as `043ee9f` and deployed 2026-07-29; production health is `ok`, required-field enforcement is live, and the web HMAC secret is configured. The isolated auth-export job is now provisioned but dormant/unscheduled with zero executions; suppression/privacy runtime remains unprovisioned. | Step 1 deployed and repeated backfill validation at zero missing |
| 3.A/5 | apps monorepo | `[user-analytics] Add client analytics contracts and delivery [step 3.A/5]` | PR #611 merged as `3a181ee3` on 2026-07-30; frozen PR #610 remains superseded | Step 2 deployed |
| 3.B/5 | apps monorepo | `[user-analytics] Add durable analytics preference sync [step 3.B/5]` | PR #612 merged as `a792481b` on 2026-07-30 | Step 3.A |
| 3.C/5 | apps monorepo | `[user-analytics] Add account-linked analytics lifecycle [step 3.C/5]` | PR #613 merged as `53e9453f` on 2026-07-30, including supplemental lifecycle decomposition PR #619 | Step 3.B |
| 3.D/5 | apps monorepo | `[user-analytics] Integrate analytics settings and routing [step 3.D/5]` | PR #614 merged as `fb8cd0e8`; focused account-page UX follow-up PR #628 merged as `5e42bedc` on 2026-07-30 | Step 3.C |
| 4.A/5 | apps monorepo | `[user-analytics] Add bounded outcome analytics contracts [step 4.A/5]` | PR #632 merged as `e3e6b6e7` on 2026-07-31; oversized PR #629 remains closed as superseded | Step 3.D released |
| 4.B/5 | apps monorepo | `[user-analytics] Instrument account-less login outcomes [step 4.B/5]` | PR #634 merged as `5223c27d` on 2026-07-31 | Step 4.A |
| 4.C/5 | apps monorepo | `[user-analytics] Instrument activation and voice outcomes [step 4.C/5]` | PR #633 merged as `c662a639` on 2026-07-31 | Step 4.B |
| 4.D/5 | apps monorepo | `[user-analytics] Instrument visible engagement outcomes [step 4.D/5]` | PR #631 merged as `671c67ed` on 2026-07-31 | Step 4.C |
| 5/5 | private `sesori_analytics_platform` + cloud | `[user-analytics] Add BigQuery metrics and Looker dashboards [step 5/5]` | Analytics `main` is `25dead8` after merged PRs #1-#4; auth dependency patch #58 is merged as `9cc4953`. GA4 privacy, billing/budget/quota, restricted raw IAM/expiration, keyless identities, and dormant isolated auth-export infrastructure are prepared. No derived warehouse mutation or job execution has occurred. Rollout is blocked only at the first controlled daily-table/start-timestamp gate before bootstrap, then continues through auth snapshot, full apply, schedules, deletion drill, and Looker acceptance as detailed above. | Steps 2 and 4.D, qualified `events_20260804`, split auth-private/privacy-private/control IAM |

## Release Evidence

- [x] Write-first auth preference endpoint deployed; backfill repeatedly reports
  zero missing; required-field enforcement deployed.
- [ ] Auth export staging validation reconciled and daily schedule enabled.
- [ ] Mobile analytics release available to production users.
- [ ] Local disable survives restart/logout, delayed stale auth work cannot
  reactivate another account, and clients observe remote preference changes on
  next auth generation/process start or explicit online Settings refresh without
  polling.
- [ ] A fresh release install starts with Firebase collection off, enables only
  after consent and release/Test Lab eligibility, emits nothing in debug/profile
  or Firebase Test Lab, and never assigns Firebase's global user ID.
- [ ] First production full-activation event joins its auth milestone row and a
  timely per-account `analytics_activation_ready` exposure from the outcome
  release; foundation-only binaries remain unmeasurable and preference-unknown
  first message is deferred rather than lost.
- [ ] Typed/voice-assisted successful messages and content-free transcription
  completions appear without transcript/audio-derived data; account-less login
  aggregates contain only pinned provider/failure dimensions and no user key.
- [ ] Every GoRouter route maps to the pinned screen enum and produces one
  canonical custom screen event plus one matching Firebase-native mirror, with
  automatic screen reporting disabled and no concrete route identifiers.
- [ ] Three complete event days reconcile through reporting models.
- [ ] Stale auth snapshot abort/recovery and GA4 upstream deletion drills pass,
  including in-flight export ordering, delayed offline upload/recurring sweep,
  flattened non-repopulation, aggregate rebuild, and explicit transient/future-
  automatic-only/never-keyed coverage limits; recurring enforcement is claimed
  only for future keyed uploads, and responses distinguish two-month upstream
  retention from 90-day restricted exported-raw expiration.
- [ ] Three-page Looker permissions, complete-period defaults, sample sizes,
  coverage, cohort maturity, and freshness verified.
- [ ] First W1 cohort matured and reviewed.
- [ ] First W4 cohort matured and reviewed, or dashboard truthfully shows no
  mature cohort yet.
