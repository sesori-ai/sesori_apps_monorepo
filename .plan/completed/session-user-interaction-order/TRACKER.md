# Running Session And Project User-Activity Order: Tracker

## Current State

- **Plan slug:** `session-user-interaction-order`
- **Implementation base:** `main` at `6ee94bfe`
- **Branch/worktree:** `session-user-interaction-order-verification`
- **Plan PR:** [#865](https://github.com/sesori-ai/sesori_apps_monorepo/pull/865)
- **Implementation PR:** [#883](https://github.com/sesori-ai/sesori_apps_monorepo/pull/883)
- **Series state:** Steps 1-3/4 merged; Step 4/4 implementation and cumulative
  L3 verification complete, with the final retirement PR ready to publish
- **Current step:** 4/4 completed; plan moved to `.plan/completed/`
- **Next action:** Publish and monitor the final Step 4 PR
- **Production source changes published:** Step 2 merged in PR #883; Step 4 is
  complete and ready for review

## Simplicity Contract

- [x] Zero new database columns or migrations.
- [x] Zero plugin API, classifier, or behavioral plugin changes; required
  shared-`Session` constructors may receive mechanical null arguments.
- [x] Zero dispatcher flags or bridge operation hooks.
- [x] Zero classifiers, correlation maps, dedupe collections, timers, locks,
  registries, or new lifecycle owners.
- [x] Reuse `last_user_message_at`, the existing unseen patch/cache/tick, and the
  existing client activity partition.
- [x] Name the transported fact `lastUserActivityAt`, not the stronger and
  misleading `lastUserInteractionAt`.
- [x] Accept generated user-side backend input as a bounded ordering heuristic.
- [x] Any implementation breach of this contract requires user approval.

## Locked Behavior

- [x] Running roots remain promoted.
- [x] Running means main-agent busy, retry, or background task; awaiting-only is
  not running.
- [x] Running roots order by existing user-side activity recency, then ID.
- [x] Null marker falls back to `time.updated`.
- [x] Inactive roots remain ordered by `time.updated`, then ID.
- [x] Projects with running roots order by latest running-root activity, then ID.
- [x] Awaiting-only does not promote a project; inactive project order remains
  timestamp, effective name, then ID.
- [x] Archived filtering and project/child ordering remain unchanged.
- [x] Auto-approved permission replies remain excluded by current orchestrator
  filtering.
- [x] Lifecycle-generated reply/rejection events can count when abort, thread
  close, process exit, or disposal clears pending input.
- [x] Automatic compaction/generated input can count when normalized as a user
  message; no plugin inference is added.
- [x] Cross-backend activity order assumes sufficiently aligned source clocks;
  skew is accepted instead of adding a bridge-observation scalar.
- [x] No analytics event.

## Delivery Steps

| Done | Step | Exact PR title | State |
|---|---|---|---|
| [x] | 1/4 | `🌱 [session-user-interaction-order] docs: simplify running session activity order [step 1/4]` | [PR #865](https://github.com/sesori-ai/sesori_apps_monorepo/pull/865) merged |
| [x] | 2/4 | `⚙️ [session-user-interaction-order] feat: order running sessions by user activity [step 2/4]` | [PR #883](https://github.com/sesori-ai/sesori_apps_monorepo/pull/883) merged |
| [x] | 3/4 | `🌱 [session-user-interaction-order] docs: define running session activity coverage [step 3/4]` | [PR #885](https://github.com/sesori-ai/sesori_apps_monorepo/pull/885) merged |
| [x] | 4/4 | `⚙️ [session-user-interaction-order] feat: order active projects and verify activity ordering [step 4/4]` | Implementation and L3 complete; ready to publish |

## Step 1 Checklist

- [x] Trace current running-prefix ownership and live list update seams.
- [x] Audit every write and projection of `last_user_message_at`.
- [x] Inspect PRs #474, #480, and #482 and identify the reverted complexity.
- [x] Confirm auto-approved permission replies are filtered before unseen routing.
- [x] Supersede the seven-step plugin-classifier design.
- [x] Supersede the second-scalar/dispatcher-hook proposal.
- [x] Define a four-step, zero-new-state implementation and accepted semantics.
- [x] Update plan-maker guidance with existing-state/history inspection.
- [x] Run fresh architecture plan review and apply valid findings.
- [x] Validate plan/tracker consistency and whitespace.
- [x] Commit, push, update PR #865 title/body, and resolve superseded discussion.

## Step 2 Checklist

- [x] Keep the stashed plugin event/origin prototype isolated; do not restore it.
- [x] Add nullable `lastUserActivityAt` to shared `Session` and the existing
  list-state patch; regenerate source.
- [x] Map existing persisted markers through bridge REST/detail and patch seams.
- [x] Pass null through ACP/Codex shared `Session` constructors without deriving
  or owning the bridge marker in plugin code.
- [x] Replace tracker boolean values with typed unseen/activity list state while
  retaining its existing cache, tick, subscription, and lifecycle.
- [x] Preserve marker values across live max-merge, REST seeding, and optimistic
  unseen updates.
- [x] Re-run `_emitFiltered` directly from the existing tracker subscription so
  an activity patch reorders an already-running session immediately.
- [x] Preserve the `SessionListLoaded` guard around that callback so seeded
  tracker replay cannot replace initial loading with an empty loaded list.
- [x] Replace alphabetical running order with activity/fallback recency and IDs.
- [x] Prove unchanged inactive, awaiting-only, archived, project, child, and
  auto-approval behavior.
- [x] Prove no schema/migration or behavioral production plugin diff.
- [x] Run focused analysis/tests and architecture implementation review.

## Step 3 Checklist

- [x] Update projects/sessions regression behavior and L3 exercise.
- [x] Reconcile turns and questions/permissions with existing marker inputs and
  auto-approval exclusion without claiming perfect human provenance.
- [x] Record representative-plugin scope and generated-input limitation.
- [x] Validate documentation consistency and whitespace.

## Step 4 Checklist

- [x] Run cumulative automated coverage and simulator/bridge session coverage.
- [x] Record omitted-marker fallback and live session reorder evidence.
- [x] Implement and verify matching running-project activity order.
- [x] Record complete cumulative project/session L3 evidence.
- [x] Keep plan active for partial/blocked/failed coverage unless explicitly
  accepted by the user.
- [x] Move plan to `.plan/completed/` only after required coverage passes.

## Decision Log

- **2026-08-13 initial plan:** seven steps with plugin facts, OpenCode/Codex
  classifiers, permission-origin contract, per-plugin mutable state, a new
  database marker, transport, client, regression, and retirement.
- **2026-08-13 user complexity review:** user rejected plugin-specific code and
  many mutable failure points for list ordering.
- **2026-08-13 first simplification:** narrowed the promise to Sesori-owned
  successful actions but still proposed a second scalar and dispatcher/create
  hooks.
- **2026-08-13 history audit:** PR #474 had already used
  `last_user_message_at`; PR #480 reverted its bridge ordering service and
  project-wide pipeline, not the underlying scalar. PR #482 established the
  client-owned running prefix used today.
- **2026-08-13 final simplification:** reuse the existing marker and current
  list-state delivery. Accept its broader user-side-activity semantics rather
  than recreating perfect origin provenance.
- **2026-08-13 clock-domain review:** accepted that source-clock markers can
  misorder sessions across skewed backends. A globally comparable observation
  marker would require the second persisted scalar this redesign intentionally
  removed; the effect is limited to running-list order and refresh cannot make
  incomparable clocks comparable.
- **2026-08-13 lifecycle/constructor review:** recorded that existing plugin
  lifecycle cancellation replies share the marker's normalized activity
  semantics. Allowed required null arguments at ACP/Codex shared `Session`
  constructors while preserving zero plugin behavior/classifier changes, and
  retained the loaded-state guard around live re-filtering.
- **2026-08-13 project-order follow-up:** carried the same durable marker and
  root updated time through the existing active summary, then reused the client
  comparator and tracker stream rather than adding project-owned ordering state.
- **2026-08-13 awaiting-only verification:** normal production root prompts stay
  running while awaiting input. The narrower ACP idle-permission state is
  representable and covered by focused ACP and client ordering tests; no
  synthetic backend flow or new test-only product machinery was added.
- **2026-08-13 row count scope:** retained the pre-existing broad active-summary
  count used by project-row presentation. Step 4 changes promotion and order;
  changing status wording for a normally unreachable root state would be a
  separate behavior change.

## Verification Log

- Original PR #865 was CI-green and bot-approved before redesign; the
  `ready-for-human-review` label was withdrawn after the user's complexity
  objection.
- Current audit confirmed the worktree has only plan/tracker/skill edits; the
  obsolete Step 2 plugin prototype remains isolated in stash
  `wip step 2 before simplification redesign` and must not be restored.
- No Dart/Flutter suite is required for this documentation/skill-only Step 1.
- Repository skill changes require an OpenCode restart before this running
  session consumes the updated instructions.
- Fresh `architecture-plan-review` approved the zero-new-state revision with no
  findings. It confirmed bridge repository/service ownership, orchestrator SSE
  projection, existing tracker lifecycle ownership, client comparator
  ownership, and additive shared-wire compatibility.
- Published the rewrite in `1ee36b9d0`, updated PR #865 to the exact four-step
  title and zero-new-state body, and confirmed GitHub has no unresolved inline
  review threads.
- Against the current Step 1 head, `git diff --numstat $(git merge-base
  origin/main HEAD) HEAD -- .plan/active/session-user-interaction-order/PLAN.md
  .plan/active/session-user-interaction-order/TRACKER.md
  .agents/skills/sesori-plan-maker/SKILL.md` reports PLAN `+337/-0`, TRACKER
  `+161/-0`, and skill `+31/-0`. The plan/tracker documentation total is 498
  lines within the recorded 350-650 target; total Step 1 additions including the
  skill are 529 lines. The same range passes `git diff --check`.
- PR #865 merged as `5954f397`; Step 2 started from `origin/main` at
  `ae7bd8f7` on `session-user-interaction-order-implementation` in the existing
  worktree.
- Shared full tests and analysis passed. Module core's 1,111 tests and strict
  analysis passed. Bridge app strict analysis and focused unseen, catalog,
  repository, and orchestrator tests passed. ACP and Codex mapper tests and
  strict analysis passed; mobile test-helper analysis passed.
- The final production diff adds no database schema or migration and no plugin
  behavior, classifier, or marker ownership. ACP/Codex changes are required
  null arguments at shared `Session` construction sites.
- `architecture-implementation-review` approved the full working-tree diff
  against `origin/main` with no findings. It confirmed additive mixed-version
  wire compatibility, bridge repository/service/orchestrator ownership, and
  client Layer-3 state/comparator ownership.
- No analytics event is added: this changes a derived list order rather than
  creating a distinct user action or authoritative product outcome.
- PR #883 merged as `2dcaeba5` with 16/16 checks passing. Review fixes kept
  activity merging inside `SessionUnseenTracker`, preserved authoritative REST
  unseen/project seeds, and received two architecture implementation approvals
  with no findings.
- Step 3 reconciles the three planned regression contracts and passes
  `git diff --check`. No Dart/Flutter suites are required for this
  documentation-only change.
- PR #885 merged as `3c1539e3`; Step 4 rebased onto `origin/main` at
  `0a9d50ef` on `session-user-interaction-order-verification`.
- Cumulative Step 4 automation passed before the project-order follow-up:
  `sesori_shared` 395 tests and analysis; `module_core` 1,114 tests and strict
  analysis; bridge app 2,593 tests and strict analysis; ACP 240 tests and strict
  analysis; Codex 361 tests and strict analysis.
- Local L3 evidence used the source bridge on macOS, the current app on an owned
  iPhone 17 iOS 26.5 simulator, and the registered Cursor plugin. Two Cursor
  root sessions were simultaneously reported `busy`; the phone promoted both
  above inactive roots and ordered the newer committed marker first. Bridge
  REST returned the corresponding non-null `lastUserActivityAt` values, and
  phone rows rendered running state and unseen badges consistently.
- While both Cursor roots remained `busy`, a second accepted prompt advanced the
  lower root's committed marker and moved it first on the phone without another
  status transition. This proves live marker-driven reordering rather than a
  refresh or activity-status edge.
- The current app was then connected to a bridge built from pre-feature commit
  `317b1ff1`. Its `/sessions` response omitted `lastUserActivityAt`; with both
  Cursor roots `busy`, the phone ordered updated time `1786629006860` before
  `1786629006823`, proving the documented old-bridge fallback.
- A real OpenCode question reached the supported pending-input UI/API path.
  OpenCode retains `busy` while a root question is unresolved. The ACP protocol
  can represent an idle permission request with `awaitingInput` true and all
  running facts false; the ACP activity test plus session/project ordering tests
  cover that exact non-promotion state.
- The iPhone simulator is the repository-prescribed local phone surface. The
  earlier claim that a physical or cloud phone was required was incorrect and
  has been superseded.
- User follow-up on 2026-08-13 identified that running projects should use the
  same activity policy. Step 4 now carries nullable durable marker/updated facts
  through `projects.summary`, reuses `SessionUnseenTracker` for live updates,
  and preserves inactive/awaiting-only project behavior.
- `origin/main` advanced to `c697f29e` with the standalone Material scaffold
  ancestry fix while Step 4 was under verification. The branch fast-forwarded
  to that commit; its scaffold test and all 14 focused project-row widget tests
  pass, and the owned simulator then rendered the project list without errors.
- `origin/main` later advanced to `6ee94bfe` with an unrelated standalone
  scaffold snackbar geometry fix. The branch fast-forwarded cleanly; all 14
  focused project-row widget tests and strict app analysis still pass.
- Current-wire capture showed a running root in `projects.summary` with
  `lastUserActivityAt` `1786632158425` and `updatedAt` `1786632158381`. The
  following auto-approved permission round trip left that marker unchanged,
  preserving the existing exclusion policy.
- With two Cursor projects already `Running`, project one initially led on marker
  `1786631136341` versus project two's `1786631130835`. A prompt accepted for
  project two advanced its committed marker to `1786631683136` and moved it
  first without a refresh or another status transition; the inactive project
  remained third and unseen rendering stayed correct.
- The current app then connected to the pre-feature bridge source at `317b1ff1`.
  Its session payloads omitted `lastUserActivityAt` and its active summaries
  omitted both new root ordering facts. With both projects `Running`, the phone
  ordered project updated time `1786632256672` before `1786632248500`, while the
  inactive project remained third, proving the two-project old-bridge fallback.
- Final cumulative verification passed: `sesori_shared` 396 tests;
  `module_core` 1,118 tests; bridge app 2,593 tests; ACP 240 tests; Codex 361
  tests; the 14 focused project-row widget tests; and strict analysis for every
  touched or downstream package. The three scaffold regression tests also pass.
- The final diff contains no schema, migration, or production plugin change;
  both staged and unstaged whitespace checks passed. Architecture plan and
  implementation reviews approved the project follow-up with no findings.
- Final correctness review found that an older cached tracker marker could mask
  a newer marker delivered by the reconnect summary. The comparator now takes
  the maximum of those two committed views before considering updated-time
  fallback, and the inverse stale-cache regression passes.
- Required coverage is complete, so this plan tree moved from `.plan/active/`
  to `.plan/completed/` in Step 4.
