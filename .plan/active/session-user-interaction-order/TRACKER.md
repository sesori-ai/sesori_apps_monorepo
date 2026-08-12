# Running Session Interaction Order: Tracker

## Current State

- **Plan slug:** `session-user-interaction-order`
- **Implementation base:** `main` at `88059e200`
- **Branch/worktree:** `session-order-ux-review`
- **Series state:** Reviewed plan; three architecture findings applied; current
  main revalidated; no implementation started
- **Current step:** 1/7 ready for publication
- **Next action:** commit, push, and open the Step 1 plan PR
- **Source changes:** none
- **Tests run:** none

## Locked Product Behavior

- [x] Running roots remain promoted.
- [x] Running means main-agent busy, retry, or at least one background task;
  awaiting-input alone remains non-running.
- [x] Running roots order by genuine interaction recency, not title.
- [x] Prompt, slash command, manual answer/decision, and manual compaction count.
- [x] Automatic compaction, generated continuation/replay, auto approval,
  cancellation, assistant/tool/title activity do not count.
- [x] Null markers fall back to `time.updated` for old bridges and migrated rows.
- [x] Non-running, project, and child-task ordering remain unchanged.
- [x] The client owns visible ordering; the bridge transmits timestamp facts.
- [x] No analytics event is added.

## Architecture Decisions

- [x] One internal `BridgeSseSessionUserInteraction` fact carries backend
  session, optional display root, and optional occurred-at timestamp.
- [x] One required manual/automatic permission origin updates all internal
  plugin implementors in lockstep.
- [x] `OpenCodeUserInteractionTracker` owns raw message/part classifier state
  before compaction provenance is erased; the top-level plugin delegates.
- [x] `CodexUserInteractionTracker` owns bounded first-user-item observation and
  shares one `CodexGeneratedContextValidator` with history mapping; ACP/Cursor
  and Claude use their accepted bridge-owned write paths.
- [x] New nullable `last_user_interaction_at`; no backfill.
- [x] Existing ordered plugin-event processing and unseen timestamp write tail
  are reused; no new lock, tracker service, or bridge ordering snapshot.
- [x] Existing `session.unseen_changed` becomes the additive post-commit
  session-list patch; no new public SSE variant.
- [x] `SessionListService` owns live/session-update/REST marker max merges; the
  Cubit only validates, delegates, and emits.
- [x] Existing unseen semantics and `last_user_message_at` are retained.

## Accepted Limitations

- [x] Direct laptop OpenCode permission replies are unknown because upstream
  does not distinguish one manual decision from an `always` cascade.
- [x] Separate ACP/Cursor and Claude laptop processes are not observable by the
  bridge-owned process.
- [x] A theoretical OpenCode part-before-envelope sequence can miss one marker;
  no timer/history lookup is added against current upstream ordering.
- [x] Existing migrated rows remain null until a new authoritative interaction
  and use updated-time fallback meanwhile.
- [x] Server-paged root responses retain updated-time order; the current app
  fetches the complete list and owns activity-aware visible order.

## Delivery Steps

| Done | Step | Exact PR title | Changed-line target | State |
|---|---|---|---:|---|
| [ ] | 1/7 | `🌱 [session-user-interaction-order] docs: plan running session interaction order [step 1/7]` | 550-950 | Reviewed and validated locally |
| [ ] | 2/7 | `🚧 [session-user-interaction-order] feat(plugins): report genuine user interactions [step 2/7]` | 1,050-1,500 | Pending |
| [ ] | 3/7 | `🚧 [session-user-interaction-order] feat(bridge): persist session interaction recency [step 3/7]` | 4,500-6,500; generated migration cap exception | Pending |
| [ ] | 4/7 | `⚙️ [session-user-interaction-order] feat(protocol): publish session interaction recency [step 4/7]` | 700-1,300 | Pending |
| [ ] | 5/7 | `⚙️ [session-user-interaction-order] feat(client): order running sessions by interaction [step 5/7]` | 350-750 | Pending |
| [ ] | 6/7 | `🌱 [session-user-interaction-order] docs: define session interaction order coverage [step 6/7]` | 50-180 | Pending |
| [ ] | 7/7 | `🌱 [session-user-interaction-order] docs: verify and retire interaction ordering [step 7/7]` | 60-220 | Pending |

## Step 1 Checklist

- [x] Trace current client list ownership and running definition.
- [x] Trace persisted unseen/user-message timestamps and prove they are unsafe
  for ordering.
- [x] Inspect OpenCode message/part and compaction ordering, including synthetic
  continuation and overflow replay.
- [x] Inspect all registered production plugin write/reply paths.
- [x] Define additive REST/live compatibility and honest null migration.
- [x] Define deterministic client fallback and merge behavior.
- [x] Record cleanup, accepted limitations, L3 proof boundaries, and matrix.
- [x] Fix exact seven-step titles and line targets.
- [x] Run architecture plan review and apply valid findings.
- [x] Run `git diff --check` and plan/tracker consistency validation.
- [ ] Commit, push, and open the Step 1 PR for the confirmed reviewed series.

## Step 2 Checklist

- [ ] Add typed internal interaction event and permission origin.
- [ ] Update OpenCode, Codex, ACP/Cursor, Claude, bridge call sites, and test
  fakes in lockstep.
- [ ] Add `OpenCodeUserInteractionTracker` with bounded envelope/part classifier
  and lifecycle cleanup.
- [ ] Add `CodexGeneratedContextValidator` and bounded
  `CodexUserInteractionTracker`; inject the validator into history mapping.
- [ ] Prove automatic compaction continuation/overflow replay exclusions.
- [ ] Prove manual versus automatic/cancelled reply behavior.
- [ ] Prove internal event ID/display-root translation and no public wire event.
- [ ] Run focused plugin/interface/app tests and strict analysis.
- [ ] Run architecture implementation review.

## Step 3 Checklist

- [ ] Rebase schema version on current `main` without rewriting merged versions.
- [ ] Add nullable column and no-backfill migration.
- [ ] Generate all Drift snapshots/steps/source/helpers.
- [ ] Preserve marker in import/projection/create paths.
- [ ] Add monotonic repository/service write through existing ordered tail.
- [ ] Consume translated facts without changing unseen formula or markers.
- [ ] Test migration, null baseline, preservation, attribution, duplicates, and
  clock rollback.
- [ ] Run strict bridge app analysis/tests and architecture implementation review.

## Step 4 Checklist

- [ ] Add required nullable shared REST and known-SSE properties with dated
  compatibility comments.
- [ ] Regenerate shared source.
- [ ] Map root/detail/child/live projections and post-commit patches.
- [ ] Test omitted null, missing old field, old/new peers, and delete null.
- [ ] Run shared/bridge tests, strict analysis, and architecture implementation
  review.

## Step 5 Checklist

- [ ] Replace alphabetical running comparator with effective interaction
  recency and deterministic ties.
- [ ] Preserve inactive, awaiting-only, archived, project, and child policies.
- [ ] Add `SessionListService.applyInteractionPatch` and consume live marker
  patches through it.
- [ ] Add `SessionListService.mergeRestSnapshot` and max-merge session updates
  at the service boundary.
- [ ] Test new/old bridge, live reorder, stale fetch, auto-update stability, and
  project mismatch.
- [ ] Run module_core tests/analyze and affected mobile/desktop downstream
  validation.
- [ ] Run architecture implementation review.

## Step 6 Checklist

- [ ] Update `projects-and-sessions.md`.
- [ ] Update `session-turns.md`.
- [ ] Reconfirm registered plugin/platform matrix from production code.
- [ ] Validate documentation consistency and `git diff --check`.

## Step 7 Checklist

- [ ] Run cumulative L3 coverage at automated, live-plugin, and phone boundaries.
- [ ] Cover every supporting registered plugin and capability in the recorded
  matrix.
- [ ] Record privacy-safe evidence, versions, limitations, and cleanup.
- [ ] Keep plan active for partial/blocked/failed coverage unless the user
  explicitly accepts a reduction.
- [ ] Move `.plan/active/session-user-interaction-order/` to `.plan/completed/`
  only after required coverage passes.

## Architecture Review

- **Reviewer:** `architecture-plan-review`
- **Reviewed scope:** complete `.plan/active/session-user-interaction-order/`
  against current plugin, bridge, shared, database, and client architecture
- **Initial verdict:** rejected with three actionable ownership findings
- **Findings applied:** `OpenCodeUserInteractionTracker` now owns OpenCode
  classifier state; `CodexUserInteractionTracker` plus one
  `CodexGeneratedContextValidator` own Codex provenance; `SessionListService`
  now owns all marker merge transformations
- **Re-review:** not run; valid concrete findings were applied directly per
  repository policy

## Verification Log

- **2026-08-13 discovery:** worktree clean on `session-order-ux-review`; no source
  edits or tests before plan creation.
- **2026-08-13 planning:** repository instructions, current client/bridge/shared
  flow, registered plugins, generated OpenCode v1.17.7 models, upstream OpenCode
  compaction implementation, relevant PR history, and regression contracts
  inspected.
- **2026-08-13 architecture review:** initial draft rejected on three concrete
  ownership gaps. All were applied directly; no product scope, compatibility,
  migration, PR lifecycle, or regression-matrix finding remained.
- **2026-08-13 plan validation:** exact slug, seven-step denominator, titles,
  ordering, line targets, architecture record, regression matrix, and cleanup
  agree between plan and tracker. Both new files pass no-index whitespace
  validation; 929 documentation lines are within the revised 550-950 Step 1
  target. No Dart/Flutter suite was run for this documentation-only work.
- **2026-08-13 main refresh:** fast-forwarded the required branch/worktree from
  `ec479cef5` to `88059e200`. Schema v13, the four-plugin registry, client running
  comparator, and plan ownership seams remain unchanged. The bundled OpenCode
  runtime advanced to v1.18.11; its source retains envelope-before-part
  compaction events, manual/automatic provenance, synthetic continuation, and
  overflow replay. Main's attachment-mapping and regression-copy changes do not
  alter this plan. No architecture re-review was needed because no architecture
  or product decision changed.
