# Running Session User-Activity Order: Tracker

## Current State

- **Plan slug:** `session-user-interaction-order`
- **Implementation base:** `main` at `88059e200`
- **Branch/worktree:** `session-order-ux-review`
- **Plan PR:** [#865](https://github.com/sesori-ai/sesori_apps_monorepo/pull/865)
- **Series state:** Step 1/4 rewritten around existing persisted state
- **Current step:** 1/4 in review; no production source published
- **Next action:** monitor Step 1 review and merge readiness
- **Production source changes published:** none

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
| [ ] | 1/4 | `🌱 [session-user-interaction-order] docs: simplify running session activity order [step 1/4]` | [PR #865](https://github.com/sesori-ai/sesori_apps_monorepo/pull/865) open; rewritten |
| [ ] | 2/4 | `⚙️ [session-user-interaction-order] feat: order running sessions by user activity [step 2/4]` | Pending |
| [ ] | 3/4 | `🌱 [session-user-interaction-order] docs: define running session activity coverage [step 3/4]` | Pending |
| [ ] | 4/4 | `🌱 [session-user-interaction-order] docs: verify and retire session activity ordering [step 4/4]` | Pending |

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

- [ ] Discard the stashed plugin event/origin prototype; do not restore it.
- [ ] Add nullable `lastUserActivityAt` to shared `Session` and the existing
  list-state patch; regenerate source.
- [ ] Map existing persisted markers through bridge REST/detail and patch seams.
- [ ] Pass null through ACP/Codex shared `Session` constructors without deriving
  or owning the bridge marker in plugin code.
- [ ] Replace tracker boolean values with typed unseen/activity list state while
  retaining its existing cache, tick, subscription, and lifecycle.
- [ ] Preserve marker values across live max-merge, REST seeding, and optimistic
  unseen updates.
- [ ] Re-run `_emitFiltered` directly from the existing tracker subscription so
  an activity patch reorders an already-running session immediately.
- [ ] Preserve the `SessionListLoaded` guard around that callback so seeded
  tracker replay cannot replace initial loading with an empty loaded list.
- [ ] Replace alphabetical running order with activity/fallback recency and IDs.
- [ ] Prove unchanged inactive, awaiting-only, archived, project, child, and
  auto-approval behavior.
- [ ] Prove no schema/migration or production plugin diff.
- [ ] Run focused analysis/tests and architecture implementation review.

## Step 3 Checklist

- [ ] Update projects/sessions regression behavior and L3 exercise.
- [ ] Reconcile turns and questions/permissions with existing marker inputs and
  auto-approval exclusion without claiming perfect human provenance.
- [ ] Record representative-plugin scope and generated-input limitation.
- [ ] Validate documentation consistency and whitespace.

## Step 4 Checklist

- [ ] Run cumulative L3 automated and phone/bridge coverage.
- [ ] Record omitted-marker fallback and live reorder evidence.
- [ ] Keep plan active for partial/blocked/failed coverage unless explicitly
  accepted by the user.
- [ ] Move plan to `.plan/completed/` only after required coverage passes.

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
- Against the Step 1 publication baseline, `git diff --numstat $(git merge-base
  origin/main 49e762c8) 49e762c8 -- .plan/active/session-user-interaction-order/PLAN.md
  .plan/active/session-user-interaction-order/TRACKER.md
  .agents/skills/sesori-plan-maker/SKILL.md` reports PLAN `+298/-0`, TRACKER
  `+133/-0`, and skill `+31/-0`. The plan/tracker documentation total is 431
  lines within the recorded 350-650 target; total Step 1 additions including the
  skill are 462 lines. The same range passes `git diff --check`.
