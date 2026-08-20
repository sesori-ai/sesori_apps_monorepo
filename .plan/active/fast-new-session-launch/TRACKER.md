# Fast New Session Launch: Tracker

## Current State

- **Plan slug:** `fast-new-session-launch`
- **Implementation base:** `origin/main` at `8ee8a47b4` after Step 5 merge and
  subsequent mainline changes
- **Current branch:** `fix/codex-new-session-prompt-history`
- **Series state:** Steps 1-5/6 and standalone follow-up 4A merged; Step 6 began
  and its Codex and ACP blockers were split into approved standalone prerequisites
- **Current step:** implement and deliver the Codex release prerequisite
- **Next action:** merge the Codex prerequisite, deliver the ACP prerequisite,
  then rerun the complete current-build Step 6 matrix

## Locked Decisions

- [x] Sesori has a stable `ses_...` ID, but allocates it only after plugin
  creation; no pending stable route is added.
- [x] Send immediately renders detail-shaped launch UI on
  `/projects/<projectId>/sessions/new`.
- [x] Real route replacement waits for a durable, queryable Sesori session.
- [x] Metadata/title leaves the create-response critical path.
- [x] Initial prompt, attachment, and slash-command acceptance remain
  synchronous.
- [x] Dedicated worktrees initially use local curated `color-animal` names.
- [x] Pair collisions retry another pair; bounded exhaustion uses a secure
  suffix.
- [x] Late metadata may rename only the still-current unpublished initial branch;
  the worktree directory remains unchanged.
- [x] Failure automatically restores the filled composer; no automatic resend.
- [x] Because current server errors can occur after durable commit, every
  creation-originated error receives the duplicate-risk warning.
- [x] Back continues creation in the background.
- [x] Launch implementation stays backend-neutral; final matrix enumerates
  registered production plugins at execution time, and evidence-backed release
  defects remain standalone changes in their owning plugins.
- [x] Detail snapshot staging is out of scope; its loading presentation becomes
  visually continuous with launch.
- [x] Performance proof uses tests plus recorded manual timings, not telemetry.

## Complexity Guardrails

- [x] No database migration or pending-session persistence.
- [x] No new client-to-bridge wire route/event/model; the existing auth metadata
  POST gains only a typed request source.
- [x] No idempotency key, retry registry, polling, or newest-session heuristic.
- [x] No plugin-name branch or per-plugin production implementation in the six
  numbered launch PRs; the user approved separate Codex and ACP release blockers.
- [x] No optimistic transcript/prompt row or partial detail snapshot.
- [x] One client submission snapshot only; no hidden attachment cache.
- [x] One transient sealed restore state consumes that snapshot once; ordinary
  rebuilds never reapply attachments.
- [x] Background leave retains submission bytes only until the in-flight request
  settles; no additional cache or persistence extends that lifetime.
- [x] `PromptInput` passes the exact trimmed `ComposerDraft`; do not reconstruct
  voice provenance from an input-mode enum.
- [x] Preserve restoration snapshots and creation warnings across reconnect/
  discovery/options refreshes; clear only on consumption, explicit submission,
  or route exit as appropriate.
- [x] Incrementally encode attachment-bearing create requests with bounded
  event-loop yields through base64, inner JSON, and outer relay-envelope
  JSON/UTF-8; do not copy bytes through isolates or couple the Cubit to frame
  lifecycle.
- [x] A background failure after route exit must not restore shared draft state.
- [x] In-route failure restores both the Cubit's cached draft and repository
  before `PromptInput` remounts.
- [x] Preserve nullable title handoff; never convert missing title to `""`.
- [x] Extend authenticated `SesoriServerApi` for metadata, including token
  acquisition and one 401 refresh/retry; do not split one provider by use case.
- [x] One late-metadata future set; drain actual workflows, abort metadata HTTP on
  shutdown, and deadline-bound standalone token refresh.
- [x] Reuse that tracked workflow/family lane for branch refinement; add no
  branch registry, watcher, lock, or second mutation stream.
- [x] Generated branch failure cannot fail creation/title, and a switched,
  detached, upstream, or matching fetched remote branch is never renamed.
- [x] Keep the normalized event consumer alive through late-metadata drain, then
  fence mutation producers before draining its listener and event tails.
- [x] Shared encryption returns preallocated typed bytes without boxed integer
  framing; analyze/test shared crypto and bridge relay callers explicitly.
- [x] Generalize the existing deletion stream/listener; do not add a second
  local mutation stream; Orchestrator owns event dispatch decisions.
- [x] Delete obsolete overlay, metadata naming, preferred-name, enrichment, and
  tests in the same owning steps.

## Delivery Steps

| Done | Step | Exact PR title | State |
|---|---|---|---|
| [x] | 1/6 | `🌱 [fast-new-session-launch] docs: plan faster new-session launch [step 1/6]` | Merged in #894 |
| [x] | 2/6 | `🌿 [fast-new-session-launch] feat(bridge): use local workspace names [step 2/6]` | Merged in #908 |
| [x] | 3/6 | `🚧 [fast-new-session-launch] feat(bridge): return sessions before generated titles [step 3/6]` | Merged in #909 |
| [x] | 4/6 | `⚙️ [fast-new-session-launch] feat(client): open launching sessions immediately [step 4/6]` | Merged in #913 |
| [x] | 4A | `⚙️ Rename generated session branches after launch` | Merged in #923 |
| [x] | 5/6 | `🌱 [fast-new-session-launch] docs: define launch regression coverage [step 5/6]` | Merged in #928 |
| [ ] | Codex prerequisite | `⚙️ Preserve Codex prompt content in transcripts` | Implementation and verification in progress |
| [ ] | ACP prerequisite | `⚙️ Preserve ACP user attachments in transcripts` | Pending Codex prerequisite delivery |
| [ ] | 6/6 | `🌿 [fast-new-session-launch] test: verify faster new-session launch [step 6/6]` | Matrix started; blocked on standalone prerequisites and live-backend setup |

## Step 1 Checklist

- [x] Trace client create, navigation, detail loading, and retry behavior.
- [x] Trace bridge stable/backend IDs, creation timing, event ordering, and
  failure behavior.
- [x] Inspect history, tests, regression docs, and prior rejected provisional
  state machinery.
- [x] Agree product experience, naming, failure, plugin, cleanup, and measurement
  choices with the user.
- [x] Inventory causal cleanup and explicit deferrals.
- [x] Record complexity budget, compatibility, L3 boundary, and required matrix.
- [x] Run architecture plan review and apply valid findings.
- [x] Run plan consistency checks and `git diff --check`.
- [x] Commit, push, open Step 1 PR, and record its URL/review result.

## Step 2 Checklist

- [x] Generate one local lowercase ASCII `color-animal` branch/worktree slug.
- [x] Retry distinct pairs, occupied paths, and bounded secure suffix candidates.
- [x] Remove preferred metadata names/validation and overlap metadata/worktree work.
- [x] Preserve existing parent reuse and Git/non-Git fallback behavior.
- [x] Pass focused tests, strict analysis, cleanup audit, and architecture review.
- [x] Retain metadata response fields for Step 3's typed API replacement.

## Step 3 Checklist

- [x] Return the committed, queryable canonical `Session` after synchronous
  backend creation and first-input/slash-command acceptance.
- [x] Move generated metadata/title work off the response path and track the
  complete workflow through shutdown.
- [x] Add authenticated metadata API/repository layers, typed request/response,
  one 401 refresh/retry, HTTP abort/deadline, and bounded standalone refresh.
- [x] Apply generated title conditionally under the session-family lane so user
  rename/deletion wins and plugin rename failure retains the local title.
- [x] Generalize local mutations and listener ownership; Orchestrator maps title
  and deletion outcomes to existing backend-neutral events.
- [x] Delete the old metadata service/model/test, synchronous title tail,
  single-session enrichment, and unused plugin-session mappers.
- [x] Run codegen, focused tests, strict analysis, cleanup audit, analytics
  assessment, and architecture implementation review.

## Step 4 Checklist

- [x] Render detail-shaped launch status immediately while retaining the
  unresolved new-session route and guarded durable-ID replacement.
- [x] Preserve exact drafts, voice spans, commands, and attachment identities
  through one-shot in-route failure restoration with duplicate-risk copy.
- [x] Keep background creation independent and prevent late failure from
  restoring abandoned shared draft state.
- [x] Bound attachment/base64/request/envelope serialization and preallocate
  typed crypto/framing buffers without changing wire bytes.
- [x] Replace both launch/loading presentations with exported
  `PregoLaunchStatus`; delete the old overlay and direct `cue` dependency.
- [x] Regenerate Freezed/localization output and pass focused tests plus strict
  analysis across all touched owning modules and the downstream mobile app.

## Follow-up 4A Checklist

- [x] Restore typed generated `branchName` consumption while continuing to
  ignore the auth response's obsolete `worktreeName`.
- [x] Keep local branch/worktree creation and the canonical response independent
  from metadata latency or failure.
- [x] Rename only a root dedicated worktree still on its initial branch with no
  upstream or matching fetched remote ref; leave its directory and plugin working
  path unchanged.
- [x] Validate the generated ref, apply bounded secure collision fallback, and
  preserve the initial branch on every ineligible/failure outcome.
- [x] Persist durable/current branch facts under the session-family lane and emit
  existing `session.updated` with `titleChanged: false`.
- [x] Preserve independent title application and tracked shutdown ownership.
- [x] Run codegen, focused tests, strict analysis, cleanup/analytics assessment,
  and architecture reviews; commit, push, open the standalone PR, and monitor it.

## Step 5 Checklist

- [x] Reconcile `session-creation-and-options.md` as the authoritative launch,
  restoration, metadata, and dedicated-branch contract.
- [x] Reconcile durable title/branch list updates in
  `projects-and-sessions.md`.
- [x] Reconcile memory-only attachment restoration and bounded serialization in
  `attachments-and-images.md`.
- [x] Reconcile stable-worktree branch refinement in
  `diffs-and-source-control.md`.
- [x] Reconcile generated branch updates and stale-target fencing in
  `pull-request-monitoring.md`.
- [x] Inspect `session-turns.md`; leave it unchanged because new-session launch
  does not alter existing-session send, queue, or turn semantics.
- [x] Complete the implementation cleanup audit and retain only compatibility or
  independently used artifacts.
- [x] Validate the documentation-only diff with `git diff --check`.
- [x] Measure the merge-base Step 5 diff and reconcile it with the 80-180
  changed-line target.
- [x] Commit, push, open Step 5, monitor it, and merge it in PR #928.

## Step 5 Cleanup Audit

- [x] Obsolete preferred metadata naming, synchronous title-tail, single-session
  enrichment, deletion-only listener, loading overlay, and app-level `cue`
  dependency symbols have no production matches.
- [x] The bridge metadata model no longer consumes `worktreeName`; the auth
  response retains it only for released-bridge compatibility outside this repo.
- [x] Generated metadata activation, durable session/worktree/base facts, explicit
  user rename, normalized mutation delivery, and shared Prego launch status remain
  independently required.
- [x] No database migration, pending-session persistence, branch watcher/lock,
  retry registry, optimistic transcript, or detail snapshot was introduced.
- [x] No additional causal cleanup or newly dead implementation was found.

## Codex Release Prerequisite

- [x] Confirm the captured dedicated-worktree rollout contains the generated
  bridge context and bounded image input; no authored text was present to recover.
- [x] Add live app-server regressions for text-plus-image and attachment-only
  user messages.
- [x] Add rollout replay regressions proving authored text and bounded images
  survive while the bridge context remains hidden.
- [x] Keep local image paths unsupported and reuse the existing bounded Codex
  image mapper for client-safe attachment output.
- [x] Pass the complete Codex test suite, strict analysis, regression-doc update,
  and cleanup audit.
- [x] Pass architecture implementation review with no findings.
- [ ] Commit, push, open the standalone PR, and monitor it.

## ACP Release Prerequisite

- [ ] Preserve bounded initial and follow-up user attachments in shared ACP
  transcript events, including attachment-only input.
- [ ] Preserve user image/file blocks during cold history replay without exposing
  host paths.
- [ ] Keep the current partial-result `session/load` fallback unless a fresh
  Cursor protocol capture proves the request itself is invalid.
- [ ] Pass the complete ACP test suite, strict analysis, regression-doc update,
  cleanup audit, and any required architecture review.
- [ ] Commit, push, open the standalone PR, and monitor it.

## Cleanup Ledger

| Artifact | Decision | Owning step |
|---|---|---|
| Layer-skipping `MetadataService` and AI branch/worktree response fields | Replaced with shared typed request plus title/branch API response; obsolete worktree response remains ignored | 3 + 4A |
| Preferred-name API/validator and tests | Delete | 2 |
| Current `session-*` random fallback | Replace with color-animal plus bounded suffix fallback | 2 |
| Synchronous generated-title await | Deleted from response path | 3 |
| Single-session enrichment and unused plugin mapper helpers | Deleted | 3 |
| Deletion-only local mutation stream/listener | Generalized/renamed in place | 3 |
| Dimming `NewSessionLoadingOverlay` and overlay tests | Delete | 4 |
| Direct mobile `cue` dependency | Delete if no consumer remains | 4 |
| Friendly rotating-copy timer | Keep one instance in exported `module_prego` launch status | 4 |
| Composer submission bytes/text snapshot | Release on success/restoration or when a background request settles; never persist attachments | 4 |
| Auth response branch/worktree keys | Keep branch as live 4A input; defer worktree removal for released-bridge compatibility | 4A + external follow-up |
| Pending session/idempotency/detail staged load | Explicitly out of scope | Separate evidence-backed work |

## Verification Record

### Automated

- Step 1 merge-base size:
  `git diff --numstat "$(git merge-base HEAD origin/main)"...HEAD -- .plan/active/fast-new-session-launch/PLAN.md .plan/active/fast-new-session-launch/TRACKER.md`
- Informational result including this record, within the 750-900 target:
  `PLAN.md +751`, `TRACKER.md +144`, total `+895 / -0`.
- Step 2 package resolution: `dart pub get` from `bridge/app` passed.
- Step 2 focused worktree/creation tests passed, 64 tests.
- Step 2 strict analysis: `dart analyze --fatal-infos` from `bridge/app` passed
  with no issues.
- Step 2 architecture reviews: initial approved; follow-up API-placement finding applied.
- Informational Step 2 diff size against `origin/main`, including this record:
  `+272 / -226` (498 changed lines), within the 200-500 target.
- Step 2 review follow-up: expanded the local vocabulary to 52 colors and 79
  animals, updated regression documentation, passed 64 focused tests and strict
  analysis, and returned to 12/12 passing CI.
- Step 3 codegen completed for `bridge/app` and `shared/sesori_shared`.
- Step 3 broad bridge verification before prerequisite sync passed, 194 tests;
  the final post-sync core suite passed, 169 tests; shared request-model
  verification passed, 1 test.
- Step 3 strict analysis: `dart analyze --fatal-infos` passed in both
  `bridge/app` and `shared/sesori_shared` with no issues.
- Step 3 architecture implementation review found listener trigger ownership,
  then peer composition; both findings were applied. No third review was run
  because repository policy caps implementation review at two passes.
- Step 3 analytics assessment: no event added because the authoritative session
  creation outcome is unchanged and a UI proxy would not measure response-path
  latency.
- Informational final Step 3 diff measured against merge-base `f3c11b379`,
  self-inclusive of this tracker record: `+2003 / -1106` (3,109 changed lines),
  above the 950-1,450 target. Verification totals are 194 broad pre-sync bridge
  tests, 169 final post-sync core bridge tests, and 1 shared model test. The diff
  includes 496 generated-model lines, deletion of 370 obsolete metadata
  implementation/model/test lines, and broad lifecycle/race coverage; no
  unrelated production feature was added.
- Step 4 codegen completed for `client/module_core`; app localization generation
  completed with `flutter gen-l10n`.
- Step 4 integrated tests passed before prerequisite sync: 398 shared tests,
  65 focused bridge relay tests, 102 focused module_core
  creation/serialization/relay tests, 198 module_prego tests, and 136 focused app
  launch/detail/split tests.
- Final post-sync verification passed: 13 focused shared crypto/framing tests,
  65 focused bridge relay tests, all 103 focused module_core tests collectively
  after serializer/lifecycle reruns, 3 focused module_prego tests, and 137 focused
  app launch/detail/split tests.
- Step 4 strict analysis: `dart analyze --fatal-infos` passed in
  `shared/sesori_shared`, `bridge/app`, `client/module_core`,
  `client/module_prego`, and `client/app` with no issues.
- Step 4 analytics assessment: no event added because existing Cubit events
  already report authoritative creation success/failure; launch rendering and
  restored-composer consumption are presentation proxies.
- Step 4 architecture implementation review found premature pending-response
  ownership, attachment-sentinel ownership, and Step 5 documentation-boundary
  issues. All three were applied; the permitted second review approved the
  merged implementation with no remaining architecture findings.
- Informational final Step 4 diff measured against Step 3 head `0f3efcdd2`,
  self-inclusive of this tracker record: `+2289 / -605` (2,894 changed lines),
  above the 800-1,400 target and 1,500-line soft cap. The diff includes 511
  generated Freezed lines, causal state/restoration/serialization regression
  coverage, typed shared/bridge caller updates, and deletion of the obsolete
  153-line overlay; no unrelated production feature was added. Splitting would
  fragment one submission/serialization lifecycle across the fixed six-step
  series, so the cohesive implementation remains one PR.
- Step 4 PR: #913, based on `main` and monitored.
- Step 4 post-Step-3-merge handoff passed 177 focused app routing/launch/detail
  tests, 65 bridge relay/orchestrator tests, and strict analysis in `client/app`
  and `bridge/app`.
- Follow-up 4A codegen completed for `bridge/app`.
- Follow-up 4A focused verification passed, 179 tests before architecture fixes
  and 115 directly affected tests after them; the complete `bridge/app` suite
  passed all 2,635 tests.
- Follow-up 4A strict analysis: `dart analyze --fatal-infos` from `bridge/app`
  passed with no issues.
- Follow-up 4A architecture implementation review found API DTO leakage through
  the metadata and Git repository boundaries. Both findings were applied; the
  permitted second review approved the implementation with no remaining
  architecture findings.
- Follow-up 4A analytics assessment: no event added because there is no product
  decision or funnel step tied to background branch refinement, and branch names
  are explicitly prohibited analytics data.
- Informational follow-up 4A diff before delivery, measured against implementation
  base `f7bcdc63e`: `+1079 / -127` (1,206 changed lines), above the 350-700
  target. This includes 264 plan/tracker lines, 33
  generated model lines, and 582 test lines covering Git eligibility, collisions,
  response timing, conditional persistence, rollback, events, and shutdown.
- Follow-up 4A PR: #923, based on `main` and monitored.
- Follow-up 4A review fixes passed 144 focused tests, all 2,641 `bridge/app`
  tests, strict analysis, and `git diff --check`.
- Step 5 merge-base documentation scope:
  `git diff --numstat "$(git merge-base HEAD origin/main)" -- .plan/active/fast-new-session-launch/{PLAN,TRACKER}.md docs/regression/{attachments-and-images,projects-and-sessions,pull-request-monitoring,session-creation-and-options}.md`.
- Self-inclusive Step 5 result: `+125 / -33` (158 changed lines), within the
  80-180 target.
- Codex prerequisite red/green regressions passed for live `userMessage`
  projection and rollout replay. After rebasing onto PR #989, all 385 Codex
  package tests passed and `dart analyze --fatal-infos` passed with no issues.
  Architecture implementation review approved the staged diff with no findings.
- The prerequisite was rebased onto PR #989 (`8ee8a47b4`) and preserves its
  `clientId` to prompt-id correlation alongside user text/image normalization.
- Self-inclusive Codex prerequisite diff before delivery: `+443 / -78` (521
  changed lines), above the 250-450 target because 160 changed lines restore the
  stale plan/tracker and record Step 6 discovery. Production, regression tests,
  and feature documentation total 361 changed lines and remain within target.

### Manual matrix

Step 6 discovery began on the pre-prerequisite build. That build enumerated
OpenCode, Codex, Cursor, Claude Code, and Hermes Agent; the final run must
enumerate `knownPlugins` again from the exact build under test.

- Cursor, OpenCode, and Codex durable text creation passed. Cursor kept its
  dedicated worktree path stable while its branch refined, and OpenCode retained
  a text-plus-image prompt after reopen.
- Codex attachment-only dedicated creation exposed the bridge worktree envelope
  and omitted the image from the live user message. The backend rollout retained
  the bounded image; this evidence defines the standalone Codex prerequisite.
- Shared ACP mapping omitted user attachments from synthetic sent-prompt events
  and cold replay, defining the standalone ACP prerequisite. Cursor
  `session/load` also returned `-32602 Invalid params`, but the current request
  defect is not proven and receives no speculative protocol change.
- A cold OpenCode detail initially showed no messages until reopen. Recheck this
  against the merged prerequisite build before classifying it as another blocker.
- The old build showed a duplicate Claude initial prompt. Current main replaced
  that path in PR #937; live confirmation is still required.
- Claude live setup is blocked by an expired OAuth session. Hermes setup is
  blocked by its missing runtime/model-provider configuration.
- Wide/split layout, reduced motion, commands, failure/reconnect, compatibility,
  and matched baseline/final timing coverage remain unexecuted.

### Timing evidence

Provisional discovery-build values only; they are not matched final evidence:

- Cold Cursor in-place: durable create/route at `4.193s`; complete detail at
  approximately `6.2s`.
- Warm Cursor dedicated: durable create/route at `1.526s`; complete detail at
  approximately `5.5s`.
- Cold OpenCode attachment creation: durable create/route at `15.879s`; the
  initial detail snapshot was incomplete.

The final Step 6 run must record launch-view, durable-route, and complete-detail
durations for matched baseline/final conditions without prompts, names, paths,
identifiers, or attachment bytes.

## Plan Review

- **Reviewer:** `architecture-plan-review` sub-agent
- **Result:** Draft rejected on three under-specified ownership boundaries;
  findings applied directly without a second review, per repository policy.
- **Applied findings:** exact `OrchestratorSession` shutdown order; metadata
  API/repository layers; `module_prego` launch primitive with app-owned copy.
- **Consistency corrections:** one-shot attachment consumption, initial
  backend-title semantics, and penultimate-doc-step rationale.
- **Follow-up 4A review:** approved after clarifying that the deployed auth
  metadata contract requires sanitized `title`, `branchName`, and
  `worktreeName`; the bridge restores `branchName` consumption while continuing
  to ignore `worktreeName`.
