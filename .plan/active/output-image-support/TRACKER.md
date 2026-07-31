# Output Image Support: Tracker

## Current State

- **Plan slug:** `output-image-support`
- **Implementation base:** `origin/main` at
  `9d2c1e9e79ab80fa8824b9d803a74798eb71140d`
- **Series state:** Step 1/12 plan delivery in progress
- **Current step:** Step 1/12 — durable plan and tracker
- **Plan PR:** pending
- **Next action:** commit, push, and open the Step 1/12 plan PR

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
| [ ] | 1/12 | `investigate-opencode-image-support` | `[output-image-support] docs: plan output image support [step 1/12]` | 450-700 | In progress |
| [ ] | 2/12 | `output-image-support-codex-rollout-content` | `[output-image-support] refactor(codex): seal rollout content [step 2/12]` | 1,200-1,650 | Blocked on Step 1 merge |
| [ ] | 3/12 | `output-image-support-codex-rollout-envelopes` | `[output-image-support] refactor(codex): seal rollout envelopes [step 3/12]` | 900-1,350 | Blocked on Step 2 merge |
| [ ] | 4/12 | `output-image-support-codex-response-items` | `[output-image-support] refactor(codex): seal response items [step 4/12]` | 1,100-1,650 | Blocked on Step 3 merge |
| [ ] | 5/12 | `output-image-support-codex-image-events` | `[output-image-support] refactor(codex): type image-bearing events [step 5/12]` | 1,200-1,700 | Blocked on Step 4 merge |
| [ ] | 6/12 | `output-image-support-codex-live-images` | `[output-image-support] feat(codex): surface live output images [step 6/12]` | 900-1,400 | Blocked on Step 5 merge |
| [ ] | 7/12 | `output-image-support-codex-image-history` | `[output-image-support] feat(codex): restore output image history [step 7/12]` | 1,100-1,600 | Blocked on Step 6 merge |
| [ ] | 8/12 | `output-image-support-acp-content-blocks` | `[output-image-support] refactor(acp): type content blocks [step 8/12]` | 1,400-1,900 | Blocked on Step 7 merge |
| [ ] | 9/12 | `output-image-support-acp-content-mapping` | `[output-image-support] refactor(acp): centralize tool content mapping [step 9/12]` | 1,100-1,600 | Blocked on Step 8 merge |
| [ ] | 10/12 | `output-image-support-acp-message-images` | `[output-image-support] feat(acp): surface live message images [step 10/12]` | 1,100-1,600 | Blocked on Step 9 merge |
| [ ] | 11/12 | `output-image-support-acp-tool-images` | `[output-image-support] feat(acp): surface live tool images [step 11/12]` | 1,200-1,700 | Blocked on Step 10 merge |
| [ ] | 12/12 | `output-image-support-acp-image-replay` | `[output-image-support] feat(acp): restore output image replay [step 12/12]` | 900-1,400 | Blocked on Step 11 merge |

## Exact PR Titles

1. `[output-image-support] docs: plan output image support [step 1/12]`
2. `[output-image-support] refactor(codex): seal rollout content [step 2/12]`
3. `[output-image-support] refactor(codex): seal rollout envelopes [step 3/12]`
4. `[output-image-support] refactor(codex): seal response items [step 4/12]`
5. `[output-image-support] refactor(codex): type image-bearing events [step 5/12]`
6. `[output-image-support] feat(codex): surface live output images [step 6/12]`
7. `[output-image-support] feat(codex): restore output image history [step 7/12]`
8. `[output-image-support] refactor(acp): type content blocks [step 8/12]`
9. `[output-image-support] refactor(acp): centralize tool content mapping [step 9/12]`
10. `[output-image-support] feat(acp): surface live message images [step 10/12]`
11. `[output-image-support] feat(acp): surface live tool images [step 11/12]`
12. `[output-image-support] feat(acp): restore output image replay [step 12/12]`

## Execution Rules

- Merge in numeric order. A successor may target its immediate predecessor while
  both are open, but each step must remain independently buildable and valid.
- Count additions plus deletions, including generated files and tests, against
  each PR base. Target 1,000-1,700; reassess at 1,700; soft ceiling 1,900.
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

- Step 1/12 (2026-07-31): plan and tracker authored; fixed slug, twelve titles,
  delivery order, and changed-line estimates cross-checked. The staged diff is
  581 changed lines and `git diff --cached --check` passes. Commit, push, and PR
  delivery remain pending; no Dart or Flutter suites were run for this
  documentation-only step.

## Findings And Plan Deltas

- **2026-07-31 — Twelve-step delivery:** Added a documentation-only Step 1/12
  and shifted the eleven implementation boundaries to Steps 2/12 through 12/12.
- **2026-07-31 — PR-size split:** Split the high-churn Codex rollout refactor
  into content, outer-envelope, and inner-response-item steps. Kept ACP DTO,
  message-state, tool-state, and replay materialization boundaries separate.
- **2026-07-31 — Split review corrections:** Ensured the Codex app-server parser
  and ACP mapper are production-consumed when introduced; made replay adopt the
  assistant tracker in the live-message step and the tool tracker in the
  live-tool step, leaving only replay materialization for the final PR.
