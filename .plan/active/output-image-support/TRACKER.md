# Output Image Support: Tracker

## Current State

- **Plan slug:** `output-image-support`
- **Implementation base:** `origin/main` at
  `9d2c1e9e79ab80fa8824b9d803a74798eb71140d`
- **Series state:** Step 1/13 plan PR open
- **Current step:** Step 1/13 — durable plan, tracker, and Plan Maker rules
- **Plan PR:** [#638](https://github.com/sesori-ai/sesori_apps_monorepo/pull/638)
- **Next action:** monitor Step 1/13 CI and review

## Plan Review

- **Verdict:** earlier drafts rejected with actionable findings; all findings
  applied directly; corrected plan not re-reviewed merely for approval
- **Reviewer:** `aristotle-plan-review`
- **Date:** 2026-07-31
- **Reviewed scope:** in-chat Codex/ACP architecture and multi-PR delivery drafts
- **Applied corrections:** sealed rollout state, typed app-server boundary,
  API/repository/tracker separation, explicit composition, one ACP tool-content
  policy, immediate production consumers, and symmetric live/replay tracker
  adoption

## Delivery Steps

| Done | Step | Branch | Exact PR title | Changed-line target | State |
|---|---|---|---|---:|---|
| [ ] | 1/13 | `investigate-opencode-image-support` | `[output-image-support] docs: plan output image support [step 1/13]` | 450-700 | [PR #638](https://github.com/sesori-ai/sesori_apps_monorepo/pull/638) open |
| [ ] | 2/13 | `output-image-support-codex-rollout-content` | `[output-image-support] refactor(codex): seal rollout content [step 2/13]` | 1,200-1,500 | Blocked on Step 1 merge |
| [ ] | 3/13 | `output-image-support-codex-rollout-envelopes` | `[output-image-support] refactor(codex): seal rollout envelopes [step 3/13]` | 900-1,350 | Blocked on Step 2 merge |
| [ ] | 4/13 | `output-image-support-codex-response-items` | `[output-image-support] refactor(codex): seal response items [step 4/13]` | 1,100-1,500 | Blocked on Step 3 merge |
| [ ] | 5/13 | `output-image-support-codex-image-events` | `[output-image-support] refactor(codex): type image-bearing events [step 5/13]` | 1,200-1,500 | Blocked on Step 4 merge |
| [ ] | 6/13 | `output-image-support-codex-live-images` | `[output-image-support] feat(codex): surface live output images [step 6/13]` | 900-1,400 | Blocked on Step 5 merge |
| [ ] | 7/13 | `output-image-support-codex-image-history` | `[output-image-support] feat(codex): restore output image history [step 7/13]` | 1,100-1,500 | Blocked on Step 6 merge |
| [ ] | 8/13 | `output-image-support-acp-content-blocks` | `[output-image-support] refactor(acp): type content blocks [step 8/13]` | 1,300-1,500 | Blocked on Step 7 merge |
| [ ] | 9/13 | `output-image-support-acp-content-mapping` | `[output-image-support] refactor(acp): centralize tool content mapping [step 9/13]` | 1,100-1,500 | Blocked on Step 8 merge |
| [ ] | 10/13 | `output-image-support-acp-message-images` | `[output-image-support] feat(acp): surface live message images [step 10/13]` | 1,100-1,500 | Blocked on Step 9 merge |
| [ ] | 11/13 | `output-image-support-acp-tool-images` | `[output-image-support] feat(acp): surface live tool images [step 11/13]` | 1,200-1,500 | Blocked on Step 10 merge |
| [ ] | 12/13 | `output-image-support-acp-image-replay` | `[output-image-support] feat(acp): restore output image replay [step 12/13]` | 900-1,400 | Blocked on Step 11 merge |
| [ ] | 13/13 | `output-image-support-retire-plan` | `[output-image-support] docs: retire output image support plan [step 13/13]` | 50-200 | Blocked on Step 12 merge |

## Exact PR Titles

1. `[output-image-support] docs: plan output image support [step 1/13]`
2. `[output-image-support] refactor(codex): seal rollout content [step 2/13]`
3. `[output-image-support] refactor(codex): seal rollout envelopes [step 3/13]`
4. `[output-image-support] refactor(codex): seal response items [step 4/13]`
5. `[output-image-support] refactor(codex): type image-bearing events [step 5/13]`
6. `[output-image-support] feat(codex): surface live output images [step 6/13]`
7. `[output-image-support] feat(codex): restore output image history [step 7/13]`
8. `[output-image-support] refactor(acp): type content blocks [step 8/13]`
9. `[output-image-support] refactor(acp): centralize tool content mapping [step 9/13]`
10. `[output-image-support] feat(acp): surface live message images [step 10/13]`
11. `[output-image-support] feat(acp): surface live tool images [step 11/13]`
12. `[output-image-support] feat(acp): restore output image replay [step 12/13]`
13. `[output-image-support] docs: retire output image support plan [step 13/13]`

## Execution Rules

- Merge in numeric order. A successor may target its immediate predecessor while
  both are open, but each step must remain independently buildable and valid.
- Count additions plus deletions, including generated files and tests, against
  each PR base. Target no more than 1,500 changed lines per PR as a soft cap;
  split coherently first or record why an expected overage is unavoidable.
- Do not merge adjacent steps merely because one is small.
- Stop and update this plan before opening a PR that cannot fit its budget
  without separating required generated output, constructor callers, production
  behavior, or meaningful tests.
- Every production parser, mapper, and tracker must have a production consumer
  when introduced.
- Live and replay adopt shared ACP policy/state in the same PR even when replay
  image rendering is materialized only in Step 12.
- Generated files are regenerated, never hand-edited.
- Run focused tests, owning-package full tests, `dart analyze --fatal-infos`,
  `git diff --check`, and architecture implementation review as declared in
  `PLAN.md` for each implementation step.

## Verification Log

- Step 1/13 (2026-07-31): plan and tracker authored; fixed slug, thirteen titles,
  lifecycle boundaries, delivery order, and changed-line estimates
  cross-checked. The original staged diff was 581 changed lines and
  `git diff --cached --check` passed. Committed as
  `3cc4881e`, pushed, and opened as
  [PR #638](https://github.com/sesori-ai/sesori_apps_monorepo/pull/638). The PR
  now also codifies the requested Plan Maker lifecycle and 1,500-line soft-cap
  rules; its current diff is 617 changed lines and `git diff --check` passes. No
  Dart or Flutter suites were run for this documentation-only step.

## Findings And Plan Deltas

- **2026-07-31 — Lifecycle and line budget:** Set a 1,500 changed-line soft cap,
  retained plan delivery as Step 1/13, kept the eleven implementation boundaries
  as Steps 2/13 through 12/13, and added plan retirement as Step 13/13.
- **2026-07-31 — PR-size split:** Split the high-churn Codex rollout refactor
  into content, outer-envelope, and inner-response-item steps. Kept ACP DTO,
  message-state, tool-state, and replay materialization boundaries separate.
- **2026-07-31 — Split review corrections:** Ensured the Codex app-server parser
  and ACP mapper are production-consumed when introduced; made replay adopt the
  assistant tracker in the live-message step and the tool tracker in the
  live-tool step, leaving only replay materialization for the final
  implementation PR.
